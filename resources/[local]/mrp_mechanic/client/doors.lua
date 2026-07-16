local QBCore = exports['qb-core']:GetCoreObject()

local doorGroups = {}
local doorLocked = {}
local entitySnapshots = {}
local doorTargetZoneIds = {}
local autoRelockState = {}

local LOCK_TX = 'mpsafecracking'
local LOCK_ICON_W = 0.016
local LOCK_ICON_H = 0.028

CreateThread(function()
    RequestStreamedTextureDict(LOCK_TX, false)
    while not HasStreamedTextureDictLoaded(LOCK_TX) do Wait(50) end
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

local function isMechanicOnDuty()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty == true
end

local function isGroupLocked(groupId)
    return doorLocked[groupId] ~= false
end

local function parseDoorLocked(v)
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
    return nil
end

local function drawDoorLock(worldX, worldY, worldZ, locked)
    if not HasStreamedTextureDictLoaded(LOCK_TX) then return end
    local r, g, b = 78, 220, 118
    if locked then r, g, b = 245, 72, 72 end
    SetDrawOrigin(worldX, worldY, worldZ, 0)
    DrawSprite(LOCK_TX, locked and 'lock_closed' or 'lock_open', 0.0, 0.0, LOCK_ICON_W * 1.42, LOCK_ICON_H * 1.42, 0.0, r, g, b, 45)
    DrawSprite(LOCK_TX, locked and 'lock_closed' or 'lock_open', 0.0, 0.0, LOCK_ICON_W, LOCK_ICON_H, 0.0, r, g, b, 245)
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

local function ensureDoorInSystem(dh, modelHash, x, y, z)
    local ok, reg = pcall(function()
        return IsDoorRegisteredWithSystem(dh)
    end)
    if not ok or not reg then
        AddDoorToSystem(dh, modelHash, x, y, z, false, false, false)
    end
end

local function entityDoorHash(ent)
    return joaat(('mech_gd_%s'):format(ent))
end

local function applyGarageEntityDoor(ent, locked)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local model = GetEntityModel(ent)
    local c = GetEntityCoords(ent)
    local dh = entityDoorHash(ent)
    if locked then
        ensureDoorInSystem(dh, model, c.x, c.y, c.z)
        DoorSystemSetDoorState(dh, 1, false, true)
        pcall(function() DoorSystemSetOpenRatio(dh, 0.0, true, true) end)
        pcall(function() DoorSystemSetAutomaticDistance(dh, 0.0, false, false) end)
        pcall(function() DoorSystemSetHoldOpen(dh, false) end)
        snapEntityToSnapshot(ent)
        FreezeEntityPosition(ent, true)
        SetEntityDynamic(ent, false)
        SetEntityInvincible(ent, true)
        SetEntityCanBeDamaged(ent, false)
        return
    end
    rememberEntitySnapshot(ent)
    ensureDoorInSystem(dh, model, c.x, c.y, c.z)
    DoorSystemSetDoorState(dh, 0, false, true)
    pcall(function() DoorSystemSetOpenRatio(dh, 1.0, true, true) end)
    pcall(function() DoorSystemSetAutomaticDistance(dh, 0.0, false, false) end)
    FreezeEntityPosition(ent, false)
    SetEntityDynamic(ent, true)
    SetEntityInvincible(ent, false)
    SetEntityCanBeDamaged(ent, true)
end

local function applyGarageRollLocked(entities, locked)
    for _, ent in ipairs(entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            if locked then rememberEntitySnapshot(ent) end
            applyGarageEntityDoor(ent, locked)
        end
    end
end

local function applyEntityGroupLocked(entities, locked)
    for _, ent in ipairs(entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            rememberEntitySnapshot(ent)
            if locked then
                snapEntityToSnapshot(ent)
                FreezeEntityPosition(ent, true)
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
    if playerCoords and #(playerCoords - center) > radius + 65.0 then
        return {}
    end
    local models = {}
    for _, name in ipairs(entityScan.models or {}) do
        models[joaat(name)] = true
    end
    local found = {}
    for _, ent in ipairs(getCachedObjectPool(8000)) do
        if DoesEntityExist(ent) then
            local m = GetEntityModel(ent)
            if models[m] then
                local c = GetEntityCoords(ent)
                local dist = #(c - center)
                if dist <= radius then
                    found[#found + 1] = { ent = ent, dist = dist }
                end
            end
        end
    end
    table.sort(found, function(a, b) return a.dist < b.dist end)
    local maxCount = entityScan.maxCount or 4
    local out = {}
    for i = 1, math.min(#found, maxCount) do
        out[#out + 1] = found[i].ent
    end
    return out
end

local function applyGroupLocked(id, locked)
    for _, g in ipairs(doorGroups) do
        if g.id == id then
            if g.doorType == 'garage_roll' then
                applyGarageRollLocked(g.entities, locked)
            else
                applyEntityGroupLocked(g.entities, locked)
            end
            return
        end
    end
end

local function nearestDoorDist(pcoords)
    local best = 9999.0
    for _, g in ipairs(doorGroups) do
        local count = 0
        local sum = vector3(0.0, 0.0, 0.0)
        for _, ent in ipairs(g.entities or {}) do
            if ent and ent ~= 0 and DoesEntityExist(ent) then
                sum = sum + GetEntityCoords(ent)
                count = count + 1
            end
        end
        if count > 0 then
            best = math.min(best, #(pcoords - (sum / count)))
        end
        if g.interact then
            local d = #(pcoords - g.interact)
            if d < best then best = d end
        end
    end
    return best
end

local function buildGroups()
    doorGroups = {}
    for _, def in ipairs(Config.DoorGroups or {}) do
        local entities = scanEntitiesForDef(def.entityScan)
        doorGroups[#doorGroups + 1] = {
            id = def.id,
            label = def.label or 'Durys',
            doorType = def.doorType,
            interact = def.interact,
            interactDist = def.interactDist or 4.0,
            entities = entities,
            entityScanDef = def.entityScan,
        }
        if doorLocked[def.id] == nil then
            doorLocked[def.id] = def.defaultLocked ~= false
        end
    end
end

local function doorInteractRadius(fallback)
    return Config.DoorToggleReach or fallback or 5.0
end

local lastToggle = 0

local function resolveDoorLockPos(group)
    if not group then return nil end
    if group.lockPosCache then return group.lockPosCache end
    local count = 0
    local sum = vector3(0.0, 0.0, 0.0)
    for _, ent in ipairs(group.entities or {}) do
        if ent and ent ~= 0 and DoesEntityExist(ent) then
            sum = sum + GetEntityCoords(ent)
            count = count + 1
        end
    end
    if count > 0 then
        local center = sum / count
        local zOff = group.doorType == 'garage_roll' and 0.55 or 0.45
        group.lockPosCache = vector3(center.x, center.y, center.z + zOff)
        return group.lockPosCache
    end
    if group.interact then
        group.lockPosCache = vector3(group.interact.x, group.interact.y, group.interact.z + 0.45)
        return group.lockPosCache
    end
    return nil
end

local function tryToggleNearestDoor(pcoords)
    if not isMechanicOnDuty() then return end
    local reach = doorInteractRadius()
    local closestHit = nil
    for _, g in ipairs(doorGroups) do
        local lockPos = resolveDoorLockPos(g) or g.interact
        if lockPos then
            local d = #(pcoords - lockPos)
            if d <= reach and (not closestHit or d < closestHit.d) then
                closestHit = { gid = g.id, d = d }
            end
        end
    end
    if not closestHit then return end
    local now = GetGameTimer()
    if now - lastToggle <= 650 then return end
    lastToggle = now
    TriggerServerEvent('mrp_mechanic:server:toggleDoorGroup', closestHit.gid)
end

local function removeDoorTargetZone(zoneId)
    if not doorTargetZoneIds[zoneId] then return end
    if GetResourceState('qb-target') == 'started' then
        pcall(function() exports['qb-target']:RemoveZone(zoneId) end)
    end
    doorTargetZoneIds[zoneId] = nil
end

local function registerDoorTargetZone(zoneId, groupId, pos, interactDist, label)
    if GetResourceState('qb-target') ~= 'started' then return false end
    removeDoorTargetZone(zoneId)
    local radius = interactDist or 4.0
    exports['qb-target']:AddCircleZone(zoneId, pos, radius + 0.35, {
        name = zoneId,
        debugPoly = false,
        useZ = true,
    }, {
        options = {
            {
                icon = 'fas fa-door-closed',
                label = label or 'Durys',
                action = function()
                    TriggerServerEvent('mrp_mechanic:server:toggleDoorGroup', groupId)
                end,
                canInteract = function()
                    return isMechanicOnDuty()
                end,
            },
        },
        distance = radius + 1.25,
    })
    doorTargetZoneIds[zoneId] = true
    return true
end

local function setupDoorTargets()
    if GetResourceState('qb-target') ~= 'started' then return false end
    for _, g in ipairs(doorGroups) do
        if g.interact then
            registerDoorTargetZone(('mech_door_%s'):format(g.id), g.id, g.interact, g.interactDist, g.label)
        end
    end
    return true
end

CreateThread(function()
    Wait(2000)
    buildGroups()
    for id, locked in pairs(doorLocked) do
        applyGroupLocked(id, locked)
    end
    local waited = 0
    while not setupDoorTargets() and waited < 30 do
        Wait(1000)
        waited = waited + 1
    end
end)

CreateThread(function()
    while true do
        Wait(20000)
        local pc = GetEntityCoords(PlayerPedId())
        if nearestDoorDist(pc) > 150.0 then goto continue end
        invalidateObjectPoolCache()
        for _, g in ipairs(doorGroups) do
            if g.entityScanDef then
                local ents = scanEntitiesForDef(g.entityScanDef, pc)
                if #ents > 0 then
                    g.entities = ents
                    g.lockPosCache = nil
                    applyGroupLocked(g.id, isGroupLocked(g.id))
                end
            end
        end
        ::continue::
    end
end)

RegisterNetEvent('mrp_mechanic:client:syncDoors', function(state)
    if type(state) ~= 'table' then return end
    for k, v in pairs(state) do
        local parsed = parseDoorLocked(v)
        if parsed ~= nil then
            doorLocked[k] = parsed
            autoRelockState[k] = parsed and nil or { opened = false, requestedAt = 0 }
        end
    end
    for id, locked in pairs(doorLocked) do
        applyGroupLocked(id, locked)
    end
end)

RegisterNetEvent('mrp_mechanic:client:setDoorState', function(id, locked)
    if type(id) ~= 'string' then return end
    local parsed = parseDoorLocked(locked)
    if parsed == nil then return end
    doorLocked[id] = parsed
    autoRelockState[id] = parsed and nil or { opened = false, requestedAt = 0 }
    applyGroupLocked(id, doorLocked[id])
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    Wait(2000)
    TriggerServerEvent('mrp_mechanic:server:requestDoorsSync')
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetTimeout(4000, function()
        TriggerServerEvent('mrp_mechanic:server:requestDoorsSync')
    end)
end)

AddEventHandler('onResourceStart', function(res)
    if res == 'qb-target' then
        SetTimeout(800, function()
            for zoneId in pairs(doorTargetZoneIds) do
                removeDoorTargetZone(zoneId)
            end
            setupDoorTargets()
        end)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for zoneId in pairs(doorTargetZoneIds) do
        removeDoorTargetZone(zoneId)
    end
end)

local cachedMechDoorTarget = { group = nil, pos = nil, dist = 9999.0 }

CreateThread(function()
    while true do
        local waitMs = 900
        if isMechanicOnDuty() then
            local pcoords = GetEntityCoords(PlayerPedId())
            local near = nearestDoorDist(pcoords)
            if near < 28.0 then
                waitMs = 150
                local nearest, nearestDist = nil, 9999.0
                for _, g in ipairs(doorGroups) do
                    local lockPos = resolveDoorLockPos(g)
                    if lockPos then
                        local d = #(pcoords - lockPos)
                        if d < nearestDist then
                            nearest, nearestDist = { group = g, pos = lockPos }, d
                        end
                    end
                end
                if nearest and nearestDist <= (Config.DoorToggleReach or 5.0) then
                    cachedMechDoorTarget = { group = nearest.group, pos = nearest.pos, dist = nearestDist }
                else
                    cachedMechDoorTarget = { group = nil, pos = nil, dist = 9999.0 }
                end
            else
                cachedMechDoorTarget = { group = nil, pos = nil, dist = 9999.0 }
            end
        else
            cachedMechDoorTarget = { group = nil, pos = nil, dist = 9999.0 }
        end
        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local target = cachedMechDoorTarget
        if isMechanicOnDuty() and target and target.pos and target.group then
            local g = target.group
            local pos = target.pos
            drawDoorLock(pos.x, pos.y, pos.z, isGroupLocked(g.id))
            EnableControlAction(0, 38, true)
            if IsControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 38) then
                tryToggleNearestDoor(GetEntityCoords(PlayerPedId()))
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

local function entityGroupPhysicalState(group)
    if not group or group.doorType == 'garage_roll' then return false, true end
    local anyOpen, allClosed, count = false, true, 0
    for _, ent in ipairs(group.entities or {}) do
        local snap = entitySnapshots[ent]
        if snap and DoesEntityExist(ent) then
            count = count + 1
            local c = GetEntityCoords(ent)
            local heading = GetEntityHeading(ent)
            local headingDelta = math.abs(((heading - snap.heading + 180.0) % 360.0) - 180.0)
            local moved = #(c - snap.coords)
            if headingDelta > 7.0 or moved > 0.16 then anyOpen = true end
            if headingDelta > 2.0 or moved > 0.045 then allClosed = false end
        end
    end
    return count > 0 and anyOpen, count > 0 and allClosed
end

--- Mechanikų paprastos durys: po atidarymo ir sugrįžimo į uždarytą padėtį užrakinti.
CreateThread(function()
    while true do
        local waitMs = 700
        if isMechanicOnDuty() then
            local pc = GetEntityCoords(PlayerPedId())
            for _, group in ipairs(doorGroups) do
                local state = autoRelockState[group.id]
                local lockPos = state and resolveDoorLockPos(group) or nil
                if state and not isGroupLocked(group.id) and lockPos and #(pc - lockPos) < 18.0 then
                    waitMs = 100
                    local anyOpen, allClosed = entityGroupPhysicalState(group)
                    if anyOpen then state.opened = true end
                    if state.opened and allClosed and GetGameTimer() - (state.requestedAt or 0) > 1200 then
                        state.requestedAt = GetGameTimer()
                        TriggerServerEvent('mrp_mechanic:server:toggleDoorGroup', group.id, true)
                    end
                end
            end
        end
        Wait(waitMs)
    end
end)

CreateThread(function()
    while true do
        local pc = GetEntityCoords(PlayerPedId())
        if nearestDoorDist(pc) > 130.0 then
            Wait(4000)
        else
            local anyNear = false
            for _, g in ipairs(doorGroups) do
                if g.doorType == 'garage_roll' and isGroupLocked(g.id) and g.interact and #(pc - g.interact) < 90.0 then
                    anyNear = true
                    applyGarageRollLocked(g.entities, true)
                end
            end
            Wait(anyNear and 5000 or 8000)
        end
    end
end)
