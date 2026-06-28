--- PD registratūra — pareiškimai ir priėmimo anketos (civiliai)
local QBCore = exports['qb-core']:GetCoreObject()

local statementCooldown = {} --- [citizenid] = os.time()
local applicationCooldown = {} --- [citizenid] = os.time()

local function receptionCfg()
    return Config.Reception or {}
end

local function trim(s, maxLen)
    s = tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if maxLen and #s > maxLen then
        s = s:sub(1, maxLen)
    end
    return s
end

local function playerDisplayName(P)
    local ci = P.PlayerData.charinfo or {}
    local fn = trim(ci.firstname, 64)
    local ln = trim(ci.lastname, 64)
    local name = (fn .. ' ' .. ln):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = 'Nežinomas' end
    return name
end

local function notifyOnDutyPolice(msg)
    for _, pid in ipairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(pid)
        if P and P.PlayerData.job
            and P.PlayerData.job.name == (Config.JobName or 'police')
            and P.PlayerData.job.onduty then
            TriggerClientEvent('QBCore:Notify', pid, msg, 'primary', 9000)
        end
    end
end

local function ensureReceptionTables()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_civilian_statements` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `author_name` varchar(128) NOT NULL DEFAULT '',
        `phone` varchar(32) DEFAULT NULL,
        `subject` varchar(128) NOT NULL,
        `location_text` varchar(255) DEFAULT NULL,
        `body` text NOT NULL,
        `status` varchar(24) NOT NULL DEFAULT 'new',
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])

    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `ltpd_recruitment_applications` (
        `id` int(11) NOT NULL AUTO_INCREMENT,
        `citizenid` varchar(50) NOT NULL,
        `applicant_name` varchar(128) NOT NULL DEFAULT '',
        `phone` varchar(32) DEFAULT NULL,
        `motivation` text NOT NULL,
        `experience` text,
        `extra_info` text,
        `status` varchar(24) NOT NULL DEFAULT 'pending',
        `created_at` datetime NOT NULL DEFAULT current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`),
        KEY `status` (`status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;]])
end

CreateThread(function()
    Wait(1200)
    ensureReceptionTables()
end)

RegisterNetEvent('mrp_ltpd:server:submitCivilianStatement', function(data)
    local src = source
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    if type(data) ~= 'table' then return end

    local cfg = receptionCfg()
    local cid = P.PlayerData.citizenid
    local cdMin = tonumber(cfg.statementCooldownMinutes) or 10
    local now = os.time()
    if statementCooldown[cid] and (now - statementCooldown[cid]) < (cdMin * 60) then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false,
            ('Palauk %d min. prieš kitą pareiškimą.'):format(cdMin))
    end

    local subject = trim(data.subject, 128)
    local body = trim(data.body, 4000)
    local locationText = trim(data.location, 255)
    local minLen = tonumber(cfg.statementMinLen) or 15

    if #subject < 3 then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false, 'Nurodyk incidento tipą.')
    end
    if #body < minLen then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false,
            ('Pareiškimas per trumpas (min. %d simbolių).'):format(minLen))
    end

    local phone = trim(P.PlayerData.charinfo and P.PlayerData.charinfo.phone, 32)
    MySQL.insert.await(
        'INSERT INTO ltpd_civilian_statements (citizenid, author_name, phone, subject, location_text, body) VALUES (?, ?, ?, ?, ?, ?)',
        { cid, playerDisplayName(P), phone ~= '' and phone or nil, subject, locationText ~= '' and locationText or nil, body }
    )

    statementCooldown[cid] = now
    TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, true,
        'Pareiškimas priimtas. Policija susisieks, jei reikės papildomos informacijos.')
    notifyOnDutyPolice(('Naujas pareiškimas registratūroje: %s — %s'):format(playerDisplayName(P), subject))
end)

RegisterNetEvent('mrp_ltpd:server:submitRecruitmentApplication', function(data)
    local src = source
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return end
    if type(data) ~= 'table' then return end

    if P.PlayerData.job and P.PlayerData.job.name == (Config.JobName or 'police') then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false,
            'Jau dirbi policijoje.')
    end

    local cfg = receptionCfg()
    local cid = P.PlayerData.citizenid
    local cdHours = tonumber(cfg.applicationCooldownHours) or 48
    local now = os.time()

    local row = MySQL.single.await(
        'SELECT id FROM ltpd_recruitment_applications WHERE citizenid = ? AND created_at > DATE_SUB(NOW(), INTERVAL ? HOUR) ORDER BY id DESC LIMIT 1',
        { cid, cdHours }
    )
    if row then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false,
            ('Anketą jau pateikei neseniai. Bandyk po %d val.'):format(cdHours))
    end
    if applicationCooldown[cid] and (now - applicationCooldown[cid]) < 120 then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false, 'Palauk kelias sekundes.')
    end

    local motivation = trim(data.motivation, 2000)
    local experience = trim(data.experience, 1500)
    local extra = trim(data.extra, 1500)
    local minMot = tonumber(cfg.applicationMinMotivation) or 20

    if #motivation < minMot then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false,
            ('Motyvacija per trumpa (min. %d simbolių).'):format(minMot))
    end

    local pending = MySQL.scalar.await(
        "SELECT COUNT(*) FROM ltpd_recruitment_applications WHERE citizenid = ? AND status = 'pending'",
        { cid }
    )
    if tonumber(pending or 0) > 0 then
        return TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, false,
            'Tavo anketa jau laukia nagrinėjimo.')
    end

    local phone = trim(P.PlayerData.charinfo and P.PlayerData.charinfo.phone, 32)
    MySQL.insert.await(
        'INSERT INTO ltpd_recruitment_applications (citizenid, applicant_name, phone, motivation, experience, extra_info) VALUES (?, ?, ?, ?, ?, ?)',
        { cid, playerDisplayName(P), phone ~= '' and phone or nil, motivation,
            experience ~= '' and experience or nil, extra ~= '' and extra or nil }
    )

    applicationCooldown[cid] = now
    TriggerClientEvent('mrp_ltpd:client:receptionSubmitResult', src, true,
        'Anketa pateikta. Vadovybė susisieks dėl pokalbio / įdarbinimo.')
    notifyOnDutyPolice(('Nauja anketa į policijos gretas: %s'):format(playerDisplayName(P)))
end)
