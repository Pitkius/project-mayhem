local QBCore = exports['qb-core']:GetCoreObject()

local activePlants = {}
local synced = false
local busy = false

local function growCfg()
    return Config.WeedGrow or {}
end

local function zoneName(plantId)
    return ('fivempro_weed_%s'):format(tostring(plantId))
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

local function setEntityScale(entity, scale)
    scale = tonumber(scale)
    if not entity or not DoesEntityExist(entity) or not scale or math.abs(scale - 1.0) < 0.01 then return end
    local forward, right, up, position = GetEntityMatrix(entity)
    SetEntityMatrix(entity, forward * scale, right * scale, up * scale, position)
end

local function resolveGroundZ(x, y, refZ)
    local found, gz = GetGroundZFor_3dCoord(x, y, refZ + 80.0, false)
    return found and gz or refZ
end

local function removeZone(plantId)
    pcall(function()
        exports['qb-target']:RemoveZone(zoneName(plantId))
    end)
end

local function deleteSpawnEntity(plantId, entry)
    if entry.entity and DoesEntityExist(entry.entity) then
        DeleteEntity(entry.entity)
    end
    entry.entity = nil
    removeZone(plantId)
end

local function propForPlant(cfg, plant)
    local props = cfg.props or {}
    if not plant or not plant.plantedAt then
        return props.empty or 'bkr_prop_weed_bucket_01a', 'empty'
    end
    local stage = tonumber(plant.stage) or 1
    if stage >= 3 then return props.stage3 or 'bkr_prop_weed_lrg_01a', 'stage3' end
    if stage >= 2 then return props.stage2 or 'bkr_prop_weed_med_01a', 'stage2' end
    return props.stage1 or 'prop_weed_02', 'stage1'
end

local function propScale(cfg, stageKey)
    local scales = cfg.propScale
    if type(scales) == 'table' and scales[stageKey] then
        return scales[stageKey]
    end
    return cfg.propScale
end

local function runSchedule(profile, onDone)
    exports['fivempro_drugs']:RunScheduleMinigame(profile, onDone)
end

local function attachZone(plantId, entry)
    local cfg = growCfg()
    local plant = entry.plant
    if not entry.coords then return end
    removeZone(plantId)

    local options = {}
    local stage = plant and (tonumber(plant.stage) or 0) or 0

    if not plant or not plant.plantedAt then
        options[#options + 1] = {
            icon = 'fas fa-seedling',
            label = cfg.plantLabel or 'Sodinti kanapes',
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
                        TriggerServerEvent('fivempro_drugs:server:plantWeed', plantId, c.x, c.y, c.z)
                        busy = false
                    end)
                end, plantId)
            end,
            canInteract = function()
                return not busy and (not entry.plant or not entry.plant.plantedAt)
            end,
        }
    elseif stage < 3 then
        options[#options + 1] = {
            icon = 'fas fa-tint',
            label = cfg.waterLabel or 'Laistyti augalą',
            action = function()
                if busy then return end
                busy = true
                DrugProgress.run('fivempro_drugs_water', cfg.waterLabel or 'Laistymas…', 3200, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableMouse = false,
                    disableCombat = true,
                }, {
                    animDict = 'amb@world_human_gardener_plant@male@base',
                    anim = 'base',
                    flags = 49,
                }, function()
                    TriggerServerEvent('fivempro_drugs:server:waterWeed', plantId)
                    busy = false
                end, function()
                    busy = false
                    QBCore.Functions.Notify('Atšaukta.', 'error')
                end)
            end,
            canInteract = function()
                return not busy and entry.plant and entry.plant.plantedAt and (tonumber(entry.plant.stage) or 1) < 3
            end,
        }
    else
        options[#options + 1] = {
            icon = 'fas fa-leaf',
            label = cfg.harvestLabel or 'Skinti lapus',
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
                        TriggerServerEvent('fivempro_drugs:server:harvestWeed', plantId, c.x, c.y, c.z)
                        busy = false
                    end)
                end, plantId)
            end,
            canInteract = function()
                return not busy and entry.plant and entry.plant.plantedAt and (tonumber(entry.plant.stage) or 0) >= 3
            end,
        }
    end

    if #options == 0 then return end

    exports['qb-target']:AddCircleZone(zoneName(plantId), entry.coords, tonumber(cfg.zoneRadius) or 0.95, {
        name = zoneName(plantId),
        debugPoly = false,
        useZ = true,
    }, {
        options = options,
        distance = (cfg.pickDistance or 2.2) + 0.35,
    })
end

local function spawnProp(plantId, entry)
    deleteSpawnEntity(plantId, entry)
    local cfg = growCfg()
    local modelName, stageKey = propForPlant(cfg, entry.plant)
    local hash = loadModel(modelName)
    if not hash then return end
    local c = entry.coords
    local obj = CreateObject(hash, c.x, c.y, c.z, false, false, false)
    if not obj or obj == 0 then
        SetModelAsNoLongerNeeded(hash)
        return
    end
    PlaceObjectOnGroundProperly(obj)
    setEntityScale(obj, propScale(cfg, stageKey))
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)
    entry.entity = obj
    entry.coords = GetEntityCoords(obj)
    SetModelAsNoLongerNeeded(hash)
    attachZone(plantId, entry)
end

local function upsertPlant(plantId, plant)
    if not plant or not plant.x or not plant.y or not plant.z then return end
    local coords = vector3(plant.x, plant.y, plant.z)
    local entry = activePlants[plantId]
    if not entry then
        entry = { coords = coords, plant = plant, entity = nil }
        activePlants[plantId] = entry
    else
        entry.coords = coords
        entry.plant = plant
    end
    spawnProp(plantId, entry)
end

local function clearPlant(plantId)
    local entry = activePlants[plantId]
    if entry then
        deleteSpawnEntity(plantId, entry)
        activePlants[plantId] = nil
    end
end

local function syncAllPlants()
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:syncWeedPlants', function(rows)
        if type(rows) ~= 'table' then return end
        synced = true
        local seen = {}
        for plantId, plant in pairs(rows) do
            seen[plantId] = true
            upsertPlant(plantId, plant)
        end
        for plantId, entry in pairs(activePlants) do
            if not seen[plantId] then
                clearPlant(plantId)
            end
        end
    end)
end

RegisterNetEvent('fivempro_drugs:client:weedPlantUpdate', function(plantId, plant)
    upsertPlant(tostring(plantId), plant)
end)

RegisterNetEvent('fivempro_drugs:client:weedPlantClear', function(plantId)
    clearPlant(tostring(plantId))
end)

RegisterNetEvent('fivempro_drugs:client:placeGrowPot', function()
    if busy then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Negalima statyti vazono transporte.', 'error')
    end
    busy = true
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local x = coords.x + forward.x * 0.85
    local y = coords.y + forward.y * 0.85
    local z = resolveGroundZ(x, y, coords.z)
    RequestAnimDict('amb@world_human_gardener_plant@male@base')
    local deadline = GetGameTimer() + 2000
    while not HasAnimDictLoaded('amb@world_human_gardener_plant@male@base') and GetGameTimer() < deadline do
        Wait(10)
    end
    if HasAnimDictLoaded('amb@world_human_gardener_plant@male@base') then
        TaskPlayAnim(ped, 'amb@world_human_gardener_plant@male@base', 'base', 4.0, 3.0, 1200, 49, 0.0, false, false, false)
    end
    Wait(900)
    TriggerServerEvent('fivempro_drugs:server:placeWeedPot', x, y, z)
    busy = false
end)

CreateThread(function()
    Wait(2500)
    while true do
        local cfg = growCfg()
        local loadDist = tonumber(cfg.loadDistance) or 140.0
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        local nearAny = false
        for plantId, entry in pairs(activePlants) do
            if entry.coords and #(pcoords - entry.coords) <= loadDist then
                nearAny = true
                break
            end
        end
        if not synced or nearAny or #(pcoords - vector3(2221.85, 5614.80, 54.90)) < 200.0 then
            syncAllPlants()
        end
        Wait(nearAny and 8000 or 15000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for plantId, entry in pairs(activePlants) do
        deleteSpawnEntity(plantId, entry)
    end
end)
