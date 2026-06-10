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
    exports['fivempro_fonts']:SetBlipName(missionBlip, label or 'Kontraktas')
end

--- Kelių maršruto taškai NUI žemėlapiui (snap į artimiausius kelių mazgus).
local function sampleRoadPath(x1, y1, z1, x2, y2, z2)
    local points = { { x = x1, y = y1 } }
    local cx, cy, cz = x1, y1, z1
    local tx, ty, tz = x2, y2, z2

    for _ = 1, 72 do
        local dx, dy, dz = tx - cx, ty - cy, tz - cz
        local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
        if dist < 90.0 then break end

        local step = math.min(160.0, dist * 0.38)
        dx, dy = dx / dist, dy / dist
        local px, py, pz = cx + dx * step, cy + dy * step, cz

        local found, nodePos = GetClosestVehicleNodeWithHeading(px, py, pz, 1, 3.0, 0)
        if found and nodePos then
            local nx, ny, nz = nodePos.x, nodePos.y, nodePos.z
            if math.abs(nx - cx) + math.abs(ny - cy) > 18.0 then
                cx, cy, cz = nx, ny, nz
                points[#points + 1] = { x = cx, y = cy }
            else
                cx, cy = cx + dx * 70.0, cy + dy * 70.0
                points[#points + 1] = { x = cx, y = cy }
            end
        else
            cx, cy = cx + dx * 70.0, cy + dy * 70.0
            points[#points + 1] = { x = cx, y = cy }
        end
    end

    points[#points + 1] = { x = tx, y = ty }
    return points
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
        if not data then
            QBCore.Functions.Notify('CargoNet duomenų nepavyko gauti.', 'error')
            return
        end
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
        if res and res.ok then
            if res.alreadyRegistered then
                QBCore.Functions.Notify('Jau esi registruotas — atidaroma panelė.', 'primary')
            else
                QBCore.Functions.Notify('Registracija sėkminga! TruckNet Level 1.', 'success')
            end
        elseif res and res.reason then
            QBCore.Functions.Notify(res.reason, 'error')
        else
            QBCore.Functions.Notify('Registracija nepavyko.', 'error')
        end
        cb(res or { ok = false })
    end)
end)

RegisterNUICallback('trucking:createCompany', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:createCompany', function(res)
        cb(res or { ok = false })
    end, data and data.name)
end)

RegisterNUICallback('trucking:getRoutePath', function(data, cb)
    local from, to = data and data.from, data and data.to
    if not from or not to or from.x == nil or to.x == nil then
        return cb({ ok = false, points = {} })
    end
    local points = sampleRoadPath(
        tonumber(from.x), tonumber(from.y), tonumber(from.z or 0),
        tonumber(to.x), tonumber(to.y), tonumber(to.z or 0)
    )
    cb({ ok = true, points = points })
end)

RegisterNUICallback('trucking:acceptContract', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:acceptContract', function(res)
        if res and res.ok then
            closeUI()
            QBCore.Functions.Notify('Kontraktas priimtas — važiuok į paėmimo vietą.', 'success')
        elseif res and res.reason then
            QBCore.Functions.Notify(res.reason, 'error')
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

local function registerAtTerminal()
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:register', function(res)
        if res and res.ok then
            if res.alreadyRegistered then
                QBCore.Functions.Notify('Atidaroma CargoNet panelė.', 'primary')
            else
                QBCore.Functions.Notify('Registracija sėkminga! CargoNet 1 lygis.', 'success')
            end
            openUI('full')
        else
            QBCore.Functions.Notify((res and res.reason) or 'Klaida.', 'error')
        end
    end)
end

local function openTerminalMenu()
    QBCore.Functions.TriggerCallback('fivempro_trucking:server:isRegistered', function(registered)
        if GetResourceState('qb-menu') == 'started' then
            local menu = {
                { header = 'CargoNet Logistics', isMenuHeader = true },
            }
            if registered then
                menu[#menu + 1] = {
                    header = 'Atidaryti CargoNet',
                    txt = 'Kontraktai, birža, įmonė ir parkas',
                    params = { event = 'fivempro_trucking:client:openUI', args = { mode = 'full' } },
                }
            else
                menu[#menu + 1] = {
                    header = 'Registruotis vairuotoju',
                    txt = 'Freelance sunkvežimio vairuotojas',
                    params = { event = 'fivempro_trucking:client:registerAtTerminal' },
                }
            end
            menu[#menu + 1] = { header = 'Uždaryti', params = { event = 'qb-menu:client:closeMenu' } }
            exports['qb-menu']:openMenu(menu)
            return
        end
        openUI('full')
    end)
end

RegisterNetEvent('fivempro_trucking:client:openUI', function(data)
    openUI(type(data) == 'table' and data.mode or 'full')
end)

RegisterNetEvent('fivempro_trucking:client:registerAtTerminal', function()
    registerAtTerminal()
end)

local function setupTargetZones()
    if GetResourceState('qb-target') ~= 'started' then return false end
    for _, term in ipairs(Config.RegistrationTerminals or {}) do
        exports['qb-target']:AddBoxZone(
            'trucknet_' .. term.id,
            term.coords,
            2.5, 2.5,
            {
                name = 'trucknet_' .. term.id,
                heading = term.heading or 0.0,
                minZ = term.coords.z - 1.2,
                maxZ = term.coords.z + 2.2,
                debugPoly = false,
            },
            {
                options = {
                    {
                        icon = 'fas fa-truck',
                        label = 'TruckNet Logistics',
                        action = openTerminalMenu,
                    },
                },
                distance = 3.0,
            }
        )
    end
    return true
end

CreateThread(function()
    for _, term in ipairs(Config.RegistrationTerminals or {}) do
        if term.blip then
            local b = AddBlipForCoord(term.coords.x, term.coords.y, term.coords.z)
            SetBlipSprite(b, term.blip.sprite or 477)
            SetBlipColour(b, term.blip.color or 47)
            SetBlipScale(b, term.blip.scale or 0.8)
            SetBlipAsShortRange(b, true)
            exports['fivempro_fonts']:SetBlipName(b, term.blip.label or 'TruckNet')
        end
    end

    local waited = 0
    while not setupTargetZones() and waited < 60 do
        Wait(1000)
        waited = waited + 1
    end
end)

CreateThread(function()
    while true do
        local sleep = 1200
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for _, term in ipairs(Config.RegistrationTerminals or {}) do
            local c = term.coords
            local dist = #(pos - vector3(c.x, c.y, c.z))
            if dist < 25.0 then
                sleep = 0
                DrawMarker(1, c.x, c.y, c.z - 1.0, 0, 0, 0, 0, 0, 0, 2.2, 2.2, 1.0, 251, 146, 60, 140, false, false, 2, false, nil, nil, false)
                if dist < 2.8 then
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ TruckNet Logistics')
                    EndTextCommandDisplayHelp(0, false, true, -1)
                    if IsControlJustReleased(0, 38) then
                        openTerminalMenu()
                    end
                end
            end
        end
        Wait(sleep)
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
