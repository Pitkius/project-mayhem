local QBCore = exports['qb-core']:GetCoreObject()

--- @class LtpdDoorSlab
--- @field doorHash number
--- @field modelHash number
--- @field coords vector3

--- @class LtpdDoorGroupRuntime
--- @field id string
--- @field label string
--- @field interact vector3
--- @field interactDist number
--- @field slabs LtpdDoorSlab[]

local doorGroups = {} ---@type LtpdDoorGroupRuntime[]
local doorLocked = {} ---@type table<string, boolean>
local dynStationDone = {} ---@type table<string, boolean>

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
    SetDrawOrigin(worldX, worldY, worldZ + 0.24, 0)
    DrawSprite(PD_LOCK_TX, locked and 'lock_closed' or 'lock_open', 0.0, 0.0, 0.038, 0.066, 0.0, 235, 232, 255, 235)
    ClearDrawOrigin()
end

local function isPdJobName(name)
    if not name then return false end
    if name == Config.JobName then return true end
    if Config.AcceptLegacyPoliceJob and name == 'police' then return true end
    return false
end

local function isPdOnDutyClient()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and isPdJobName(P.job.name) and P.job.onduty
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

local function ensureDoorInSystem(dh, modelHash, x, y, z)
    local ok, reg = pcall(function()
        return IsDoorRegisteredWithSystem(dh)
    end)
    if not ok or not reg then
        AddDoorToSystem(dh, modelHash, x, y, z, false, false, false)
    end
end

local function registerSlab(groupId, slabIndex, modelName, coords)
    local modelHash = type(modelName) == 'string' and joaat(modelName) or modelName
    local dh = slabScriptHash(groupId, slabIndex)
    ensureDoorInSystem(dh, modelHash, coords.x, coords.y, coords.z)
    return { doorHash = dh, modelHash = modelHash, coords = coords }
end

local function registerDynSlab(modelHash, x, y, z)
    local dh = dynSlabScriptHash(modelHash, x, y, z)
    ensureDoorInSystem(dh, modelHash, x, y, z)
    return { doorHash = dh, modelHash = modelHash, coords = vector3(x, y, z) }
end

local function applyGroupLocked(id, locked)
    for _, g in ipairs(doorGroups) do
        if g.id == id then
            local state = locked and 1 or 0
            for _, slab in ipairs(g.slabs) do
                DoorSystemSetDoorState(slab.doorHash, state, false, false)
            end
            return
        end
    end
end

local function buildManualGroups()
    for _, def in ipairs(Config.PdDoorGroups or {}) do
        local slabs = {}
        for i, d in ipairs(def.doors or {}) do
            local coords = d.coords
            local model = d.model
            slabs[#slabs + 1] = registerSlab(def.id, i, model, coords)
        end
        local interact = def.interact
        if not interact and #slabs > 0 then
            local c = vector3(0, 0, 0)
            for _, s in ipairs(slabs) do
                c = c + s.coords
            end
            interact = c / #slabs
        end
        doorGroups[#doorGroups + 1] = {
            id = def.id,
            label = def.label or 'PD durys',
            interact = interact,
            interactDist = def.interactDist or 2.5,
            slabs = slabs,
        }
        if doorLocked[def.id] == nil then
            doorLocked[def.id] = def.defaultLocked ~= false
        end
    end
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
                if vecInBounds(c, minV, maxV) then
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
        local qx, qy, qz = quantKey(c.x, c.y, c.z)
        local groupId = ('dyn_%s_%x_%d_%d_%d'):format(dyn.stationId, cluster[1].modelHash, qx, qy, qz)
        local slabs = {}
        for si, s in ipairs(cluster) do
            slabs[si] = registerDynSlab(s.modelHash, s.coords.x, s.coords.y, s.coords.z)
        end
        if not groupIdExists(groupId) then
            doorGroups[#doorGroups + 1] = {
                id = groupId,
                label = dyn.label or 'PD durys',
                interact = c + (dyn.interactOffset or vector3(0, 0, 0)),
                interactDist = dyn.interactDist or 2.5,
                slabs = slabs,
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
        Wait(2200)
        local ped = PlayerPedId()
        local pc = GetEntityCoords(ped)
        for _, dyn in ipairs(Config.PdDoorDynamics or {}) do
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
        local waitMs = 650
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        local nearAny = false

        for _, g in ipairs(doorGroups) do
            local dist = #(pcoords - g.interact)
            local maxd = g.interactDist or 2.5
            if dist < maxd + 12.0 then
                waitMs = 120
            end
            if dist < maxd then
                nearAny = true
                waitMs = 0
                if isPdOnDutyClient() then
                    local locked = doorLocked[g.id] ~= false
                    local iconPos = g.interact
                    local best = 99999.0
                    for _, slab in ipairs(g.slabs or {}) do
                        local sd = #(pcoords - slab.coords)
                        if sd < best then
                            best = sd
                            iconPos = slab.coords
                        end
                    end
                    drawPdDoorLock(iconPos.x, iconPos.y, iconPos.z, locked)
                    if IsControlJustPressed(0, 38) then
                        local now = GetGameTimer()
                        if now - lastToggle > 650 then
                            lastToggle = now
                            TriggerServerEvent('fivempro_ltpd:server:togglePdDoorGroup', g.id)
                        end
                    end
                end
            end
        end

        if nearAny then
            Wait(waitMs)
        else
            Wait(waitMs)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(450)
        for _, g in ipairs(doorGroups) do
            local locked = doorLocked[g.id] ~= false
            applyGroupLocked(g.id, locked)
        end
    end
end)
