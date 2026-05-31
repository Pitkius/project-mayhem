local QBCore = exports['qb-core']:GetCoreObject()

--- @class LtpdDoorSlab
--- @field doorHash number
--- @field modelHash number
--- @field coords vector3
--- @field heading number|nil

--- @class LtpdDoorGroupRuntime
--- @field id string
--- @field label string
--- @field doorType string|nil
--- @field interact vector3
--- @field interactDist number
--- @field slabs LtpdDoorSlab[]
--- @field entities number[]
--- @field entityScanDef table|nil

local doorGroups = {} ---@type LtpdDoorGroupRuntime[]
local doorLocked = {} ---@type table<string, boolean>
local dynStationDone = {} ---@type table<string, boolean>
local entitySnapshots = {} ---@type table<number, { coords: vector3, heading: number }>

--- Rakto ikonos dydis (DrawSprite – ~2.5× mažesnis nei anksčiau)
local LOCK_ICON_W = 0.016
local LOCK_ICON_H = 0.028

--- Kad dinaminis skeneris nedubliuotų durų, kurias valdome iš `PdDoorGroups`.
local manualPdSlabSkip = {}

local function rebuildManualPdSlabSkip()
    manualPdSlabSkip = {}
    for _, def in ipairs(Config.PdDoorGroups or {}) do
        for _, d in ipairs(def.doors or {}) do
            manualPdSlabSkip[#manualPdSlabSkip + 1] = {
                m = joaat(d.model),
                c = d.coords,
            }
        end
    end
    for _, def in ipairs(Config.EmsDoorGroups or {}) do
        for _, d in ipairs(def.doors or {}) do
            manualPdSlabSkip[#manualPdSlabSkip + 1] = {
                m = joaat(d.model),
                c = d.coords,
            }
        end
    end
end

local function isManualPdDoorSlab(modelHash, coords)
    for _, e in ipairs(manualPdSlabSkip) do
        if e.m == modelHash and #(coords - e.c) < 1.25 then
            return true
        end
    end
    return false
end

--- GTA saugos spynos sprites (`mpsafecracking`): lock_closed / lock_open
local PD_LOCK_TX = 'mpsafecracking'

CreateThread(function()
    RequestStreamedTextureDict(PD_LOCK_TX, false)
    while true do
        if HasStreamedTextureDictLoaded(PD_LOCK_TX) then break end
        Wait(50)
    end
end)

local function drawPdDoorLock(worldX, worldY, worldZ, locked)
    RequestStreamedTextureDict(PD_LOCK_TX, false)
    if not HasStreamedTextureDictLoaded(PD_LOCK_TX) then return end
    SetDrawOrigin(worldX, worldY, worldZ, 0)
    DrawSprite(PD_LOCK_TX, locked and 'lock_closed' or 'lock_open', 0.0, 0.0, LOCK_ICON_W, LOCK_ICON_H, 0.0, 235, 232, 255, 230)
    ClearDrawOrigin()
end

local function rememberEntitySnapshot(ent)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if entitySnapshots[ent] then return end
    entitySnapshots[ent] = {
        coords = GetEntityCoords(ent),
        heading = GetEntityHeading(ent),
    }
end

local function snapEntityToSnapshot(ent)
    local snap = entitySnapshots[ent]
    if not snap or not DoesEntityExist(ent) then return end
    SetEntityCoords(ent, snap.coords.x, snap.coords.y, snap.coords.z, false, false, false, false)
    SetEntityHeading(ent, snap.heading)
end

local function iconZOffset(doorType, isEntity)
    if doorType == 'bollard' then return isEntity and 0.55 or 0.62 end
    if doorType == 'garage_roll' then return isEntity and 0.38 or 0.42 end
    if isEntity then return 0.68 end
    return 1.02
end

local function isPdJobName(name)
    return name == Config.JobName
end

local function inferDoorTypeFromModelName(name)
    if not name or name == '' then return nil end
    local n = name:lower()
    if n:find('bollard', 1, true) then return 'bollard' end
    if n:find('barrier', 1, true) or n:find('prop_barrier', 1, true) then return 'barrier' end
    if n:find('parkingdoor', 1, true) or n:find('gardoor', 1, true) or n:find('garage_door', 1, true) or n:find('garagedoor', 1, true) then
        return 'garage_roll'
    end
    if n:find('gate', 1, true) or n:find('fence', 1, true) or n:find('fancegate', 1, true) or n:find('facgate', 1, true) then
        return 'barrier'
    end
    return nil
end

local function allDoorDynamics()
    local out = {}
    for _, d in ipairs(Config.PdDoorDynamics or {}) do
        out[#out + 1] = d
    end
    for _, d in ipairs(Config.EmsDoorDynamics or {}) do
        out[#out + 1] = d
    end
    return out
end

local function isEmsJobName(name)
    return name == (Config.EmsDoorJob or 'ambulance')
end

local function doorGroupService(groupId)
    if type(groupId) ~= 'string' then return 'police' end
    if groupId:sub(1, 8) == 'dyn_ems_' then return 'ems' end
    for _, def in ipairs(Config.EmsDoorGroups or {}) do
        if def.id == groupId then return 'ems' end
    end
    return 'police'
end

local function canUseDoorGroupClient(groupId)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not P.job.onduty then return false end
    local svc = doorGroupService(groupId)
    if svc == 'ems' then return isEmsJobName(P.job.name) end
    return isPdJobName(P.job.name)
end

local function canUseServiceDoorsClient()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not P.job.onduty then return false end
    return isPdJobName(P.job.name) or isEmsJobName(P.job.name)
end

local function quantKey(x, y, z)
    return math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5), math.floor(z * 100 + 0.5)
end

local function slabScriptHash(groupId, slabIndex)
    return joaat(('ltpd_man_%s_%d'):format(groupId, slabIndex))
end

local function dynSlabScriptHash(modelHash, x, y, z)
    local qx, qy, qz = quantKey(x, y, z)
    return joaat(('ltpd_w_%x_%d_%d_%d'):format(modelHash, qx, qy, qz))
end

local function vecInBounds(v, minV, maxV)
    return v.x >= minV.x and v.x <= maxV.x and v.y >= minV.y and v.y <= maxV.y and v.z >= minV.z and v.z <= maxV.z
end

local function groupIdExists(id)
    for _, g in ipairs(doorGroups) do
        if g.id == id then return true end
    end
    return false
end

local function findDoorGroupById(id)
    for _, g in ipairs(doorGroups) do
        if g.id == id then return g end
    end
    return nil
end

local function buildPdDoorProximityZones()
    local zones = {}
    for _, g in ipairs(doorGroups) do
        if g.interact then
            zones[#zones + 1] = { groupId = g.id, pos = g.interact, maxd = g.interactDist or 2.5 }
        end
    end
    for _, ex in ipairs(Config.PdDoorInteractExtras or {}) do
        if ex.groupId and ex.interact then
            zones[#zones + 1] = { groupId = ex.groupId, pos = ex.interact, maxd = ex.interactDist or 2.5 }
        end
    end
    return zones
end

local function pdDoorZoneIdleWaitMs(zones, pcoords)
    local wm = 650
    for _, z in ipairs(zones) do
        if #(pcoords - z.pos) < z.maxd + 14.0 then
            wm = 120
            break
        end
    end
    return wm
end

local function ensureDoorInSystem(dh, modelHash, x, y, z)
    local ok, reg = pcall(function()
        return IsDoorRegisteredWithSystem(dh)
    end)
    if not ok or not reg then
        AddDoorToSystem(dh, modelHash, x, y, z, false, false, false)
    end
end

local function findClosestObject(modelHash, coords, radius)
    local best, bestD = 0, (radius or 5.0) + 1.0
    for _, ent in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(ent) and GetEntityModel(ent) == modelHash then
            local d = #(GetEntityCoords(ent) - coords)
            if d <= (radius or 5.0) and d < bestD then
                bestD = d
                best = ent
            end
        end
    end
    return best
end

local function registerSlab(groupId, slabIndex, modelName, coords, heading)
    local modelHash = type(modelName) == 'string' and joaat(modelName) or modelName
    local dh = slabScriptHash(groupId, slabIndex)
    ensureDoorInSystem(dh, modelHash, coords.x, coords.y, coords.z)
    return { doorHash = dh, modelHash = modelHash, coords = coords, heading = heading }
end

local function alignSlabToWorld(slab)
    local ent = findClosestObject(slab.modelHash, slab.coords, 4.0)
    if ent == 0 then return end
    rememberEntitySnapshot(ent)
    slab.coords = GetEntityCoords(ent)
    if not slab.heading then
        slab.heading = GetEntityHeading(ent)
    end
    ensureDoorInSystem(slab.doorHash, slab.modelHash, slab.coords.x, slab.coords.y, slab.coords.z)
end

local function snapSlabEntity(slab)
    local ent = findClosestObject(slab.modelHash, slab.coords, 3.5)
    if ent == 0 then return end
    rememberEntitySnapshot(ent)
    if slab.heading then
        SetEntityHeading(ent, slab.heading + 0.0)
    end
    SetEntityCoords(ent, slab.coords.x, slab.coords.y, slab.coords.z, false, false, false, false)
end

local function applyStandardSlabLocked(slab, locked)
    local dh = slab.doorHash
    local force = true
    if locked then
        DoorSystemSetDoorState(dh, 4, false, force)
        pcall(function() DoorSystemSetOpenRatio(dh, 0.0, true, true) end)
        pcall(function() DoorSystemSetHoldOpen(dh, false) end)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 0.0, false, false) end)
        snapSlabEntity(slab)
    else
        DoorSystemSetDoorState(dh, 0, false, force)
        pcall(function() DoorSystemSetOpenRatio(dh, 1.0, false, false) end)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 30.0, false, false) end)
    end
end

local function getSlabIconPos(slab, doorType)
    local ent = findClosestObject(slab.modelHash, slab.coords, 3.5)
    if ent ~= 0 then
        local ec = GetEntityCoords(ent)
        return vector3(ec.x, ec.y, ec.z + iconZOffset(doorType, false))
    end
    return vector3(slab.coords.x, slab.coords.y, slab.coords.z + iconZOffset(doorType, false))
end

local function drawGroupLockIcons(g, pcoords, locked)
    local maxDist = (g.interactDist or 2.5) + 5.5
    for _, slab in ipairs(g.slabs or {}) do
        if #(pcoords - slab.coords) <= maxDist then
            local pos = getSlabIconPos(slab, g.doorType)
            drawPdDoorLock(pos.x, pos.y, pos.z, locked)
        end
    end
    for _, ent in ipairs(g.entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            local ec = GetEntityCoords(ent)
            if #(pcoords - ec) <= maxDist then
                drawPdDoorLock(ec.x, ec.y, ec.z + iconZOffset(g.doorType, true), locked)
            end
        end
    end
end

local function applyGarageSlabDoorSystem(slab, locked)
    local dh = slab.doorHash
    local force = true
    if locked then
        DoorSystemSetDoorState(dh, 4, false, force)
        pcall(function()
            DoorSystemSetOpenRatio(dh, 0.0, true, true)
        end)
        pcall(function()
            DoorSystemSetAutomaticDistance(dh, 0.0, false, false)
        end)
        pcall(function()
            DoorSystemSetHoldOpen(dh, false)
        end)
    else
        DoorSystemSetDoorState(dh, 0, false, force)
        pcall(function()
            DoorSystemSetOpenRatio(dh, 1.0, true, true)
        end)
        pcall(function()
            DoorSystemSetAutomaticDistance(dh, 30.0, false, false)
        end)
    end
end

local function entityDoorHash(ent)
    return joaat(('ltpd_gd_%s'):format(ent))
end

local function applyGarageEntityDoor(ent, locked)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    rememberEntitySnapshot(ent)
    local model = GetEntityModel(ent)
    local c = GetEntityCoords(ent)
    local dh = entityDoorHash(ent)
    ensureDoorInSystem(dh, model, c.x, c.y, c.z)
    if locked then
        DoorSystemSetDoorState(dh, 4, false, true)
        pcall(function() DoorSystemSetOpenRatio(dh, 0.0, true, true) end)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 0.0, false, false) end)
        pcall(function() DoorSystemSetHoldOpen(dh, false) end)
        snapEntityToSnapshot(ent)
        FreezeEntityPosition(ent, true)
        SetEntityDynamic(ent, false)
    else
        DoorSystemSetDoorState(dh, 0, false, true)
        pcall(function() DoorSystemSetOpenRatio(dh, 1.0, true, true) end)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 28.0, false, false) end)
        FreezeEntityPosition(ent, false)
        SetEntityDynamic(ent, true)
    end
end

local BOLLARD_RAISE_Z = 0.42

local function applyBarrierEntity(ent, locked)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    rememberEntitySnapshot(ent)
    if locked then
        snapEntityToSnapshot(ent)
        FreezeEntityPosition(ent, true)
        SetEntityDynamic(ent, false)
        SetEntityInvincible(ent, true)
        SetEntityCanBeDamaged(ent, false)
    else
        FreezeEntityPosition(ent, false)
        SetEntityDynamic(ent, true)
        SetEntityInvincible(ent, false)
        SetEntityCanBeDamaged(ent, true)
    end
end

local function applyBollardEntity(ent, locked)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    rememberEntitySnapshot(ent)
    local snap = entitySnapshots[ent]
    if not snap then return end
    if locked then
        SetEntityCoords(ent, snap.coords.x, snap.coords.y, snap.coords.z + BOLLARD_RAISE_Z, false, false, false, false)
        SetEntityHeading(ent, snap.heading)
        FreezeEntityPosition(ent, true)
        SetEntityDynamic(ent, false)
        SetEntityInvincible(ent, true)
        SetEntityCollision(ent, true, true)
    else
        SetEntityCoords(ent, snap.coords.x, snap.coords.y, snap.coords.z, false, false, false, false)
        SetEntityHeading(ent, snap.heading)
        FreezeEntityPosition(ent, false)
        SetEntityDynamic(ent, true)
        SetEntityInvincible(ent, false)
    end
end

local function applyBarrierGroupLocked(slabs, entities, locked)
    for _, ent in ipairs(entities or {}) do
        applyBarrierEntity(ent, locked)
    end
    for _, slab in ipairs(slabs or {}) do
        local ent = findClosestObject(slab.modelHash, slab.coords, 6.0)
        if ent ~= 0 then applyBarrierEntity(ent, locked) end
    end
end

local function applyBollardGroupLocked(slabs, entities, locked)
    for _, ent in ipairs(entities or {}) do
        applyBollardEntity(ent, locked)
    end
    for _, slab in ipairs(slabs or {}) do
        local ent = findClosestObject(slab.modelHash, slab.coords, 8.0)
        if ent ~= 0 then applyBollardEntity(ent, locked) end
    end
end

local function applyGarageRollLocked(slabs, entities, locked)
    local seen = {}
    for _, slab in ipairs(slabs or {}) do
        applyGarageSlabDoorSystem(slab, locked)
        local ent = findClosestObject(slab.modelHash, slab.coords, 8.0)
        if ent ~= 0 then
            seen[ent] = true
            applyGarageEntityDoor(ent, locked)
            if locked then
                if slab.heading then SetEntityHeading(ent, slab.heading + 0.0) end
                SetEntityCoords(ent, slab.coords.x, slab.coords.y, slab.coords.z, false, false, false, false)
                FreezeEntityPosition(ent, true)
                SetEntityDynamic(ent, false)
                SetEntityInvincible(ent, true)
            else
                FreezeEntityPosition(ent, false)
                SetEntityDynamic(ent, true)
                SetEntityInvincible(ent, false)
            end
        end
    end
    for _, ent in ipairs(entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) and not seen[ent] then
            seen[ent] = true
            applyGarageEntityDoor(ent, locked)
            if locked then
                FreezeEntityPosition(ent, true)
                SetEntityDynamic(ent, false)
            else
                FreezeEntityPosition(ent, false)
                SetEntityDynamic(ent, true)
            end
        end
    end
end

local function registerDynSlab(modelHash, x, y, z)
    local dh = dynSlabScriptHash(modelHash, x, y, z)
    ensureDoorInSystem(dh, modelHash, x, y, z)
    return { doorHash = dh, modelHash = modelHash, coords = vector3(x, y, z) }
end

local function applyEntityGroupLocked(entities, locked)
    for _, ent in ipairs(entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            rememberEntitySnapshot(ent)
            if locked then
                snapEntityToSnapshot(ent)
                FreezeEntityPosition(ent, true)
                SetEntityCollision(ent, not locked, not locked)
            else
                FreezeEntityPosition(ent, false)
                SetEntityCollision(ent, true, true)
            end
        end
    end
end

local function scanEntitiesForDef(entityScan)
    if not entityScan or not entityScan.center then return {} end
    local center = entityScan.center
    local radius = entityScan.radius or 12.0
    local models = {}
    for _, name in ipairs(entityScan.models or {}) do
        models[joaat(name)] = true
    end
    local out = {}
    for _, ent in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(ent) then
            local m = GetEntityModel(ent)
            if models[m] then
                local c = GetEntityCoords(ent)
                if #(c - center) <= radius then
                    out[#out + 1] = ent
                end
            end
        end
    end
    return out
end

local function applyGroupLocked(id, locked)
    for _, g in ipairs(doorGroups) do
        if g.id == id then
            if g.doorType == 'garage_roll' then
                applyGarageRollLocked(g.slabs, g.entities, locked)
                return
            end
            if g.doorType == 'bollard' then
                applyBollardGroupLocked(g.slabs, g.entities, locked)
                return
            end
            if g.doorType == 'barrier' then
                applyBarrierGroupLocked(g.slabs, g.entities, locked)
                return
            end
            for _, slab in ipairs(g.slabs) do
                applyStandardSlabLocked(slab, locked)
            end
            applyEntityGroupLocked(g.entities, locked)
            return
        end
    end
end

local function buildManualGroupDef(def)
    local slabs = {}
    for i, d in ipairs(def.doors or {}) do
        local coords = d.coords
        local model = d.model
        local slab = registerSlab(def.id, i, model, coords, d.heading)
        alignSlabToWorld(slab)
        if d.heading then
            slab.heading = d.heading + 0.0
            snapSlabEntity(slab)
        end
        slabs[#slabs + 1] = slab
    end
    local interact = def.interact
    if not interact and #slabs > 0 then
        local c = vector3(0, 0, 0)
        for _, s in ipairs(slabs) do
            c = c + s.coords
        end
        interact = c / #slabs
    end
    local entities = scanEntitiesForDef(def.entityScan)
    for _, ent in ipairs(entities) do
        rememberEntitySnapshot(ent)
    end
    doorGroups[#doorGroups + 1] = {
        id = def.id,
        label = def.label or 'Durys',
        doorType = def.doorType,
        interact = interact,
        interactDist = def.interactDist or 2.5,
        slabs = slabs,
        entities = entities,
        entityScanDef = def.entityScan,
    }
    if doorLocked[def.id] == nil then
        doorLocked[def.id] = def.defaultLocked ~= false
    end
end

local function buildManualGroups()
    for _, def in ipairs(Config.PdDoorGroups or {}) do
        buildManualGroupDef(def)
    end
    for _, def in ipairs(Config.EmsDoorGroups or {}) do
        buildManualGroupDef(def)
    end
    rebuildManualPdSlabSkip()
end

local function scanDynamicForStation(dyn)
    if dynStationDone[dyn.stationId] then return end
    local minV, maxV = dyn.bounds.min, dyn.bounds.max
    local whitelist = {}
    for _, name in ipairs(dyn.models or {}) do
        whitelist[joaat(name)] = name
    end
    local found = {}
    for _, ent in ipairs(GetGamePool('CObject')) do
        if DoesEntityExist(ent) then
            local m = GetEntityModel(ent)
            if whitelist[m] then
                local c = GetEntityCoords(ent)
                if vecInBounds(c, minV, maxV) and not isManualPdDoorSlab(m, c) then
                    found[#found + 1] = { modelHash = m, coords = c }
                end
            end
        end
    end

    local pairDist = dyn.pairDist or 2.35
    local used = {}
    local clusters = {}

    for i = 1, #found do
        if not used[i] then
            local bestj, bestd = nil, pairDist + 1.0
            for j = i + 1, #found do
                if not used[j] and found[i].modelHash == found[j].modelHash then
                    local dd = #(found[i].coords - found[j].coords)
                    if dd <= pairDist and dd < bestd then
                        bestd = dd
                        bestj = j
                    end
                end
            end
            if bestj then
                used[i] = true
                used[bestj] = true
                clusters[#clusters + 1] = { found[i], found[bestj] }
            else
                used[i] = true
                clusters[#clusters + 1] = { found[i] }
            end
        end
    end

    for _, cluster in ipairs(clusters) do
        local c = vector3(0, 0, 0)
        for _, s in ipairs(cluster) do
            c = c + s.coords
        end
        c = c / #cluster
        local modelName = whitelist[cluster[1].modelHash]
        local doorType = dyn.doorType or inferDoorTypeFromModelName(modelName)
        local qx, qy, qz = quantKey(c.x, c.y, c.z)
        local groupId = ('dyn_%s_%x_%d_%d_%d'):format(dyn.stationId, cluster[1].modelHash, qx, qy, qz)
        local slabs = {}
        local entities = {}
        for si, s in ipairs(cluster) do
            local slab = registerDynSlab(s.modelHash, s.coords.x, s.coords.y, s.coords.z)
            alignSlabToWorld(slab)
            slabs[si] = slab
            if doorType == 'barrier' or doorType == 'bollard' or doorType == 'garage_roll' then
                local ent = findClosestObject(s.modelHash, s.coords, 5.0)
                if ent ~= 0 then
                    entities[#entities + 1] = ent
                    rememberEntitySnapshot(ent)
                end
            end
        end
        if not groupIdExists(groupId) then
            doorGroups[#doorGroups + 1] = {
                id = groupId,
                label = dyn.label or 'Durys',
                doorType = doorType,
                interact = c + (dyn.interactOffset or vector3(0, 0, 0)),
                interactDist = dyn.interactDist or 2.5,
                slabs = slabs,
                entities = entities,
            }
            local regSlabs = {}
            for _, s in ipairs(cluster) do
                regSlabs[#regSlabs + 1] = { x = s.coords.x, y = s.coords.y, z = s.coords.z, model = s.modelHash }
            end
            TriggerServerEvent('fivempro_ltpd:server:registerPdDynDoorGroup', groupId, dyn.stationId, c.x, c.y, c.z, dyn.interactDist or 2.5, regSlabs)
        end
    end
    if #found > 0 then
        dynStationDone[dyn.stationId] = true
    end
end

CreateThread(function()
    Wait(1500)
    buildManualGroups()
    for id, locked in pairs(doorLocked) do
        applyGroupLocked(id, locked)
    end
end)

CreateThread(function()
    while true do
        Wait(4500)
        for _, g in ipairs(doorGroups) do
            if g.entityScanDef then
                g.entities = scanEntitiesForDef(g.entityScanDef)
                for _, ent in ipairs(g.entities) do
                    rememberEntitySnapshot(ent)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1800)
        local pc = GetEntityCoords(PlayerPedId())
        for _, g in ipairs(doorGroups) do
            if g.doorType == 'garage_roll' and doorLocked[g.id] ~= false then
                local near = false
                for _, slab in ipairs(g.slabs or {}) do
                    if #(pc - slab.coords) < 95.0 then
                        near = true
                        break
                    end
                end
                if near then
                    applyGarageRollLocked(g.slabs, g.entities, true)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2200)
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        for _, dyn in ipairs(allDoorDynamics()) do
            if not dynStationDone[dyn.stationId] then
                local c = (dyn.bounds.min + dyn.bounds.max) * 0.5
                if #(pc - c) < 145.0 then
                    scanDynamicForStation(dyn)
                    for id, locked in pairs(doorLocked) do
                        applyGroupLocked(id, locked ~= false)
                    end
                end
            end
        end
    end
end)

RegisterNetEvent('fivempro_ltpd:client:syncPdDoors', function(states)
    if type(states) ~= 'table' then return end
    for k, v in pairs(states) do
        doorLocked[k] = v == true
    end
    for id, locked in pairs(doorLocked) do
        applyGroupLocked(id, locked)
    end
end)

RegisterNetEvent('fivempro_ltpd:client:setPdDoorState', function(id, locked)
    if not id then return end
    doorLocked[id] = locked == true
    applyGroupLocked(id, doorLocked[id])
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('fivempro_ltpd:server:requestPdDoorsSync')
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(4000, function()
        TriggerServerEvent('fivempro_ltpd:server:requestPdDoorsSync')
    end)
end)

local lastToggle = 0
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        local zones = buildPdDoorProximityZones()
        local waitMs = pdDoorZoneIdleWaitMs(zones, pcoords)

        local bestByGroup = {}
        local closestHit = nil

        for _, z in ipairs(zones) do
            local d = #(pcoords - z.pos)
            if d <= z.maxd then
                local prev = bestByGroup[z.groupId]
                if not prev or d < prev.d then
                    bestByGroup[z.groupId] = { d = d, z = z }
                end
                if not closestHit or d < closestHit.d then
                    closestHit = { gid = z.groupId, d = d, z = z }
                end
            end
        end

        if next(bestByGroup) then
            waitMs = 0
            if canUseServiceDoorsClient() then
                for gid, hit in pairs(bestByGroup) do
                    if canUseDoorGroupClient(gid) then
                        local g = findDoorGroupById(gid)
                        if g then
                            local locked = doorLocked[g.id] ~= false
                            drawGroupLockIcons(g, pcoords, locked)
                        end
                    end
                end
                if closestHit and canUseDoorGroupClient(closestHit.gid) and IsControlJustPressed(0, 38) then
                    local now = GetGameTimer()
                    if now - lastToggle > 650 then
                        lastToggle = now
                        local g = findDoorGroupById(closestHit.gid)
                        if g then
                            TriggerServerEvent('fivempro_ltpd:server:togglePdDoorGroup', g.id)
                        end
                    end
                end
            end
        end

        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        local nearGarage = false
        for _, g in ipairs(doorGroups) do
            if g.doorType == 'garage_roll' and g.interact and #(pc - g.interact) < 55.0 then
                nearGarage = true
                break
            end
        end
        Wait(nearGarage and 120 or 450)
        for _, g in ipairs(doorGroups) do
            local locked = doorLocked[g.id] ~= false
            applyGroupLocked(g.id, locked)
        end
    end
end)

--- Užrakinti garažo vartai: priverstinai laikomi uždaryti (fizika / kiti scriptai).
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        local anyNear = false
        for _, g in ipairs(doorGroups) do
            if (g.doorType == 'barrier' or g.doorType == 'bollard') and doorLocked[g.id] ~= false then
                local near = g.interact and #(pc - g.interact) < 55.0
                if not near then
                    for _, slab in ipairs(g.slabs or {}) do
                        if #(pc - slab.coords) < 55.0 then
                            near = true
                            break
                        end
                    end
                end
                if near then
                    anyNear = true
                    if g.doorType == 'bollard' then
                        applyBollardGroupLocked(g.slabs, g.entities, true)
                    else
                        applyBarrierGroupLocked(g.slabs, g.entities, true)
                    end
                end
            elseif g.doorType == 'garage_roll' and doorLocked[g.id] ~= false then
                local near = false
                if g.interact and #(pc - g.interact) < 90.0 then
                    near = true
                end
                if not near then
                    for _, slab in ipairs(g.slabs or {}) do
                        if #(pc - slab.coords) < 90.0 then
                            near = true
                            break
                        end
                    end
                end
                if near then
                    anyNear = true
                    applyGarageRollLocked(g.slabs, g.entities, true)
                end
            end
        end
        Wait(anyNear and 0 or 400)
    end
end)
