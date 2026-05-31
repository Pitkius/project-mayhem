local QBCore = exports['qb-core']:GetCoreObject()

local uiOpen = false
local deliveryState = nil
local missionBlip = nil

local function clearBlip()
    if missionBlip and DoesBlipExist(missionBlip) then
        RemoveBlip(missionBlip)
    end
    missionBlip = nil
end

local function setMissionBlip(coords, label, route)
    clearBlip()
    missionBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(missionBlip, route and 1 or 478)
    SetBlipColour(missionBlip, 47)
    SetBlipScale(missionBlip, 0.9)
    SetBlipRoute(missionBlip, route == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Kontraktas')
    EndTextCommandSetBlipName(missionBlip)
end

local function isAllowedTruck()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return false end
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return false end
    local model = GetEntityModel(veh)
    return Config.AllowedVehicleHashes[model] ~= nil
end

local function runLocalProgress(ms, label)
    local endAt = GetGameTimer() + ms
    QBCore.Functions.Notify(label or 'Vykdoma…', 'primary')
    while GetGameTimer() < endAt do
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        Wait(0)
    end
    return true
end

local function openUI(mode)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:getDashboard', function(data)
        if not data then return end
        uiOpen = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'open',
            mode = mode or 'full',
            data = data,
        })
    end)
end

local function closeUI()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('fivempro_trucking:client:openUI', function(mode)
    openUI(mode or 'full')
end)

RegisterNetEvent('fivempro_trucking:client:startDelivery', function(state)
    deliveryState = state
    if state and state.contract then
        setMissionBlip(state.contract.pickup, 'Paėmimas: ' .. (state.contract.pickupLabel or ''), true)
    end
end)

RegisterNetEvent('fivempro_trucking:client:clearDelivery', function()
    deliveryState = nil
    clearBlip()
end)

RegisterNUICallback('trucking:close', function(_, cb)
    closeUI()
    cb({ ok = true })
end)

RegisterNUICallback('trucking:refresh', function(_, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:getDashboard', function(data)
        cb({ ok = true, data = data })
    end)
end)

RegisterNUICallback('trucking:register', function(_, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:register', function(res)
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('trucking:createCompany', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:createCompany', function(res)
        cb(res or { ok = false })
    end, data and data.name)
end)

RegisterNUICallback('trucking:acceptContract', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:acceptContract', function(res)
        if res and res.ok then
            closeUI()
            QBCore.Functions.Notify('Kontraktas priimtas — važiuok į paėmimo vietą.', 'success')
        end
        cb(res or { ok = false })
    end, data and data.contractId)
end)

RegisterNUICallback('trucking:buyFleet', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:buyFleetVehicle', function(res)
        cb(res or { ok = false })
    end, data and data.model)
end)

RegisterNUICallback('trucking:cancelDelivery', function(_, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:cancelDelivery', function(res)
        cb(res or { ok = true })
    end)
end)

CreateThread(function()
    if GetResourceState('qb-target') ~= 'started' then return end
    for _, term in ipairs(Config.RegistrationTerminals or {}) do
        if term.blip then
            local b = AddBlipForCoord(term.coords.x, term.coords.y, term.coords.z)
            SetBlipSprite(b, term.blip.sprite or 477)
            SetBlipColour(b, term.blip.color or 47)
            SetBlipScale(b, term.blip.scale or 0.8)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(term.blip.label or 'TruckNet')
            EndTextCommandSetBlipName(b)
        end
        exports['qb-target']:AddBoxZone(
            'trucknet_' .. term.id,
            term.coords,
            2.2, 2.2,
            {
                name = 'trucknet_' .. term.id,
                heading = term.heading or 0.0,
                minZ = term.coords.z - 1.0,
                maxZ = term.coords.z + 2.0,
                debugPoly = false,
            },
            {
                options = {
                    {
                        icon = 'fas fa-truck',
                        label = 'Atidaryti TruckNet Logistics',
                        action = function()
                            openUI('full')
                        end,
                    },
                    {
                        icon = 'fas fa-id-card',
                        label = 'Registruotis vairuotoju',
                        action = function()
                            QBCore.Functions.TriggerCallback('fivempro_trucking:server:register', function(res)
                                if res and res.ok then
                                    QBCore.Functions.Notify('Registracija sėkminga! TruckNet Level 1.', 'success')
                                    openUI('full')
                                else
                                    QBCore.Functions.Notify((res and res.reason) or 'Klaida.', 'error')
                                end
                            end)
                        end,
                    },
                },
                distance = 2.5,
            }
        )
    end
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if deliveryState and deliveryState.contract then
            sleep = 0
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local c = deliveryState.contract
            if deliveryState.phase == 'pickup' then
                local hub = vector3(c.pickup.x, c.pickup.y, c.pickup.z)
                local dist = #(pos - hub)
                if dist < (Config.PickupRadius or 18.0) then
                    DrawMarker(1, hub.x, hub.y, hub.z - 1.0, 0, 0, 0, 0, 0, 0, 3.5, 3.5, 1.2, 167, 139, 250, 120, false, false, 2, false, nil, nil, false)
                    if dist < 6.0 and IsControlJustReleased(0, 38) then
                        if not isAllowedTruck() then
                            QBCore.Functions.Notify('Reikia tinkamo transporto (Mule, Benson, Phantom…).', 'error')
                        else
                            runLocalProgress(Config.LoadDurationMs or 6000, 'Kraunamas krovinys…')
                            QBCore.Functions.TriggerCallback('fivempro_trucking:server:loadCargo', function(res)
                                if res and res.ok then
                                    deliveryState.phase = 'delivery'
                                    setMissionBlip(c.delivery, 'Pristatymas: ' .. (c.deliveryLabel or ''), true)
                                    QBCore.Functions.Notify('Krovinys pakrautas — važiuok į pristatymo vietą.', 'primary')
                                end
                            end)
                        end
                    end
                end
            elseif deliveryState.phase == 'delivery' then
                local hub = vector3(c.delivery.x, c.delivery.y, c.delivery.z)
                local dist = #(pos - hub)
                if dist < (Config.DeliveryRadius or 22.0) then
                    DrawMarker(1, hub.x, hub.y, hub.z - 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 1.4, 124, 58, 237, 130, false, false, 2, false, nil, nil, false)
                    if dist < 7.0 and IsControlJustReleased(0, 38) then
                        runLocalProgress(Config.UnloadDurationMs or 7000, 'Iškraunamas krovinys…')
                        local cond = deliveryState.condition or 100
                        QBCore.Functions.TriggerCallback('fivempro_trucking:server:completeDelivery', function(res)
                            if res and res.ok then
                                clearBlip()
                                deliveryState = nil
                                QBCore.Functions.Notify(
                                    ('Pristatyta! $%s (XP +%s)'):format(res.pay or 0, res.xpGain or 0),
                                    'success'
                                )
                            else
                                QBCore.Functions.Notify((res and res.reason) or 'Pristatymas nepavyko.', 'error')
                            end
                        end, cond)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(2500)
        if not deliveryState then goto continue end
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then goto continue end
        local veh = GetVehiclePedIsIn(ped, false)
        local cond = deliveryState.condition or 100
        local body = GetVehicleBodyHealth(veh) or 1000.0
        if body < 850.0 then cond = cond - 2 end
        if IsEntityUpsidedown(veh) then cond = cond - 8 end
        local speed = GetEntitySpeed(veh) * 3.6
        if speed > 110.0 then cond = cond - 1 end
        cond = TruckingShared.Clamp(cond, 0, 100)
        deliveryState.condition = cond
        TriggerServerEvent('fivempro_trucking:server:updateCondition', cond)
        if deliveryState.contract and deliveryState.contract.illegal then
            if math.random(100) <= 1 then
                if GetResourceState('fivempro_dispatch') == 'started' then
                    local c = GetEntityCoords(ped)
                    TriggerServerEvent('fivempro_dispatch:server:createServiceCall', 'police', 'suspicious_vehicle', 'Įtartinas krovinys', { x = c.x, y = c.y, z = c.z })
                end
            end
        end
        ::continue::
    end
end)

RegisterCommand('trucknet', function()
    openUI('full')
end, false)

exports('OpenTruckNet', function(mode)
    openUI(mode or 'full')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlip()
    if uiOpen then SetNuiFocus(false, false) end
end)
