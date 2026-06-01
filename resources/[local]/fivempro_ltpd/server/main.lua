local QBCore = exports['qb-core']:GetCoreObject()

local function ensureTables()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_profiles` (
        `citizenid` varchar(50) NOT NULL,
        `division` varchar(32) NOT NULL DEFAULT 'patrol',
        `badge` varchar(16) DEFAULT NULL,
        `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`citizenid`),
        KEY `division` (`division`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_fines` (
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

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_wanted` (
        `citizenid` varchar(50) NOT NULL,
        `level` tinyint(4) NOT NULL DEFAULT 0,
        `reason` varchar(512) DEFAULT NULL,
        `updated_by` varchar(50) DEFAULT NULL,
        `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_wanted_history` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `level` tinyint(4) NOT NULL,
        `officer_citizenid` varchar(50) DEFAULT NULL,
        `note` varchar(512) DEFAULT NULL,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_arrests` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `officer_citizenid` varchar(50) NOT NULL,
        `notes` text,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_fingerprints` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `officer_citizenid` varchar(50) NOT NULL,
        `subject_citizenid` varchar(50) NOT NULL,
        `subject_name` varchar(128) NOT NULL DEFAULT '',
        `fingerprint` varchar(64) NOT NULL,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        UNIQUE KEY `officer_subject` (`officer_citizenid`, `subject_citizenid`),
        KEY `officer` (`officer_citizenid`),
        KEY `fingerprint` (`fingerprint`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

local function decodeCharinfo(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function personDisplayName(charinfo)
    charinfo = charinfo or {}
    return ((charinfo.firstname or '') .. ' ' .. (charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
end

local function decodeMetadata(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function fingerprintFromRow(row)
    if not row then return nil end
    local meta = decodeMetadata(row.metadata)
    local fp = meta.fingerprint
    if fp and fp ~= '' then return tostring(fp) end
    return nil
end

local function parsePlayerInventory(raw)
    if not raw or raw == '' then return {} end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function itemBelongsToCitizen(info, citizenid)
    if not info or not info.citizenid or info.citizenid == '' then return true end
    return info.citizenid == citizenid
end

local function inventoryHasItem(inv, itemNames, citizenid)
    if type(inv) ~= 'table' then return false end
    local names = type(itemNames) == 'table' and itemNames or { itemNames }
    for _, item in pairs(inv) do
        if type(item) == 'table' and item.name then
            for _, want in ipairs(names) do
                if item.name == want and itemBelongsToCitizen(item.info, citizenid) then
                    return true
                end
            end
        end
    end
    return false
end

local function playerHasItem(Player, itemNames, citizenid)
    if not Player then return false end
    local names = type(itemNames) == 'table' and itemNames or { itemNames }
    for _, name in ipairs(names) do
        local items = Player.Functions.GetItemsByName(name)
        for _, it in pairs(items or {}) do
            if itemBelongsToCitizen(it.info, citizenid) then return true end
        end
    end
    return false
end

local function licenceCategoryActive(licences, cat)
    licences = licences or {}
    if licences[cat.key] == true then return true end
    if cat.altKeys then
        for _, k in ipairs(cat.altKeys) do
            if licences[k] == true then return true end
        end
    end
    return false
end

local function isLicenseExpiryValid(expiryStr)
    if not expiryStr or expiryStr == '' then return true end
    local y, m, d = tostring(expiryStr):match('^(%d%d%d%d)%-(%d%d)%-(%d%d)')
    if not y then return true end
    local exp = os.time({
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = 23,
        min = 59,
        sec = 59,
    })
    return os.time() <= exp
end

local function buildPersonLicenses(citizenid, meta, inv, onlinePlayer)
    meta = meta or {}
    local cfg = Config.MdtLicenses or {}
    local licences = meta.licences or {}
    local out = {}

    local hasId = meta.id_issued ~= nil or meta.idcard_issued ~= nil
    if onlinePlayer then
        hasId = hasId or playerHasItem(onlinePlayer, cfg.IdItem or 'id_card', citizenid)
    else
        hasId = hasId or inventoryHasItem(inv, cfg.IdItem or 'id_card', citizenid)
    end
    out[#out + 1] = { id = 'id', label = 'Tapatybės kortelė', active = hasId }

    local drivingLetters = {}
    for _, cat in ipairs(cfg.DrivingCategories or {}) do
        if licenceCategoryActive(licences, cat) then
            drivingLetters[#drivingLetters + 1] = cat.letter
        end
    end
    local hasDriving = #drivingLetters > 0
    if onlinePlayer then
        hasDriving = hasDriving or playerHasItem(onlinePlayer, cfg.DrivingItems, citizenid)
    else
        hasDriving = hasDriving or inventoryHasItem(inv, cfg.DrivingItems, citizenid)
    end
    local drivingDetail = #drivingLetters > 0 and ('Kategorijos: ' .. table.concat(drivingLetters, ', ')) or nil
    out[#out + 1] = {
        id = 'driving',
        label = 'Vairuotojo pažymėjimas',
        active = hasDriving,
        detail = drivingDetail,
        expiry = meta.driver_license_expiry,
    }

    local function outdoorsActive(expiryKey, issuedKey, itemName)
        local hasMeta = (meta[expiryKey] and meta[expiryKey] ~= '') or (meta[issuedKey] and meta[issuedKey] ~= '')
        if hasMeta and not isLicenseExpiryValid(meta[expiryKey]) then return false, meta[expiryKey] end
        if hasMeta then return true, meta[expiryKey] end
        if onlinePlayer then
            return playerHasItem(onlinePlayer, itemName, citizenid), nil
        end
        return inventoryHasItem(inv, itemName, citizenid), nil
    end

    local fishActive, fishExp = outdoorsActive('fishing_license_expiry', 'fishing_license_issued', cfg.FishingItem or 'fishing_license')
    out[#out + 1] = {
        id = 'fishing',
        label = 'Žvejybos licencija',
        active = fishActive,
        expiry = fishExp or meta.fishing_license_expiry,
    }

    local huntActive, huntExp = outdoorsActive('hunting_license_expiry', 'hunting_license_issued', cfg.HuntingItem or 'hunting_license')
    out[#out + 1] = {
        id = 'hunting',
        label = 'Medžioklės licencija',
        active = huntActive,
        expiry = huntExp or meta.hunting_license_expiry,
    }

    return out
end

local function migrateLtpdJobToPolice()
    local rows = MySQL.query.await("SELECT citizenid, job FROM players WHERE job LIKE '%\"name\":\"ltpd\"%'", {}) or {}
    local migrated = 0
    for _, row in ipairs(rows) do
        local ok, job = pcall(json.decode, row.job)
        if ok and job and job.name == 'ltpd' then
            job.name = 'police'
            if job.label == 'Lietuvos policija' or job.label == 'ltpd' then
                job.label = 'Lietuvos policija'
            end
            MySQL.update.await('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(job), row.citizenid })
            migrated = migrated + 1
        end
    end
    if migrated > 0 then
        print(('[^2fivempro_ltpd^7] Migrated %s player job records: ltpd → police'):format(migrated))
    end
end

MySQL.ready(function()
    ensureTables()
    migrateLtpdJobToPolice()
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local job = Player.PlayerData.job
    if job and job.name == 'ltpd' then
        Player.Functions.SetJob('police', tonumber(job.grade and job.grade.level) or 0)
    end
end)

local function getGrade(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return -1 end
    return tonumber(Player.PlayerData.job.grade.level) or 0
end

local function jobIsPd(j)
    return j and j.name == Config.JobName
end

local function isLtpdOnDuty(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local j = Player.PlayerData.job
    return jobIsPd(j) and j.onduty == true
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
        map = Config.MdtMap,
        division = getDivisionForCitizenid(P.PlayerData.citizenid),
        grade = getGrade(src),
        permissions = {
            fullSearch = mdtFullAccess(src),
            fine = hasPerm(src, 'mdt_fine'),
            wanted = hasPerm(src, 'mdt_wanted'),
            fingerprint = hasPerm(src, 'mdt_fingerprint'),
            arrest = hasPerm(src, 'mdt_arrest_record'),
            cctv = hasPerm(src, 'mdt_cctv'),
            bodycam = hasPerm(src, 'mdt_bodycam'),
        },
    })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:searchPerson', function(src, cb, query)
    if not hasPerm(src, 'mdt_search_basic') then return cb({ ok = false, message = 'Nėra teisės' }) end
    query = tostring(query or ''):gsub('%%', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if #query < 2 then return cb({ ok = true, rows = {} }) end

    local ok, err = pcall(function()
    local qLower = query:lower()
    local like = '%' .. qLower .. '%'
    local parts = {}
    for w in qLower:gmatch('%S+') do
        parts[#parts + 1] = w
    end

    local rows = {}
    local seen = {}

    local function addRows(list)
        for _, r in ipairs(list or {}) do
            if r.citizenid and not seen[r.citizenid] then
                seen[r.citizenid] = true
                rows[#rows + 1] = r
            end
        end
    end

    if #parts >= 2 then
        local p1, p2 = '%' .. parts[1] .. '%', '%' .. parts[2] .. '%'
        addRows(MySQL.query.await([[
            SELECT citizenid, charinfo, money, metadata, inventory
            FROM players
            WHERE (
                (LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))) LIKE ?
                 AND LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?)
                OR (LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))) LIKE ?
                    AND LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?)
            )
            OR LOWER(citizenid) LIKE ?
            LIMIT 25
        ]], { p1, p2, p2, p1, like }))
    end

    addRows(MySQL.query.await([[
        SELECT citizenid, charinfo, money, metadata, inventory
        FROM players
        WHERE LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname'))) LIKE ?
           OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))) LIKE ?
           OR LOWER(CONCAT(
                COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), ''),
                ' ',
                COALESCE(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname')), '')
           )) LIKE ?
           OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.phone'))) LIKE ?
           OR LOWER(charinfo) LIKE ?
           OR LOWER(citizenid) LIKE ?
           OR LOWER(JSON_UNQUOTE(JSON_EXTRACT(metadata, '$.fingerprint'))) LIKE ?
        LIMIT 30
    ]], { like, like, like, like, like, like, like }))

    if #rows == 0 then
        addRows(MySQL.query.await(
            'SELECT citizenid, charinfo, money, metadata, inventory FROM players WHERE LOWER(citizenid) = ? LIMIT 1',
            { qLower }
        ))
    end

    if #rows > 25 then
        local trimmed = {}
        for i = 1, 25 do trimmed[i] = rows[i] end
        rows = trimmed
    end

    local full = mdtFullAccess(src)
    for _, r in ipairs(rows) do
        local charinfo = decodeCharinfo(r.charinfo)
        r.name = personDisplayName(charinfo)
        r.citizenid = r.citizenid
        r.fingerprint = fingerprintFromRow(r)
        local onlineP = QBCore.Functions.GetPlayerByCitizenId(r.citizenid)
        r.online = onlineP ~= nil
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
        local meta = decodeMetadata(r.metadata)
        if onlineP then
            meta = onlineP.PlayerData.metadata or meta
        end
        local inv = onlineP and (onlineP.PlayerData.items or {}) or parsePlayerInventory(r.inventory)
        r.licenses = buildPersonLicenses(r.citizenid, meta, inv, onlineP)
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
        r.inventory = nil
    end

    cb({ ok = true, rows = rows, full = full })
    end)

    if not ok then
        print(('[fivempro_ltpd] searchPerson error: %s'):format(tostring(err)))
        cb({ ok = false, message = 'Paieškos klaida. Patikrink DB.' })
    end
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

    MySQL.insert.await(
        'INSERT INTO ltpd_fines (citizenid, officer_citizenid, amount, reason_code, reason_label) VALUES (?, ?, ?, ?, ?)',
        { tid, Officer.PlayerData.citizenid, amount, code, label }
    )

    TriggerClientEvent('QBCore:Notify', src, 'Bauda išrašyta', 'success')
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:collectFingerprint', function(src, cb, citizenid)
    if not hasPerm(src, 'mdt_fingerprint') then return cb({ ok = false, message = 'Nėra teisės.' }) end
    citizenid = tostring(citizenid or ''):sub(1, 50)
    if citizenid == '' then return cb({ ok = false, message = 'Nenurodytas citizenid.' }) end

    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return cb({ ok = false, message = 'Klaida.' }) end

    local row = MySQL.single.await('SELECT citizenid, charinfo, metadata FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then return cb({ ok = false, message = 'Asmuo nerastas DB.' }) end

    local fp = fingerprintFromRow(row)
    if not fp then return cb({ ok = false, message = 'Šiam asmeniui nėra pirštų atspaudų DB.' }) end

    local charinfo = decodeCharinfo(row.charinfo)
    local name = personDisplayName(charinfo)
    if name == '' then name = citizenid end

    MySQL.query.await([[
        INSERT INTO ltpd_fingerprints (officer_citizenid, subject_citizenid, subject_name, fingerprint)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE subject_name = VALUES(subject_name), fingerprint = VALUES(fingerprint), created_at = CURRENT_TIMESTAMP
    ]], { Officer.PlayerData.citizenid, citizenid, name, fp })

    cb({ ok = true, message = ('Atspaudai įrašyti: %s'):format(name), fingerprint = fp })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:getMyFingerprints', function(src, cb)
    if not isLtpdOnDuty(src) then return cb({ ok = false, message = 'Tik tarnybos metu.' }) end
    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return cb({ ok = false, rows = {} }) end

    local rows = MySQL.query.await([[
        SELECT subject_citizenid AS citizenid, subject_name AS name, fingerprint, created_at
        FROM ltpd_fingerprints
        WHERE officer_citizenid = ?
        ORDER BY created_at DESC
        LIMIT 50
    ]], { Officer.PlayerData.citizenid }) or {}

    cb({ ok = true, rows = rows })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:setWanted', function(src, cb, data)
    if not hasPerm(src, 'mdt_wanted') then return cb({ ok = false, message = 'Nėra teisės nustatyti paieškomumo.' }) end
    local tid = data and data.citizenid
    tid = tid and tostring(tid):match('^%s*(.-)%s*$') or ''
    local level = math.floor(tonumber(data and data.level) or 0)
    local reason = tostring(data and data.reason or ''):sub(1, 500)
    if tid == '' then return cb({ ok = false, message = 'Įvesk citizenid.' }) end
    if level < 0 or level > 5 then return cb({ ok = false, message = 'Lygis turi būti 0–5.' }) end

    local exists = MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ? LIMIT 1', { tid })
    if not exists then return cb({ ok = false, message = 'Citizenid nerastas.' }) end

    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer then return cb({ ok = false, message = 'Klaida.' }) end

    MySQL.query.await(
        [[INSERT INTO ltpd_wanted (citizenid, level, reason, updated_by)
          VALUES (?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE level = VALUES(level), reason = VALUES(reason), updated_by = VALUES(updated_by)]],
        { tid, level, reason, Officer.PlayerData.citizenid }
    )

    MySQL.insert.await(
        'INSERT INTO ltpd_wanted_history (citizenid, level, officer_citizenid, note) VALUES (?, ?, ?, ?)',
        { tid, level, Officer.PlayerData.citizenid, reason }
    )

    local T = QBCore.Functions.GetPlayerByCitizenId(tid)
    if T then
        TriggerClientEvent('QBCore:Notify', T.PlayerData.source, ('Paieškomumas: %s'):format(level), 'primary')
    end

    TriggerClientEvent('QBCore:Notify', src, ('Paieškomumas %s nustatytas (lygis %s).'):format(tid, level), 'success')
    cb({ ok = true, message = 'Paieškomumas išsaugotas.' })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:addArrestNote', function(src, cb, citizenid, notes, reason, sentence)
    if not hasPerm(src, 'mdt_arrest_record') then return cb({ ok = false }) end
    local Officer = QBCore.Functions.GetPlayer(src)
    if not Officer or not citizenid then return cb({ ok = false }) end
    citizenid = tostring(citizenid):sub(1, 50)
    local payload = {
        reason = tostring(reason or ''):sub(1, 256),
        sentence = tostring(sentence or ''):sub(1, 256),
        notes = tostring(notes or ''):sub(1, 1500),
        officer_name = ((Officer.PlayerData.charinfo.firstname or '') .. ' ' .. (Officer.PlayerData.charinfo.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
        at = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    MySQL.insert.await(
        'INSERT INTO ltpd_arrests (citizenid, officer_citizenid, notes) VALUES (?, ?, ?)',
        { citizenid, Officer.PlayerData.citizenid, json.encode(payload) }
    )
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('fivempro_ltpd:server:getArrestHistory', function(src, cb, citizenid)
    if not hasPerm(src, 'mdt_arrest_record') then return cb({ ok = false }) end
    citizenid = tostring(citizenid or ''):sub(1, 50)
    if citizenid == '' then return cb({ ok = true, rows = {} }) end
    local rows = MySQL.query.await([[
        SELECT a.id, a.citizenid, a.officer_citizenid, a.notes, a.created_at,
               p.charinfo AS officer_charinfo
        FROM ltpd_arrests a
        LEFT JOIN players p ON p.citizenid = a.officer_citizenid
        WHERE a.citizenid = ?
        ORDER BY a.id DESC
        LIMIT 50
    ]], { citizenid }) or {}
    for _, r in ipairs(rows) do
        local parsed = {}
        local ok, dec = pcall(json.decode, r.notes or '{}')
        if ok and type(dec) == 'table' then parsed = dec end
        r.reason = parsed.reason or ''
        r.sentence = parsed.sentence or ''
        r.detail_notes = parsed.notes or (not ok and tostring(r.notes or '') or '')
        r.officer_name = parsed.officer_name or ''
        if r.officer_name == '' and r.officer_charinfo then
            local ch = json.decode(r.officer_charinfo or '{}') or {}
            r.officer_name = ((ch.firstname or '') .. ' ' .. (ch.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        end
        r.officer_charinfo = nil
        r.notes = nil
    end
    cb({ ok = true, rows = rows })
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

local function getStationById(id)
    id = tostring(id or '')
    for _, st in ipairs(Config.Stations or {}) do
        if st.id == id then return st end
    end
    return nil
end

local function officerNearCoords(src, coordsVec3, maxDist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    return #(p - coordsVec3) <= maxDist
end

local function fleetModelAllowed(modelName)
    modelName = tostring(modelName or ''):lower()
    for _, v in ipairs(Config.FleetVehicles or {}) do
        if v.model and tostring(v.model):lower() == modelName then return true end
    end
    return false
end

RegisterNetEvent('fivempro_ltpd:server:openPoliceStash', function(stationId, stashIndex)
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    if Player(src).state.inv_busy then
        return TriggerClientEvent('QBCore:Notify', src, 'Uždaryk inventorių ir bandyk dar kartą.', 'error')
    end
    if not hasPerm(src, 'armory') then
        return TriggerClientEvent('QBCore:Notify', src, 'Prieinama tik policijai tarnyboje.', 'error')
    end
    stationId = tostring(stationId or '')
    stashIndex = tonumber(stashIndex)
    if not stashIndex or stashIndex < 1 then return end
    local st = getStationById(stationId)
    if not st or not st.stashes then return end
    local entry = st.stashes[stashIndex]
    if not entry or not entry.coords or not entry.stashId then return end
    if getGrade(src) < (tonumber(entry.minGrade) or 0) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per žemas rangas šiam sandėliui.', 'error')
    end
    local maxD = tonumber(Config.ArmoryGarageDistance) or 22.0
    if not officerNearCoords(src, entry.coords, maxD) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo sandėlio.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, entry.stashId, {
        maxweight = entry.maxweight or 2000000,
        slots = entry.slots or 60,
        label = entry.label or 'PD sandėlis',
    })
end)

RegisterNetEvent('fivempro_ltpd:server:openArmory', function(stationId)
    local src = source
    if GetResourceState('qb-inventory') ~= 'started' then
        return TriggerClientEvent('QBCore:Notify', src, 'qb-inventory neįjungtas.', 'error')
    end
    if Player(src).state.inv_busy then
        return TriggerClientEvent('QBCore:Notify', src, 'Uždaryk inventorių ir bandyk dar kartą.', 'error')
    end
    if not hasPerm(src, 'armory') then
        return TriggerClientEvent('QBCore:Notify', src, 'Prieinama tik policijai tarnyboje.', 'error')
    end
    stationId = tostring(stationId or '')
    local st = getStationById(stationId)
    if not st or not st.armory or not st.armory.coords or not st.armory.stashId then return end
    local maxD = tonumber(Config.ArmoryGarageDistance) or 22.0
    if not officerNearCoords(src, st.armory.coords, maxD) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo ginklinės (rūbinės). Priartėk arba patikrink koordinates.', 'error')
    end
    exports['qb-inventory']:OpenInventory(src, st.armory.stashId, {
        maxweight = st.armory.maxweight or 4000000,
        slots = st.armory.slots or 80,
        label = st.armory.label or 'Policijos ginklinė',
    })
end)

RegisterNetEvent('fivempro_ltpd:server:spawnFleet', function(stationId, modelName)
    local src = source
    if not hasPerm(src, 'garage') then return end
    stationId = tostring(stationId or '')
    modelName = tostring(modelName or ''):lower()
    if not fleetModelAllowed(modelName) then return end
    local st = getStationById(stationId)
    if not st or not st.garage or not st.garage.spawn then return end
    local sp = st.garage.spawn
    local checkVec = vector3(sp.x, sp.y, sp.z)
    local maxD = tonumber(Config.ArmoryGarageDistance) or 22.0
    if not officerNearCoords(src, checkVec, maxD + 6.0) then
        TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo PD transporto vietos.', 'error')
        return
    end
    local hash = joaat(modelName)
    local veh = QBCore.Functions.SpawnVehicle(src, hash, sp, true)
    if not veh or veh == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Nepavyko sukurti transporto.', 'error')
        return
    end
    local plateRaw = ('PD%s'):format(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plateRaw)
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(veh))
    if plate == nil or plate == '' then plate = plateRaw end
    SetVehicleEngineOn(veh, true, true, false)
    TriggerClientEvent('fivempro_ltpd:client:fleetVehicleReady', src, plate)
    TriggerClientEvent('QBCore:Notify', src, 'Transportas paruoštas.', 'success')
end)

local function fleetHeliModelAllowed(modelName)
    modelName = tostring(modelName or ''):lower()
    for _, v in ipairs(Config.FleetHelicopters or {}) do
        if v.model and tostring(v.model):lower() == modelName then return true end
    end
    return false
end

RegisterNetEvent('fivempro_ltpd:server:spawnFleetHeli', function(stationId, modelName)
    local src = source
    if not hasPerm(src, 'garage') then return end
    stationId = tostring(stationId or '')
    modelName = tostring(modelName or ''):lower()
    if not fleetHeliModelAllowed(modelName) then return end
    local st = getStationById(stationId)
    if not st or not st.heliGarage or not st.heliGarage.spawn then
        return TriggerClientEvent('QBCore:Notify', src, 'Helipadas nekonfigūruotas.', 'error')
    end
    local sp = st.heliGarage.spawn
    local checkVec = vector3(sp.x, sp.y, sp.z)
    local maxD = (tonumber(Config.ArmoryGarageDistance) or 22.0) + 10.0
    if not officerNearCoords(src, checkVec, maxD) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo helipado.', 'error')
    end
    local hash = joaat(modelName)
    local veh = QBCore.Functions.SpawnVehicle(src, hash, sp, true)
    if not veh or veh == 0 then
        veh = QBCore.Functions.CreateVehicle(src, hash, 'heli', sp, true)
    end
    if not veh or veh == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko sukurti sraigtasparnio.', 'error')
    end
    local plateRaw = ('PD%s'):format(math.random(1000, 9999))
    SetVehicleNumberPlateText(veh, plateRaw)
    local plate = QBCore.Shared.Trim(GetVehicleNumberPlateText(veh))
    if plate == nil or plate == '' then plate = plateRaw end
    SetVehicleEngineOn(veh, true, true, false)
    TriggerClientEvent('fivempro_ltpd:client:fleetVehicleReady', src, plate)
    TriggerClientEvent('QBCore:Notify', src, 'Sraigtasparnis paruoštas.', 'success')
end)

local function canBossAction(src)
    if not isLtpdOnDuty(src) then return false end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return false end
    if P.PlayerData.job.isboss then return true end
    return getGrade(src) >= (Config.Permissions.boss_menu or 7)
end

local function nearAnyManagement(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local c = GetEntityCoords(ped)
    local r = tonumber(Config.ManagementRadius) or 12.0
    for _, st in ipairs(Config.Stations or {}) do
        if st.management and st.management.coords then
            if #(c - st.management.coords) <= r then
                return true
            end
        end
    end
    return false
end

--- Vadovas gali keisti tik žemesnio rango pareigūnus (isboss – viską).
local function bossOutranks(bossSrc, targetGrade)
    local B = QBCore.Functions.GetPlayer(bossSrc)
    if not B then return false end
    if B.PlayerData.job.isboss then return true end
    local bg = getGrade(bossSrc)
    return bg > (tonumber(targetGrade) or 0)
end

RegisterNetEvent('fivempro_ltpd:server:bossHire', function(targetId, grade)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearAnyManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or targetId < 1 then return end
    if grade == nil or grade < 0 or grade > 10 then return end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti aukštesnio ar lygaus rango už save.', 'error')
    end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    T.Functions.SetJobDuty(true)
    TriggerClientEvent('QBCore:Notify', src, ('Įdarbinta (ID %s), rangas %s'):format(targetId, grade), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Priimta į policiją. Rangas: %s'):format(grade), 'success')
end)

RegisterNetEvent('fivempro_ltpd:server:bossFire', function(targetId)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearAnyManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    if not targetId or targetId < 1 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    if not jobIsPd(T.PlayerData.job) then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis žaidėjas ne PD.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali atleisti aukštesnio ar lygaus rango.', 'error')
    end
    T.Functions.SetJob('unemployed', 0)
    TriggerClientEvent('QBCore:Notify', src, ('Atleistas žaidėjas ID %s'):format(targetId), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, 'Atleistas iš policijos.', 'error')
end)

RegisterNetEvent('fivempro_ltpd:server:bossSetGrade', function(targetId, grade)
    local src = source
    if not canBossAction(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Vadovybė: neturi teisės arba ne tarnyboje.', 'error')
    end
    if not nearAnyManagement(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo vadovybės punkto.', 'error')
    end
    targetId = tonumber(targetId)
    grade = tonumber(grade)
    if not targetId or targetId < 1 then return end
    if grade == nil or grade < 0 or grade > 10 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas neprisijungęs.', 'error')
    end
    if not jobIsPd(T.PlayerData.job) then
        return TriggerClientEvent('QBCore:Notify', src, 'Žaidėjas ne PD.', 'error')
    end
    local tg = tonumber(T.PlayerData.job.grade.level) or 0
    if not bossOutranks(src, tg) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali keisti aukštesnio ar lygaus rango.', 'error')
    end
    if not bossOutranks(src, grade) then
        return TriggerClientEvent('QBCore:Notify', src, 'Negali skirti šio rango (per aukštas).', 'error')
    end
    T.Functions.SetJob(Config.JobName, grade)
    TriggerClientEvent('QBCore:Notify', src, ('Rangas pakeistas (ID %s → %s)'):format(targetId, grade), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Tavo naujas rangas: %s'):format(grade), 'primary')
end)

exports('IsLtpdOnDuty', function(src)
    return isLtpdOnDuty(src)
end)

exports('HasLtpdPermission', function(src, key)
    return hasPerm(src, key)
end)

--- PD sirenos įranga: entity statebags (networked vehicles)
local function normalizeEmergencyMode(mode)
    mode = tostring(mode or 'off'):gsub('^%s+', ''):gsub('%s+$', ''):lower()
    return mode
end

local function pedVehicleSeatIsDriver(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    if GetPedInVehicleSeat(veh, -1) ~= ped then return nil end
    return ped, veh
end

local function vehicleNearPlayer(src, veh, maxDist)
    local pd = GetPlayerPed(src)
    if not pd or pd == 0 or not veh or veh == 0 then return false end
    maxDist = tonumber(maxDist) or 28.0
    local p = GetEntityCoords(pd)
    local v = GetEntityCoords(veh)
    return #(p - v) <= maxDist
end

local function isEmergencyFleetModel(entity)
    if not entity or entity == 0 then return false end
    local hash = GetEntityModel(entity)
    if IsThisModelEmergencyVehicle(hash) then return true end
    local classId = GetVehicleClass(entity)
    if classId == 18 then return true end --- Emergency
    if Config.FleetVehicles then
        for _, v in ipairs(Config.FleetVehicles) do
            if v and v.model and joaat(v.model) == hash then
                return true
            end
        end
    end
    if Config.FleetHelicopters then
        for _, v in ipairs(Config.FleetHelicopters) do
            if v and v.model and joaat(v.model) == hash then
                return true
            end
        end
    end
    return false
end

local LtPdEmergencyModes = { off = true, lights = true, sound = true, full = true }

RegisterNetEvent('fivempro_ltpd:server:setPdEmergencyMode', function(mode)
    local src = source
    if not hasPerm(src, 'pd_siren_controller') then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės sirenos meniu.', 'error')
    end
    mode = normalizeEmergencyMode(type(mode) == 'string' and mode or 'off')
    if not LtPdEmergencyModes[mode] then mode = 'off' end
    local     _, veh = pedVehicleSeatIsDriver(src)
    if not veh then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti vairuotoju transporte.', 'error')
    end
    if NetworkGetNetworkIdFromEntity(veh) == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Mašina turi būti tinkamai sinchronizuota (išimk iš garažo / naujas spawn).', 'error')
    end
    if not vehicleNearPlayer(src, veh, Config.EmergencyVehicle and Config.EmergencyVehicle.validateDistance) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo transporto.', 'error')
    end
    if mode ~= 'off' and not isEmergencyFleetModel(veh) then
        if Entity(veh).state.ltPdKit ~= true then
            return TriggerClientEvent(
                'QBCore:Notify',
                src,
                'Ant civilinės TP pirmiausiai uždėk laikinas sirenas („/pdiranga“ įmontuoti).',
                'error'
            )
        end
    end
    Entity(veh).state:set('ltPdSirenMode', mode, true)
    TriggerClientEvent('QBCore:Notify', src, ('Šviesos / sirena: %s'):format(mode), 'primary')
end)

RegisterNetEvent('fivempro_ltpd:server:setPdEmergencyKit', function(equip)
    local src = source
    if not hasPerm(src, 'pd_emergency_kit') then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės laikinai montuoti įrangą.', 'error')
    end
    local _, veh = pedVehicleSeatIsDriver(src)
    if not veh then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti vairuotoju transporte.', 'error')
    end
    if not vehicleNearPlayer(src, veh, Config.EmergencyVehicle and Config.EmergencyVehicle.validateDistance) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo transporto.', 'error')
    end
    if NetworkGetNetworkIdFromEntity(veh) == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Mašina turi būti tinkamai sinchronizuota (išimk iš garažo / naujas spawn).', 'error')
    end
    if isEmergencyFleetModel(veh) then
        return TriggerClientEvent('QBCore:Notify', src, 'Ši mašina jau turi tarnybinę įrangą (ne civilinė).', 'error')
    end
    equip = equip == true
    Entity(veh).state:set('ltPdKit', equip, true)
    if equip then
        TriggerClientEvent('QBCore:Notify', src, 'Įdėtos laikinos sirenos ir žibintai ant šio TP – nuimi per tą patį meniu.', 'success')
    else
        Entity(veh).state:set('ltPdSirenMode', 'off', true)
        TriggerClientEvent('QBCore:Notify', src, 'Laikina įranga nuimta.', 'primary')
    end
end)

RegisterNetEvent('fivempro_ltpd:server:clearPdEmergencyOnExit', function(netId)
    local src = source
    netId = tonumber(netId)
    if not netId then return end
    if not isLtpdOnDuty(src) then return end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 then return end
    if not vehicleNearPlayer(src, veh, (Config.EmergencyVehicle and Config.EmergencyVehicle.validateDistance or 28.0) + 10.0) then
        return
    end
    Entity(veh).state:set('ltPdSirenMode', 'off', true)
end)

--- PD durų / vartų būsenos (sinchronas visiems klientams)
local LtpdPdDoorLocked = {}
local LtpdPdDoorMeta = {}

local function vecInBoundsPdDoor(v, minV, maxV)
    return v.x >= minV.x and v.x <= maxV.x and v.y >= minV.y and v.y <= maxV.y and v.z >= minV.z and v.z <= maxV.z
end

local function dynDoorCfgForStation(stationId)
    for _, d in ipairs(Config.PdDoorDynamics or {}) do
        if d.stationId == stationId then return d end
    end
    for _, d in ipairs(Config.EmsDoorDynamics or {}) do
        if d.stationId == stationId then return d end
    end
    for _, d in ipairs(Config.RangerDoorDynamics or {}) do
        if d.stationId == stationId then return d end
    end
end

local function doorGroupService(groupId)
    if type(groupId) ~= 'string' then return 'police' end
    if groupId:sub(1, 8) == 'dyn_ems_' then return 'ems' end
    if groupId:sub(1, 11) == 'dyn_ranger_' then return 'ranger' end
    for _, g in ipairs(Config.EmsDoorGroups or {}) do
        if g.id == groupId then return 'ems' end
    end
    for _, g in ipairs(Config.RangerDoorGroups or {}) do
        if g.id == groupId then return 'ranger' end
    end
    return 'police'
end

local function canUseServiceDoors(src, groupId)
    local svc = doorGroupService(groupId)
    if svc == 'ems' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        local j = Player.PlayerData.job
        if not j or j.onduty ~= true then return false end
        return j.name == (Config.EmsDoorJob or 'ambulance')
    end
    if svc == 'ranger' then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player then return false end
        local j = Player.PlayerData.job
        if not j or j.onduty ~= true then return false end
        return j.name == (Config.RangerDoorJob or 'ranger')
    end
    return hasPerm(src, 'pd_doors')
end

local function dynDoorModelWhitelist(dyn)
    local t = {}
    for _, n in ipairs(dyn.models or {}) do
        t[joaat(n)] = true
    end
    return t
end

local function pdDoorInteractAnchorsByGroup()
    local m = {}
    for _, row in ipairs(Config.PdDoorInteractExtras or {}) do
        local gid = row.groupId
        local c = row.interact
        if gid and c then
            m[gid] = m[gid] or {}
            local t = m[gid]
            t[#t + 1] = { coords = c, interactDist = row.interactDist or 2.5 }
        end
    end
    return m
end

local function initManualPdDoors()
    local anchors = pdDoorInteractAnchorsByGroup()
    local function registerGroupList(list)
        for _, g in ipairs(list or {}) do
            local slabs = {}
            for _, d in ipairs(g.doors or {}) do
                slabs[#slabs + 1] = d.coords
            end
            local interact = g.interact
            if not interact and #slabs > 0 then
                interact = vector3(0.0, 0.0, 0.0)
                for _, c in ipairs(slabs) do
                    interact = interact + c
                end
                interact = interact / #slabs
            end
            LtpdPdDoorMeta[g.id] = {
                slabs = slabs,
                interact = interact,
                interactDist = g.interactDist or 2.5,
                interactAnchors = anchors[g.id] or {},
            }
            if LtpdPdDoorLocked[g.id] == nil then
                LtpdPdDoorLocked[g.id] = g.defaultLocked ~= false
            end
        end
    end
    registerGroupList(Config.PdDoorGroups)
    registerGroupList(Config.EmsDoorGroups)
    registerGroupList(Config.RangerDoorGroups)
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    initManualPdDoors()
end)

RegisterNetEvent('fivempro_ltpd:server:requestPdDoorsSync', function()
    TriggerClientEvent('fivempro_ltpd:client:syncPdDoors', source, LtpdPdDoorLocked)
end)

local LtpdPdDoorRegCount = {}

RegisterNetEvent('fivempro_ltpd:server:registerPdDynDoorGroup', function(groupId, stationId, cx, cy, cz, interactDist, regSlabs)
    local src = source
    LtpdPdDoorRegCount[src] = (LtpdPdDoorRegCount[src] or 0) + 1
    if LtpdPdDoorRegCount[src] > 160 then return end
    if type(groupId) ~= 'string' or type(stationId) ~= 'string' or type(regSlabs) ~= 'table' then return end
    if groupId:sub(1, 4) ~= 'dyn_' then return end
    if #regSlabs < 1 or #regSlabs > 4 then return end
    local dyn = dynDoorCfgForStation(stationId)
    if not dyn then return end
    local whitelist = dynDoorModelWhitelist(dyn)
    local slabs = {}
    for _, s in ipairs(regSlabs) do
        local mh = tonumber(s.model)
        if not mh or not whitelist[mh] then return end
        local x, y, z = tonumber(s.x), tonumber(s.y), tonumber(s.z)
        if not x or not y or not z then return end
        local c = vector3(x, y, z)
        if not vecInBoundsPdDoor(c, dyn.bounds.min, dyn.bounds.max) then return end
        slabs[#slabs + 1] = c
    end
    if LtpdPdDoorMeta[groupId] then return end
    LtpdPdDoorMeta[groupId] = {
        slabs = slabs,
        interact = vector3(tonumber(cx) or 0.0, tonumber(cy) or 0.0, tonumber(cz) or 0.0),
        interactDist = tonumber(interactDist) or 2.5,
        interactAnchors = {},
    }
    if LtpdPdDoorLocked[groupId] == nil then
        LtpdPdDoorLocked[groupId] = true
    end
end)

local LtpdPdDoorToggleCooldown = {}

AddEventHandler('playerDropped', function()
    local src = source
    LtpdPdDoorRegCount[src] = nil
    LtpdPdDoorToggleCooldown[src] = nil
end)

RegisterNetEvent('fivempro_ltpd:server:togglePdDoorGroup', function(groupId)
    local src = source
    if type(groupId) ~= 'string' then return end
    if not canUseServiceDoors(src, groupId) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės arba ne tarnyboje.', 'error')
    end
    local meta = LtpdPdDoorMeta[groupId]
    if not meta then return end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pc = GetEntityCoords(ped)
    local reach = (Config.PdDoorToggleReach or 4.2) + 0.05
    local ok = false
    for _, c in ipairs(meta.slabs) do
        if #(pc - c) <= reach then
            ok = true
            break
        end
    end
    if not ok and meta.interact then
        if #(pc - meta.interact) <= (meta.interactDist or 2.5) + 1.45 then
            ok = true
        end
    end
    if not ok and type(meta.interactAnchors) == 'table' then
        for _, anch in ipairs(meta.interactAnchors) do
            local ac = anch.coords
            if ac and #(pc - ac) <= (anch.interactDist or 2.5) + 1.45 then
                ok = true
                break
            end
        end
    end
    if not ok then
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo durų.', 'error')
    end
    local now = GetGameTimer()
    if (LtpdPdDoorToggleCooldown[src] or 0) > now then return end
    LtpdPdDoorToggleCooldown[src] = now + 650
    local cur = LtpdPdDoorLocked[groupId] ~= false
    LtpdPdDoorLocked[groupId] = not cur
    TriggerClientEvent('fivempro_ltpd:client:setPdDoorState', -1, groupId, LtpdPdDoorLocked[groupId])
    TriggerClientEvent(
        'QBCore:Notify',
        src,
        LtpdPdDoorLocked[groupId] and 'Durys užrakintos.' or 'Durys atrakintos.',
        'primary'
    )
end)
