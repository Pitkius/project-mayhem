local QBCore = exports['qb-core']:GetCoreObject()

local mdtOpen = false
local activeService = nil

local function serviceForJob(jobName)
    jobName = tostring(jobName or '')
    for service, cfg in pairs(Config.Services or {}) do
        for _, j in ipairs(cfg.jobs or {}) do
            if j == jobName then return service end
        end
    end
    local shared = QBCore.Shared and QBCore.Shared.Jobs or {}
    local row = shared[jobName]
    if row then
        if row.type == 'ems' then return 'ems' end
        if row.type == 'mechanic' then return 'mechanic' end
    end
    return nil
end

local function isOnDutyForService(service)
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return false end
    local cfg = Config.Services[service]
    if not cfg then return false end
    for _, j in ipairs(cfg.jobs or {}) do
        if P.job.name == j and P.job.onduty then return true end
    end
    return false
end

local function closeMdt()
    if not mdtOpen then return end
    local closingService = activeService
    mdtOpen = false
    activeService = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if closingService then
        QBCore.Functions.TriggerCallback('mrp_service_mdt:server:mdtSessionClose', function() end, closingService)
    end
end

local function setMdtNuiFocus(cursor)
    if not mdtOpen then
        SetNuiFocus(false, false)
        return
    end
    SetNuiFocus(true, cursor == true)
end

local function openMdt(service)
    service = tostring(service or '')
    if not Config.Services[service] then
        return QBCore.Functions.Notify('Nežinoma MDT tarnyba.', 'error')
    end
    if not isOnDutyForService(service) then
        return QBCore.Functions.Notify('MDT prieinamas tik tarnybos metu.', 'error')
    end

    QBCore.Functions.TriggerCallback('mrp_service_mdt:server:canOpen', function(can)
        if not can then
            return QBCore.Functions.Notify('Neturite prieigos prie šio MDT.', 'error')
        end
        QBCore.Functions.TriggerCallback('mrp_service_mdt:server:mdtContext', function(ctx)
            if not ctx then return end
            activeService = service
            mdtOpen = true
            setMdtNuiFocus(true)
            SendNUIMessage({ action = 'open', data = ctx })
        end, service)
    end, service)
end

exports('OpenMdt', openMdt)
exports('CloseMdt', closeMdt)
exports('IsMdtOpen', function() return mdtOpen end)

RegisterNetEvent('mrp_service_mdt:client:open', function(service)
    openMdt(service)
end)

RegisterNetEvent('mrp_service_mdt:client:forceClose', function()
    closeMdt()
end)

RegisterCommand('servicemdtui', function()
    local P = QBCore.Functions.GetPlayerData()
    if not P or not P.job then return end
    local service = serviceForJob(P.job.name)
    if not service then
        return QBCore.Functions.Notify('Tavo darbas neturi MDT.', 'error')
    end
    openMdt(service)
end, false)

RegisterNUICallback('mdtClose', function(_, cb)
    closeMdt()
    cb({ ok = true })
end)

RegisterNUICallback('mdtTelemetry', function(data, cb)
    if activeService and data then data.service = activeService end
    QBCore.Functions.TriggerCallback('mrp_service_mdt:server:mdtTelemetry', function(result)
        cb(result or { ok = true })
    end, data)
end)

RegisterNUICallback('mdtPing', function(_, cb)
    cb({ ok = true, mdtOpen = mdtOpen, service = activeService })
end)

RegisterNUICallback('dispatchSnapshot', function(_, cb)
    if not activeService then
        return cb({ ok = false, calls = {}, crews = {}, units = {} })
    end
    if GetResourceState('mrp_dispatch') ~= 'started' then
        return cb({
            ok = true,
            readOnly = true,
            calls = {},
            crews = {},
            units = {},
            msg = 'mrp_dispatch neįkeltas',
        })
    end
    local done = false
    local function reply(payload)
        if done then return end
        done = true
        cb(payload or { ok = false, calls = {}, crews = {}, units = {} })
    end
    SetTimeout(12000, function()
        reply({ ok = false, msg = 'Dispatch timeout', calls = {}, crews = {}, units = {} })
    end)
    QBCore.Functions.TriggerCallback('mrp_dispatch:server:getMdtSnapshot', function(result)
        reply(result or { ok = false, calls = {}, crews = {}, units = {} })
    end, activeService)
end)

local function isDispatchWritable()
    return mdtOpen and activeService and isOnDutyForService(activeService)
end

RegisterNUICallback('dispatchAction', function(data, cb)
    if not isDispatchWritable() then
        return cb({ ok = false, msg = 'Tik pamainoje galima valdyti dispatch.' })
    end
    if data and data.callId and data.action then
        TriggerServerEvent('mrp_dispatch:server:updateCallStatus', data.callId, data.action)
    end
    cb({ ok = true })
end)

RegisterNUICallback('crewAction', function(data, cb)
    if not isDispatchWritable() then
        return cb({ ok = false, msg = 'Tik pamainoje galima valdyti ekipažus.' })
    end
    local cfg = activeService and Config.Services[activeService]
    if cfg and cfg.enableCrews == false then
        return cb({ ok = false, msg = 'Šis MDT neturi ekipažų.' })
    end
    local action = tostring(data and data.action or '')
    if action == 'create' then
        TriggerServerEvent('mrp_dispatch:server:createCrew', tostring(data.callsign or ''))
    elseif action == 'join' then
        TriggerServerEvent('mrp_dispatch:server:joinCrew', tostring(data.crewId or ''))
    elseif action == 'addMember' then
        TriggerServerEvent('mrp_dispatch:server:addToCrew', tostring(data.crewId or ''), tonumber(data.targetId))
    elseif action == 'delete' then
        TriggerServerEvent('mrp_dispatch:server:deleteCrew', tostring(data.crewId or ''))
    elseif action == 'leave' then
        TriggerServerEvent('mrp_dispatch:server:leaveCrew')
    elseif action == 'setCallsign' then
        TriggerServerEvent('mrp_dispatch:server:setCallsign', tostring(data.callsign or ''))
    end
    cb({ ok = true })
end)

RegisterNUICallback('mdtSetRoute', function(data, cb)
    local x, y = tonumber(data and data.x), tonumber(data and data.y)
    if x and y then
        SetNewWaypoint(x + 0.0, y + 0.0)
    end
    cb({ ok = true })
end)

RegisterNUICallback('issueInvoice', function(data, cb)
    if not activeService then return cb({ ok = false }) end
    data = data or {}
    data.service = activeService
    QBCore.Functions.TriggerCallback('mrp_service_mdt:server:issueInvoice', function(result)
        cb(result or { ok = false })
    end, data)
end)

RegisterNUICallback('searchInvoices', function(data, cb)
    if not activeService then return cb({ ok = false, rows = {} }) end
    data = data or {}
    data.service = activeService
    QBCore.Functions.TriggerCallback('mrp_service_mdt:server:searchInvoices', function(result)
        cb(result or { ok = false, rows = {} })
    end, data)
end)

RegisterNUICallback('recentInvoices', function(_, cb)
    if not activeService then return cb({ ok = false, rows = {} }) end
    QBCore.Functions.TriggerCallback('mrp_service_mdt:server:recentInvoices', function(result)
        cb(result or { ok = false, rows = {} })
    end, activeService)
end)

local function incidentCb(name, serverCb, allowedServices)
    RegisterNUICallback(name, function(data, cb)
        if not activeService then
            return cb({ ok = false, message = 'MDT neaktyvus.' })
        end
        local services = allowedServices or { ems = true, mechanic = true }
        if not services[activeService] then
            return cb({ ok = false, message = 'Ši tarnyba neturi bylų.' })
        end
        data = data or {}
        data.service = activeService
        QBCore.Functions.TriggerCallback(serverCb, function(result)
            cb(result or { ok = false })
        end, data)
    end)
end

incidentCb('incidentMeta', 'mrp_service_mdt:server:incidentMeta')
incidentCb('incidentList', 'mrp_service_mdt:server:incidentList')
incidentCb('incidentGet', 'mrp_service_mdt:server:incidentGet')
incidentCb('incidentCreate', 'mrp_service_mdt:server:incidentCreate')
incidentCb('incidentTransition', 'mrp_service_mdt:server:incidentTransition')
incidentCb('incidentUpdateCase', 'mrp_service_mdt:server:incidentUpdateCase')
incidentCb('incidentSaveReport', 'mrp_service_mdt:server:incidentSaveReport')
incidentCb('incidentNearby', 'mrp_service_mdt:server:incidentNearby')
incidentCb('incidentAttachParty', 'mrp_service_mdt:server:incidentAttachParty')
incidentCb('incidentDetachParty', 'mrp_service_mdt:server:incidentDetachParty')
incidentCb('incidentAttachUnit', 'mrp_service_mdt:server:incidentAttachUnit')
incidentCb('incidentAttachMedic', 'mrp_service_mdt:server:incidentAttachMedic', { ems = true })
incidentCb('incidentAddMed', 'mrp_service_mdt:server:incidentAddMed', { ems = true })
incidentCb('incidentAddAction', 'mrp_service_mdt:server:incidentAddAction', { ems = true })
incidentCb('incidentAddEquipment', 'mrp_service_mdt:server:incidentAddEquipment', { ems = true })
incidentCb('incidentAttachVehicle', 'mrp_service_mdt:server:incidentAttachVehicle', { mechanic = true })
incidentCb('incidentDetachVehicle', 'mrp_service_mdt:server:incidentDetachVehicle', { mechanic = true })
incidentCb('incidentAddDiagnostic', 'mrp_service_mdt:server:incidentAddDiagnostic', { mechanic = true })
incidentCb('incidentAddWork', 'mrp_service_mdt:server:incidentAddWork', { mechanic = true })
incidentCb('incidentAddPart', 'mrp_service_mdt:server:incidentAddPart', { mechanic = true })
incidentCb('incidentAddTowRef', 'mrp_service_mdt:server:incidentAddTowRef', { mechanic = true })

CreateThread(function()
    local lastPos = nil
    while true do
        if mdtOpen then
            local perf = Config.MdtPerformance or {}
            local interval = math.max(200, tonumber(perf.PlayerPosIntervalMs) or 750)
            local minMove = tonumber(perf.PlayerPosMinMoveM) or 2.5
            local minMoveSq = minMove * minMove

            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            local send = not lastPos
            if lastPos then
                local dx = c.x - lastPos.x
                local dy = c.y - lastPos.y
                local dz = c.z - lastPos.z
                if (dx * dx + dy * dy + dz * dz) >= minMoveSq then
                    send = true
                end
            end
            if send then
                lastPos = c
                SendNUIMessage({
                    action = 'mdtPlayerPos',
                    selfSource = GetPlayerServerId(PlayerId()),
                    x = c.x,
                    y = c.y,
                    z = c.z,
                    heading = GetEntityHeading(ped),
                })
            end
            Wait(interval)
        else
            lastPos = nil
            Wait(500)
        end
    end
end)

RegisterNetEvent('mrp_dispatch:client:update', function(payload)
    if not mdtOpen or not payload or payload.service ~= activeService then return end
    SendNUIMessage({
        action = 'dispatchLive',
        data = {
            units = payload.units or {},
            calls = payload.calls or {},
            crews = payload.crews or {},
            selfSource = GetPlayerServerId(PlayerId()),
            ts = payload.ts,
        },
    })
end)

CreateThread(function()
    while true do
        if mdtOpen then
            if IsControlJustReleased(0, 322) or IsControlJustReleased(0, 200) then
                closeMdt()
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        closeMdt()
    end
end)
