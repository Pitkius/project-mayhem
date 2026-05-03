local QBCore = exports['qb-core']:GetCoreObject()
local mdtOpen = false

local function closeMdt()
    if not mdtOpen then return end
    mdtOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('fivempro_ltpd:client:forceCloseMdt', function()
    closeMdt()
end)

RegisterNetEvent('fivempro_ltpd:client:cuffedState', function(state)
    LocalPlayer.state:set('ltpdCuffed', state, true)
    local ped = PlayerPedId()
    if state then
        RequestAnimDict('mp_arresting')
        while not HasAnimDictLoaded('mp_arresting') do Wait(10) end
        TaskPlayAnim(ped, 'mp_arresting', 'idle', 8.0, -8.0, -1, 49, 0, false, false, false)
    else
        ClearPedTasks(ped)
    end
end)

CreateThread(function()
    while true do
        if LocalPlayer.state.ltpdCuffed then
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            Wait(0)
        else
            Wait(300)
        end
    end
end)

local function openMdt()
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:canOpenMdt', function(can)
        if not can then
            return QBCore.Functions.Notify('MDT prieinamas tik policijai tarnybos metu.', 'error')
        end
        QBCore.Functions.TriggerCallback('fivempro_ltpd:server:mdtContext', function(ctx)
            if not ctx then return end
            mdtOpen = true
            SetNuiFocus(true, true)
            SendNUIMessage({ action = 'open', data = ctx })
        end)
    end)
end

RegisterCommand('mdt', function()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or Player.job.name ~= Config.JobName or not Player.job.onduty then
        return QBCore.Functions.Notify('Tu ne policininkas arba ne tarnyboje.', 'error')
    end
    openMdt()
end, false)

RegisterNUICallback('close', function(_, cb)
    closeMdt()
    cb('ok')
end)

RegisterNUICallback('searchPerson', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:searchPerson', function(result)
        cb(result or { ok = false })
    end, data and data.query)
end)

RegisterNUICallback('searchVehicle', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:searchVehicle', function(result)
        cb(result or { ok = false })
    end, data and data.plate)
end)

RegisterNUICallback('issueFine', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:issueFine', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('setWanted', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:setWanted', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('addArrest', function(data, cb)
    QBCore.Functions.TriggerCallback('fivempro_ltpd:server:addArrestNote', function(result)
        cb(result or { ok = false })
    end, data and data.citizenid, data and data.notes)
end)

CreateThread(function()
    while true do
        if mdtOpen and (IsControlJustPressed(0, 199) or IsDisabledControlJustPressed(0, 199) or IsControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 200)) then
            closeMdt()
        end
        Wait(0)
    end
end)

RegisterNetEvent('fivempro_ltpd:client:openMdtAtStation', function()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or Player.job.name ~= Config.JobName or not Player.job.onduty then
        return QBCore.Functions.Notify('MDT – tik policijai tarnyboje.', 'error')
    end
    openMdt()
end)

local function isLtpdClient()
    local P = QBCore.Functions.GetPlayerData()
    return P and P.job and P.job.name == Config.JobName and P.job.onduty
end

RegisterNetEvent('fivempro_ltpd:client:tryOpenArmory', function(data)
    if not isLtpdClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId then return end
    TriggerServerEvent('fivempro_ltpd:server:openArmory', stationId)
end)

RegisterNetEvent('fivempro_ltpd:client:openGarageMenu', function(data)
    if not isLtpdClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId or not Config.FleetVehicles or not next(Config.FleetVehicles) then return end
    local stLabel = 'PD transportas'
    for _, s in ipairs(Config.Stations or {}) do
        if s.id == stationId then
            stLabel = s.label or stLabel
            break
        end
    end
    local menu = {
        { header = stLabel, isMenuHeader = true },
    }
    for _, v in ipairs(Config.FleetVehicles) do
        menu[#menu + 1] = {
            header = v.label,
            txt = v.model,
            params = {
                event = 'fivempro_ltpd:client:requestSpawnFleet',
                args = { stationId = stationId, model = v.model },
            },
        }
    end
    if GetResourceState('qb-menu') == 'started' then
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    else
        QBCore.Functions.Notify('Įdiek qb-menu garažo meniu.', 'error')
    end
end)

RegisterNetEvent('fivempro_ltpd:client:requestSpawnFleet', function(args)
    if not isLtpdClient() then return end
    local model = args and args.model
    local stationId = args and args.stationId
    if not model or not stationId then return end
    TriggerServerEvent('fivempro_ltpd:server:spawnFleet', stationId, model)
end)

RegisterNetEvent('fivempro_ltpd:client:openHeliGarageMenu', function(data)
    if not isLtpdClient() then
        return QBCore.Functions.Notify('Tik policijai tarnyboje.', 'error')
    end
    local stationId = data and data.stationId
    if not stationId or not Config.FleetHelicopters or not next(Config.FleetHelicopters) then return end
    local stLabel = 'PD oro tarnyba'
    for _, s in ipairs(Config.Stations or {}) do
        if s.id == stationId then
            stLabel = (s.label or '') .. ' – sraigtasparniai'
            break
        end
    end
    local menu = {
        { header = stLabel, isMenuHeader = true },
    }
    for _, v in ipairs(Config.FleetHelicopters) do
        menu[#menu + 1] = {
            header = v.label,
            txt = v.model,
            params = {
                event = 'fivempro_ltpd:client:requestSpawnHeli',
                args = { stationId = stationId, model = v.model },
            },
        }
    end
    if GetResourceState('qb-menu') == 'started' then
        TriggerEvent('qb-menu:client:openMenu', menu, false, true)
    else
        QBCore.Functions.Notify('Reikia qb-menu.', 'error')
    end
end)

RegisterNetEvent('fivempro_ltpd:client:requestSpawnHeli', function(args)
    if not isLtpdClient() then return end
    local model = args and args.model
    local stationId = args and args.stationId
    if not model or not stationId then return end
    TriggerServerEvent('fivempro_ltpd:server:spawnFleetHeli', stationId, model)
end)

RegisterNetEvent('fivempro_ltpd:client:fleetVehicleReady', function(plate)
    if not plate or plate == '' then return end
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end)

CreateThread(function()
    if not Config.ShowStationBlips then return end
    for _, st in ipairs(Config.Stations or {}) do
        if st.coords then
            local b = AddBlipForCoord(st.coords.x, st.coords.y, st.coords.z)
            SetBlipSprite(b, Config.BlipSprite or 60)
            SetBlipDisplay(b, 4)
            SetBlipScale(b, Config.BlipScale or 0.85)
            SetBlipColour(b, Config.BlipColour or 38)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(st.label or 'Policija')
            EndTextCommandSetBlipName(b)
        end
        if Config.ShowHelipadBlip and st.heliGarage and st.heliGarage.coords then
            local h = st.heliGarage.coords
            local bh = AddBlipForCoord(h.x, h.y, h.z)
            SetBlipSprite(bh, Config.HelipadBlipSprite or 43)
            SetBlipDisplay(bh, 4)
            SetBlipScale(bh, Config.HelipadBlipScale or 0.9)
            SetBlipColour(bh, Config.BlipColour or 38)
            SetBlipAsShortRange(bh, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName((st.label or 'PD') .. ' – helipadas')
            EndTextCommandSetBlipName(bh)
        end
    end
end)

CreateThread(function()
    while GetResourceState('qb-target') ~= 'started' do
        Wait(300)
    end
    for _, st in ipairs(Config.Stations or {}) do
        if st.mdt then
            exports['qb-target']:AddCircleZone(('ltpd_mdt_%s'):format(st.id), st.coords, 0.55, {
                name = ('ltpd_mdt_%s'):format(st.id),
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:openMdtAtStation',
                        icon = 'fas fa-tablet-screen-button',
                        label = 'MDT planšetė',
                        job = { ltpd = 0 },
                    },
                },
                distance = Config.TargetDistance,
            })
        end
        if st.armory and st.armory.coords then
            exports['qb-target']:AddCircleZone(('ltpd_armory_%s'):format(st.id), st.armory.coords, 0.45, {
                name = ('ltpd_armory_%s'):format(st.id),
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:tryOpenArmory',
                        icon = 'fas fa-box-open',
                        label = 'Ginklinė',
                        stationId = st.id,
                        job = { ltpd = 0 },
                    },
                },
                distance = Config.TargetDistance,
            })
        end
        if st.garage and st.garage.coords then
            exports['qb-target']:AddCircleZone(('ltpd_garage_%s'):format(st.id), st.garage.coords, 0.65, {
                name = ('ltpd_garage_%s'):format(st.id),
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:openGarageMenu',
                        icon = 'fas fa-car',
                        label = 'Tarnybinis transportas',
                        stationId = st.id,
                        job = { ltpd = 0 },
                    },
                },
                distance = Config.TargetDistance + 0.5,
            })
        end
        if st.management and st.management.coords then
            exports['qb-target']:AddCircleZone(('ltpd_mgmt_%s'):format(st.id), st.management.coords, 0.5, {
                name = ('ltpd_mgmt_%s'):format(st.id),
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:bossOpenMenu',
                        icon = 'fas fa-user-tie',
                        label = 'PD vadovybė (įdarb./rangai/tarnyba)',
                        job = { ltpd = 8 },
                    },
                },
                distance = Config.TargetDistance + 0.5,
            })
        end
        if st.heliGarage and st.heliGarage.coords then
            exports['qb-target']:AddCircleZone(('ltpd_heli_%s'):format(st.id), st.heliGarage.coords, 1.2, {
                name = ('ltpd_heli_%s'):format(st.id),
                debugPoly = false,
                useZ = true,
            }, {
                options = {
                    {
                        type = 'client',
                        event = 'fivempro_ltpd:client:openHeliGarageMenu',
                        icon = 'fas fa-helicopter',
                        label = 'PD sraigtasparniai (helipadas)',
                        stationId = st.id,
                        job = { ltpd = 0 },
                    },
                },
                distance = Config.TargetDistance + 2.0,
            })
        end
    end
end)
