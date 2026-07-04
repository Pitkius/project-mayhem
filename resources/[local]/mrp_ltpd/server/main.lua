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

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_interrogations` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `officer_citizenid` varchar(50) NOT NULL,
        `mode` varchar(16) NOT NULL DEFAULT 'police',
        `room_id` varchar(64) DEFAULT NULL,
        `result` varchar(64) DEFAULT NULL,
        `recorded` tinyint(1) NOT NULL DEFAULT 0,
        `pressure_max` tinyint(3) NOT NULL DEFAULT 0,
        `payload` longtext,
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `officer` (`officer_citizenid`)
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
    local first = charinfo.firstname or charinfo.firstName or ''
    local last = charinfo.lastname or charinfo.lastName or ''
    return (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
end

local LT_FOLD = {
    ['ą'] = 'a', ['č'] = 'c', ['ę'] = 'e', ['ė'] = 'e', ['į'] = 'i',
    ['š'] = 's', ['ų'] = 'u', ['ū'] = 'u', ['ž'] = 'z',
}

local function foldSearchText(s)
    s = tostring(s or ''):lower()
    for from, to in pairs(LT_FOLD) do
        s = s:gsub(from, to)
    end
    return s
end

local function splitSearchWords(query)
    local q = foldSearchText(query):gsub('%%', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    local parts = {}
    for w in q:gmatch('%S+') do
        parts[#parts + 1] = w
    end
    return q, parts
end

local function charinfoSearchFields(charinfo)
    charinfo = charinfo or {}
    local fn = foldSearchText(charinfo.firstname or charinfo.firstName or '')
    local ln = foldSearchText(charinfo.lastname or charinfo.lastName or '')
    local full = (fn .. ' ' .. ln):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    return fn, ln, full
end

local function personMatchesSearch(charinfo, parts, qFold)
    local fn, ln, full = charinfoSearchFields(charinfo)
    local phone = foldSearchText(charinfo.phone or '')
    if qFold ~= '' and full:find(qFold, 1, true) then return true end
    if phone ~= '' and qFold ~= '' and phone:find(qFold, 1, true) then return true end
    if #parts >= 2 then
        local a, b = parts[1], parts[2]
        if fn:find(a, 1, true) and ln:find(b, 1, true) then return true end
        if fn:find(b, 1, true) and ln:find(a, 1, true) then return true end
        if full:find(a .. ' ' .. b, 1, true) then return true end
        if full:find(b .. ' ' .. a, 1, true) then return true end
        return false
    end
    if #parts == 1 then
        local w = parts[1]
        return fn:find(w, 1, true) or ln:find(w, 1, true) or full:find(w, 1, true)
    end
    return false
end

local function searchPersonDbRows(query)
    local qFold, parts = splitSearchWords(query)
    if #qFold < 2 then return {} end

    local seen = {}
    local candidates = {}

    local function addList(list)
        for _, r in ipairs(list or {}) do
            if r.citizenid and not seen[r.citizenid] then
                seen[r.citizenid] = true
                candidates[#candidates + 1] = r
            end
        end
    end

    local likeCid = '%' .. qFold .. '%'
    addList(MySQL.query.await([[
        SELECT citizenid, charinfo, money, metadata
        FROM players
        WHERE LOWER(citizenid) LIKE ?
        LIMIT 25
    ]], { likeCid }))

    if #parts >= 2 then
        local jsonPattern = '%' .. table.concat(parts, '%') .. '%'
        addList(MySQL.query.await([[
            SELECT citizenid, charinfo, money, metadata
            FROM players
            WHERE LOWER(charinfo) LIKE ?
            LIMIT 40
        ]], { jsonPattern }))
    end

    for _, w in ipairs(parts) do
        local like = '%' .. w .. '%'
        addList(MySQL.query.await([[
            SELECT citizenid, charinfo, money, metadata
            FROM players
            WHERE LOWER(charinfo) LIKE ?
               OR LOWER(citizenid) LIKE ?
            LIMIT 40
        ]], { like, like }))
    end

    local metaLike = '%' .. qFold .. '%'
    addList(MySQL.query.await([[
        SELECT citizenid, charinfo, money, metadata
        FROM players
        WHERE LOWER(metadata) LIKE ?
        LIMIT 15
    ]], { metaLike }))

    local rows = {}
    for _, r in ipairs(candidates) do
        local charinfo = decodeCharinfo(r.charinfo)
        local matched = personMatchesSearch(charinfo, parts, qFold)
        if not matched and qFold ~= '' then
            local meta = decodeMetadata(r.metadata)
            local fp = foldSearchText(meta.fingerprint or '')
            if fp ~= '' and fp:find(qFold, 1, true) then
                matched = true
            end
        end
        if matched then
            rows[#rows + 1] = r
        end
        if #rows >= 25 then break end
    end

    return rows
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

local function fetchPlayerInventory(citizenid, onlineP)
    if onlineP then return onlineP.PlayerData.items or {} end
    local ok, raw = pcall(function()
        return MySQL.scalar.await('SELECT inventory FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    end)
    if ok and raw then return parsePlayerInventory(raw) end
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

    local weaponActive, weaponExp = outdoorsActive('weapon_license_expiry', 'weapon_license_issued', cfg.WeaponItem or 'weaponlicense')
    if not weaponActive and (meta.licences or {}).weapon == true and isLicenseExpiryValid(meta.weapon_license_expiry) then
        weaponActive = true
        weaponExp = meta.weapon_license_expiry
    end
    out[#out + 1] = {
        id = 'weapon',
        label = 'Ginklo licencija',
        active = weaponActive,
        expiry = weaponExp or meta.weapon_license_expiry,
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
        print(('[^2mrp_ltpd^7] Migrated %s player job records: ltpd → police'):format(migrated))
    end
end

MySQL.ready(function()
    ensureTables()
    migrateLtpdJobToPolice()
    MySQL.update.await("UPDATE ltpd_profiles SET division = 'sor' WHERE division IN ('aro', 'aras', 'ARAS')")
    MySQL.update.await("UPDATE ltpd_profiles SET division = 'mp' WHERE division = 'patrol'")
    MySQL.update.await("UPDATE ltpd_profiles SET division = 'kpd' WHERE division = 'traffic'")
    MySQL.update.await("UPDATE ltpd_profiles SET division = 'ktd' WHERE division = 'criminal'")
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
    if GetResourceState('mrp_bossmenu') == 'started' then
        local override = exports['mrp_bossmenu']:GetGradePermissionMin('police', getGrade(src), key)
        if override ~= nil then
            return getGrade(src) >= override
        end
    end
    return getGrade(src) >= need
end

local function isAdmin(src)
    return QBCore.Functions.HasPermission(src, 'admin') or QBCore.Functions.HasPermission(src, 'god')
end

QBCore.Functions.CreateCallback('mrp_ltpd:server:isAdmin', function(src, cb)
    cb(isAdmin(src))
end)

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
    return PdDivisions.normalize(row and row.division or 'mp')
end

local function setDivisionForCitizenid(citizenid, division)
    division = PdDivisions.normalize(division)
    if not Config.Divisions[division] then return false end
    MySQL.query.await(
        'INSERT INTO ltpd_profiles (citizenid, division) VALUES (?, ?) ON DUPLICATE KEY UPDATE division = VALUES(division)',
        { citizenid, division }
    )
    return true
end

local function defaultDivisionForGrade(grade)
    grade = tonumber(grade) or 0
    local lpmMax = tonumber((Config.DivisionRules or {}).lpmMaxGrade) or 3
    if grade <= lpmMax then
        return 'lpm'
    end
    return 'mp'
end

local function enforceDivisionForPlayer(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobIsPd(P.PlayerData.job) then return end
    local grade = getGrade(src)
    local cid = P.PlayerData.citizenid
    local stored = getDivisionForCitizenid(cid)
    local want = defaultDivisionForGrade(grade)
    if grade <= ((Config.DivisionRules or {}).lpmMaxGrade or 3) then
        if stored ~= 'lpm' then
            setDivisionForCitizenid(cid, 'lpm')
        end
        return 'lpm'
    end
    if stored == 'lpm' then
        setDivisionForCitizenid(cid, 'mp')
        stored = 'mp'
    end
    return stored
end

local function syncDivisionClient(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobIsPd(P.PlayerData.job) then return end
    local grade = getGrade(src)
    local div = enforceDivisionForPlayer(src)
    TriggerClientEvent('mrp_ltpd:client:syncDivision', src, {
        division = div,
        storedDivision = getDivisionForCitizenid(P.PlayerData.citizenid),
        grade = grade,
        effective = PdDivisions.effectiveDivision(grade, div),
    })
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    local job = Player.PlayerData.job
    if job and job.name == 'ltpd' then
        Player.Functions.SetJob('police', tonumber(job.grade and job.grade.level) or 0)
    end
    if jobIsPd(Player.PlayerData.job) then
        local grade = tonumber(Player.PlayerData.job.grade and Player.PlayerData.job.grade.level) or 0
        MySQL.query.await('INSERT IGNORE INTO ltpd_profiles (citizenid, division) VALUES (?, ?)', {
            Player.PlayerData.citizenid,
            defaultDivisionForGrade(grade),
        })
        enforceDivisionForPlayer(Player.PlayerData.source)
        syncDivisionClient(Player.PlayerData.source)
    end
end)

local function pdAccessPayload(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobIsPd(P.PlayerData.job) then return nil end
    local grade = getGrade(src)
    local stored = enforceDivisionForPlayer(src)
    return {
        division = stored,
        grade = grade,
        effective = PdDivisions.effectiveDivision(grade, stored),
    }
end

-- Išplėstinė MDT informacija (transportas, baudų istorija, pinigai)
local function mdtFullAccess(src)
    if not hasPerm(src, 'mdt_search_full') then return false end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    local g = getGrade(src)
    local div = getDivisionForCitizenid(Player.PlayerData.citizenid)
    if (div == 'sor' or div == 'aro') and g < 5 then
        return false
    end
    local divCfg = Config.Divisions[div]
    if divCfg and g < (divCfg.minGrade or 0) then
        return false
    end
    return true
end

RegisterNetEvent('mrp_ltpd:server:setDivision', function(targetCitizenid, newDiv)
    local src = source
    if not hasPerm(src, 'division_admin') then return end
    newDiv = PdDivisions.normalize(newDiv)
    if not Config.Divisions[newDiv] then return end
    setDivisionForCitizenid(targetCitizenid, newDiv)
    local T = QBCore.Functions.GetPlayerByCitizenId(targetCitizenid)
    if T then syncDivisionClient(T.PlayerData.source) end
end)

RegisterNetEvent('mrp_ltpd:server:chooseDivision', function(data)
    local src = source
    if not isLtpdOnDuty(src) then
        return TriggerClientEvent('QBCore:Notify', src, 'Tik tarnyboje.', 'error')
    end
    local newDiv = PdDivisions.normalize(type(data) == 'table' and data.division or data)
    local chooseMin = tonumber((Config.DivisionRules or {}).chooseMinGrade) or 4
    if getGrade(src) < chooseMin then
        return TriggerClientEvent('QBCore:Notify', src, 'Padalinį galima keisti nuo 4 rango.', 'error')
    end
    if not PdDivisions.isChoosable(newDiv) then
        return TriggerClientEvent('QBCore:Notify', src, 'Šis padalinys neprieinamas.', 'error')
    end
    local cfg = Config.Divisions[newDiv]
    if getGrade(src) < (tonumber(cfg.minGrade) or chooseMin) then
        return TriggerClientEvent('QBCore:Notify', src, 'Per žemas rangas šiam padaliniui.', 'error')
    end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    setDivisionForCitizenid(P.PlayerData.citizenid, newDiv)
    syncDivisionClient(src)
    TriggerClientEvent('QBCore:Notify', src, ('Padalinys: %s'):format(cfg.label or newDiv), 'success')
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:getPdDivisionState', function(src, cb)
    cb(pdAccessPayload(src))
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:canOpenMdt', function(src, cb)
    cb(hasPerm(src, 'mdt_open'))
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:mdtContext', function(src, cb)
    if not hasPerm(src, 'mdt_open') then return cb(nil) end
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return cb(nil) end
    local defDiv = defaultDivisionForGrade(getGrade(src))
    MySQL.query.await('INSERT IGNORE INTO ltpd_profiles (citizenid, division) VALUES (?, ?)', {
        P.PlayerData.citizenid,
        defDiv,
    })
    enforceDivisionForPlayer(src)
    local ped = GetPlayerPed(src)
    local c = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    cb({
        presets = Config.FinePresets,
        map = Config.MdtMap,
        selfSource = src,
        playerPos = {
            x = c.x + 0.0,
            y = c.y + 0.0,
            z = c.z + 0.0,
            heading = (ped and ped ~= 0) and (GetEntityHeading(ped) + 0.0) or 0.0,
        },
        division = PdDivisions.effectiveDivision(getGrade(src), getDivisionForCitizenid(P.PlayerData.citizenid)),
        divisionStored = getDivisionForCitizenid(P.PlayerData.citizenid),
        grade = getGrade(src),
        permissions = {
            fullSearch = mdtFullAccess(src),
            fine = hasPerm(src, 'mdt_fine'),
            wanted = hasPerm(src, 'mdt_wanted'),
            fingerprint = hasPerm(src, 'mdt_fingerprint'),
            arrest = hasPerm(src, 'mdt_arrest_record'),
            interrogation = hasPerm(src, 'mdt_interrogation'),
            cctv = hasPerm(src, 'mdt_cctv'),
            bodycam = hasPerm(src, 'mdt_bodycam'),
            weaponLicense = hasPerm(src, 'mdt_weapon_license'),
        },
        surveillanceMaintenance = Config.Surveillance and Config.Surveillance.MaintenanceMode == true,
        surveillanceMaintenanceMessage = (Config.Surveillance and Config.Surveillance.MaintenanceMessage)
            or 'Sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.',
        mapMaintenance = Config.MdtMapMaintenance and Config.MdtMapMaintenance.enabled == true,
        mapMaintenanceMessage = (Config.MdtMapMaintenance and Config.MdtMapMaintenance.message)
            or 'GPS žemėlapio sistema laikinai neveikia. Dėl finansavimo skyrimo ir įrengimo kreipkitės į miesto merą.',
    })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:searchPerson', function(src, cb, query)
    if not hasPerm(src, 'mdt_search_basic') then return cb({ ok = false, message = 'Nėra teisės' }) end
    query = tostring(query or ''):gsub('%%', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$') or ''
    if #query < 2 then return cb({ ok = true, rows = {} }) end

    local ok, err = pcall(function()
        local rows = searchPersonDbRows(query)
        local full = mdtFullAccess(src)

        for _, r in ipairs(rows) do
            local charinfo = decodeCharinfo(r.charinfo)
            r.name = personDisplayName(charinfo)
            r.fingerprint = fingerprintFromRow(r)
            local onlineP = QBCore.Functions.GetPlayerByCitizenId(r.citizenid)
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
            local inv = fetchPlayerInventory(r.citizenid, onlineP)
            r.licenses = buildPersonLicenses(r.citizenid, meta, inv, onlineP)
            if full then
                r.vehicles = MySQL.query.await(
                    'SELECT plate, vehicle, state FROM player_vehicles WHERE citizenid = ? LIMIT 15',
                    { r.citizenid }
                ) or {}
                r.fines = MySQL.query.await(
                    'SELECT amount, reason_label, created_at FROM ltpd_fines WHERE citizenid = ? ORDER BY id DESC LIMIT 10',
                    { r.citizenid }
                ) or {}
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

    if not ok then
        print(('[mrp_ltpd] searchPerson error: %s'):format(tostring(err)))
        cb({ ok = false, message = 'Paieškos klaida. Patikrink DB.' })
    end
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:issueWeaponLicense', function(src, cb, citizenid)
    if not hasPerm(src, 'mdt_weapon_license') then
        return cb({ ok = false, message = 'Nėra teisės išduoti ginklo licencijos (reikia ≥3 rango).' })
    end
    citizenid = tostring(citizenid or ''):match('^%s*(.-)%s*$') or ''
    if citizenid == '' then return cb({ ok = false, message = 'Neteisingas citizenid.' }) end
    if GetResourceState('mrp_gunshop') ~= 'started' then
        return cb({ ok = false, message = 'mrp_gunshop neaktyvus.' })
    end
    local ok, msg = exports['mrp_gunshop']:IssueWeaponLicense(citizenid, src)
    cb({ ok = ok == true, message = msg })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:revokeWeaponLicense', function(src, cb, citizenid)
    if not hasPerm(src, 'mdt_weapon_license') then
        return cb({ ok = false, message = 'Nėra teisės atšaukti ginklo licencijos (reikia ≥3 rango).' })
    end
    citizenid = tostring(citizenid or ''):match('^%s*(.-)%s*$') or ''
    if citizenid == '' then return cb({ ok = false, message = 'Neteisingas citizenid.' }) end
    if GetResourceState('mrp_gunshop') ~= 'started' then
        return cb({ ok = false, message = 'mrp_gunshop neaktyvus.' })
    end
    local ok, msg = exports['mrp_gunshop']:RevokeWeaponLicense(citizenid)
    cb({ ok = ok == true, message = msg })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:searchVehicle', function(src, cb, plate)
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

QBCore.Functions.CreateCallback('mrp_ltpd:server:issueFine', function(src, cb, data)
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

QBCore.Functions.CreateCallback('mrp_ltpd:server:collectFingerprint', function(src, cb, citizenid)
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

QBCore.Functions.CreateCallback('mrp_ltpd:server:getMyFingerprints', function(src, cb)
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

QBCore.Functions.CreateCallback('mrp_ltpd:server:setWanted', function(src, cb, data)
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

QBCore.Functions.CreateCallback('mrp_ltpd:server:addArrestNote', function(src, cb, citizenid, notes, reason, sentence)
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

local function saveInterrogationRecord(officerSrc, record)
    if not record or not record.citizenid then return false end
    local Officer = QBCore.Functions.GetPlayer(officerSrc)
    if not Officer then return false end
    if not hasPerm(officerSrc, 'mdt_interrogation') and not hasPerm(officerSrc, 'mdt_arrest_record') then
        return false
    end
    local payload = {
        suspect_name = tostring(record.suspect_name or ''):sub(1, 128),
        officer_name = tostring(record.officer_name or ''):sub(1, 128),
        summary = tostring(record.summary or ''):sub(1, 800),
        notes = record.notes or {},
        answers = record.answers or {},
        categories = record.categories or {},
        consent_at = record.consent_at,
        duration_sec = tonumber(record.duration_sec) or 0,
    }
    MySQL.insert.await(
        [[INSERT INTO ltpd_interrogations
          (citizenid, officer_citizenid, mode, room_id, result, recorded, pressure_max, payload)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            tostring(record.citizenid):sub(1, 50),
            Officer.PlayerData.citizenid,
            tostring(record.mode or 'police'):sub(1, 16),
            tostring(record.room_id or ''):sub(1, 64),
            tostring(record.result or ''):sub(1, 64),
            (record.recorded and 1 or 0),
            math.min(100, math.floor(tonumber(record.pressure_max) or 0)),
            json.encode(payload),
        }
    )
    return true
end

exports('SaveInterrogationRecord', saveInterrogationRecord)

QBCore.Functions.CreateCallback('mrp_ltpd:server:getInterrogationHistory', function(src, cb, citizenid)
    if not hasPerm(src, 'mdt_interrogation') then return cb({ ok = false }) end
    citizenid = tostring(citizenid or ''):sub(1, 50)
    if citizenid == '' then return cb({ ok = true, rows = {} }) end
    local rows = MySQL.query.await([[
        SELECT i.id, i.citizenid, i.officer_citizenid, i.mode, i.room_id, i.result,
               i.recorded, i.pressure_max, i.payload, i.created_at,
               p.charinfo AS officer_charinfo
        FROM ltpd_interrogations i
        LEFT JOIN players p ON p.citizenid = i.officer_citizenid
        WHERE i.citizenid = ?
        ORDER BY i.id DESC
        LIMIT 40
    ]], { citizenid }) or {}
    for _, r in ipairs(rows) do
        local parsed = {}
        local ok, dec = pcall(json.decode, r.payload or '{}')
        if ok and type(dec) == 'table' then parsed = dec end
        r.suspect_name = parsed.suspect_name or ''
        r.officer_name = parsed.officer_name or ''
        r.summary = parsed.summary or ''
        r.notes = parsed.notes or {}
        r.answers = parsed.answers or {}
        if r.officer_name == '' and r.officer_charinfo then
            local ch = json.decode(r.officer_charinfo or '{}') or {}
            r.officer_name = ((ch.firstname or '') .. ' ' .. (ch.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
        end
        r.officer_charinfo = nil
        r.payload = nil
    end
    cb({ ok = true, rows = rows })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:getArrestHistory', function(src, cb, citizenid)
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

RegisterNetEvent('mrp_ltpd:server:cuffPlayer', function(targetId)
    local src = source
    if not hasPerm(src, 'cuff') then return end
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId, 3.5) then return end
    if GetResourceState('mrp_restraints') ~= 'started' then return end
    TriggerEvent('mrp_restraints:internal:toggleRestraint', src, targetId, 'handcuffs')
end)

RegisterNetEvent('mrp_ltpd:server:trySearchInventory', function(targetId)
    local src = source
    if not hasPerm(src, 'search_inventory') then return end
    targetId = tonumber(targetId)
    if not targetId or not validTarget(src, targetId, 3.0) then return end
    if GetResourceState('mrp_restraints') ~= 'started' then
        if GetResourceState('qb-inventory') ~= 'started' then return end
        return exports['qb-inventory']:OpenInventoryById(src, targetId)
    end
    TriggerEvent('mrp_restraints:internal:searchPlayer', src, targetId)
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

RegisterNetEvent('mrp_ltpd:server:openPoliceStash', function(stationId, stashIndex)
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
    local P = QBCore.Functions.GetPlayer(src)
    local div = P and getDivisionForCitizenid(P.PlayerData.citizenid) or 'mp'
    if not PdDivisions.canAccessPoint(getGrade(src), div, entry) then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi prieigos prie šio sandėlio (rangas / padalinys).', 'error')
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

RegisterNetEvent('mrp_ltpd:server:openArmory', function(stationId)
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
    local P = QBCore.Functions.GetPlayer(src)
    local div = P and getDivisionForCitizenid(P.PlayerData.citizenid) or 'mp'
    if not PdDivisions.canAccessPoint(getGrade(src), div, st.armory) then
        return TriggerClientEvent('QBCore:Notify', src, 'ARO sandėlis – tik ARO padaliniui.', 'error')
    end
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

RegisterNetEvent('mrp_ltpd:server:spawnFleet', function(stationId, modelName)
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
    TriggerClientEvent('mrp_ltpd:client:fleetVehicleReady', src, plate)
    TriggerClientEvent('QBCore:Notify', src, 'Transportas paruoštas.', 'success')
end)

local function fleetHeliModelAllowed(modelName)
    modelName = tostring(modelName or ''):lower()
    for _, v in ipairs(Config.FleetHelicopters or {}) do
        if v.model and tostring(v.model):lower() == modelName then return true end
    end
    return false
end

RegisterNetEvent('mrp_ltpd:server:spawnFleetHeli', function(stationId, modelName)
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
    TriggerClientEvent('mrp_ltpd:client:fleetVehicleReady', src, plate)
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
        if st.boss and st.boss.coords then
            local bc = st.boss.coords
            local pos = vector3(bc.x, bc.y, bc.z)
            if #(c - pos) <= r then
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

RegisterNetEvent('mrp_ltpd:server:bossHire', function(targetId, grade)
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
    setDivisionForCitizenid(T.PlayerData.citizenid, defaultDivisionForGrade(grade))
    syncDivisionClient(targetId)
    TriggerClientEvent('QBCore:Notify', src, ('Įdarbinta (ID %s), rangas %s'):format(targetId, grade), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Priimta į policiją. Rangas: %s'):format(grade), 'success')
end)

RegisterNetEvent('mrp_ltpd:server:bossFire', function(targetId)
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

RegisterNetEvent('mrp_ltpd:server:bossSetGrade', function(targetId, grade)
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
    enforceDivisionForPlayer(targetId)
    syncDivisionClient(targetId)
    TriggerClientEvent('QBCore:Notify', src, ('Rangas pakeistas (ID %s → %s)'):format(targetId, grade), 'success')
    TriggerClientEvent('QBCore:Notify', targetId, ('Tavo naujas rangas: %s'):format(grade), 'primary')
end)

exports('IsLtpdOnDuty', function(src)
    return isLtpdOnDuty(src)
end)

exports('HasLtpdPermission', function(src, key)
    return hasPerm(src, key)
end)

local function divisionLabelForPlayer(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not jobIsPd(P.PlayerData.job) then return nil end
    local grade = getGrade(src)
    local stored = getDivisionForCitizenid(P.PlayerData.citizenid)
    local effective = PdDivisions.effectiveDivision(grade, stored)
    local cfg = Config.Divisions and Config.Divisions[effective]
    return (cfg and cfg.label) or effective
end

exports('GetDivisionLabelForPlayer', divisionLabelForPlayer)

--- PD sirenos įranga: entity statebags (networked vehicles) + išsaugojimas player_vehicles.mods
local EMERGENCY_MOD_KEYS = { mrpPdKit = true, mrpEmsKit = true }

local function normalizePlate(plate)
    return QBCore.Shared.Trim(tostring(plate or '')):upper()
end

local function mergeVehicleEmergencyMods(plate, citizenid, fields)
    plate = normalizePlate(plate)
    if plate == '' or type(fields) ~= 'table' then return end
    citizenid = citizenid and tostring(citizenid) or nil

    local row
    if citizenid then
        row = MySQL.single.await(
            'SELECT mods FROM player_vehicles WHERE plate = ? AND citizenid = ? LIMIT 1',
            { plate, citizenid }
        )
    else
        row = MySQL.single.await('SELECT mods FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
    end
    if not row then return end

    local mods = {}
    if row.mods and row.mods ~= '' then
        local ok, decoded = pcall(json.decode, row.mods)
        if ok and type(decoded) == 'table' then mods = decoded end
    end

    for key, value in pairs(fields) do
        if EMERGENCY_MOD_KEYS[key] then
            if value == true then
                mods[key] = true
            else
                mods[key] = nil
            end
        end
    end

    local whereSql = citizenid and 'plate = ? AND citizenid = ?' or 'plate = ?'
    local params = citizenid and { json.encode(mods), plate, citizenid } or { json.encode(mods), plate }
    MySQL.update.await(('UPDATE player_vehicles SET mods = ? WHERE %s'):format(whereSql), params)
end

exports('PersistVehicleEmergencyMods', function(plate, citizenid, fields)
    mergeVehicleEmergencyMods(plate, citizenid, fields)
end)

exports('ApplyVehicleEmergencyFromMods', function(veh, mods)
    if type(mods) == 'string' and mods ~= '' then
        local ok, decoded = pcall(json.decode, mods)
        mods = ok and decoded or nil
    end
    if type(mods) ~= 'table' then return end
    if mods.mrpPdKit == true then
        Entity(veh).state:set('ltPdKit', true, true)
    else
        Entity(veh).state:set('ltPdKit', false, true)
        Entity(veh).state:set('ltPdSirenMode', 'off', true)
    end
    if mods.mrpEmsKit == true then
        Entity(veh).state:set('ltEmsKit', true, true)
    else
        Entity(veh).state:set('ltEmsKit', false, true)
        Entity(veh).state:set('ltEmsSirenMode', 'off', true)
    end
end)

local function resolveVehicleNetId(netId)
    netId = tonumber(netId) or 0
    if netId <= 0 then return 0 end
    if type(NetworkDoesNetworkIdExist) == 'function' and not NetworkDoesNetworkIdExist(netId) then
        return 0
    end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent == 0 or not DoesEntityExist(ent) or GetEntityType(ent) ~= 2 then
        return 0
    end
    return ent
end

RegisterNetEvent('mrp_ltpd:server:restoreVehicleEmergency', function(netId)
    local src = source
    local veh = resolveVehicleNetId(netId)
    if veh == 0 then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    if plate == '' then return end

    local row = MySQL.single.await(
        'SELECT mods FROM player_vehicles WHERE plate = ? AND citizenid = ? LIMIT 1',
        { plate, Player.PlayerData.citizenid }
    )
    if not row then return end

    exports['mrp_ltpd']:ApplyVehicleEmergencyFromMods(veh, row.mods)
end)

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

local function pedVehicleOccupant(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    if not veh or veh == 0 then return nil end
    return ped, veh
end

local function pedVehicleForSirenControl(src)
    local ec = Config.EmergencyVehicle or {}
    if ec.allowPassengerControl == false then
        return pedVehicleSeatIsDriver(src)
    end
    return pedVehicleOccupant(src)
end

local function vehicleNearPlayer(src, veh, maxDist)
    local pd = GetPlayerPed(src)
    if not pd or pd == 0 or not veh or veh == 0 then return false end
    maxDist = tonumber(maxDist) or 28.0
    local p = GetEntityCoords(pd)
    local v = GetEntityCoords(veh)
    return #(p - v) <= maxDist
end

local function safeVehicleNetId(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return 0 end
    return NetworkGetNetworkIdFromEntity(veh)
end

local function isEmergencyFleetModel(entity)
    if not entity or entity == 0 then return false end
    local hash = GetEntityModel(entity)
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

RegisterNetEvent('mrp_ltpd:server:setPdEmergencyMode', function(mode)
    local src = source
    if not hasPerm(src, 'pd_siren_controller') then
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės sirenos meniu.', 'error')
    end
    mode = normalizeEmergencyMode(type(mode) == 'string' and mode or 'off')
    if not LtPdEmergencyModes[mode] then mode = 'off' end
    local     _, veh = pedVehicleForSirenControl(src)
    if not veh then
        return TriggerClientEvent('QBCore:Notify', src, 'Turi būti transporto salėje.', 'error')
    end
    if safeVehicleNetId(veh) == 0 then
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
                'Ant civilinės TP pirmiausiai uždėk avarinę įrangą (itemas iš inventoriaus).',
                'error'
            )
        end
    end
    Entity(veh).state:set('ltPdSirenMode', mode, true)
    TriggerClientEvent('QBCore:Notify', src, ('Šviesos / sirena: %s'):format(mode), 'primary')
    TriggerClientEvent('mrp_siren:client:syncUi', src)
end)

RegisterNetEvent('mrp_ltpd:server:setPdEmergencyKit', function(equip)
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
    if safeVehicleNetId(veh) == 0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Mašina turi būti tinkamai sinchronizuota (išimk iš garažo / naujas spawn).', 'error')
    end
    if isEmergencyFleetModel(veh) then
        return TriggerClientEvent('QBCore:Notify', src, 'Ši mašina jau turi tarnybinę įrangą (ne civilinė).', 'error')
    end
    local hash = GetEntityModel(veh)
    for _, name in ipairs({ 'IsThisModelEmergencyVehicle', 'IsThisModelAnEmergencyVehicle' }) do
        local fn = rawget(_G, name)
        if type(fn) == 'function' then
            local ok, isEmerg = pcall(fn, hash)
            if ok and isEmerg then
                return TriggerClientEvent('QBCore:Notify', src, 'Šiai mašinai negalima montuoti laikinos įrangos.', 'error')
            end
        end
    end
    equip = equip == true
    local ec = Config.EmergencyVehicle or {}
    local kitItem = ec.kitItem or 'pd_emergency_kit'
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    if equip then
        if not isAdmin(src) then
            if not Player.Functions.GetItemByName(kitItem) then
                return TriggerClientEvent(
                    'QBCore:Notify',
                    src,
                    'Neturi avarinės įrangos inventoriuje.',
                    'error'
                )
            end
            if not Player.Functions.RemoveItem(kitItem, 1) then
                return TriggerClientEvent('QBCore:Notify', src, 'Nepavyko paimti įrangos.', 'error')
            end
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[kitItem], 'remove', 1)
        end
    elseif ec.returnKitItemOnRemove ~= false and not isAdmin(src) then
        if not Player.Functions.AddItem(kitItem, 1) then
            return TriggerClientEvent('QBCore:Notify', src, 'Inventorius pilnas – negalima grąžinti įrangos.', 'error')
        end
        TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[kitItem], 'add', 1)
    end
    Entity(veh).state:set('ltPdKit', equip, true)
    local plate = normalizePlate(GetVehicleNumberPlateText(veh))
    if plate ~= '' then
        mergeVehicleEmergencyMods(plate, Player.PlayerData.citizenid, { mrpPdKit = equip })
    end
    if equip then
        TriggerClientEvent('QBCore:Notify', src, 'Įdėtos sirenos, švyturėliai ir lengvas našumo pakėlimas ant šio TP.', 'success')
    else
        Entity(veh).state:set('ltPdSirenMode', 'off', true)
        TriggerClientEvent('QBCore:Notify', src, 'Laikina įranga nuimta.', 'primary')
    end
end)

RegisterNetEvent('mrp_ltpd:server:clearPdEmergencyOnExit', function(netId)
    local src = source
    local veh = resolveVehicleNetId(netId)
    if veh == 0 then return end
    if not isLtpdOnDuty(src) then return end
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

RegisterNetEvent('mrp_ltpd:server:requestPdDoorsSync', function()
    TriggerClientEvent('mrp_ltpd:client:syncPdDoors', source, LtpdPdDoorLocked)
end)

local LtpdPdDoorRegCount = {}

RegisterNetEvent('mrp_ltpd:server:registerPdDynDoorGroup', function(groupId, stationId, cx, cy, cz, interactDist, regSlabs)
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

local function pdDoorSlabToggleReach(meta, slabCoord)
    local base = (Config.PdDoorToggleReach or 5.0) + 0.35
    local idist = meta.interactDist or 2.5
    if meta.interact and slabCoord then
        local span = #(slabCoord - meta.interact)
        if span > 3.0 then
            return math.max(base, idist + span * 0.55 + 2.0)
        end
    end
    return math.max(base, idist + 0.5)
end

local function playerNearPdDoorGroup(pc, meta)
    if not meta then return false end
    for _, c in ipairs(meta.slabs or {}) do
        if #(pc - c) <= pdDoorSlabToggleReach(meta, c) then
            return true
        end
    end
    local interactReach = math.max(meta.interactDist or 2.5, Config.PdDoorToggleReach or 5.0) + 0.5
    if meta.interact and #(pc - meta.interact) <= interactReach then
        return true
    end
    if type(meta.interactAnchors) == 'table' then
        for _, anch in ipairs(meta.interactAnchors) do
            local ac = anch.coords
            if ac and #(pc - ac) <= math.max(anch.interactDist or 2.5, Config.PdDoorToggleReach or 5.0) + 0.5 then
                return true
            end
        end
    end
    return false
end

AddEventHandler('playerDropped', function()
    local src = source
    LtpdPdDoorRegCount[src] = nil
    LtpdPdDoorToggleCooldown[src] = nil
end)

local function syncPdDoorStateToClient(clientId, groupId)
    TriggerClientEvent('mrp_ltpd:client:setPdDoorState', clientId, groupId, LtpdPdDoorLocked[groupId])
end

local function parseWantDoorLocked(v)
    if v == true or v == 1 then return true end
    if v == false or v == 0 then return false end
    return nil
end

RegisterNetEvent('mrp_ltpd:server:setPdDoorGroup', function(groupId, wantLocked)
    local src = source
    if type(groupId) ~= 'string' then return end
    local parsed = parseWantDoorLocked(wantLocked)
    if parsed == nil then return end

    if not canUseServiceDoors(src, groupId) then
        syncPdDoorStateToClient(src, groupId)
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės arba ne tarnyboje.', 'error')
    end
    local meta = LtpdPdDoorMeta[groupId]
    if not meta then
        syncPdDoorStateToClient(src, groupId)
        return TriggerClientEvent('QBCore:Notify', src, 'Durų duomenys dar kraunami — palauk kelias sekundes.', 'error')
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pc = GetEntityCoords(ped)
    if not playerNearPdDoorGroup(pc, meta) then
        syncPdDoorStateToClient(src, groupId)
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo durų.', 'error')
    end
    local now = GetGameTimer()
    if (LtpdPdDoorToggleCooldown[src] or 0) > now then
        syncPdDoorStateToClient(src, groupId)
        return
    end
    LtpdPdDoorToggleCooldown[src] = now + 650

    if LtpdPdDoorLocked[groupId] == parsed then
        syncPdDoorStateToClient(src, groupId)
        return
    end

    LtpdPdDoorLocked[groupId] = parsed
    TriggerClientEvent('mrp_ltpd:client:setPdDoorState', -1, groupId, parsed)
    TriggerClientEvent(
        'QBCore:Notify',
        src,
        parsed and 'Durys užrakintos.' or 'Durys atrakintos.',
        'primary'
    )
end)

RegisterNetEvent('mrp_ltpd:server:togglePdDoorGroup', function(groupId)
    local src = source
    if type(groupId) ~= 'string' then return end
    if not canUseServiceDoors(src, groupId) then
        syncPdDoorStateToClient(src, groupId)
        return TriggerClientEvent('QBCore:Notify', src, 'Neturi teisės arba ne tarnyboje.', 'error')
    end
    local meta = LtpdPdDoorMeta[groupId]
    if not meta then
        syncPdDoorStateToClient(src, groupId)
        return TriggerClientEvent('QBCore:Notify', src, 'Durų duomenys dar kraunami — palauk kelias sekundes.', 'error')
    end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local pc = GetEntityCoords(ped)
    if not playerNearPdDoorGroup(pc, meta) then
        syncPdDoorStateToClient(src, groupId)
        return TriggerClientEvent('QBCore:Notify', src, 'Per toli nuo durų.', 'error')
    end
    local now = GetGameTimer()
    if (LtpdPdDoorToggleCooldown[src] or 0) > now then
        syncPdDoorStateToClient(src, groupId)
        return
    end
    LtpdPdDoorToggleCooldown[src] = now + 650
    local cur = LtpdPdDoorLocked[groupId] ~= false
    LtpdPdDoorLocked[groupId] = not cur
    TriggerClientEvent('mrp_ltpd:client:setPdDoorState', -1, groupId, LtpdPdDoorLocked[groupId])
    TriggerClientEvent(
        'QBCore:Notify',
        src,
        LtpdPdDoorLocked[groupId] and 'Durys užrakintos.' or 'Durys atrakintos.',
        'primary'
    )
end)

CreateThread(function()
    Wait(800)
    local ec = Config.EmergencyVehicle or {}
    local kitItem = ec.kitItem or 'pd_emergency_kit'
    QBCore.Functions.CreateUseableItem(kitItem, function(source)
        TriggerClientEvent('mrp_ltpd:client:openEmergencyKitMenu', source)
    end)
end)

local function mergeBossmenuDivisions()
    if GetResourceState('mrp_bossmenu') ~= 'started' then return end
    local map = exports['mrp_bossmenu']:GetDivisionsMap('police')
    for id, div in pairs(map or {}) do
        Config.Divisions[id] = {
            label = div.label,
            abbr = div.abbr,
            minGrade = div.minGrade,
            choosable = div.choosable,
            description = div.description,
        }
    end
    TriggerClientEvent('mrp_ltpd:client:patchDivisions', -1, Config.Divisions)
end

AddEventHandler('mrp_bossmenu:divisionsUpdated', function(jobName)
    if jobName ~= 'police' then return end
    mergeBossmenuDivisions()
end)

AddEventHandler('mrp_bossmenu:internal:setPdDivision', function(targetId, divisionId)
    targetId = tonumber(targetId)
    if not targetId or targetId < 1 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or not jobIsPd(T.PlayerData.job) then return end
    divisionId = PdDivisions.normalize(divisionId)
    if not Config.Divisions[divisionId] then return end
    setDivisionForCitizenid(T.PlayerData.citizenid, divisionId)
    syncDivisionClient(targetId)
end)

AddEventHandler('mrp_bossmenu:internal:setPdDivisionByGrade', function(targetId, grade)
    targetId = tonumber(targetId)
    if not targetId or targetId < 1 then return end
    local T = QBCore.Functions.GetPlayer(targetId)
    if not T or not jobIsPd(T.PlayerData.job) then return end
    setDivisionForCitizenid(T.PlayerData.citizenid, defaultDivisionForGrade(grade))
    syncDivisionClient(targetId)
end)

CreateThread(function()
    Wait(2500)
    mergeBossmenuDivisions()
end)
