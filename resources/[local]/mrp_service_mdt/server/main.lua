local QBCore = exports['qb-core']:GetCoreObject()

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `fivempro_service_invoices` (
        `id` BIGINT NOT NULL AUTO_INCREMENT,
        `service` VARCHAR(32) NOT NULL,
        `citizenid` VARCHAR(64) NOT NULL,
        `issuer_citizenid` VARCHAR(64) NOT NULL,
        `amount` INT NOT NULL,
        `reason_code` VARCHAR(64) NULL,
        `reason_label` VARCHAR(255) NOT NULL,
        `plate` VARCHAR(16) NULL,
        `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (`id`),
        KEY `idx_service_citizen` (`service`, `citizenid`),
        KEY `idx_created_at` (`created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end)

local function mdtCoreReady()
    return GetResourceState('mrp_mdt_core') == 'started'
end

local function mdtPerformancePayload()
    local perf = Config.MdtPerformance or {}
    return {
        dispatchPollMs = perf.DispatchPollMs or 2500,
        pushStaleMs = perf.PushStaleMs or 3500,
        dispatchPollPushMs = perf.DispatchPollPushMs or 8000,
        disablePollWhenPushActive = perf.DisablePollWhenPushActive ~= false,
    }
end

local function serviceCfg(service)
    return Config.Services and Config.Services[service]
end

local function jobMatchesService(jobName, service)
    local cfg = serviceCfg(service)
    if not cfg or not jobName then return false end
    for _, j in ipairs(cfg.jobs or {}) do
        if j == jobName then return true end
    end
    return false
end

local function playerService(src, requireDuty)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData or not P.PlayerData.job then return nil end
    local jn = P.PlayerData.job.name
    if requireDuty and P.PlayerData.job.onduty ~= true then return nil end
    for service, _ in pairs(Config.Services or {}) do
        if jobMatchesService(jn, service) then return service end
    end
    return nil
end

local function canIssueInvoice(src, service)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData or not P.PlayerData.job then return false end
    if not jobMatchesService(P.PlayerData.job.name, service) then return false end
    if P.PlayerData.job.onduty ~= true then return false end
    if service == 'ems' and GetResourceState('mrp_mdt_core') == 'started' then
        local ok, allowed = pcall(function()
            return exports['mrp_mdt_core']:HasPermission(src, 'EMS_MDT_INVOICE') == true
        end)
        if ok and allowed then return true end
    end
    if service == 'mechanic' and GetResourceState('mrp_mdt_core') == 'started' then
        local ok, allowed = pcall(function()
            return exports['mrp_mdt_core']:HasPermission(src, 'MECH_MDT_INVOICE') == true
        end)
        if ok and allowed then return true end
    end
    local cfg = serviceCfg(service)
    local minG = cfg and cfg.invoiceMinGrade or 0
    return (P.PlayerData.job.grade and P.PlayerData.job.grade.level or 0) >= minG
end

local function canViewEmsIncidents(src)
    if GetResourceState('mrp_mdt_core') == 'started' then
        local ok, allowed = pcall(function()
            return exports['mrp_mdt_core']:HasPermission(src, 'EMS_INCIDENT_VIEW') == true
                or exports['mrp_mdt_core']:HasPermission(src, 'INCIDENT_VIEW') == true
        end)
        if ok and allowed then return true end
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P or P.PlayerData.job.name ~= 'ambulance' then return false end
    return true
end

local function canViewMechanicIncidents(src)
    if GetResourceState('mrp_mdt_core') == 'started' then
        local ok, allowed = pcall(function()
            return exports['mrp_mdt_core']:HasPermission(src, 'MECH_INCIDENT_VIEW') == true
                or exports['mrp_mdt_core']:HasPermission(src, 'INCIDENT_VIEW') == true
        end)
        if ok and allowed then return true end
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData or not P.PlayerData.job then return false end
    local shared = QBCore.Shared and QBCore.Shared.Jobs or {}
    local row = shared[P.PlayerData.job.name]
    return row and row.type == 'mechanic'
end

local function canViewServiceIncidents(src, service)
    if service == 'ems' then return canViewEmsIncidents(src) end
    if service == 'mechanic' then return canViewMechanicIncidents(src) end
    return false
end

--- Single write path for service invoices (MDT tab + incident link).
function IssueServiceInvoice(src, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not canIssueInvoice(src, service) then
        return { ok = false, message = 'Nėra teisės išrašyti sąskaitos.' }
    end

    local tid = tostring(data.citizenid or ''):sub(1, 64)
    local amount = tonumber(data.amount) or 0
    local code = tostring(data.reason_code or ''):sub(1, 64)
    local label = tostring(data.reason_label or ''):sub(1, 255)
    local plate = tostring(data.plate or ''):sub(1, 16)
    if plate == '' then plate = nil end

    if tid == '' or amount < 1 or amount > (Config.MaxInvoiceAmount or 25000) or label == '' then
        return { ok = false, message = 'Neteisingi duomenys.' }
    end

    local Issuer = QBCore.Functions.GetPlayer(src)
    if not Issuer then return { ok = false, message = 'Klaida.' } end

    local Target = QBCore.Functions.GetPlayerByCitizenId(tid)
    if Target then
        if not Target.Functions.RemoveMoney('bank', amount, ('service-invoice-%s'):format(service)) then
            if not Target.Functions.RemoveMoney('cash', amount, ('service-invoice-%s'):format(service)) then
                return { ok = false, message = 'Klientas neturi pinigų (bankas/grynieji).' }
            end
        end
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source,
            ('Sąskaita %s €: %s'):format(amount, label), 'error')
    end

    local invoiceId = MySQL.insert.await(
        'INSERT INTO fivempro_service_invoices (service, citizenid, issuer_citizenid, amount, reason_code, reason_label, plate) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { service, tid, Issuer.PlayerData.citizenid, amount, code, label, plate }
    )

    local incidentLink
    if (service == 'ems' or service == 'mechanic') and ServiceMdtIncidents and ServiceMdtIncidents.OnInvoiceIssued then
        incidentLink = ServiceMdtIncidents.OnInvoiceIssued(src, {
            service = service,
            citizenid = tid,
            amount = amount,
            reason_code = code,
            reason_label = label,
            plate = plate,
            invoiceId = invoiceId,
            incidentId = data.incidentId,
        })
    end

    TriggerClientEvent('QBCore:Notify', src, 'Sąskaita išrašyta.', 'success')
    return {
        ok = true,
        invoiceId = invoiceId,
        incident = incidentLink,
    }
end

exports('IssueServiceInvoice', IssueServiceInvoice)

local function personNameFromRow(row)
    if not row then return '—' end
    local ok, charinfo = pcall(json.decode, row.charinfo or '{}')
    if not ok or type(charinfo) ~= 'table' then return row.citizenid or '—' end
    return (tostring(charinfo.firstname or '') .. ' ' .. tostring(charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

QBCore.Functions.CreateCallback('mrp_service_mdt:server:canOpen', function(src, cb, service)
    service = tostring(service or '')
    if not serviceCfg(service) then return cb(false) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobMatchesService(P.PlayerData.job.name, service) then
        return cb(false)
    end
    if mdtCoreReady() then
        local perm = service == 'ems' and 'EMS_MDT_OPEN' or (service == 'mechanic' and 'MECH_MDT_OPEN' or nil)
        if perm then
            local ok, allowed = pcall(function()
                return exports['mrp_mdt_core']:HasPermission(src, perm) == true
            end)
            if ok then return cb(allowed == true) end
        end
    end
    cb(true)
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:mdtContext', function(src, cb, service)
    service = tostring(service or '')
    local cfg = serviceCfg(service)
    if not cfg then return cb(nil) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobMatchesService(P.PlayerData.job.name, service) then return cb(nil) end

    local ped = GetPlayerPed(src)
    local c = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)

    if mdtCoreReady() then
        pcall(function()
            exports['mrp_mdt_core']:BeginMdtSession(src, {
                service = service,
                citizenid = P.PlayerData.citizenid,
            })
        end)
    end

    cb({
        service = service,
        label = cfg.label,
        brand = cfg.brand,
        accent = cfg.accent,
        unitLabel = cfg.unitLabel or 'Vienetas',
        map = Config.MdtMap,
        presets = cfg.invoicePresets or {},
        selfSource = src,
        onDuty = P.PlayerData.job.onduty == true,
        canInvoice = canIssueInvoice(src, service),
        enableCrews = cfg.enableCrews ~= false,
        enableIncidents = canViewServiceIncidents(src, service),
        permissions = {
            incidents = canViewServiceIncidents(src, service),
        },
        playerPos = {
            x = c.x + 0.0,
            y = c.y + 0.0,
            z = c.z + 0.0,
            heading = (ped and ped ~= 0) and (GetEntityHeading(ped) + 0.0) or 0.0,
        },
        performance = mdtPerformancePayload(),
    })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:mdtSessionClose', function(src, cb, service)
    if mdtCoreReady() then
        pcall(function()
            exports['mrp_mdt_core']:EndMdtSession(src, { service = tostring(service or '') })
        end)
    end
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:mdtTelemetry', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local event = tostring(data.event or ''):sub(1, 64)
    if event == 'tab_switch' and data.tab and mdtCoreReady() then
        pcall(function()
            exports['mrp_mdt_core']:RecordTelemetry('tab_switch', {
                source = src,
                service = tostring(data.service or playerService(src, false) or ''):sub(1, 32),
                meta = { tab = tostring(data.tab):sub(1, 32) },
            })
        end)
    end
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:issueInvoice', function(src, cb, data)
    cb(IssueServiceInvoice(src, data))
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:searchInvoices', function(src, cb, data)
    local service = tostring(data and data.service or '')
    if not serviceCfg(service) then return cb({ ok = false, rows = {} }) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobMatchesService(P.PlayerData.job.name, service) then
        return cb({ ok = false, rows = {} })
    end

    local citizenid = tostring(data and data.citizenid or ''):sub(1, 64)
    if citizenid == '' then return cb({ ok = false, message = 'Nenurodytas citizenid.' }) end

    local rows = MySQL.query.await(
        'SELECT id, amount, reason_label, plate, created_at FROM fivempro_service_invoices WHERE service = ? AND citizenid = ? ORDER BY id DESC LIMIT 25',
        { service, citizenid }
    ) or {}

    local person = MySQL.single.await('SELECT citizenid, charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    cb({
        ok = true,
        citizenid = citizenid,
        name = personNameFromRow(person),
        rows = rows,
    })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:recentInvoices', function(src, cb, service)
    service = tostring(service or '')
    if not serviceCfg(service) then return cb({ ok = false, rows = {} }) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobMatchesService(P.PlayerData.job.name, service) then
        return cb({ ok = false, rows = {} })
    end

    local rows = MySQL.query.await(
        [[SELECT i.id, i.citizenid, i.amount, i.reason_label, i.plate, i.created_at,
                 p.charinfo AS charinfo
          FROM fivempro_service_invoices i
          LEFT JOIN players p ON p.citizenid = i.citizenid
          WHERE i.service = ?
          ORDER BY i.id DESC LIMIT 30]],
        { service }
    ) or {}

    for _, row in ipairs(rows) do
        row.name = personNameFromRow(row)
    end

    cb({ ok = true, rows = rows })
end)

exports('PlayerService', function(src)
    return playerService(src, false)
end)

exports('PlayerServiceOnDuty', function(src)
    return playerService(src, true)
end)
