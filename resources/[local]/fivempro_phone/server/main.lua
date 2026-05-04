local QBCore = exports['qb-core']:GetCoreObject()

local ActiveCalls = {}
local NextCallId = 1

local DeathStartedAt = {}
local LastEmergencyCall = {}
local LastMedicRequest = {}

local function trim(s)
    return tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function clampStr(s, maxLen)
    s = trim(s)
    if #s > maxLen then
        s = s:sub(1, maxLen)
    end
    return s
end

local function digitsOnly(s)
    return tostring(s or ''):gsub('%D+', '')
end

local function getPlayer(src)
    return QBCore.Functions.GetPlayer(src)
end

local function getCitizen(src)
    local P = getPlayer(src)
    if not P then return nil end
    return P.PlayerData.citizenid, P
end

local function generateUniqueNumber()
    local minN = (Config.Phone and Config.Phone.numberMin) or 100000
    local maxN = (Config.Phone and Config.Phone.numberMax) or 999999
    for _ = 1, 50 do
        local n = tostring(math.random(minN, maxN))
        local exists = MySQL.scalar.await('SELECT id FROM fivempro_phone_users WHERE phone_number = ? LIMIT 1', { n })
        if not exists then
            return n
        end
    end
    return tostring(math.random(minN, maxN))
end

local function ensurePhoneUser(citizenid, fullname)
    local row = MySQL.single.await('SELECT phone_number, profile_name FROM fivempro_phone_users WHERE citizenid = ? LIMIT 1', { citizenid })
    if row and row.phone_number then
        return tostring(row.phone_number), tostring(row.profile_name or fullname or 'Player')
    end
    local phone = generateUniqueNumber()
    local profile = clampStr(fullname ~= '' and fullname or 'Player', 64)
    MySQL.insert.await('INSERT INTO fivempro_phone_users (citizenid, phone_number, profile_name) VALUES (?, ?, ?)', {
        citizenid, phone, profile
    })
    return phone, profile
end

local function getFullName(player)
    if not player then return 'Player' end
    local c = player.PlayerData.charinfo or {}
    local fn = trim(c.firstname or '')
    local ln = trim(c.lastname or '')
    local full = trim((fn .. ' ' .. ln))
    if full == '' then return 'Player' end
    return full
end

local function getUserByNumber(number)
    number = digitsOnly(number)
    if number == '' then return nil end
    return MySQL.single.await('SELECT citizenid, phone_number, profile_name FROM fivempro_phone_users WHERE phone_number = ? LIMIT 1', { number })
end

local function getNumberByCitizen(citizenid)
    local row = MySQL.single.await('SELECT phone_number FROM fivempro_phone_users WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then return nil end
    return tostring(row.phone_number)
end

local function sourceByCitizen(citizenid)
    local players = QBCore.Functions.GetQBPlayers()
    for sid, player in pairs(players) do
        if player and player.PlayerData and player.PlayerData.citizenid == citizenid then
            return sid, player
        end
    end
    return nil, nil
end

local function jobMatchesPolice(jobName)
    jobName = tostring(jobName or ''):lower()
    for _, n in ipairs((Config.Emergency and Config.Emergency.policeJobs) or { 'police' }) do
        if jobName == tostring(n):lower() then return true end
    end
    return false
end

local function pickNearestHospital(pos)
    local hw = Config.HospitalWake or {}
    local locs = hw.locations
    if type(locs) ~= 'table' or #locs == 0 then
        return hw.coords or vector4(-458.6, -327.15, 34.50, 91.30)
    end
    local best = locs[1]
    local bestD = 1e12
    for i = 1, #locs do
        local h = locs[i]
        if h and h.x then
            local d = #(vector3(pos.x, pos.y, pos.z) - vector3(h.x + 0.0, h.y + 0.0, h.z + 0.0))
            if d < bestD then
                bestD = d
                best = h
            end
        end
    end
    return best
end

local function dispatchEmergency(src, service)
    service = tostring(service or ''):lower()
    local cfg = Config.Emergency or {}
    local now = os.time()
    LastEmergencyCall[src] = LastEmergencyCall[src] or {}
    local last = tonumber(LastEmergencyCall[src][service]) or 0
    if now - last < (tonumber(cfg.callCooldownSec) or 45) then
        return TriggerClientEvent('QBCore:Notify', src, 'Palaukite prieš kitą skambutį.', 'error')
    end
    LastEmergencyCall[src][service] = now

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    local Player = getPlayer(src)
    if not Player then return end
    local callerName = getFullName(Player)
    local phone = ensurePhoneUser(Player.PlayerData.citizenid, callerName)

    local labels = {
        police = ('Policija: %s skambina (%s)'):format(callerName, phone),
        ems = ('Greitoji: %s skambina (%s)'):format(callerName, phone),
        taxi = ('Taksi: %s skambina (%s)'):format(callerName, phone),
    }
    local title = labels[service] or 'Skubus skambutis'

    local count = 0
    for _, P in pairs(QBCore.Functions.GetQBPlayers()) do
        if P and P.PlayerData and P.PlayerData.job and P.PlayerData.job.onduty then
            local jn = P.PlayerData.job.name
            local match = false
            if service == 'police' then
                match = jobMatchesPolice(jn)
            elseif service == 'ems' then
                match = jn == (cfg.ambulanceJob or 'ambulance')
            elseif service == 'taxi' then
                match = jn == (cfg.taxiJob or 'taxi')
            end
            if match then
                count = count + 1
                TriggerClientEvent('fivempro_phone:client:serviceDispatch', P.PlayerData.source, {
                    service = service,
                    x = c.x, y = c.y, z = c.z,
                    title = title,
                    caller = callerName,
                    phone = phone,
                    duration = tonumber(cfg.blipDurationMs) or 120000,
                    sprite = tonumber(cfg.blipSprite) or 161,
                    scale = tonumber(cfg.blipScale) or 1.0,
                })
            end
        end
    end

    if count == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Šiuo metu niekas neatsiliepia (tarnyba ne duty).', 'error')
    else
        TriggerClientEvent('QBCore:Notify', src, ('Skambutis perduotas (%s pareigūnų).'):format(count), 'success')
    end
end

local function getInitialDataFor(src)
    local citizenid, P = getCitizen(src)
    if not citizenid then return nil end
    local fullname = getFullName(P)
    local myNumber, profile = ensurePhoneUser(citizenid, fullname)

    local contacts = MySQL.query.await([[
        SELECT id, display_name, contact_number
        FROM fivempro_phone_contacts
        WHERE owner_citizenid = ?
        ORDER BY display_name ASC, id DESC
    ]], { citizenid }) or {}

    local msgs = MySQL.query.await([[
        SELECT id, from_number, to_number, body, created_at
        FROM fivempro_phone_messages
        WHERE from_citizenid = ? OR to_citizenid = ?
        ORDER BY id DESC
        LIMIT 120
    ]], { citizenid, citizenid }) or {}

    local ads = MySQL.query.await([[
        SELECT id, author_name, phone_number, body, created_at
        FROM fivempro_phone_ads
        ORDER BY id DESC
        LIMIT 80
    ]]) or {}

    local posts = MySQL.query.await([[
        SELECT id, author_name, caption, image_url, likes, created_at
        FROM fivempro_phone_posts
        ORDER BY id DESC
        LIMIT 120
    ]]) or {}

    return {
        ok = true,
        me = {
            number = myNumber,
            name = profile,
        },
        contacts = contacts,
        messagePreview = msgs,
        ads = ads,
        posts = posts,
    }
end

QBCore.Functions.CreateCallback('fivempro_phone:server:getInitialData', function(source, cb)
    local data = getInitialDataFor(source)
    cb(data or { ok = false })
end)

QBCore.Functions.CreateCallback('fivempro_phone:server:saveContact', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Player not found' }) end
    local fullname = getFullName(P)
    ensurePhoneUser(citizenid, fullname)

    local maxContacts = (Config.Phone and Config.Phone.maxContacts) or 120
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM fivempro_phone_contacts WHERE owner_citizenid = ?', { citizenid }) or 0
    if tonumber(count) >= maxContacts then
        return cb({ ok = false, message = 'Kontaktų limitas pasiektas.' })
    end

    local name = clampStr(data and data.name or '', 60)
    local number = digitsOnly(data and data.number or '')
    if name == '' or number == '' then
        return cb({ ok = false, message = 'Blogi duomenys.' })
    end

    MySQL.insert.await([[
        INSERT INTO fivempro_phone_contacts (owner_citizenid, display_name, contact_number)
        VALUES (?, ?, ?)
    ]], { citizenid, name, number })

    cb({ ok = true })
    TriggerClientEvent('fivempro_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('fivempro_phone:server:sendMessage', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local fullname = getFullName(P)
    local fromNumber = ensurePhoneUser(citizenid, fullname)
    local toNumber = digitsOnly(data and data.number or '')
    local body = clampStr(data and data.body or '', (Config.Phone and Config.Phone.maxMessageLength) or 320)

    if toNumber == '' or body == '' then
        return cb({ ok = false, message = 'Įvesk numerį ir žinutę.' })
    end
    if toNumber == fromNumber then
        return cb({ ok = false, message = 'Negali rašyti sau.' })
    end

    local target = getUserByNumber(toNumber)
    if not target or not target.citizenid then
        return cb({ ok = false, message = 'Numeris nerastas.' })
    end

    MySQL.insert.await([[
        INSERT INTO fivempro_phone_messages
        (from_citizenid, to_citizenid, from_number, to_number, body)
        VALUES (?, ?, ?, ?, ?)
    ]], { citizenid, target.citizenid, fromNumber, toNumber, body })

    local targetSrc = sourceByCitizen(target.citizenid)
    if targetSrc then
        TriggerClientEvent('fivempro_phone:client:newMessageNotify', targetSrc, fromNumber)
        TriggerClientEvent('fivempro_phone:client:refreshData', targetSrc)
    end

    cb({ ok = true })
    TriggerClientEvent('fivempro_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('fivempro_phone:server:getConversation', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false, messages = {} }) end

    local targetNumber = digitsOnly(data and data.number or '')
    if targetNumber == '' then
        return cb({ ok = true, messages = {} })
    end

    local rows = MySQL.query.await([[
        SELECT id, from_number, to_number, body, created_at
        FROM fivempro_phone_messages
        WHERE (from_citizenid = ? AND to_number = ?)
           OR (to_citizenid = ? AND from_number = ?)
        ORDER BY id ASC
        LIMIT 300
    ]], { citizenid, targetNumber, citizenid, targetNumber }) or {}

    cb({ ok = true, messages = rows })
end)

QBCore.Functions.CreateCallback('fivempro_phone:server:createAd', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local fullname = getFullName(P)
    local number = ensurePhoneUser(citizenid, fullname)
    local body = clampStr(data and data.body or '', (Config.Phone and Config.Phone.maxAdLength) or 260)
    if body == '' then
        return cb({ ok = false, message = 'Skelbimas tuščias.' })
    end
    MySQL.insert.await([[
        INSERT INTO fivempro_phone_ads (citizenid, author_name, phone_number, body)
        VALUES (?, ?, ?, ?)
    ]], { citizenid, fullname, number, body })
    cb({ ok = true })
    local players = QBCore.Functions.GetQBPlayers()
    for sid in pairs(players) do
        TriggerClientEvent('fivempro_phone:client:refreshData', sid)
    end
end)

QBCore.Functions.CreateCallback('fivempro_phone:server:createPost', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local fullname = getFullName(P)
    ensurePhoneUser(citizenid, fullname)
    local cap = clampStr(data and data.caption or '', (Config.Phone and Config.Phone.maxPostCaptionLength) or 260)
    local image = clampStr(data and data.imageUrl or '', (Config.Phone and Config.Phone.maxImageUrlLength) or 500)
    if cap == '' and image == '' then
        return cb({ ok = false, message = 'Įrašas tuščias.' })
    end
    MySQL.insert.await([[
        INSERT INTO fivempro_phone_posts (citizenid, author_name, caption, image_url, likes)
        VALUES (?, ?, ?, ?, 0)
    ]], { citizenid, fullname, cap, image })
    cb({ ok = true })
    local players = QBCore.Functions.GetQBPlayers()
    for sid in pairs(players) do
        TriggerClientEvent('fivempro_phone:client:refreshData', sid)
    end
end)

QBCore.Functions.CreateCallback('fivempro_phone:server:likePost', function(source, cb, data)
    local postId = tonumber(data and data.postId)
    if not postId then return cb({ ok = false }) end
    MySQL.update.await('UPDATE fivempro_phone_posts SET likes = likes + 1 WHERE id = ?', { postId })
    cb({ ok = true })
    TriggerClientEvent('fivempro_phone:client:refreshData', source)
end)

RegisterNetEvent('fivempro_phone:server:startCall', function(data)
    local src = source
    local citizenid, P = getCitizen(src)
    if not citizenid or not P then return end
    local fromName = getFullName(P)
    local fromNumber = ensurePhoneUser(citizenid, fromName)
    local toNumber = digitsOnly(data and data.number or '')
    if toNumber == '' or toNumber == fromNumber then
        return TriggerClientEvent('QBCore:Notify', src, 'Neteisingas numeris.', 'error')
    end

    local target = getUserByNumber(toNumber)
    if not target or not target.citizenid then
        return TriggerClientEvent('QBCore:Notify', src, 'Numeris nerastas.', 'error')
    end
    local targetSrc = sourceByCitizen(target.citizenid)
    if not targetSrc then
        return TriggerClientEvent('QBCore:Notify', src, 'Abonentas nepasiekiamas.', 'error')
    end

    local callId = NextCallId
    NextCallId = NextCallId + 1
    ActiveCalls[callId] = {
        id = callId,
        callerSrc = src,
        calleeSrc = targetSrc,
        callerCid = citizenid,
        calleeCid = target.citizenid,
        fromNumber = fromNumber,
        toNumber = toNumber,
        accepted = false,
        startedAt = os.time(),
    }

    TriggerClientEvent('fivempro_phone:client:callState', src, {
        id = callId,
        status = 'ringing',
        toNumber = toNumber,
    })
    TriggerClientEvent('fivempro_phone:client:incomingCall', targetSrc, {
        id = callId,
        fromNumber = fromNumber,
        fromName = fromName,
    })
end)

RegisterNetEvent('fivempro_phone:server:respondCall', function(data)
    local src = source
    local callId = tonumber(data and data.callId)
    local accept = data and data.accept == true
    local call = callId and ActiveCalls[callId]
    if not call then return end
    if src ~= call.calleeSrc then return end

    if not accept then
        TriggerClientEvent('fivempro_phone:client:callState', call.callerSrc, {
            id = call.id, status = 'rejected'
        })
        TriggerClientEvent('fivempro_phone:client:callState', call.calleeSrc, {
            id = call.id, status = 'ended'
        })
        ActiveCalls[call.id] = nil
        return
    end

    call.accepted = true
    call.connectedAt = os.time()
    TriggerClientEvent('fivempro_phone:client:callState', call.callerSrc, {
        id = call.id,
        status = 'connected',
        peerNumber = call.toNumber,
    })
    TriggerClientEvent('fivempro_phone:client:callState', call.calleeSrc, {
        id = call.id,
        status = 'connected',
        peerNumber = call.fromNumber,
    })
end)

RegisterNetEvent('fivempro_phone:server:endCall', function(data)
    local src = source
    local callId = tonumber(data and data.callId)
    local call = callId and ActiveCalls[callId]
    if not call then return end
    if src ~= call.callerSrc and src ~= call.calleeSrc then return end
    TriggerClientEvent('fivempro_phone:client:callState', call.callerSrc, { id = call.id, status = 'ended' })
    TriggerClientEvent('fivempro_phone:client:callState', call.calleeSrc, { id = call.id, status = 'ended' })
    ActiveCalls[call.id] = nil
end)

AddEventHandler('playerDropped', function()
    local src = source
    for id, call in pairs(ActiveCalls) do
        if call.callerSrc == src or call.calleeSrc == src then
            local other = (call.callerSrc == src) and call.calleeSrc or call.callerSrc
            if other then
                TriggerClientEvent('fivempro_phone:client:callState', other, { id = id, status = 'ended' })
            end
            ActiveCalls[id] = nil
        end
    end
    DeathStartedAt[src] = nil
    LastEmergencyCall[src] = nil
    LastMedicRequest[src] = nil
end)

RegisterNetEvent('fivempro_phone:server:emergencyCall', function(service)
    service = tostring(service or ''):lower()
    if service ~= 'police' and service ~= 'ems' and service ~= 'taxi' then return end
    dispatchEmergency(source, service)
end)

RegisterNetEvent('fivempro_phone:server:reportDeath', function()
    local src = source
    DeathStartedAt[src] = os.time()
end)

RegisterNetEvent('fivempro_phone:server:reportAlive', function()
    local src = source
    DeathStartedAt[src] = nil
end)

RegisterNetEvent('fivempro_phone:server:hospitalWake', function()
    local src = source
    local t0 = DeathStartedAt[src]
    if not t0 then
        return TriggerClientEvent('QBCore:Notify', src, 'Negalima atsikelti.', 'error')
    end
    local need = (Config.HospitalWake and Config.HospitalWake.waitAfterDeathSec) or 900
    if os.time() - t0 < need then
        return TriggerClientEvent('QBCore:Notify', src, ('Dar liko laukti ~%s min.'):format(math.ceil((need - (os.time() - t0)) / 60)), 'error')
    end
    local Player = getPlayer(src)
    if Player then
        Player.Functions.SetMetaData('isdead', false)
        Player.Functions.SetMetaData('inlaststand', false)
    end
    DeathStartedAt[src] = nil
    local ped = GetPlayerPed(src)
    local pos = ped and ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
    local hosp = pickNearestHospital(pos)
    TriggerClientEvent('fivempro_phone:client:hospitalWake', src, { x = hosp.x, y = hosp.y, z = hosp.z, w = hosp.w })
    TriggerClientEvent('QBCore:Notify', src, 'Atsikėlei artimiausioje ligoninėje.', 'success')
end)

RegisterNetEvent('fivempro_phone:server:medicRequestFromDead', function()
    local src = source
    if not DeathStartedAt[src] then
        DeathStartedAt[src] = os.time()
    end
    local now = os.time()
    local last = tonumber(LastMedicRequest[src]) or 0
    local cd = (Config.Emergency and Config.Emergency.medicRequestCooldownSec) or 90
    if now - last < cd then
        return TriggerClientEvent('QBCore:Notify', src, 'Per dažnai – palauk.', 'error')
    end
    LastMedicRequest[src] = now

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    local Player = getPlayer(src)
    local callerName = Player and getFullName(Player) or 'Nežinomas'
    local phone = ''
    if Player then
        phone = ensurePhoneUser(Player.PlayerData.citizenid, callerName)
    end

    local cfg = Config.Emergency or {}
    local count = 0
    for _, P in pairs(QBCore.Functions.GetQBPlayers()) do
        if P and P.PlayerData and P.PlayerData.job and P.PlayerData.job.onduty then
            if P.PlayerData.job.name == (cfg.ambulanceJob or 'ambulance') then
                count = count + 1
                TriggerClientEvent('fivempro_phone:client:serviceDispatch', P.PlayerData.source, {
                    service = 'ems',
                    x = c.x, y = c.y, z = c.z,
                    title = ('MEDIC: %s prašo pagalbos (%s)'):format(callerName, phone),
                    caller = callerName,
                    phone = phone,
                    duration = tonumber(cfg.blipDurationMs) or 120000,
                    sprite = 153,
                    scale = 1.1,
                })
                TriggerClientEvent('QBCore:Notify', P.PlayerData.source, ('Medic: %s – žemėlapyje taškas.'):format(callerName), 'error')
            end
        end
    end
    if count == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Medikai ne duty arba nėra prisijungusių.', 'error')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Medikai iškviesti – EMS pamatys tavo vietą žemėlapyje ir gali atvykti.', 'success')
    end
end)

CreateThread(function()
    math.randomseed(os.time())
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `fivempro_phone_users` (
          `id` int NOT NULL AUTO_INCREMENT,
          `citizenid` varchar(60) NOT NULL,
          `phone_number` varchar(20) NOT NULL,
          `profile_name` varchar(64) NOT NULL DEFAULT 'Player',
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          UNIQUE KEY `uniq_citizen` (`citizenid`),
          UNIQUE KEY `uniq_phone` (`phone_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `fivempro_phone_contacts` (
          `id` int NOT NULL AUTO_INCREMENT,
          `owner_citizenid` varchar(60) NOT NULL,
          `display_name` varchar(60) NOT NULL,
          `contact_number` varchar(20) NOT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_owner` (`owner_citizenid`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `fivempro_phone_messages` (
          `id` int NOT NULL AUTO_INCREMENT,
          `from_citizenid` varchar(60) NOT NULL,
          `to_citizenid` varchar(60) NOT NULL,
          `from_number` varchar(20) NOT NULL,
          `to_number` varchar(20) NOT NULL,
          `body` varchar(320) NOT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_to` (`to_citizenid`),
          KEY `idx_from` (`from_citizenid`),
          KEY `idx_pair` (`from_number`,`to_number`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `fivempro_phone_ads` (
          `id` int NOT NULL AUTO_INCREMENT,
          `citizenid` varchar(60) NOT NULL,
          `author_name` varchar(64) NOT NULL,
          `phone_number` varchar(20) NOT NULL,
          `body` varchar(260) NOT NULL,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `fivempro_phone_posts` (
          `id` int NOT NULL AUTO_INCREMENT,
          `citizenid` varchar(60) NOT NULL,
          `author_name` varchar(64) NOT NULL,
          `caption` varchar(260) NOT NULL,
          `image_url` varchar(500) NOT NULL DEFAULT '',
          `likes` int NOT NULL DEFAULT 0,
          `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
          PRIMARY KEY (`id`),
          KEY `idx_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]])
end)

local phoneItemName = (Config.PhoneItem or 'phone')
QBCore.Functions.CreateUseableItem(phoneItemName, function(src, _item)
    if not exports['qb-inventory']:HasItem(src, phoneItemName, 1) then return end
    TriggerClientEvent('fivempro_phone:client:openPhoneFromItem', src)
end)
