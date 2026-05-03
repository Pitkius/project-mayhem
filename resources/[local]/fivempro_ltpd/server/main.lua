local QBCore = exports['qb-core']:GetCoreObject()

local function ensureTables()
    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_profiles` (
        `citizenid` varchar(50) NOT NULL,
        `division` varchar(32) NOT NULL DEFAULT 'patrol',
        `badge` varchar(16) DEFAULT NULL,
        `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`citizenid`),
        KEY `division` (`division`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_fines` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `officer_citizenid` varchar(50) NOT NULL,
        `amount` int(11) NOT NULL,
        `reason_code` varchar(64) DEFAULT NULL,
        `reason_label` varchar(255) DEFAULT NULL,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `officer` (`officer_citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_wanted` (
        `citizenid` varchar(50) NOT NULL,
        `level` tinyint(4) NOT NULL DEFAULT 0,
        `reason` varchar(512) DEFAULT NULL,
        `updated_by` varchar(50) DEFAULT NULL,
        `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_wanted_history` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `level` tinyint(4) NOT NULL,
        `officer_citizenid` varchar(50) DEFAULT NULL,
        `note` varchar(512) DEFAULT NULL,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS `ltpd_arrests` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `officer_citizenid` varchar(50) NOT NULL,
        `notes` text,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

MySQL.ready(function()
    ensureTables()
end)

local function getGrade(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return -1 end
    return tonumber(Player.PlayerData.job.grade.level) or 0
end

local function isLtpdOnDuty(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local j = Player.PlayerData.job
    return j and j.name == Config.JobName and j.onduty == true
end

local function hasPerm(src, key)
    if not isLtpdOnDuty(src) then return false end
    local need = Config.Permissions[key]
    if need == nil then return false end
    return getGrade(src) >= need
end

--- @param targetSrc number|nil
local function validTarget(officerSrc, targetSrc, maxDist)
    if not targetSrc or targetSrc < 1 then return false end
    local oPed = GetPlayerPed(officerSrc)
    local tPed = GetPlayerPed(targetSrc)
    if not oPed or not tPed or oPed == 0 or tPed == 0 then return false end
    local oc = GetEntityCoords(oPed)
    local tc = GetEntityCoords(tPed)
    return #(oc - tc) <= (maxDist or 3.5)
end

local function getDivisionForCitizenid(citizenid)
    local row = MySQL.single.await('SELECT division FROM ltpd_profiles WHERE citizenid = ?', { citizenid })
    if row and row.division then return row.division end
    return 'patrol'
end

-- Išplėstinė MDT informacija (transportas, baudų istorija, pinigai)
local function mdtFullAccess(src)
    if not hasPerm(src, 'mdt_search_full') then return false end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local g = getGrade(src)
    local div = getDivisionForCitizenid(Player.PlayerData.citizenid)
    if div == 'aras' and g < 5 then
        return false
    end
    local divCfg = Config.Divisions[div]
    if divCfg and g < (divCfg.minGrade or 0) then
        return false
    end
    return true
end

RegisterNetEvent('fivempro_ltpd:server:setDivision', function(targetCitizenid, newDiv)
    local src = source
    if not hasPerm(src, 'division_admin') then return end
    if not Config.Divisions[newDiv] then return end
    MySQL.query.await(
        'INSERT INTO ltpd_profiles (citizenid, division) VALUES (?, ?) ON DUPLICATE KEY UPDATE division = VALUES(division)',
        { targetCitizenid, newDiv }
    )
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:canOpenMdt', function(src, cb)
    cb(hasPerm(src, 'mdt_open'))
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:mdtContext', function(src, cb)
    if not hasPerm(src, 'mdt_open') then return cb(nil) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb(nil) end
    MySQL.query.await('INSERT IGNORE INTO ltpd_profiles (citizenid, division) VALUES (?, ?)', {
        P.PlayerData.citizenid,
        'patrol',
    })
    cb({
        presets = Config.FinePresets,
        division = getDivisionForCitizenid(P.PlayerData.citizenid),
        grade = getGrade(src),
        permissions = {
            fullSearch = mdtFullAccess(src),
            fine = hasPerm(src, 'mdt_fine'),
            wanted = hasPerm(src, 'mdt_wanted'),
            arrest = hasPerm(src, 'mdt_arrest_record'),
        },
    })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:searchPerson', function(src, cb, query)
    if not hasPerm(src, 'mdt_search_basic') then return cb({ ok = false }) end
    query = tostring(query or ''):gsub('%%', ''):sub(1, 64)
    if #query < 2 then return cb({ ok = true, rows = {} }) end

    local like = '%' .. query:lower() .. '%'
    local rows = MySQL.query.await([[
        SELECT citizenid, charinfo, money, metadata
        FROM players
        WHERE LOWER(charinfo) LIKE ?
        OR LOWER(citizenid) LIKE ?
        LIMIT 25
    ]], { like, like }) or {}

    local full = mdtFullAccess(src)
    for _, r in ipairs(rows) do
        local charinfo = json.decode(r.charinfo or '{}') or {}
        r.name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
        r.citizenid = r.citizenid
        local onlineP = QBCore.Functions.GetPlayerByCitizenId(r.citizenid)
        r.player_id = onlineP and onlineP.PlayerData.source or nil
        local money = json.decode(r.money or '{}') or {}
        if full then
            r.cash = tonumber(money.cash) or 0
            r.bank = tonumber(money.bank) or 0
        else
            r.cash = nil
            r.bank = nil
        end
        local wanted = MySQL.single.await('SELECT level, reason FROM ltpd_wanted WHERE citizenid = ?', { r.citizenid })
        r.wanted_level = wanted and tonumber(wanted.level) or 0
        r.wanted_reason = wanted and wanted.reason or ''
        if full then
            local veh = MySQL.query.await(
                'SELECT plate, vehicle, state FROM player_vehicles WHERE citizenid = ? LIMIT 15',
                { r.citizenid }
            ) or {}
            r.vehicles = veh
            local fines = MySQL.query.await(
                'SELECT amount, reason_label, created_at FROM ltpd_fines WHERE citizenid = ? ORDER BY id DESC LIMIT 10',
                { r.citizenid }
            ) or {}
            r.fines = fines
        else
            r.vehicles = nil
            r.fines = nil
        end
        r.charinfo = nil
        r.money = nil
        r.metadata = nil
    end

    cb({ ok = true, rows = rows, full = full })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:searchVehicle', function(src, cb, plate)
    if not hasPerm(src, 'mdt_search_basic') then return cb({ ok = false }) end
    plate = tostring(plate or ''):upper():gsub('%s+', ''):sub(1, 16)
    if #plate < 2 then return cb({ ok = true, row = nil }) end

    local row = MySQL.single.await([[
        SELECT pv.plate, pv.vehicle, pv.citizenid, pv.state,
               p.charinfo
        FROM player_vehicles pv
        LEFT JOIN players p ON p.citizenid = pv.citizenid
        WHERE pv.plate = ?
        LIMIT 1
    ]], { plate })

    if not row then return cb({ ok = true, row = nil }) end

    local charinfo = json.decode(row.charinfo or '{}') or {}
    row.owner_name = (charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')
    row.charinfo = nil
    row.status = tonumber(row.state) == 0 and 'lauke' or 'garaže / saugoma'
    cb({ ok = true, row = row })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:issueFine', function(src, cb, data)
    if not hasPerm(src, 'mdt_fine') then return cb({ ok = false, message = 'Nėra teisės' }) end
    local tid = data and data.citizenid
    local amount = tonumber(data and data.amount) or 0
    local code = tostring(data and data.reason_code or ''):sub(1, 64)
    local label = tostring(data and data.reason_label or ''):sub(1, 255)
    if not tid or amount < 1 or amount > Config.MaxFineAmount then return cb({ ok = false }) end

    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return cb({ ok = false }) end

    local Target = QBCore.Functions.GetPlayerByCitizenId(tid)
    if Target then
        if not Target.Functions.RemoveMoney('bank', amount, 'ltpd-fine') then
            if not Target.Functions.RemoveMoney('cash', amount, 'ltpd-fine') then
                return cb({ ok = false, message = 'Žaidėjas neturi pinigų (bankas/grynieji)' })
            end
        end
        TriggerClientEvent('QBCore:Notify', Target.PlayerData.source, ('Bauda %s €: %s'):format(amount, label), 'error')
    end

    MySQL.insert(
        'INSERT INTO ltpd_fines (citizenid, officer_citizenid, amount, reason_code, reason_label) VALUES (?, ?, ?, ?, ?)',
        { tid, Officer.PlayerData.citizenid, amount, code, label }
    )

    TriggerClientEvent('QBCore:Notify', src, 'Bauda išrašyta', 'success')
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:setWanted', function(src, cb, data)
    if not hasPerm(src, 'mdt_wanted') then return cb({ ok = false }) end
    local tid = data and data.citizenid
    local level = math.floor(tonumber(data and data.level) or 0)
    local reason = tostring(data and data.reason or ''):sub(1, 500)
    if not tid or level < 0 or level > 5 then return cb({ ok = false }) end

    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return cb({ ok = false }) end

    MySQL.query.await(
        [[INSERT INTO ltpd_wanted (citizenid, level, reason, updated_by)
          VALUES (?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE level = VALUES(level), reason = VALUES(reason), updated_by = VALUES(updated_by)]],
        { tid, level, reason, Officer.PlayerData.citizenid }
    )

    MySQL.insert(
        'INSERT INTO ltpd_wanted_history (citizenid, level, officer_citizenid, note) VALUES (?, ?, ?, ?)',
        { tid, level, Officer.PlayerData.citizenid, reason }
    )

    local T = QBCore.Functions.GetPlayerByCitizenId(tid)
    if T then
        TriggerClientEvent('QBCore:Notify', T.PlayerData.source, ('Paieškomumas: %s'):format(level), 'primary')
    end

    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:addArrestNote', function(src, cb, citizenid, notes)
    if not hasPerm(src, 'mdt_arrest_record') then return cb({ ok = false }) end
    notes = tostring(notes or ''):sub(1, 2000)
    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer or not citizenid then return cb({ ok = false }) end
    MySQL.insert(
        'INSERT INTO ltpd_arrests (citizenid, officer_citizenid, notes) VALUES (?, ?, ?)',
        { citizenid, Officer.PlayerData.citizenid, notes }
    )
    cb({ ok = true })
end)

RegisterNetEvent('fivempro_ltpd:server:cuffPlayer', function(targetId)
    local src = source
    if not hasPerm(src, 'cuff') then return end
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId, 3.5) then return end

    local tPlayer = QBCore.Functions.GetPlayer(targetId)
    if not tPlayer then return end

    local cuffed = Player(targetId).state.ltpdCuffed
    Player(targetId).state:set('ltpdCuffed', not cuffed, true)
    TriggerClientEvent('fivempro_ltpd:client:cuffedState', targetId, not cuffed)
    TriggerClientEvent('QBCore:Notify', src, cuffed and 'Antrankiai nuimti' or 'Uždėti antrankiai', 'primary')
end)

RegisterNetEvent('fivempro_ltpd:server:trySearchInventory', function(targetId)
    local src = source
    if not hasPerm(src, 'search_inventory') then return end
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId, 3.0) then return end
    if GetResourceState('qb-inventory') ~= 'started' then return end
    exports['qb-inventory']:OpenInventoryById(src, targetId)
end)

exports('IsLtpdOnDuty', function(src)
    return isLtpdOnDuty(src)
end)

exports('HasLtpdPermission', function(src, key)
    return hasPerm(src, key)
end)
