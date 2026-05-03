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
                        station = st.id,
                    },
                },
                distance = Config.TargetDistance,
            })
        end
    end
end)

RegisterNetEvent('fivempro_ltpd:client:openMdtAtStation', function()
    local Player = QBCore.Functions.GetPlayerData()
    if not Player or Player.job.name ~= Config.JobName or not Player.job.onduty then
        return QBCore.Functions.Notify('MDT – tik policijai tarnyboje.', 'error')
    end
    openMdt()
end)
