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
    local cfg = serviceCfg(service)
    local minG = cfg and cfg.invoiceMinGrade or 0
    return (P.PlayerData.job.grade and P.PlayerData.job.grade.level or 0) >= minG
end

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
        playerPos = {
            x = c.x + 0.0,
            y = c.y + 0.0,
            z = c.z + 0.0,
            heading = (ped and ped ~= 0) and (GetEntityHeading(ped) + 0.0) or 0.0,
        },
    })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:issueInvoice', function(src, cb, data)
    local service = tostring(data and data.service or '')
    if not canIssueInvoice(src, service) then
        return cb({ ok = false, message = 'Nėra teisės išrašyti sąskaitos.' })
    end

    local tid = tostring(data and data.citizenid or ''):sub(1, 64)
    local amount = tonumber(data and data.amount) or 0
    local code = tostring(data and data.reason_code or ''):sub(1, 64)
    local label = tostring(data and data.reason_label or ''):sub(1, 255)
    local plate = tostring(data and data.plate or ''):sub(1, 16)
    if plate == '' then plate = nil end

    if tid == '' or amount < 1 or amount > (Config.MaxInvoiceAmount or 25000) or label == '' then
        return cb({ ok = false, message = 'Neteisingi duomenys.' })
    end

    local Issuer = QBCore.Functions.GetPlayer(src)
    if not Issuer then return cb({ ok = false, message = 'Klaida.' }) end

    local Target = QBCore.Functions.GetPlayerByCitizenId(tid)
    if Target then
        if not Target.Functions.RemoveMoney('bank', amount, ('service-invoice-%s'):format(service)) then
            if not Target.Functions.RemoveMoney('cash', amount, ('service-invoice-%s'):format(service)) then
                return cb({ ok = false, message = 'Klientas neturi pinigų (bankas/grynieji).' })
            end
        end
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source,
            ('Sąskaita %s €: %s'):format(amount, label), 'error')
    end

    MySQL.insert.await(
        'INSERT INTO fivempro_service_invoices (service, citizenid, issuer_citizenid, amount, reason_code, reason_label, plate) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { service, tid, Issuer.PlayerData.citizenid, amount, code, label, plate }
    )

    TriggerClientEvent('QBCore:Notify', src, 'Sąskaita išrašyta.', 'success')
    cb({ ok = true })
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
