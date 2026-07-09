local QBCore = exports['qb-core']:GetCoreObject()

local activePlants = {}
local synced = false
local busy = false

local function growCfg()
    return Config.WeedGrow or {}
end

local function zoneName(plantId)
    return ('mrp_weed_%s'):format(tostring(plantId))
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

local function cloudNow()
    return GetCloudTimeAsInt()
end

local function formatTime(sec)
    sec = math.max(0, math.floor(tonumber(sec) or 0))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return ('%d:%02d'):format(m, s)
end

local function computeClientGrowState(plant)
    local cfg = growCfg()
    if not plant or not plant.plantedAt then
        return 0, 0
    end
    local bonus = (tonumber(plant.watered) or 0) * (tonumber(cfg.waterBonusSec) or 55)
    local plantedAt = tonumber(plant.plantedAt) or 0
    local elapsed = cloudNow() - plantedAt + bonus
    local stage3 = tonumber(cfg.stage3Sec) or 480
    local stage2 = tonumber(cfg.stage2Sec) or 180
    local remain = math.max(0, stage3 - elapsed)
    local stage = 1
    if elapsed >= stage3 then
        stage = 3
    elseif elapsed >= stage2 then
        stage = 2
    end
    return stage, remain
end

local function computeWaterCooldownLeft(plant)
    local cfg = growCfg()
    if not plant or not plant.plantedAt then return 0 end
    local cd = tonumber(cfg.waterCooldownSec) or 120
    local last = tonumber(plant.lastWaterAt) or 0
    if last <= 0 then return 0 end
    return math.max(0, (last + cd) - cloudNow())
end

local function visualStageForPlant(plant)
    local clientStage = select(1, computeClientGrowState(plant))
    local serverStage = tonumber(plant and plant.stage) or 0
    return math.max(clientStage, serverStage)
end

local function removeZone(plantId)
    pcall(function()
        exports['qb-target']:RemoveZone(zoneName(plantId))
    end)
    local entry = activePlants[plantId]
    if entry then
        entry._zoneAttached = false
        entry._targetMode = nil
        entry._zoneCoords = nil
    end
end

local function targetModeForPlant(plant)
    if not plant or not plant.soiled then return 'soil' end
    if not plant.plantedAt then return 'seed' end
    if visualStageForPlant(plant) >= 3 then return 'harvest' end
    return 'water'
end

local function coordsNear(a, b)
    if not a or not b then return false end
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z)) < 0.2
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
    local stage = visualStageForPlant(plant)
    if stage >= 3 then return 'stage3' end
    if stage >= 2 then return 'stage2' end
    return 'stage1'
end

local function plantAttachZ(cfg, stageKey)
    local tbl = cfg.plantAttachZ
    if type(tbl) == 'table' and stageKey and tbl[stageKey] then
        return tonumber(tbl[stageKey]) or 0.24
    end
    return tonumber(cfg.plantOffsetZ) or 0.24
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
    exports['mrp_drugs']:RunScheduleMinigame(profile, function(success, result)
        if onDone then onDone(success, result or {}) end
    end)
end

local function drawMultilinePlantHud(coords, lines)
    if not lines or #lines == 0 then return end
    local text = table.concat(lines, '~n~')
    local scale = 0.34
    local lineCount = #lines
    local maxLen = 0
    for _, line in ipairs(lines) do
        maxLen = math.max(maxLen, #(tostring(line):gsub('~%w~', '')))
    end

    -- Tekstas ir fonas centre — anksčiau tekstas būdavo per žemai dėl neteisingo Y offset.
    local lineStep = 0.020
    local textY = -((lineCount - 1) * lineStep * 0.5) - 0.008
    local factor = maxLen / 300
    local boxW = 0.024 + factor
    local boxH = lineStep * lineCount + 0.016
    local boxY = textY + (lineCount * lineStep) * 0.5 + 0.007

    if GetResourceState('mrp_fonts') == 'started' then
        exports['mrp_fonts']:ApplyTextFont()
    end
    SetTextScale(scale, scale)
    if GetResourceState('mrp_fonts') ~= 'started' then
        SetTextFont(4)
    end
    SetTextProportional(1)
    SetTextColour(196, 181, 253, 240)
    SetTextCentre(true)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    DrawRect(0.0, boxY, boxW, boxH, 12, 8, 22, 175)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, textY)
    ClearDrawOrigin()
end

local function drawPlantHud(entry)
    local plant = entry.plant
    if not plant or not entry.coords then return end
    local ped = PlayerPedId()
    if #(GetEntityCoords(ped) - entry.coords) > 6.5 then return end

    local cfg = growCfg()
    local statusLabel = plant.statusLabel or 'Tuščia'
    local quality = tonumber(plant.quality) or tonumber(cfg.qualityStart) or 72
    local moisture = tonumber(plant.moisture) or 0
    local lines = { ('~p~%s~s~'):format(statusLabel) }

    if plant.plantedAt then
        local stage, remain = computeClientGrowState(plant)
        local total = tonumber(cfg.stage3Sec) or 480
        local pct = 100
        if stage < 3 and remain > 0 then
            pct = math.floor(math.max(0, math.min(100, ((total - remain) / total) * 100)))
        end
        lines[#lines + 1] = ('Augimas %d%% · liko %s'):format(pct, stage < 3 and formatTime(remain) or '0:00')
        lines[#lines + 1] = ('Drėgmė %d%% · Kokybė %d%%'):format(moisture, quality)

        if stage < 3 then
            local waterCd = computeWaterCooldownLeft(plant)
            local watersLeft = tonumber(plant.watersLeft) or 0
            if watersLeft > 0 then
                if waterCd <= 0 then
                    lines[#lines + 1] = ('Laistyti galima · liko %dx'):format(watersLeft)
                else
                    lines[#lines + 1] = ('Laistyti po %s'):format(formatTime(waterCd))
                end
            end
        else
            lines[#lines + 1] = '~g~Paruošta derliui~s~'
        end
    elseif plant.soiled then
        lines[#lines + 1] = 'Substratas paruoštas — sodink sėklas'
    else
        lines[#lines + 1] = 'Supilk substratą (trąšų maišas)'
    end

    local hudZ = entry.coords.z + 1.15
    if entry.potEntity and DoesEntityExist(entry.potEntity) then
        local potCoords = GetEntityCoords(entry.potEntity)
        hudZ = potCoords.z + 1.05
    end
    drawMultilinePlantHud(vector3(entry.coords.x, entry.coords.y, hudZ), lines)
end

local function attachZone(plantId, entry)
    local cfg = growCfg()
    local plant = entry.plant
    if not entry.coords then return end
    removeZone(plantId)

    local options = {}
    local stage = plant and visualStageForPlant(plant) or 0

    if not plant or not plant.soiled then
        options[#options + 1] = {
            icon = 'fas fa-mound',
            label = cfg.soilLabel or 'Supilti substratą',
            action = function()
                if busy then return end
                busy = true
                QBCore.Functions.TriggerCallback('mrp_drugs:server:canAddSoilWeed', function(ok, reason)
                    if not ok then
                        busy = false
                        return QBCore.Functions.Notify(reason or 'Negalima.', 'error')
                    end
                    local profile = Config.GetScheduleMinigame('weed_soil')
                    runSchedule(profile, function(success, result)
                        if not success then
                            busy = false
                            return QBCore.Functions.Notify('Substrato pylimas nepavyko.', 'error')
                        end
                        TriggerServerEvent('mrp_drugs:server:addSoilWeed', plantId, result.score or result.quality or 75)
                        busy = false
                    end)
                end, plantId)
            end,
            canInteract = function()
                return not busy and entry.plant and not entry.plant.soiled and not entry.plant.plantedAt
            end,
        }
    elseif not plant.plantedAt then
        options[#options + 1] = {
            icon = 'fas fa-seedling',
            label = cfg.plantLabel or 'Sodinti sėklas',
            action = function()
                if busy then return end
                busy = true
                QBCore.Functions.TriggerCallback('mrp_drugs:server:canPlantWeed', function(ok, reason)
                    if not ok then
                        busy = false
                        return QBCore.Functions.Notify(reason or 'Negalima sodinti.', 'error')
                    end
                    local profile = Config.GetScheduleMinigame('weed_seed')
                    runSchedule(profile, function(success, result)
                        if not success then
                            busy = false
                            return QBCore.Functions.Notify('Sodinimas nepavyko.', 'error')
                        end
                        local ped = PlayerPedId()
                        local c = GetEntityCoords(ped)
                        TriggerServerEvent('mrp_drugs:server:plantWeed', plantId, c.x, c.y, c.z, result.score or result.quality or 75)
                        busy = false
                    end)
                end, plantId)
            end,
            canInteract = function()
                return not busy and entry.plant and entry.plant.soiled and not entry.plant.plantedAt
            end,
        }
    elseif stage < 3 then
        options[#options + 1] = {
            icon = 'fas fa-fill-drip',
            label = cfg.waterLabel or 'Laistyti',
            action = function()
                if busy then return end
                local cd = computeWaterCooldownLeft(entry.plant)
                if cd > 0 then
                    return QBCore.Functions.Notify(('Palauk %s prieš laistymą.'):format(formatTime(cd)), 'error')
                end
                busy = true
                QBCore.Functions.TriggerCallback('mrp_drugs:server:canWaterWeed', function(ok, reason)
                    if not ok then
                        busy = false
                        return QBCore.Functions.Notify(reason or 'Negalima laistyti.', 'error')
                    end
                    local profile = Config.GetScheduleMinigame('weed_water')
                    runSchedule(profile, function(success, result)
                        if not success then
                            busy = false
                            return QBCore.Functions.Notify('Laistymas nepavyko.', 'error')
                        end
                        TriggerServerEvent('mrp_drugs:server:waterWeed', plantId, result.moisture or 55, result.score or result.quality)
                        busy = false
                    end)
                end, plantId)
            end,
            canInteract = function()
                if busy or not entry.plant or not entry.plant.plantedAt then return false end
                if visualStageForPlant(entry.plant) >= 3 then return false end
                if (tonumber(entry.plant.watersLeft) or 0) <= 0 then return false end
                local itemName = growCfg().waterCanItem or 'watering_can'
                return QBCore.Functions.HasItem(itemName, 1)
            end,
        }
    else
        options[#options + 1] = {
            icon = 'fas fa-scissors',
            label = cfg.harvestLabel or 'Skinti žirklėmis',
            action = function()
                if busy then return end
                busy = true
                QBCore.Functions.TriggerCallback('mrp_drugs:server:canHarvestWeed', function(ok, reason)
                    if not ok then
                        busy = false
                        return QBCore.Functions.Notify(reason or 'Dar nebrandu.', 'error')
                    end
                    local profile = Config.GetScheduleMinigame('weed_harvest')
                    runSchedule(profile, function(success, result)
                        if not success then
                            busy = false
                            return QBCore.Functions.Notify('Derlius nepavyko.', 'error')
                        end
                        local ped = PlayerPedId()
                        local c = GetEntityCoords(ped)
                        TriggerServerEvent('mrp_drugs:server:harvestWeed', plantId, c.x, c.y, c.z, result.score or result.quality or 75)
                        busy = false
                    end)
                end, plantId)
            end,
            canInteract = function()
                if busy or not entry.plant or not entry.plant.plantedAt then return false end
                if visualStageForPlant(entry.plant) < 3 then return false end
                local cfg = growCfg()
                local scissors = cfg.scissorsItem or 'trimming_scissors'
                local gloves = cfg.glovesItem or 'gloves'
                return QBCore.Functions.HasItem(scissors, 1) and QBCore.Functions.HasItem(gloves, 1)
            end,
        }
    end

    if #options == 0 then
        removeZone(plantId)
        return
    end

    local mode = targetModeForPlant(plant)
    local zname = zoneName(plantId)
    local targetDistance = (cfg.pickDistance or 2.2) + 0.35
    local targetPayload = { options = options, distance = targetDistance }

    if entry._zoneAttached and entry._targetMode == mode and coordsNear(entry._zoneCoords, entry.coords) then
        pcall(function()
            exports['qb-target']:UpdateZoneData(zname, targetPayload)
        end)
        return
    end

    removeZone(plantId)

    exports['qb-target']:AddCircleZone(zname, entry.coords, tonumber(cfg.zoneRadius) or 0.95, {
        name = zname,
        debugPoly = false,
        useZ = true,
    }, targetPayload)

    entry._zoneAttached = true
    entry._targetMode = mode
    entry._zoneCoords = vector3(entry.coords.x, entry.coords.y, entry.coords.z)
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
    if entry.plant and entry.plant.heading then
        SetEntityHeading(pot, tonumber(entry.plant.heading) or 0.0)
    end
    setEntityScale(pot, cfg.potScale or 0.92)
    FreezeEntityPosition(pot, true)
    SetEntityAsMissionEntity(pot, true, true)
    entry.potEntity = pot
    entry.coords = GetEntityCoords(pot)

    local stageKey = plantStageKey(entry.plant)
    if stageKey then
        local plantHash = loadModel(plantModelForStage(cfg, stageKey))
        if plantHash then
            local pc = GetEntityCoords(pot)
            local attachZ = plantAttachZ(cfg, stageKey)
            local plantObj = CreateObject(plantHash, pc.x, pc.y, pc.z, false, false, false)
            if plantObj and plantObj ~= 0 then
                setEntityScale(plantObj, plantScaleForStage(cfg, stageKey))
                AttachEntityToEntity(
                    plantObj, pot, 0,
                    0.0, 0.0, attachZ,
                    0.0, 0.0, 0.0,
                    false, false, false, false, 2, true
                )
                FreezeEntityPosition(plantObj, true)
                SetEntityAsMissionEntity(plantObj, true, true)
                entry.plantEntity = plantObj
            end
            SetModelAsNoLongerNeeded(plantHash)
        end
    end

    SetModelAsNoLongerNeeded(potHash)
    entry._visualStageKey = plantStageKey(entry.plant)
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
    QBCore.Functions.TriggerCallback('mrp_drugs:server:syncWeedPlants', function(rows)
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

RegisterNetEvent('mrp_drugs:client:weedPlantUpdate', function(plantId, plant)
    upsertPlant(tostring(plantId), plant)
end)

RegisterNetEvent('mrp_drugs:client:weedPlantClear', function(plantId)
    clearPlant(tostring(plantId))
end)

local function startPotPlacement()
    if busy then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        return QBCore.Functions.Notify('Negalima statyti vazono transporte.', 'error')
    end

    local cfg = growCfg()
    local potModel = cfg.potModel or 'bkr_prop_weed_bucket_01a'
    local potHash = loadModel(potModel)
    if not potHash then
        return QBCore.Functions.Notify('Vazono modelis nerastas.', 'error')
    end

    busy = true
    local preview = CreateObject(potHash, 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(preview, tonumber(cfg.placeGhostAlpha) or 160, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)
    setEntityScale(preview, cfg.potScale or 0.92)

    QBCore.Functions.Notify('[E] Padėti · [SCROLL] Sukti · [BACKSPACE] Atšaukti', 'primary', 5500)

    CreateThread(function()
        local heading = GetEntityHeading(ped)
        local placing = true
        while placing do
            Wait(0)
            DisableControlAction(0, 24, true)
            local c = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            local dist = tonumber(cfg.placeForwardM) or 1.15
            local x = c.x + fwd.x * dist
            local y = c.y + fwd.y * dist
            local z = resolveGroundZ(x, y, c.z)
            SetEntityCoords(preview, x, y, z, false, false, false, false)
            PlaceObjectOnGroundProperly(preview)
            if IsControlPressed(0, 241) then heading = heading + 1.2 end
            if IsControlPressed(0, 242) then heading = heading - 1.2 end
            SetEntityHeading(preview, heading)

            if IsControlJustPressed(0, 177) then
                placing = false
                QBCore.Functions.Notify('Atšaukta.', 'error')
            elseif IsControlJustPressed(0, 38) then
                local fc = GetEntityCoords(preview)
                local fh = GetEntityHeading(preview)
                placing = false
                RequestAnimDict('amb@world_human_gardener_plant@male@base')
                local deadline = GetGameTimer() + 2000
                while not HasAnimDictLoaded('amb@world_human_gardener_plant@male@base') and GetGameTimer() < deadline do
                    Wait(10)
                end
                if HasAnimDictLoaded('amb@world_human_gardener_plant@male@base') then
                    TaskPlayAnim(ped, 'amb@world_human_gardener_plant@male@base', 'base', 4.0, 3.0, 1200, 49, 0.0, false, false, false)
                end
                Wait(600)
                TriggerServerEvent('mrp_drugs:server:placeWeedPot', fc.x, fc.y, fc.z, fh)
            end
        end

        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(potHash)
        busy = false
    end)
end

RegisterNetEvent('mrp_drugs:client:placeGrowPot', function()
    startPotPlacement()
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
        Wait(1000)
        for plantId, entry in pairs(activePlants) do
            local plant = entry.plant
            if not plant or not plant.plantedAt then goto continue end
            local stageKey = plantStageKey(plant)
            local prevKey = entry._visualStageKey
            if stageKey and stageKey ~= prevKey then
                entry._visualStageKey = stageKey
                if entry.potEntity and DoesEntityExist(entry.potEntity) then
                    spawnPotAndPlant(plantId, entry)
                end
            end
            ::continue::
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 900
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        for _, entry in pairs(activePlants) do
            if entry.plant and entry.coords and #(pcoords - entry.coords) < 6.5 then
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
