local QBCore = exports['qb-core']:GetCoreObject()

local spawnedPeds = {}
local rentedVehicle = nil
local rentedNetId = nil

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    local t = 0
    while not HasModelLoaded(hash) and t < 100 do
        Wait(10)
        t = t + 1
    end
    return HasModelLoaded(hash)
end

local function deleteRentedBike()
    if rentedVehicle and DoesEntityExist(rentedVehicle) then
        SetEntityAsMissionEntity(rentedVehicle, true, true)
        DeleteVehicle(rentedVehicle)
    end
    rentedVehicle = nil
    rentedNetId = nil
end

local function openRentalMenu(locationId)
    local loc
    for _, l in ipairs(Config.Locations) do
        if l.id == locationId then loc = l break end
    end
    if not loc then return end

    local menu = {
        { header = loc.label or 'Dviračių nuoma', isMenuHeader = true },
    }
    for _, bike in ipairs(Config.Bikes) do
        menu[#menu + 1] = {
            header = bike.label .. ' — $' .. bike.price,
            txt = 'Nuomoti dviratį',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_bikerental:server:rent', locationId, bike.model)
                end,
            },
        }
    end
    if rentedVehicle and DoesEntityExist(rentedVehicle) then
        local pct = tonumber(Config.RefundPercent) or 0
        menu[#menu + 1] = {
            header = 'Grąžinti dviratį',
            txt = pct > 0 and ('Grąžinimas: ~%s%% nuomos'):format(pct) or 'Grąžinti nuomotą dviratį',
            params = {
                isAction = true,
                event = function()
                    TriggerServerEvent('mrp_bikerental:server:returnBike', locationId)
                end,
            },
        }
    end
    exports['qb-menu']:openMenu(menu)
end

RegisterNetEvent('mrp_bikerental:client:spawnBike', function(locationId, model, plate)
    local loc
    for _, l in ipairs(Config.Locations) do
        if l.id == locationId then loc = l break end
    end
    if not loc or not loc.spawn then return end

    deleteRentedBike()

    if not loadModel(model) then
        return QBCore.Functions.Notify('Dviratis neprieinamas.', 'error')
    end

    local sp = loc.spawn
    local veh = CreateVehicle(joaat(model), sp.x, sp.y, sp.z, sp.w, true, false)
    if not veh or veh == 0 then
        return QBCore.Functions.Notify('Nepavyko išduoti dviračio.', 'error')
    end

    SetVehicleNumberPlateText(veh, plate or 'BIKE01')
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleOnGroundProperly(veh)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    TriggerEvent('vehiclekeys:client:SetOwner', plate or GetVehicleNumberPlateText(veh))

    rentedVehicle = veh
    rentedNetId = NetworkGetNetworkIdFromEntity(veh)
    SetModelAsNoLongerNeeded(joaat(model))
    QBCore.Functions.Notify('Dviratis išnuomotas. Saugok jį arba grąžink nuomos punkte.', 'success')
end)

RegisterNetEvent('mrp_bikerental:client:returnedBike', function(refund)
    deleteRentedBike()
    if refund and refund > 0 then
        QBCore.Functions.Notify(('Dviratis grąžintas. Grąžinta $%s.'):format(refund), 'success')
    else
        QBCore.Functions.Notify('Dviratis grąžintas.', 'success')
    end
end)

CreateThread(function()
    local blipCfg = Config.Blip or {}
    for _, loc in ipairs(Config.Locations) do
        local c = loc.coords
        local blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, blipCfg.sprite or 348)
        SetBlipColour(blip, blipCfg.colour or 2)
        SetBlipScale(blip, blipCfg.scale or 0.75)
        SetBlipAsShortRange(blip, true)
        exports['mrp_fonts']:SetBlipName(blip, blipCfg.label or 'Dviračių nuoma')
    end
end)

CreateThread(function()
    Wait(1500)
    for _, loc in ipairs(Config.Locations) do
        local c = loc.coords
        exports['qb-target']:AddBoxZone('bikerental_' .. loc.id, vector3(c.x, c.y, c.z), 1.2, 1.2, {
            name = 'bikerental_' .. loc.id,
            heading = c.w,
            minZ = c.z - 1.0,
            maxZ = c.z + 1.5,
            debugPoly = false,
        }, {
            options = {
                {
                    icon = 'fas fa-bicycle',
                    label = 'Dviračių nuoma',
                    action = function()
                        openRentalMenu(loc.id)
                    end,
                },
            },
            distance = Config.TargetDistance or 2.5,
        })
    end
end)

CreateThread(function()
    local model = Config.PedModel or 'u_m_m_bikehire_01'
    while true do
        local ped = PlayerPedId()
        local pcoords = GetEntityCoords(ped)
        for _, loc in ipairs(Config.Locations) do
            local c = loc.coords
            local key = loc.id
            if #(pcoords - vector3(c.x, c.y, c.z)) < 80.0 then
                if not spawnedPeds[key] or not DoesEntityExist(spawnedPeds[key]) then
                    if loadModel(model) then
                        local npc = CreatePed(0, joaat(model), c.x, c.y, c.z - 1.0, c.w, false, false)
                        SetEntityInvincible(npc, true)
                        SetBlockingOfNonTemporaryEvents(npc, true)
                        FreezeEntityPosition(npc, true)
                        if Config.PedScenario then
                            TaskStartScenarioInPlace(npc, Config.PedScenario, 0, true)
                        end
                        spawnedPeds[key] = npc
                        SetModelAsNoLongerNeeded(joaat(model))
                    end
                end
            elseif spawnedPeds[key] and DoesEntityExist(spawnedPeds[key]) then
                DeleteEntity(spawnedPeds[key])
                spawnedPeds[key] = nil
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    deleteRentedBike()
    for _, p in pairs(spawnedPeds) do
        if p and DoesEntityExist(p) then DeleteEntity(p) end
    end
end)
