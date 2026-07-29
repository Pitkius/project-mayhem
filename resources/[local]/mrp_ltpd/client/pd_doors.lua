local QBCore = exports['qb-core']:GetCoreObject()

--- @class LtpdDoorSlab
--- @field doorHash number
--- @field modelHash number
--- @field coords vector3
--- @field heading number|nil
--- @field restZ number|nil
--- @field pitch number|nil
--- @field roll number|nil

--- @class LtpdDoorGroupRuntime
--- @field id string
--- @field label string
--- @field doorType string|nil
--- @field interact vector3
--- @field interactDist number
--- @field slabs LtpdDoorSlab[]
--- @field entities number[]
--- @field entityScanDef table|nil
--- @field bollardRaiseZ number|nil
--- @field gateOpenHeadingDelta number|nil

local doorGroups = {} ---@type LtpdDoorGroupRuntime[]
local doorLocked = {} ---@type table<string, boolean>
local lastAppliedLockState = {} ---@type table<string, boolean>
local lastAppliedEntitySig = {} ---@type table<string, number>
local dynStationDone = {} ---@type table<string, boolean>
local entitySnapshots = {} ---@type table<number, { coords: vector3, heading: number }>
local doorToggleCooldownUntil = {} ---@type table<string, number>
local doorTogglePendingUntil = {} ---@type table<string, number>
local doorEntityScanSig = {} ---@type table<string, number>
local applyGroupLocked

--- Rakto ikonos dydis (DrawSprite – ~2.5× mažesnis nei anksčiau)
local LOCK_ICON_W = 0.016
local LOCK_ICON_H = 0.028

--- Kad dinaminis skeneris nedubliuotų durų, kurias valdome iš `PdDoorGroups`.
local manualPdSlabSkip = {}

local function rebuildManualPdSlabSkip()
    manualPdSlabSkip = {}
    for _, g in ipairs(doorGroups) do
        for _, slab in ipairs(g.slabs or {}) do
            manualPdSlabSkip[#manualPdSlabSkip + 1] = {
                m = slab.modelHash,
                c = slab.coords,
            }
        end
    end
end

local function isManualPdDoorSlab(modelHash, coords)
    for _, e in ipairs(manualPdSlabSkip) do
        if e.m == modelHash and #(coords - e.c) < 2.75 then
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

local cachedObjectPool = nil
local cachedObjectPoolAt = 0

local function invalidateObjectPoolCache()
    cachedObjectPool = nil
    cachedObjectPoolAt = 0
end

local function getCachedObjectPool(maxAgeMs)
    maxAgeMs = maxAgeMs or 6000
    local now = GetGameTimer()
    if not cachedObjectPool or (now - cachedObjectPoolAt) > maxAgeMs then
        cachedObjectPool = GetGamePool('CObject')
        cachedObjectPoolAt = now
    end
    return cachedObjectPool
end

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

local function seedGarageEntitySnapshot(ent, slab)
    if not ent or ent == 0 or not DoesEntityExist(ent) or not slab then return end
    entitySnapshots[ent] = {
        coords = vector3(slab.coords.x, slab.coords.y, slab.coords.z),
        heading = slab.heading or GetEntityHeading(ent),
    }
end

local function parseDoorLocked(v)
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
    return nil
end

local function isGroupLocked(groupId)
    return doorLocked[groupId] ~= false
end

local doorIconStable = {} ---@type table<string, { value: boolean, since: number }>

local function stableDoorIconLocked(groupId)
    local raw = isGroupLocked(groupId)
    local now = GetGameTimer()
    local s = doorIconStable[groupId]
    if not s then
        doorIconStable[groupId] = { value = raw, since = now }
        return raw
    end
    if s.value ~= raw then
        if now - s.since > 220 then
            s.value = raw
            s.since = now
        end
    else
        s.since = now
    end
    return s.value
end

local function snapGarageEntityClosed(ent, slab)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if slab then
        SetEntityCoords(ent, slab.coords.x, slab.coords.y, slab.coords.z, false, false, false, false)
        if slab.heading then
            SetEntityHeading(ent, slab.heading + 0.0)
        end
    else
        snapEntityToSnapshot(ent)
    end
    FreezeEntityPosition(ent, true)
    SetEntityDynamic(ent, false)
    SetEntityInvincible(ent, true)
    SetEntityCanBeDamaged(ent, false)
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
    for _, d in ipairs(Config.RangerDoorDynamics or {}) do
        out[#out + 1] = d
    end
    return out
end

local function isEmsJobName(name)
    return name == (Config.EmsDoorJob or 'ambulance')
end

local function isRangerJobName(name)
    return name == (Config.RangerDoorJob or 'ranger')
end

local function doorGroupService(groupId)
    if type(groupId) ~= 'string' then return 'police' end
    if groupId:sub(1, 8) == 'dyn_ems_' then return 'ems' end
    if groupId:sub(1, 11) == 'dyn_ranger_' then return 'ranger' end
    for _, def in ipairs(Config.EmsDoorGroups or {}) do
        if def.id == groupId then return 'ems' end
    end
    for _, def in ipairs(Config.RangerDoorGroups or {}) do
        if def.id == groupId then return 'ranger' end
    end
    return 'police'
end

local function canUseDoorGroupClient(groupId)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job or not P.job.onduty then return false end
    local svc = doorGroupService(groupId)
    if svc == 'ems' then return isEmsJobName(P.job.name) end
    if svc == 'ranger' then return isRangerJobName(P.job.name) end
    return isPdJobName(P.job.name)
end

local function isDoorTogglePending(groupId)
    return GetGameTimer() < (doorTogglePendingUntil[groupId] or 0)
end

local function requestPdDoorToggle(groupId)
    if type(groupId) ~= 'string' or groupId == '' then return end
    if not canUseDoorGroupClient(groupId) then return end
    local now = GetGameTimer()
    if now < (doorToggleCooldownUntil[groupId] or 0) or isDoorTogglePending(groupId) then return end
    doorToggleCooldownUntil[groupId] = now + 900
    doorTogglePendingUntil[groupId] = now + 3000
    local newLocked = not isGroupLocked(groupId)
    doorLocked[groupId] = newLocked
    doorIconStable[groupId] = { value = newLocked, since = now }
    lastAppliedLockState[groupId] = nil
    lastAppliedEntitySig[groupId] = nil
    applyGroupLocked(groupId, newLocked, true)
    TriggerServerEvent('mrp_ltpd:server:setPdDoorGroup', groupId, newLocked)
end

local serviceDoorAccessCache = { ok = false, at = 0 }

local function canUseServiceDoorsClient()
    local now = GetGameTimer()
    if now - serviceDoorAccessCache.at < 600 then
        return serviceDoorAccessCache.ok
    end
    local P = QBCore.Functions.GetPlayerData()
    local ok = P and P.job and P.job.onduty == true
        and (isPdJobName(P.job.name) or isEmsJobName(P.job.name) or isRangerJobName(P.job.name))
    serviceDoorAccessCache = { ok = ok == true, at = now }
    return serviceDoorAccessCache.ok
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', function()
    serviceDoorAccessCache.at = 0
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    serviceDoorAccessCache.at = 0
end)

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

local function doorLockZOffset(doorType)
    if doorType == 'garage_roll' then return 0.85 end
    if doorType == 'yard_gate' then return 0.9 end
    if doorType == 'barrier' then return 0.75 end
    if doorType == 'bollard' then return 0.5 end
    return tonumber(Config.PdDoorLockIconZOffset) or 0.38
end

--- Spynos ikona ant durų centro (ne virš jų, ne ant E taško).
--- Slabai nestovi judantys — cache'inam. Entity tik kai nėra slabų.
local function resolveDoorLockPos(group, forceRefresh)
    if not group then return nil end
    if not forceRefresh and group.lockPosCache then
        return group.lockPosCache
    end

    local zOff = doorLockZOffset(group.doorType)
    local slabs = group.slabs or {}
    if #slabs > 0 then
        local sum = vector3(0.0, 0.0, 0.0)
        for _, s in ipairs(slabs) do
            sum = sum + s.coords
        end
        local c = sum / #slabs
        group.lockPosCache = vector3(c.x, c.y, c.z + zOff)
        return group.lockPosCache
    end

    local count = 0
    local sum = vector3(0.0, 0.0, 0.0)
    for _, ent in ipairs(group.entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            sum = sum + GetEntityCoords(ent)
            count = count + 1
        end
    end
    if count > 0 then
        local c = sum / count
        group.lockPosCache = vector3(c.x, c.y, c.z + zOff)
        return group.lockPosCache
    end

    if group.interact then
        group.lockPosCache = vector3(group.interact.x, group.interact.y, group.interact.z + zOff)
        return group.lockPosCache
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

local cachedDoorProximityZones = nil
local doorTargetZoneIds = {} ---@type table<string, boolean>

local function pdDoorUseQbTarget()
    return Config.PdDoorUseQbTarget == true
end

local function doorInteractRadius(dist)
    local base = tonumber(dist) or 2.5
    local reach = tonumber(Config.PdDoorToggleReach) or 5.0
    return math.max(base, reach) + 0.35
end

local function getPdDoorProximityZones()
    if not cachedDoorProximityZones then
        cachedDoorProximityZones = buildPdDoorProximityZones()
    end
    return cachedDoorProximityZones
end

local nearDoorDistCache = { dist = 999999.0, at = 0, x = 0.0, y = 0.0, z = 0.0 }

local function nearestPdDoorDist(pcoords)
    local now = GetGameTimer()
    local c = nearDoorDistCache
    if now - c.at < 500 then
        local dx, dy, dz = pcoords.x - c.x, pcoords.y - c.y, pcoords.z - c.z
        if (dx * dx + dy * dy + dz * dz) < 4.0 then
            return c.dist
        end
    end
    --- Tik interact taškai — greita. Spynos pozicija naudojama tik E/ikona thread'e.
    local minD = 999999.0
    for _, g in ipairs(doorGroups) do
        if g.interact then
            minD = math.min(minD, #(pcoords - g.interact))
        end
    end
    nearDoorDistCache = { dist = minD, at = now, x = pcoords.x, y = pcoords.y, z = pcoords.z }
    return minD
end

local function removeDoorTargetZone(zoneId)
    if not zoneId or not doorTargetZoneIds[zoneId] then return end
    if GetResourceState('qb-target') == 'started' then
        pcall(function()
            exports['qb-target']:RemoveZone(zoneId)
        end)
    end
    doorTargetZoneIds[zoneId] = nil
end

local function registerDoorTargetZone(zoneId, groupId, pos, interactDist, label)
    if not pdDoorUseQbTarget() then return false end
    if not zoneId or not groupId or not pos or doorTargetZoneIds[zoneId] then return false end
    if GetResourceState('qb-target') ~= 'started' then return false end

    local radius = doorInteractRadius(interactDist)
    local optionLabel = label and ('%s'):format(label) or 'Durų spyna'

    exports['qb-target']:AddCircleZone(zoneId, pos, radius, {
        name = zoneId,
        debugPoly = false,
        useZ = true,
    }, {
        options = {
            {
                icon = 'fas fa-door-closed',
                label = optionLabel,
                action = function()
                    requestPdDoorToggle(groupId)
                end,
                canInteract = function()
                    return canUseDoorGroupClient(groupId)
                end,
            },
        },
        distance = radius + 1.25,
    })

    doorTargetZoneIds[zoneId] = true
    return true
end

local function registerDoorGroupTarget(g)
    if not g or not g.interact then return end
    local zoneId = ('ltpd_door_%s_main'):format(g.id)
    registerDoorTargetZone(zoneId, g.id, g.interact, g.interactDist, g.label)
end

local function setupDoorTargetsFromZones()
    if not pdDoorUseQbTarget() then return false end
    if GetResourceState('qb-target') ~= 'started' then return false end
    local zones = getPdDoorProximityZones()
    for i, z in ipairs(zones) do
        local g = findDoorGroupById(z.groupId)
        local zoneId = ('ltpd_door_%s_%d'):format(z.groupId, i)
        registerDoorTargetZone(zoneId, z.groupId, z.pos, z.maxd, g and g.label)
    end
    return true
end

local function refreshPdDoorProximityCache()
    cachedDoorProximityZones = buildPdDoorProximityZones()
    nearDoorDistCache.at = 0
end

local function refreshPdDoorInteractZones()
    refreshPdDoorProximityCache()
    if not pdDoorUseQbTarget() then
        for zoneId in pairs(doorTargetZoneIds) do
            removeDoorTargetZone(zoneId)
        end
        return
    end
    for zoneId in pairs(doorTargetZoneIds) do
        removeDoorTargetZone(zoneId)
    end
    setupDoorTargetsFromZones()
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
    local r = radius or 5.0
    local ent = GetClosestObjectOfType(coords.x, coords.y, coords.z, r, modelHash, false, false, false)
    if ent and ent ~= 0 then return ent end
    if r < 9.0 then
        ent = GetClosestObjectOfType(coords.x, coords.y, coords.z, 9.0, modelHash, false, false, false)
        if ent and ent ~= 0 then return ent end
    end
    return 0
end

local function registerSlab(groupId, slabIndex, modelName, coords, heading, opts)
    opts = opts or {}
    local modelHash = type(modelName) == 'string' and joaat(modelName) or modelName
    local dh = slabScriptHash(groupId, slabIndex)
    ensureDoorInSystem(dh, modelHash, coords.x, coords.y, coords.z)
    return {
        doorHash = dh,
        modelHash = modelHash,
        coords = coords,
        heading = heading,
        restZ = opts.restZ,
        pitch = opts.pitch,
        roll = opts.roll,
    }
end

local function findSlabForEntity(slabs, ent, maxDist)
    if not slabs or not ent or ent == 0 or not DoesEntityExist(ent) then return nil end
    maxDist = maxDist or 8.0
    local em = GetEntityModel(ent)
    local ec = GetEntityCoords(ent)
    local best, bestD = nil, maxDist + 1.0
    for _, slab in ipairs(slabs) do
        if slab.modelHash == em then
            local d = #(ec - slab.coords)
            if d <= maxDist and d < bestD then
                bestD = d
                best = slab
            end
        end
    end
    return best
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

local function doorSystemGetState(dh)
    local ok, st = pcall(function()
        return DoorSystemGetDoorState(dh)
    end)
    if not ok then return nil end
    return tonumber(st)
end

local function doorSystemGetRatio(dh)
    local ok, ratio = pcall(function()
        return DoorSystemGetOpenRatio(dh)
    end)
    if not ok then return nil end
    return math.abs(tonumber(ratio) or 0.0)
end

--- DoorSystem: 0 unlocked, 1 locked (2/4 = force-locked variants).
local function doorSystemMatchesLocked(dh, locked)
    local st = doorSystemGetState(dh)
    if st == nil then return false end
    if locked then
        return st == 1 or st == 2 or st == 4
    end
    return st == 0
end

local function applyStandardSlabLocked(slab, locked, hardForce)
    local dh = slab.doorHash
    hardForce = hardForce == true
    if not hardForce and doorSystemMatchesLocked(dh, locked) then
        if locked then
            local ratio = doorSystemGetRatio(dh) or 0.0
            if ratio > 0.06 then
                DoorSystemSetDoorState(dh, 1, false, false)
                pcall(function() DoorSystemSetOpenRatio(dh, 0.0, false, false) end)
            end
        end
        return
    end
    if locked then
        DoorSystemSetDoorState(dh, 1, false, hardForce)
        pcall(function() DoorSystemSetOpenRatio(dh, 0.0, hardForce, hardForce) end)
        pcall(function() DoorSystemSetHoldOpen(dh, false) end)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 0.0, false, false) end)
        if hardForce then
            snapSlabEntity(slab)
        end
    else
        DoorSystemSetDoorState(dh, 0, false, hardForce)
        pcall(function() DoorSystemSetHoldOpen(dh, false) end)
        -- Negrąžinti durų į 0 ratio per jėgą: jos atsirakina vienu E ir juda natūraliai.
        pcall(function() DoorSystemSetAutomaticDistance(dh, 3.0, false, false) end)
    end
end

local DEFAULT_BOLLARD_RAISE_Z = 0.38

local BOLLARD_MODEL_HASHES = {
    [joaat('gabz_mrpd_bollards1')] = true,
    [joaat('gabz_mrpd_bollards2')] = true,
}

local FACGATE_MODEL_HASH = joaat('prop_facgate_07b')

local function isBollardModel(modelHash)
    return BOLLARD_MODEL_HASHES[modelHash] == true
end

local function isFacGateModel(modelHash)
    return modelHash == FACGATE_MODEL_HASH
end

local function bollardRaiseForGroup(group)
    if group and group.bollardRaiseZ then
        return group.bollardRaiseZ + 0.0
    end
    return DEFAULT_BOLLARD_RAISE_Z
end

local function rememberBollardSnapshot(ent, assumeRaised, raiseZ, groundZHint, slab)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    raiseZ = raiseZ or DEFAULT_BOLLARD_RAISE_Z
    if slab and slab.restZ then
        entitySnapshots[ent] = {
            coords = vector3(slab.coords.x, slab.coords.y, slab.restZ + 0.0),
            heading = (slab.heading or GetEntityHeading(ent)) + 0.0,
            restZ = slab.restZ + 0.0,
            pitch = slab.pitch or 0.0,
            roll = slab.roll or 0.0,
        }
        return
    end
    local c = GetEntityCoords(ent)
    local snap = entitySnapshots[ent]
    if snap and snap.restZ then
        -- Visada naudojam žemiausią matytą Z kaip „nuleistą“ poziciją (MLO kartais spawnina per aukštai).
        if c.z < snap.restZ then
            snap.restZ = c.z
            snap.coords = vector3(c.x, c.y, c.z)
        end
        return
    end
    local restZ = c.z
    if assumeRaised then
        restZ = c.z - raiseZ
    elseif groundZHint and c.z > groundZHint + 0.15 then
        restZ = c.z - raiseZ
    end
    entitySnapshots[ent] = {
        coords = vector3(c.x, c.y, restZ),
        heading = GetEntityHeading(ent),
        restZ = restZ,
        pitch = 0.0,
        roll = 0.0,
    }
end

local applyBarrierEntity

local function applyBollardEntity(ent, locked, raiseZ, slab, hardForce)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    raiseZ = raiseZ or DEFAULT_BOLLARD_RAISE_Z
    rememberBollardSnapshot(ent, locked, raiseZ, nil, slab)
    local snap = entitySnapshots[ent]
    if not snap or not snap.restZ then return end
    local targetZ = locked and (snap.restZ + raiseZ) or snap.restZ
    if not hardForce then
        local c = GetEntityCoords(ent)
        if math.abs(c.z - targetZ) < 0.04 and IsEntityPositionFrozen(ent) then
            return
        end
    end
    SetEntityCoords(ent, snap.coords.x, snap.coords.y, targetZ, false, false, false, false)
    SetEntityRotation(ent, snap.pitch or 0.0, snap.roll or 0.0, snap.heading or 0.0, 2, true)
    FreezeEntityPosition(ent, true)
    SetEntityDynamic(ent, false)
    SetEntityInvincible(ent, true)
    SetEntityCanBeDamaged(ent, false)
    SetEntityCollision(ent, true, true)
end

local function applyFacGateEntity(ent, locked, slab, openDelta, hardForce)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if not slab then
        applyBarrierEntity(ent, locked, nil, hardForce)
        return
    end
    openDelta = openDelta or 82.0
    local closedHeading = (slab.heading or GetEntityHeading(ent)) + 0.0
    local heading = locked and closedHeading or ((closedHeading + openDelta) % 360.0)
    if not hardForce then
        local c = GetEntityCoords(ent)
        local h = GetEntityHeading(ent)
        local headingDiff = math.abs(((h - heading + 540.0) % 360.0) - 180.0)
        if #(c - slab.coords) < 0.08 and headingDiff < 1.5 and IsEntityPositionFrozen(ent) then
            return
        end
    end
    SetEntityCoords(ent, slab.coords.x, slab.coords.y, slab.coords.z, false, false, false, false)
    SetEntityHeading(ent, heading)
    FreezeEntityPosition(ent, true)
    SetEntityDynamic(ent, false)
    SetEntityInvincible(ent, true)
    SetEntityCanBeDamaged(ent, false)
    SetEntityCollision(ent, true, true)
end

local function drawGroupLockIcons(g, pcoords, locked)
    if not g.interact then return end
    local maxDist = (g.interactDist or 2.5) + 5.5
    if #(pcoords - g.interact) > maxDist then return end
    local lockPos = resolveDoorLockPos(g)
    if not lockPos then return end
    drawPdDoorLock(lockPos.x, lockPos.y, lockPos.z, locked)
end

local function applyGarageSlabDoorSystem(slab, locked, hardForce)
    local dh = slab.doorHash
    hardForce = hardForce == true
    local wantRatio = locked and 0.0 or 1.0
    if not hardForce and doorSystemMatchesLocked(dh, locked) then
        local ratio = doorSystemGetRatio(dh)
        if ratio ~= nil and math.abs(ratio - wantRatio) < 0.08 then
            return
        end
    end
    if locked then
        DoorSystemSetDoorState(dh, 1, false, hardForce)
        pcall(function()
            DoorSystemSetOpenRatio(dh, 0.0, hardForce, hardForce)
        end)
        pcall(function()
            DoorSystemSetAutomaticDistance(dh, 0.0, false, false)
        end)
        pcall(function()
            DoorSystemSetHoldOpen(dh, false)
        end)
    else
        DoorSystemSetDoorState(dh, 0, false, hardForce)
        pcall(function()
            DoorSystemSetOpenRatio(dh, 1.0, hardForce, hardForce)
        end)
        pcall(function()
            DoorSystemSetAutomaticDistance(dh, 0.0, false, false)
        end)
        pcall(function()
            DoorSystemSetHoldOpen(dh, false)
        end)
    end
end

local function entityDoorHash(ent)
    return joaat(('ltpd_gd_%s'):format(ent))
end

local function applyGarageEntityDoor(ent, locked, slab, hardForce)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    hardForce = hardForce == true
    local dh = entityDoorHash(ent)
    local model = GetEntityModel(ent)
    local c = GetEntityCoords(ent)
    ensureDoorInSystem(dh, model, c.x, c.y, c.z)
    local wantRatio = locked and 0.0 or 1.0
    if not hardForce and doorSystemMatchesLocked(dh, locked) then
        local ratio = doorSystemGetRatio(dh)
        if ratio ~= nil and math.abs(ratio - wantRatio) < 0.08 then
            if locked and IsEntityPositionFrozen(ent) then
                return
            end
            if not locked then
                return
            end
        end
    end
    if locked then
        DoorSystemSetDoorState(dh, 1, false, hardForce)
        pcall(function() DoorSystemSetOpenRatio(dh, 0.0, hardForce, hardForce) end)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 0.0, false, false) end)
        pcall(function() DoorSystemSetHoldOpen(dh, false) end)
        snapGarageEntityClosed(ent, slab)
        return
    end
    rememberEntitySnapshot(ent)
    DoorSystemSetDoorState(dh, 0, false, hardForce)
    pcall(function() DoorSystemSetOpenRatio(dh, 1.0, hardForce, hardForce) end)
    pcall(function() DoorSystemSetAutomaticDistance(dh, 0.0, false, false) end)
    FreezeEntityPosition(ent, false)
    SetEntityDynamic(ent, true)
    SetEntityInvincible(ent, false)
    SetEntityCanBeDamaged(ent, true)
end


applyBarrierEntity = function(ent, locked, slab, hardForce)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    if not entitySnapshots[ent] then rememberEntitySnapshot(ent) end
    if locked then
        local tx, ty, tz, th
        if slab and slab.heading then
            tx, ty, tz = slab.coords.x, slab.coords.y, slab.coords.z
            th = slab.heading + 0.0
        else
            local snap = entitySnapshots[ent]
            if not snap then return end
            tx, ty, tz = snap.coords.x, snap.coords.y, snap.coords.z
            th = snap.heading
        end
        if not hardForce then
            local c = GetEntityCoords(ent)
            local h = GetEntityHeading(ent)
            local headingDiff = math.abs(((h - th + 540.0) % 360.0) - 180.0)
            if #(c - vector3(tx, ty, tz)) < 0.08 and headingDiff < 1.5 and IsEntityPositionFrozen(ent) then
                return
            end
        end
        SetEntityCoords(ent, tx, ty, tz, false, false, false, false)
        SetEntityHeading(ent, th)
        FreezeEntityPosition(ent, true)
        SetEntityDynamic(ent, false)
        SetEntityInvincible(ent, true)
        SetEntityCanBeDamaged(ent, false)
    else
        if not hardForce and not IsEntityPositionFrozen(ent) then
            return
        end
        FreezeEntityPosition(ent, false)
        SetEntityDynamic(ent, true)
        SetEntityInvincible(ent, false)
        SetEntityCanBeDamaged(ent, true)
    end
end

local function applyBarrierGroupLocked(slabs, entities, locked, raiseZ, hardForce)
    raiseZ = raiseZ or DEFAULT_BOLLARD_RAISE_Z
    for _, ent in ipairs(entities or {}) do
        if isBollardModel(GetEntityModel(ent)) then
            applyBollardEntity(ent, locked, raiseZ, findSlabForEntity(slabs, ent), hardForce)
        else
            applyBarrierEntity(ent, locked, findSlabForEntity(slabs, ent, 6.0), hardForce)
        end
    end
    for _, slab in ipairs(slabs or {}) do
        local ent = findClosestObject(slab.modelHash, slab.coords, 6.0)
        if ent ~= 0 then
            if isBollardModel(slab.modelHash) then
                applyBollardEntity(ent, locked, raiseZ, slab, hardForce)
            else
                applyBarrierEntity(ent, locked, slab, hardForce)
            end
        end
    end
end

local function gateSlabForGroup(slabs)
    for _, slab in ipairs(slabs or {}) do
        if isFacGateModel(slab.modelHash) then
            return slab
        end
    end
    return slabs and slabs[1] or nil
end

local function applyYardGateGroupLocked(group, locked, hardForce)
    local slabs = group.slabs
    local entities = group.entities
    local gateSlab = gateSlabForGroup(slabs)
    local raiseZ = bollardRaiseForGroup(group)
    local openDelta = group.gateOpenHeadingDelta or 82.0
    local seen = {}
    for _, ent in ipairs(entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            seen[ent] = true
            local model = GetEntityModel(ent)
            local slab = findSlabForEntity(slabs, ent)
            if isBollardModel(model) then
                applyBollardEntity(ent, locked, raiseZ, slab, hardForce)
            elseif isFacGateModel(model) then
                applyFacGateEntity(ent, locked, slab or gateSlab, openDelta, hardForce)
            else
                applyBarrierEntity(ent, locked, slab or gateSlab, hardForce)
            end
        end
    end
    for _, slab in ipairs(slabs or {}) do
        local ent = findClosestObject(slab.modelHash, slab.coords, 8.0)
        if ent ~= 0 and not seen[ent] then
            if isFacGateModel(slab.modelHash) then
                applyFacGateEntity(ent, locked, slab, openDelta, hardForce)
            elseif isBollardModel(slab.modelHash) then
                applyBollardEntity(ent, locked, raiseZ, slab, hardForce)
            else
                applyBarrierEntity(ent, locked, slab, hardForce)
            end
        end
    end
end

local function applyBollardGroupLocked(slabs, entities, locked, raiseZ, hardForce)
    raiseZ = raiseZ or DEFAULT_BOLLARD_RAISE_Z
    for _, ent in ipairs(entities or {}) do
        applyBollardEntity(ent, locked, raiseZ, findSlabForEntity(slabs, ent), hardForce)
    end
    for _, slab in ipairs(slabs or {}) do
        local ent = findClosestObject(slab.modelHash, slab.coords, 8.0)
        if ent ~= 0 then applyBollardEntity(ent, locked, raiseZ, slab, hardForce) end
    end
end

local function applyGarageRollLocked(slabs, entities, locked, hardForce)
    local seen = {}
    for _, slab in ipairs(slabs or {}) do
        applyGarageSlabDoorSystem(slab, locked, hardForce)
        local ent = findClosestObject(slab.modelHash, slab.coords, 8.0)
        if ent ~= 0 then
            seen[ent] = true
            if locked then
                seedGarageEntitySnapshot(ent, slab)
            end
            applyGarageEntityDoor(ent, locked, slab, hardForce)
        end
    end
    for _, ent in ipairs(entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) and not seen[ent] then
            seen[ent] = true
            applyGarageEntityDoor(ent, locked, nil, hardForce)
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
                -- Užrakinta entity privalo likti su collision; kitaip galima praeiti kiaurai.
                SetEntityCollision(ent, true, true)
            else
                FreezeEntityPosition(ent, false)
                SetEntityCollision(ent, true, true)
            end
        end
    end
end

local function scanEntitiesForDef(entityScan, playerCoords)
    if not entityScan or not entityScan.center then return {} end
    local center = entityScan.center
    local radius = entityScan.radius or 12.0
    if playerCoords and #(playerCoords - center) > radius + 28.0 then
        -- nil reiškia „nuskenuoti praleista“, o ne „durų nebėra“.
        return nil
    end
    local models = {}
    for _, name in ipairs(entityScan.models or {}) do
        models[joaat(name)] = true
    end
    local out = {}
    for _, ent in ipairs(getCachedObjectPool(8000)) do
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

--- Identity-only signature: model/handle/doorHash — not live open-door world coords (anti-flash).
local function doorGroupEntitySig(group)
    if not group then return 0 end
    local parts = { tostring(#(group.slabs or {})) }
    for _, slab in ipairs(group.slabs or {}) do
        parts[#parts + 1] = ('s:%x:%x'):format(slab.doorHash or 0, slab.modelHash or 0)
    end
    for _, ent in ipairs(group.entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            parts[#parts + 1] = ('e:%x:%d'):format(GetEntityModel(ent), ent)
        end
    end
    table.sort(parts)
    return joaat(table.concat(parts, '|'))
end

local function entitiesScanMeaningfullyChanged(groupId, newSig)
    local prev = doorEntityScanSig[groupId]
    if prev == newSig then return false end
    doorEntityScanSig[groupId] = newSig
    return prev ~= nil
end

--- Ar specialus (garažas/vartai) fiziškai neatitinka užrakintos būsenos — soft maintain trigger.
local function specialGroupNeedsResync(group, locked)
    if not group or not locked then return false end
    local dtype = group.doorType
    if dtype == 'garage_roll' then
        for _, slab in ipairs(group.slabs or {}) do
            if not doorSystemMatchesLocked(slab.doorHash, true) then return true end
            local ratio = doorSystemGetRatio(slab.doorHash)
            if ratio and ratio > 0.08 then return true end
        end
        for _, ent in ipairs(group.entities or {}) do
            if ent and ent ~= 0 and DoesEntityExist(ent) and not IsEntityPositionFrozen(ent) then
                return true
            end
        end
        return false
    end
    if dtype == 'bollard' or dtype == 'barrier' or dtype == 'yard_gate' then
        for _, ent in ipairs(group.entities or {}) do
            if ent and ent ~= 0 and DoesEntityExist(ent) and not IsEntityPositionFrozen(ent) then
                return true
            end
        end
        for _, slab in ipairs(group.slabs or {}) do
            local ent = findClosestObject(slab.modelHash, slab.coords, 6.0)
            if ent ~= 0 and not IsEntityPositionFrozen(ent) then
                return true
            end
        end
        return false
    end
    return false
end

applyGroupLocked = function(id, locked, force)
    local group
    for _, g in ipairs(doorGroups) do
        if g.id == id then
            group = g
            break
        end
    end
    if not group then return end

    local hardForce = force == true
    local sig = doorGroupEntitySig(group)
    if not hardForce and lastAppliedLockState[id] == locked and lastAppliedEntitySig[id] == sig then
        return
    end
    lastAppliedLockState[id] = locked
    lastAppliedEntitySig[id] = sig

    local g = group
    if g.doorType == 'garage_roll' then
        applyGarageRollLocked(g.slabs, g.entities, locked, hardForce)
        return
    end
    if g.doorType == 'bollard' then
        applyBollardGroupLocked(g.slabs, g.entities, locked, bollardRaiseForGroup(g), hardForce)
        return
    end
    if g.doorType == 'yard_gate' then
        applyYardGateGroupLocked(g, locked, hardForce)
        return
    end
    if g.doorType == 'barrier' then
        applyBarrierGroupLocked(g.slabs, g.entities, locked, bollardRaiseForGroup(g), hardForce)
        return
    end
    for _, slab in ipairs(g.slabs) do
        applyStandardSlabLocked(slab, locked, hardForce)
    end
    applyEntityGroupLocked(g.entities, locked)
end

local function buildManualGroupDef(def)
    local slabs = {}
    for i, d in ipairs(def.doors or {}) do
        local coords = d.coords
        local model = d.model
        local slab = registerSlab(def.id, i, model, coords, d.heading, {
            restZ = d.restZ,
            pitch = d.pitch,
            roll = d.roll,
        })
        if def.doorType == 'garage_roll' or def.doorType == 'yard_gate' then
            if d.heading then
                slab.heading = d.heading + 0.0
            end
        else
            alignSlabToWorld(slab)
            if d.heading then
                slab.heading = d.heading + 0.0
                snapSlabEntity(slab)
            end
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
    local groundZHint = nil
    for _, slab in ipairs(slabs) do
        if slab.restZ then
            groundZHint = slab.restZ
            break
        end
    end
    if not groundZHint and #slabs > 0 then
        groundZHint = slabs[1].coords.z
    end
    for _, ent in ipairs(entities) do
        if def.doorType == 'garage_roll' then
            local ec = GetEntityCoords(ent)
            local em = GetEntityModel(ent)
            local matched = nil
            for _, slab in ipairs(slabs) do
                if slab.modelHash == em and #(ec - slab.coords) < 5.0 then
                    matched = slab
                    break
                end
            end
            if matched then
                seedGarageEntitySnapshot(ent, matched)
            else
                rememberEntitySnapshot(ent)
            end
        elseif def.doorType == 'yard_gate' then
            local raiseZ = def.bollardRaiseZ or DEFAULT_BOLLARD_RAISE_Z
            if isBollardModel(GetEntityModel(ent)) then
                rememberBollardSnapshot(ent, def.defaultLocked ~= false, raiseZ, groundZHint, findSlabForEntity(slabs, ent))
            else
                rememberEntitySnapshot(ent)
            end
        else
            rememberEntitySnapshot(ent)
        end
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
        bollardRaiseZ = def.bollardRaiseZ,
        gateOpenHeadingDelta = def.gateOpenHeadingDelta,
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
    for _, def in ipairs(Config.RangerDoorGroups or {}) do
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
    for _, ent in ipairs(getCachedObjectPool(10000)) do
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
    local newGroupIds = {}

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
            registerDoorGroupTarget(doorGroups[#doorGroups])
            newGroupIds[#newGroupIds + 1] = groupId
            local regSlabs = {}
            for _, s in ipairs(cluster) do
                regSlabs[#regSlabs + 1] = { x = s.coords.x, y = s.coords.y, z = s.coords.z, model = s.modelHash }
            end
            TriggerServerEvent('mrp_ltpd:server:registerPdDynDoorGroup', groupId, dyn.stationId, c.x, c.y, c.z, dyn.interactDist or 2.5, regSlabs)
        end
    end
    for _, gid in ipairs(newGroupIds) do
        applyGroupLocked(gid, doorLocked[gid] ~= false)
    end
    if #newGroupIds > 0 then
        refreshPdDoorInteractZones()
        nearDoorDistCache.at = 0
    end
    if #found > 0 then
        dynStationDone[dyn.stationId] = true
    end
end

CreateThread(function()
    Wait(1500)
    buildManualGroups()
    refreshPdDoorProximityCache()
    for id, locked in pairs(doorLocked) do
        applyGroupLocked(id, locked)
    end
    if pdDoorUseQbTarget() then
        local waited = 0
        while not setupDoorTargetsFromZones() and waited < 45 do
            Wait(1000)
            waited = waited + 1
        end
    end
end)

CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        local doorNear = nearestPdDoorDist(pc)
        local waitMs = doorNear < 70.0 and 12000 or 25000
        Wait(waitMs)
        if doorNear > 150.0 then
            goto continue
        end
        invalidateObjectPoolCache()
        for _, g in ipairs(doorGroups) do
            if g.entityScanDef then
                if isDoorTogglePending(g.id) then goto next_group end
                local ents = scanEntitiesForDef(g.entityScanDef, pc)
                if not ents or #ents == 0 then goto next_group end
                local newSig = doorGroupEntitySig({ slabs = g.slabs, entities = ents })
                local entitiesChanged = entitiesScanMeaningfullyChanged(g.id, newSig)
                g.entities = ents
                g.lockPosCache = nil
                if not entitiesChanged then goto next_group end
                if g.doorType == 'garage_roll' then
                    for _, ent in ipairs(g.entities) do
                        local ec = GetEntityCoords(ent)
                        local em = GetEntityModel(ent)
                        for _, slab in ipairs(g.slabs or {}) do
                            if slab.modelHash == em and #(ec - slab.coords) < 5.0 then
                                seedGarageEntitySnapshot(ent, slab)
                                break
                            end
                        end
                    end
                    lastAppliedEntitySig[g.id] = nil
                    applyGroupLocked(g.id, doorLocked[g.id] ~= false)
                elseif g.doorType == 'yard_gate' then
                    local raiseZ = bollardRaiseForGroup(g)
                    local groundZHint = nil
                    for _, slab in ipairs(g.slabs or {}) do
                        if slab.restZ then
                            groundZHint = slab.restZ
                            break
                        end
                    end
                    if not groundZHint and g.slabs and g.slabs[1] then
                        groundZHint = g.slabs[1].coords.z
                    end
                    local locked = isGroupLocked(g.id)
                    for _, ent in ipairs(g.entities) do
                        if isBollardModel(GetEntityModel(ent)) then
                            rememberBollardSnapshot(ent, locked, raiseZ, groundZHint, findSlabForEntity(g.slabs, ent))
                        else
                            rememberEntitySnapshot(ent)
                        end
                    end
                    lastAppliedLockState[g.id] = nil
                    lastAppliedEntitySig[g.id] = nil
                    applyGroupLocked(g.id, locked)
                else
                    for _, ent in ipairs(g.entities) do
                        rememberEntitySnapshot(ent)
                    end
                    lastAppliedEntitySig[g.id] = nil
                    applyGroupLocked(g.id, doorLocked[g.id] ~= false)
                end
            end
            ::next_group::
        end
        for _, g in ipairs(doorGroups) do
            if g.interact and not g.entityScanDef and #(pc - g.interact) < 18.0 and not isDoorTogglePending(g.id) then
                local aligned = false
                for _, slab in ipairs(g.slabs or {}) do
                    local before = slab.coords
                    alignSlabToWorld(slab)
                    if #(before - slab.coords) > 0.01 then
                        aligned = true
                    end
                end
                if aligned then
                    g.lockPosCache = nil
                    -- Soft re-sync only; identity sig skip avoids DoorSystem force flash.
                    applyGroupLocked(g.id, doorLocked[g.id] ~= false)
                end
            end
        end
        ::continue::
    end
end)

CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        local doorNear = nearestPdDoorDist(pc)
        local waitMs = doorNear < 90.0 and 3500 or 10000
        Wait(waitMs)
        local allDone = true
        for _, dyn in ipairs(allDoorDynamics()) do
            if not dynStationDone[dyn.stationId] then
                allDone = false
                break
            end
        end
        if allDone then
            Wait(doorNear < 90.0 and 15000 or 30000)
            goto continue
        end
        for _, dyn in ipairs(allDoorDynamics()) do
            if not dynStationDone[dyn.stationId] then
                local c = (dyn.bounds.min + dyn.bounds.max) * 0.5
                if #(pc - c) < 145.0 then
                    scanDynamicForStation(dyn)
                end
            end
        end
        ::continue::
    end
end)

RegisterNetEvent('mrp_ltpd:client:syncPdDoors', function(states)
    if type(states) ~= 'table' then return end
    for k, v in pairs(states) do
        local parsed = parseDoorLocked(v)
        if parsed ~= nil then
            doorLocked[k] = parsed
        end
    end
    for id, locked in pairs(doorLocked) do
        if lastAppliedLockState[id] ~= locked then
            applyGroupLocked(id, locked)
        end
    end
end)

RegisterNetEvent('mrp_ltpd:client:setPdDoorState', function(id, locked)
    if not id then return end
    local parsed = parseDoorLocked(locked)
    if parsed == nil then parsed = locked == true end
    doorTogglePendingUntil[id] = nil
    if doorLocked[id] == parsed and lastAppliedLockState[id] == parsed then
        return
    end
    doorLocked[id] = parsed
    doorIconStable[id] = { value = parsed, since = GetGameTimer() }
    lastAppliedLockState[id] = nil
    lastAppliedEntitySig[id] = nil
    applyGroupLocked(id, parsed, true)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('mrp_ltpd:server:requestPdDoorsSync')
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(4000, function()
        TriggerServerEvent('mrp_ltpd:server:requestPdDoorsSync')
    end)
end)

local function doorToggleReachFor(dist)
    local maxReach = tonumber(Config.PdDoorToggleReach) or 6.0
    return math.min(maxReach, doorInteractRadius(dist))
end

local function findNearestToggleDoor(pcoords)
    if not canUseServiceDoorsClient() then return nil end
    local closestHit = nil
    local preScan = (tonumber(Config.PdDoorToggleReach) or 6.0) + 2.5

    --- Pirma greiti interact zonų kandidatai (be entity scan).
    for _, z in ipairs(getPdDoorProximityZones()) do
        if not canUseDoorGroupClient(z.groupId) then goto continue_zone end
        local d = #(pcoords - z.pos)
        if d > preScan then goto continue_zone end
        local r = doorToggleReachFor(z.maxd)
        if d <= r and (not closestHit or d < closestHit.d) then
            local g = findDoorGroupById(z.groupId)
            local lockPos = resolveDoorLockPos(g)
            local lockD = lockPos and #(pcoords - lockPos) or d
            --- Jei spyna arčiau / tame pačiame reach — prioritetas spynai.
            if lockPos and lockD <= r then
                closestHit = {
                    gid = z.groupId,
                    d = lockD,
                    pos = lockPos,
                    lockPos = lockPos,
                    label = (g or {}).label,
                }
            elseif not closestHit or d < closestHit.d then
                closestHit = {
                    gid = z.groupId,
                    d = d,
                    pos = z.pos,
                    lockPos = lockPos,
                    label = (g or {}).label,
                }
            end
        end
        ::continue_zone::
    end
    return closestHit
end

local function tryToggleNearestDoor(pcoords)
    local hit = findNearestToggleDoor(pcoords)
    if not hit then return end
    requestPdDoorToggle(hit.gid)
end

--- Cache: sunki paieška retai, piešimas — tik iš cache (pigus DrawSprite).
local doorIconTarget = {
    hit = nil,
    at = 0,
    near = 999999.0,
}

CreateThread(function()
    local iconDrawDist = tonumber(Config.PdDoorLockIconDrawDistance) or 10.0
    while true do
        local waitMs = 900
        if canUseServiceDoorsClient() then
            local pcoords = GetEntityCoords(PlayerPedId())
            local doorNear = nearestPdDoorDist(pcoords)
            doorIconTarget.near = doorNear
            if doorNear < iconDrawDist + 8.0 then
                waitMs = 150
                doorIconTarget.hit = findNearestToggleDoor(pcoords)
                doorIconTarget.at = GetGameTimer()
            else
                doorIconTarget.hit = nil
                if doorNear < 45.0 then waitMs = 400 end
            end
        else
            doorIconTarget.hit = nil
        end
        Wait(waitMs)
    end
end)

--- Spynos ikona + E. DrawSprite kiekvieną kadrą TIK kai yra cache hit — be sunkių loop'ų.
CreateThread(function()
    local iconDrawDist = tonumber(Config.PdDoorLockIconDrawDistance) or 10.0
    while true do
        local hit = doorIconTarget.hit
        if hit and canUseServiceDoorsClient() and doorIconTarget.near < iconDrawDist then
            local locked = stableDoorIconLocked(hit.gid)
            local lockPos = hit.lockPos
            if lockPos then
                drawPdDoorLock(lockPos.x, lockPos.y, lockPos.z, locked)
            end
            EnableControlAction(0, 38, true)
            if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                requestPdDoorToggle(hit.gid)
            end
            Wait(0)
        else
            Wait(doorIconTarget.near < 45.0 and 250 or 800)
        end
    end
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'qb-target' and pdDoorUseQbTarget() then
        SetTimeout(800, function()
            refreshPdDoorInteractZones()
        end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for zoneId in pairs(doorTargetZoneIds) do
        removeDoorTargetZone(zoneId)
    end
end)

--- Užrakinti garažo / kiemo vartai: retas patikrinimas.
--- Soft maintain — hard DoorSystem force tik per E / setPdDoorState.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        if nearestPdDoorDist(pc) > 130.0 then
            Wait(8000)
        else
            local anyNear = false
            for _, g in ipairs(doorGroups) do
                if isDoorTogglePending(g.id) then goto continue_maint end
                if not isGroupLocked(g.id) then goto continue_maint end
                local near = g.interact and #(pc - g.interact) < 55.0
                local special = g.doorType == 'garage_roll' or g.doorType == 'barrier'
                    or g.doorType == 'yard_gate' or g.doorType == 'bollard'
                if g.doorType == 'garage_roll' then
                    near = g.interact and #(pc - g.interact) < 90.0
                end
                if near then
                    anyNear = true
                    if special then
                        if specialGroupNeedsResync(g, true) then
                            lastAppliedLockState[g.id] = nil
                            lastAppliedEntitySig[g.id] = nil
                            applyGroupLocked(g.id, true, false)
                        end
                    else
                        local needs = false
                        for _, slab in ipairs(g.slabs or {}) do
                            if not doorSystemMatchesLocked(slab.doorHash, true) then
                                needs = true
                                break
                            end
                            local ratio = doorSystemGetRatio(slab.doorHash)
                            if ratio and ratio > 0.08 then
                                needs = true
                                break
                            end
                        end
                        if needs then
                            lastAppliedLockState[g.id] = nil
                            applyGroupLocked(g.id, true, false)
                        end
                    end
                end
                ::continue_maint::
            end
            Wait(anyNear and 14000 or 18000)
        end
    end
end)
