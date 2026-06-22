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

local function formatTime(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local m = math.floor(sec / 60)
    local s = sec % 60
    if m > 0 then return ('%dm %02ds'):format(m, s) end
    return ('%ds'):format(s)
end

local function removeZone(plantId)
    pcall(function()
        exports['qb-target']:RemoveZone(zoneName(plantId))
    end)
end

local function deletePlantEntities(entry)
    if entry.plantEntity and DoesEntityExist(entry.plantEntity) then
        DeleteEntity(entry.plantEntity)
    end
    if entry.potEntity and DoesEntityExist(entry.potEntity) then
        DeleteEntity(entry.potEntity)
    end
    entry.plantEntity = nil
    entry.potEntity = nil
end

local function deleteSpawnEntity(plantId, entry)
    deletePlantEntities(entry)
    removeZone(plantId)
end

local function plantStageKey(plant)
    if not plant or not plant.plantedAt then return nil end
    local stage = tonumber(plant.stage) or 1
    if stage >= 3 then return 'stage3' end
    if stage >= 2 then return 'stage2' end
    return 'stage1'
end

local function plantModelForStage(cfg, stageKey)
    local props = cfg.plantProps or {}
    return props[stageKey] or props.stage1 or 'prop_weed_02'
end

local function plantScaleForStage(cfg, stageKey)
    local scales = cfg.plantScale or {}
    if type(scales) == 'table' and scales[stageKey] then
        return scales[stageKey]
    end
    return 0.5
end

local function runSchedule(profile, onDone)
    exports['fivempro_drugs']:RunScheduleMinigame(profile, onDone)
end

local function drawText3D(coords, text, scale)
    if GetResourceState('fivempro_fonts') == 'started' then
        exports['fivempro_fonts']:DrawText3D(coords.x, coords.y, coords.z, text, {
            scale = scale or 0.32,
            center = true,
            background = true,
        })
        return
    end
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(180, 255, 180, 230)
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawPlantHud(entry)
    local plant = entry.plant
    if not plant or not plant.plantedAt or not entry.coords then return end
    local ped = PlayerPedId()
    if #(GetEntityCoords(ped) - entry.coords) > 6.5 then return end

    local stage = tonumber(plant.stage) or 1
    local remain = tonumber(plant.growRemaining) or 0
    local pct = 100
    if stage < 3 and remain > 0 then
        local cfg = growCfg()
        local total = tonumber(cfg.stage3Sec) or 480
        pct = math.floor(math.max(0, math.min(100, ((total - remain) / total) * 100)))
    end

    local lines = { ('~g~Kanapės · %d%%'):format(pct) }
    if stage < 3 then
        lines[#lines + 1] = ('Brandu: %s'):format(formatTime(remain))
        if plant.watersLeft and plant.watersLeft > 0 then
            if plant.canWater then
                lines[#lines + 1] = ('Laistyti galima · liko %dx'):format(plant.watersLeft)
            else
                lines[#lines + 1] = ('Laistyti po %s'):format(formatTime(plant.waterCooldownLeft or 0))
            end
        else
            lines[#lines + 1] = 'Laistymas baigtas'
        end
    else
        lines[#lines + 1] = '~y~Paruošta derliui'
    end

    local z = entry.coords.z + 1.05
    for i, line in ipairs(lines) do
        drawText3D(vector3(entry.coords.x, entry.coords.y, z + (i - 1) * 0.11), line:gsub('~%w~', ''), 0.32)
    end
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
        local label = cfg.waterLabel or 'Laistyti'
        if plant and not plant.canWater and (plant.waterCooldownLeft or 0) > 0 then
            label = ('Laistyti (%s)'):format(formatTime(plant.waterCooldownLeft))
        end
        options[#options + 1] = {
            icon = 'fas fa-fill-drip',
            label = label,
            action = function()
                if busy then return end
                if plant and not plant.canWater then
                    return QBCore.Functions.Notify(('Palauk %s prieš laistymą.'):format(formatTime(plant.waterCooldownLeft or 0)), 'error')
                end
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
                return not busy and entry.plant and entry.plant.plantedAt
                    and (tonumber(entry.plant.stage) or 1) < 3
                    and (entry.plant.watersLeft or 0) > 0
            end,
        }
    else
        options[#options + 1] = {
            icon = 'fas fa-scissors',
            label = cfg.harvestLabel or 'Skinti žirklėmis',
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

local function spawnPotAndPlant(plantId, entry)
    deletePlantEntities(entry)
    local cfg = growCfg()
    local c = entry.coords
    local potModel = cfg.potModel or 'bkr_prop_weed_bucket_01a'
    local potHash = loadModel(potModel)
    if not potHash then return end

    local pot = CreateObject(potHash, c.x, c.y, c.z, false, false, false)
    if not pot or pot == 0 then
        SetModelAsNoLongerNeeded(potHash)
        return
    end
    PlaceObjectOnGroundProperly(pot)
    setEntityScale(pot, cfg.potScale or 0.92)
    FreezeEntityPosition(pot, true)
    SetEntityAsMissionEntity(pot, true, true)
    entry.potEntity = pot
    entry.coords = GetEntityCoords(pot)

    local stageKey = plantStageKey(entry.plant)
    if stageKey then
        local plantHash = loadModel(plantModelForStage(cfg, stageKey))
        if plantHash then
            local offsetZ = tonumber(cfg.plantOffsetZ) or 0.36
            local pc = entry.coords
            local plantObj = CreateObject(plantHash, pc.x, pc.y, pc.z + offsetZ, false, false, false)
            if plantObj and plantObj ~= 0 then
                setEntityScale(plantObj, plantScaleForStage(cfg, stageKey))
                FreezeEntityPosition(plantObj, true)
                SetEntityAsMissionEntity(plantObj, true, true)
                entry.plantEntity = plantObj
            end
            SetModelAsNoLongerNeeded(plantHash)
        end
    end

    SetModelAsNoLongerNeeded(potHash)
    attachZone(plantId, entry)
end

local function upsertPlant(plantId, plant)
    if not plant or not plant.x or not plant.y or not plant.z then return end
    local coords = vector3(plant.x, plant.y, plant.z)
    local entry = activePlants[plantId]
    local prevStageKey
    if entry and entry.plant then
        prevStageKey = plantStageKey(entry.plant)
    end
    if not entry then
        entry = { coords = coords, plant = plant, potEntity = nil, plantEntity = nil }
        activePlants[plantId] = entry
    else
        entry.coords = coords
        entry.plant = plant
    end
    local nextStageKey = plantStageKey(plant)
    if entry.potEntity and DoesEntityExist(entry.potEntity) and prevStageKey == nextStageKey then
        attachZone(plantId, entry)
        return
    end
    spawnPotAndPlant(plantId, entry)
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
        for plantId in pairs(activePlants) do
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
        for _, entry in pairs(activePlants) do
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

CreateThread(function()
    while true do
        local sleep = 900
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        for _, entry in pairs(activePlants) do
            if entry.plant and entry.plant.plantedAt and entry.coords and #(pcoords - entry.coords) < 6.5 then
                sleep = 0
                drawPlantHud(entry)
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for plantId, entry in pairs(activePlants) do
        deleteSpawnEntity(plantId, entry)
    end
end)
