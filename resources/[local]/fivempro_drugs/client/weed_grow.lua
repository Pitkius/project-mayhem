local QBCore = exports['qb-core']:GetCoreObject()

local fieldSpawns = {}
local fieldsReady = {}
local busy = false

local function plantKey(fieldId, spawnIndex)
    return ('%s:%s'):format(tostring(fieldId), tostring(spawnIndex))
end

local function getField(fieldId)
    for _, field in ipairs(Config.WeedGrowFields or {}) do
        if field.id == fieldId then return field end
    end
end

local function zoneName(fieldId, spawnIndex)
    return ('fivempro_weed_%s_%s'):format(tostring(fieldId), tostring(spawnIndex))
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(10)
        t = t + 1
    end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function ensureGroundLoaded(x, y, z)
    for _ = 1, 8 do
        RequestCollisionAtCoord(x, y, z)
        Wait(0)
    end
end

local function resolveGroundZ(x, y, refZ)
    local z = refZ
    local found, gz = GetGroundZFor_3dCoord(x, y, refZ + 80.0, false)
    if found then z = gz end
    return z
end

local function spawnCoordForIndex(field, index)
    if field.fixedSpawns and field.fixedSpawns[index] then
        local c = field.fixedSpawns[index]
        return vector3(c.x, c.y, c.z)
    end
    local total = math.max(1, tonumber(field.spawnCount) or 8)
    local radius = tonumber(field.radius) or 30.0
    local angle = ((index - 1) / total) * (math.pi * 2.0)
    local ring = 0.28 + (((index - 1) % 4) * 0.14)
    local dist = radius * ring
    local x = field.center.x + math.cos(angle) * dist
    local y = field.center.y + math.sin(angle) * dist
    local z = resolveGroundZ(x, y, field.center.z)
    return vector3(x, y, z)
end

local function setEntityScale(entity, scale)
    scale = tonumber(scale)
    if not entity or not DoesEntityExist(entity) or not scale or math.abs(scale - 1.0) < 0.01 then return end
    local forward, right, up, position = GetEntityMatrix(entity)
    SetEntityMatrix(entity, forward * scale, right * scale, up * scale, position)
end

local function removeZone(fieldId, spawnIndex)
    pcall(function()
        exports['qb-target']:RemoveZone(zoneName(fieldId, spawnIndex))
    end)
end

local function deleteSpawnEntity(fieldId, spawn)
    if spawn.entity and DoesEntityExist(spawn.entity) then
        DeleteEntity(spawn.entity)
    end
    spawn.entity = nil
    removeZone(fieldId, spawn.index)
end

local function propForSpawn(field, spawn)
    local props = field.props or {}
    if not spawn.plant then
        return props.empty or 'bkr_prop_weed_bucket_01a', 'empty'
    end
    local stage = tonumber(spawn.plant.stage) or 1
    if stage >= 3 then return props.stage3 or 'bkr_prop_weed_lrg_01a', 'stage3' end
    if stage >= 2 then return props.stage2 or 'bkr_prop_weed_med_01a', 'stage2' end
    return props.stage1 or 'prop_weed_02', 'stage1'
end

local function propScale(field, stageKey)
    local scales = field.propScale
    if type(scales) == 'table' and scales[stageKey] then
        return scales[stageKey]
    end
    return field.propScale
end

local function runSchedule(profile, onDone)
    exports['fivempro_drugs']:RunScheduleMinigame(profile, onDone)
end

local function attachZone(field, spawn)
    if not spawn.coords then return end
    removeZone(field.id, spawn.index)

    local options = {}
    local stage = spawn.plant and (tonumber(spawn.plant.stage) or 1) or 0

    if not spawn.plant then
        options[#options + 1] = {
            icon = 'fas fa-seedling',
            label = field.plantLabel or 'Sodinti kanapes',
            action = function()
                if busy then return end
                busy = true
                QBCore.Functions.TriggerCallback('fivempro_drugs:server:canPlantWeed', function(ok, reason)
                    if not ok then
                        busy = false
                        return QBCore.Functions.Notify(reason or 'Negalima sodinti.', 'error')
                    end
                    local profile = Config.GetScheduleMinigame('weed_plant')
                    runSchedule(profile, function(success)
                        if not success then
                            busy = false
                            return QBCore.Functions.Notify('Sodinimas nepavyko.', 'error')
                        end
                        local ped = PlayerPedId()
                        local c = GetEntityCoords(ped)
                        TriggerServerEvent('fivempro_drugs:server:plantWeed', field.id, spawn.index, c.x, c.y, c.z)
                        busy = false
                    end)
                end, field.id, spawn.index)
            end,
            canInteract = function()
                return not busy and not spawn.plant
            end,
        }
    elseif stage < 3 then
        options[#options + 1] = {
            icon = 'fas fa-tint',
            label = field.waterLabel or 'Laistyti augalą',
            action = function()
                if busy then return end
                busy = true
                DrugProgress.run('fivempro_drugs_water', field.waterLabel or 'Laistymas…', 3200, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {
                    animDict = 'amb@world_human_gardener_plant@male@base',
                    anim = 'base',
                    flags = 49,
                }, function()
                    TriggerServerEvent('fivempro_drugs:server:waterWeed', field.id, spawn.index)
                    busy = false
                end, function()
                    busy = false
                    QBCore.Functions.Notify('Atšaukta.', 'error')
                end)
            end,
            canInteract = function()
                return not busy and spawn.plant and (tonumber(spawn.plant.stage) or 1) < 3
            end,
        }
    else
        options[#options + 1] = {
            icon = 'fas fa-leaf',
            label = field.harvestLabel or 'Skinti lapus',
            action = function()
                if busy then return end
                busy = true
                QBCore.Functions.TriggerCallback('fivempro_drugs:server:canHarvestWeed', function(ok, reason)
                    if not ok then
                        busy = false
                        return QBCore.Functions.Notify(reason or 'Dar nebrandu.', 'error')
                    end
                    local profile = Config.GetScheduleMinigame('weed_harvest')
                    runSchedule(profile, function(success)
                        if not success then
                            busy = false
                            return QBCore.Functions.Notify('Derlius nepavyko.', 'error')
                        end
                        local ped = PlayerPedId()
                        local c = GetEntityCoords(ped)
                        TriggerServerEvent('fivempro_drugs:server:harvestWeed', field.id, spawn.index, c.x, c.y, c.z)
                        busy = false
                    end)
                end, field.id, spawn.index)
            end,
            canInteract = function()
                return not busy and spawn.plant and (tonumber(spawn.plant.stage) or 0) >= 3
            end,
        }
    end

    if #options == 0 then return end

    exports['qb-target']:AddCircleZone(zoneName(field.id, spawn.index), spawn.coords, tonumber(field.zoneRadius) or 0.95, {
        name = zoneName(field.id, spawn.index),
        debugPoly = false,
        useZ = true,
    }, {
        options = options,
        distance = (field.pickDistance or 2.2) + 0.35,
    })
end

local function spawnProp(field, spawn)
    deleteSpawnEntity(field.id, spawn)
    local modelName, stageKey = propForSpawn(field, spawn)
    local hash = loadModel(modelName)
    if not hash then return end
    local obj = CreateObject(hash, spawn.coords.x, spawn.coords.y, spawn.coords.z, false, false, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    PlaceObjectOnGroundProperly(obj)
    setEntityScale(obj, propScale(field, stageKey))
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    spawn.entity = obj
    spawn.coords = GetEntityCoords(obj)
    SetModelAsNoLongerNeeded(hash)
    attachZone(field, spawn)
end

local function applyPlantState(fieldId, spawnIndex, plant)
    local state = fieldSpawns[fieldId]
    if not state then return end
    local spawn = state.spawns[spawnIndex]
    if not spawn then return end
    spawn.plant = plant
    spawnProp(state.field, spawn)
end

local function initField(field)
    if not field or not field.id or not field.center then return end
    if fieldsReady[field.id] then return end
    ensureGroundLoaded(field.center.x, field.center.y, field.center.z)

    local spawns = {}
    local count = math.max(1, tonumber(field.spawnCount) or 8)
    for i = 1, count do
        spawns[i] = {
            index = i,
            coords = spawnCoordForIndex(field, i),
            plant = nil,
            entity = nil,
        }
    end
    fieldSpawns[field.id] = { field = field, spawns = spawns }
    fieldsReady[field.id] = true

    QBCore.Functions.TriggerCallback('fivempro_drugs:server:syncWeedField', function(rows)
        if type(rows) == 'table' then
            for idx, plant in pairs(rows) do
                local spawn = spawns[tonumber(idx)]
                if spawn then spawn.plant = plant end
            end
        end
        for _, spawn in ipairs(spawns) do
            spawnProp(field, spawn)
        end
    end, field.id)
end

RegisterNetEvent('fivempro_drugs:client:weedPlantUpdate', function(fieldId, spawnIndex, plant)
    applyPlantState(fieldId, spawnIndex, plant)
end)

RegisterNetEvent('fivempro_drugs:client:weedPlantClear', function(fieldId, spawnIndex)
    applyPlantState(fieldId, spawnIndex, nil)
end)

CreateThread(function()
    Wait(2000)
    while true do
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        for _, field in ipairs(Config.WeedGrowFields or {}) do
            local loadDist = tonumber(field.loadDistance) or 120.0
            if #(pcoords - field.center) <= loadDist then
                initField(field)
            end
        end
        Wait(1500)
    end
end)

CreateThread(function()
    while true do
        Wait(15000)
        for fieldId, state in pairs(fieldSpawns) do
            QBCore.Functions.TriggerCallback('fivempro_drugs:server:syncWeedField', function(rows)
                if type(rows) ~= 'table' then return end
                for idx, plant in pairs(rows) do
                    local spawn = state.spawns[tonumber(idx)]
                    if spawn then
                        local oldStage = spawn.plant and spawn.plant.stage or 0
                        local newStage = plant and plant.stage or 0
                        spawn.plant = plant
                        if oldStage ~= newStage then
                            spawnProp(state.field, spawn)
                        end
                    end
                end
                for idx, spawn in ipairs(state.spawns or {}) do
                    if not rows[tostring(idx)] and not rows[idx] and spawn.plant then
                        spawn.plant = nil
                        spawnProp(state.field, spawn)
                    end
                end
            end, fieldId)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for fieldId, state in pairs(fieldSpawns) do
        for _, spawn in ipairs(state.spawns or {}) do
            deleteSpawnEntity(fieldId, spawn)
        end
    end
end)
