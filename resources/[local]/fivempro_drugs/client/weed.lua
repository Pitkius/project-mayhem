local QBCore = exports['qb-core']:GetCoreObject()

local plantProps = {}
local plantData = {}
local placing = false
local busy = false
local weedShopPed = 0

local function notify(msg, typ)
    QBCore.Functions.Notify(msg, typ or 'primary')
end

local function growCfg()
    return Config.WeedGrow or {}
end

local function shopCfg()
    return Config.WeedGrowShop or {}
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 5000 do
        Wait(10)
        t = t + 10
    end
    return HasModelLoaded(hash)
end

local function propForGrowth(growth)
    local chosen = (growCfg().props or {})[1]
    local g = tonumber(growth) or 0
    for _, row in ipairs(growCfg().props or {}) do
        if g >= (tonumber(row.min) or 0) then
            chosen = row
        end
    end
    return chosen and chosen.model or 'prop_weed_01'
end

local function deletePlantProp(id)
    local ent = plantProps[id]
    if ent and DoesEntityExist(ent) then
        exports['qb-target']:RemoveTargetEntity(ent)
        DeleteEntity(ent)
    end
    plantProps[id] = nil
end

local function openWeedGrowShop()
    QBCore.Functions.TriggerCallback('fivempro_drugs:server:openWeedGrowShop', function(res)
        if not res or not res.ok then
            notify((res and res.reason) or 'Nepavyko atidaryti parduotuvės.', 'error')
        end
    end)
end

local function refreshPlantTargets()
    for id, obj in pairs(plantProps) do
        if obj and DoesEntityExist(obj) then
            local data = plantData[id]
            exports['qb-target']:RemoveTargetEntity(obj)
            exports['qb-target']:AddTargetEntity(obj, {
                options = {
                    {
                        icon = 'fas fa-seedling',
                        label = 'Patręšti augalą',
                        canInteract = function()
                            return data and (data.growth or 0) < (growCfg().harvestAt or 100)
                        end,
                        action = function()
                            if busy then return end
                            busy = true
                            QBCore.Functions.Progressbar('fivempro_weed_feed', 'Tręši…', growCfg().feedDurationMs or 3800, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableCombat = true,
                            }, {
                                animDict = 'amb@world_human_gardener_plant@male@base',
                                anim = 'base',
                                flags = 49,
                            }, {}, {}, function()
                                busy = false
                                TriggerServerEvent('fivempro_drugs:server:feedWeedPlant', id)
                            end, function()
                                busy = false
                                notify('Atšaukta.', 'error')
                            end)
                        end,
                    },
                    {
                        icon = 'fas fa-cannabis',
                        label = 'Skinti žolę',
                        canInteract = function()
                            return data and (data.growth or 0) >= (growCfg().harvestAt or 100)
                        end,
                        action = function()
                            if busy then return end
                            busy = true
                            QBCore.Functions.Progressbar('fivempro_weed_harvest', 'Renki žolę…', growCfg().harvestDurationMs or 5600, false, true, {
                                disableMovement = true,
                                disableCarMovement = true,
                                disableCombat = true,
                            }, {
                                animDict = 'amb@world_human_gardener_plant@male@base',
                                anim = 'base',
                                flags = 49,
                            }, {}, {}, function()
                                busy = false
                                TriggerServerEvent('fivempro_drugs:server:harvestWeedPlant', id)
                            end, function()
                                busy = false
                                notify('Atšaukta.', 'error')
                            end)
                        end,
                    },
                },
                distance = growCfg().interactDistance or 2.4,
            })
        end
    end
end

local function spawnPlant(plant)
    if not plant or not plant.id then return end
    deletePlantProp(plant.id)
    plantData[plant.id] = plant

    local model = propForGrowth(plant.growth)
    if not loadModel(model) then return end

    local obj = CreateObject(joaat(model), plant.x, plant.y, plant.z, false, false, false)
    SetEntityHeading(obj, plant.heading or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityAsMissionEntity(obj, true, true)

    plantProps[plant.id] = obj
    SetModelAsNoLongerNeeded(joaat(model))
end

RegisterNetEvent('fivempro_drugs:client:syncWeedPlants', function(list)
    local seen = {}
    for _, plant in ipairs(list or {}) do
        seen[plant.id] = true
        local prev = plantData[plant.id]
        local modelChanged = not prev or propForGrowth(prev.growth) ~= propForGrowth(plant.growth)
        if modelChanged or not plantProps[plant.id] or not DoesEntityExist(plantProps[plant.id]) then
            spawnPlant(plant)
        else
            plantData[plant.id] = plant
        end
    end
    for id in pairs(plantProps) do
        if not seen[id] then
            deletePlantProp(id)
            plantData[id] = nil
        end
    end
    Wait(150)
    refreshPlantTargets()
end)

RegisterNetEvent('fivempro_drugs:client:startPlaceWeed', function(seedItem)
    if placing or busy then return end
    seedItem = tostring(seedItem or 'weed_seed')

    local model = propForGrowth(0)
    if not loadModel(model) then
        return notify('Modelis nerastas.', 'error')
    end

    placing = true
    local ped = PlayerPedId()
    local preview = CreateObject(joaat(model), 0.0, 0.0, 0.0, false, false, false)
    SetEntityAlpha(preview, 180, false)
    SetEntityCollision(preview, false, false)
    FreezeEntityPosition(preview, true)

    notify('[E] Sodinti · [SCROLL] Sukti · [BACKSPACE] Atšaukti', 'primary')

    CreateThread(function()
        local heading = GetEntityHeading(ped)
        local dist = growCfg().placeDistance or 1.35
        while placing do
            Wait(0)
            local c = GetEntityCoords(ped)
            local fwd = GetEntityForwardVector(ped)
            local pos = c + fwd * dist
            SetEntityCoords(preview, pos.x, pos.y, pos.z, false, false, false, false)
            PlaceObjectOnGroundProperly(preview)
            if IsControlPressed(0, 241) then heading = heading + 1.2 end
            if IsControlPressed(0, 242) then heading = heading - 1.2 end
            SetEntityHeading(preview, heading)

            if IsControlJustPressed(0, 177) then
                placing = false
            elseif IsControlJustPressed(0, 38) then
                local fc = GetEntityCoords(preview)
                local fh = GetEntityHeading(preview)
                placing = false
                busy = true
                QBCore.Functions.Progressbar('fivempro_weed_plant', 'Sodini sėklą…', growCfg().plantDurationMs or 4200, false, true, {
                    disableMovement = true,
                    disableCarMovement = true,
                    disableCombat = true,
                }, {
                    animDict = 'amb@world_human_gardener_plant@male@base',
                    anim = 'base',
                    flags = 49,
                }, {}, {}, function()
                    busy = false
                    TriggerServerEvent('fivempro_drugs:server:placeWeedPlant', fc.x, fc.y, fc.z, fh, seedItem)
                end, function()
                    busy = false
                    notify('Atšaukta.', 'error')
                end)
            end
        end
        if DoesEntityExist(preview) then DeleteEntity(preview) end
        SetModelAsNoLongerNeeded(joaat(model))
    end)
end)

local function spawnWeedShopNpc()
    local cfg = shopCfg()
    if not cfg or cfg.enabled == false or not cfg.coords then return end

    local model = joaat(cfg.model or 's_m_y_dealer_01')
    RequestModel(model)
    local t = GetGameTimer() + 8000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return end

    local c = cfg.coords
    weedShopPed = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetEntityInvincible(weedShopPed, true)
    FreezeEntityPosition(weedShopPed, true)
    SetBlockingOfNonTemporaryEvents(weedShopPed, true)
    SetEntityCoordsNoOffset(weedShopPed, c.x, c.y, c.z, false, false, false)
    if cfg.scenario then
        TaskStartScenarioInPlace(weedShopPed, cfg.scenario, 0, true)
    end

    exports['qb-target']:AddTargetEntity(weedShopPed, {
        options = {
            {
                icon = cfg.targetIcon or 'fas fa-cannabis',
                label = cfg.label or 'Žolės reikmenys',
                action = openWeedGrowShop,
            },
        },
        distance = (cfg.maxDistance or 3.5) + 0.5,
    })

    SetModelAsNoLongerNeeded(model)
end

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(250)
    end
    Wait(600)
    spawnWeedShopNpc()
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(plantProps) do
        deletePlantProp(id)
    end
    if weedShopPed ~= 0 and DoesEntityExist(weedShopPed) then
        DeleteEntity(weedShopPed)
    end
end)
