local QBCore = exports['qb-core']:GetCoreObject()

local cfg = Config.Reports or {}
local isOpen = false

local function setNui(state)
    isOpen = state
    SetNuiFocus(state, state)
    SetNuiFocusKeepInput(false)
end

local function openReports(view)
    if isOpen then return end
    QBCore.Functions.TriggerCallback('mrp_reports:server:getBootstrap', function(data)
        if not data then return end
        if view == 'admin' and not data.showAdminModeButton then
            view = 'create'
        end
        setNui(true)
        SendNUIMessage({
            action = 'open',
            view = view or 'create',
            data = data,
        })
    end)
end

local function closeReports()
    if not isOpen then return end
    setNui(false)
    SendNUIMessage({ action = 'close' })
end

RegisterNetEvent('mrp_reports:client:forceClose', function()
    closeReports()
end)

RegisterNetEvent('mrp_reports:client:open', function(view)
    openReports(view)
end)

RegisterNetEvent('mrp_reports:client:staffAlert', function()
    PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', true)
end)

RegisterNetEvent('mrp_reports:client:refreshPlayer', function()
    if not isOpen then return end
    QBCore.Functions.TriggerCallback('mrp_reports:server:myReports', function(rows)
        SendNUIMessage({ action = 'myReports', rows = rows or {} })
    end)
end)

RegisterNetEvent('mrp_reports:client:refreshAdmin', function()
    if not isOpen then return end
    QBCore.Functions.TriggerCallback('mrp_reports:server:adminReports', function(rows)
        SendNUIMessage({ action = 'adminReports', rows = rows or {} })
    end)
end)

RegisterNUICallback('close', function(_, cb)
    closeReports()
    cb('ok')
end)

RegisterNUICallback('submit', function(payload, cb)
    QBCore.Functions.TriggerCallback('mrp_reports:server:submit', function(result)
        if result and result.ok then
            QBCore.Functions.Notify(('Report #%s pateiktas!'):format(result.report.id), 'success', 8000)
            QBCore.Functions.TriggerCallback('mrp_reports:server:myReports', function(rows)
                SendNUIMessage({ action = 'submitted', report = result.report, rows = rows or {} })
            end)
        else
            QBCore.Functions.Notify((result and result.error) or 'Nepavyko pateikti.', 'error', 8000)
        end
        cb(result or { ok = false })
    end, payload)
end)

RegisterNUICallback('setStatus', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_reports:server:setStatus', function(result)
        if result and result.ok then
            QBCore.Functions.Notify('Būsena atnaujinta.', 'success')
        else
            QBCore.Functions.Notify((result and result.error) or 'Klaida.', 'error')
        end
        cb(result or { ok = false })
    end, data.reportId, data.status)
end)

RegisterNUICallback('reply', function(data, cb)
    QBCore.Functions.TriggerCallback('mrp_reports:server:reply', function(result)
        if result and result.ok then
            QBCore.Functions.Notify('Atsakymas išsiųstas.', 'success')
        else
            QBCore.Functions.Notify((result and result.error) or 'Klaida.', 'error')
        end
        cb(result or { ok = false })
    end, data.reportId, data.text)
end)

RegisterNUICallback('refresh', function(data, cb)
    if data.mode == 'admin' then
        QBCore.Functions.TriggerCallback('mrp_reports:server:adminReports', function(rows)
            cb({ rows = rows or {} })
        end)
    else
        QBCore.Functions.TriggerCallback('mrp_reports:server:myReports', function(rows)
            cb({ rows = rows or {} })
        end)
    end
end)

RegisterCommand('reportmenu', function()
    openReports('create')
end, false)

if cfg.OpenKey and cfg.OpenKey ~= '' then
    RegisterKeyMapping('reportmenu', cfg.OpenKeyDescription or 'Pagalbos centras', 'keyboard', cfg.OpenKey)
end

CreateThread(function()
    while true do
        if isOpen then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 18, true)
            DisableControlAction(0, 322, true)
            Wait(0)
        else
            Wait(400)
        end
    end
end)

exports('OpenReports', openReports)
exports('CloseReports', closeReports)
