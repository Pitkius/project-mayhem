local QBCore = exports['qb-core']:GetCoreObject()

local ActiveCalls = {}
local NextCallId = 1

local DeathStartedAt = {}
local LastEmergencyCall = {}
local LastMedicRequest = {}

local function trim(s)
    return tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function photosEnabled()
    return Config.Phone and Config.Phone.enablePhotos == true
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

local function ensurePhoneAccount(citizenid, fullname)
    local row = MySQL.single.await('SELECT username FROM fivempro_phone_accounts WHERE citizenid = ? LIMIT 1', { citizenid })
    if row then
        return true, tostring(row.username or fullname or 'Player')
    end
    return false, nil
end

local function getInstalledApps(citizenid)
    local rows = MySQL.query.await('SELECT app_id FROM fivempro_phone_installed_apps WHERE citizenid = ?', { citizenid }) or {}
    local set = {}
    for _, r in ipairs(rows) do
        set[tostring(r.app_id)] = true
    end
    if not photosEnabled() then
        set.camera = nil
        set.gallery = nil
    end
    return set
end

local function ensureDefaultInstalledApps(citizenid)
    local row = MySQL.single.await('SELECT id FROM fivempro_phone_accounts WHERE citizenid = ? LIMIT 1', { citizenid })
    if not row then return end
    for _, app in ipairs((Config.Phone and Config.Phone.AppStoreApps) or {}) do
        if app.default == true then
            local appId = tostring(app.id or '')
            if appId ~= '' and (photosEnabled() or (appId ~= 'camera' and appId ~= 'gallery')) then
                MySQL.insert.await('INSERT IGNORE INTO fivempro_phone_installed_apps (citizenid, app_id) VALUES (?, ?)', {
                    citizenid, appId
                })
            end
        end
    end
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

local function syncCharinfoPhone(src, phone)
    if not src or not phone then return end
    local P = getPlayer(src)
    if not P or not P.PlayerData then return end
    phone = tostring(phone)
    local c = P.PlayerData.charinfo or {}
    if tostring(c.phone or '') == phone then return end
    if P.Functions and P.Functions.SetCharInfo then
        P.Functions.SetCharInfo('phone', phone)
    else
        c.phone = phone
        P.Functions.SetPlayerData('charinfo', c)
    end
end

local function setPhoneCallVoice(call, channel)
    if GetResourceState('pma-voice') ~= 'started' then return end
    if not call then return end
    channel = tonumber(channel) or 0
    pcall(function()
        exports['pma-voice']:setPlayerCall(call.callerSrc, channel)
        exports['pma-voice']:setPlayerCall(call.calleeSrc, channel)
    end)
end

local function endPhoneCall(call, status)
    if not call then return end
    setPhoneCallVoice(call, 0)
    TriggerClientEvent('mrp_phone:client:callState', call.callerSrc, { id = call.id, status = status or 'ended' })
    TriggerClientEvent('mrp_phone:client:callState', call.calleeSrc, { id = call.id, status = status or 'ended' })
    ActiveCalls[call.id] = nil
end

local function getMessageThreads(citizenid)
    local rows = MySQL.query.await([[
        SELECT id, from_citizenid, to_citizenid, from_number, to_number, body, created_at
        FROM fivempro_phone_messages
        WHERE from_citizenid = ? OR to_citizenid = ?
        ORDER BY id DESC
        LIMIT 500
    ]], { citizenid, citizenid }) or {}

    local threads = {}
    local seen = {}
    for _, m in ipairs(rows) do
        local peer = (m.from_citizenid == citizenid) and tostring(m.to_number) or tostring(m.from_number)
        if peer ~= '' and not seen[peer] then
            seen[peer] = true
            threads[#threads + 1] = {
                peer_number = peer,
                last_body = tostring(m.body or ''),
                last_at = m.created_at,
                direction = (m.from_citizenid == citizenid) and 'out' or 'in',
            }
        end
    end
    return threads
end

local function getDefaultContactsConfig()
    local out = {}
    for _, def in ipairs((Config.Phone and Config.Phone.DefaultContacts) or {}) do
        local service = tostring(def.service or def.key or '')
        out[#out + 1] = {
            key = tostring(def.key or ''),
            name = tostring(def.name or ''),
            number = digitsOnly(def.number or ''),
            service = service,
            icon = tostring(def.icon or ('service-' .. service)),
        }
    end
    if #out == 0 then
        out = {
            { key = 'police', name = 'Policija', number = '112', service = 'police', icon = 'service-police' },
            { key = 'ems', name = 'Greitoji pagalba', number = '113', service = 'ems', icon = 'service-ems' },
            { key = 'mechanic', name = 'Mechanikas', number = '111', service = 'mechanic', icon = 'service-mechanic' },
            { key = 'taxi', name = 'Taksi', number = '1818', service = 'taxi', icon = 'service-taxi' },
        }
    end
    return out
end

local function getServiceByHotline(number)
    number = digitsOnly(number)
    if number == '' then return nil end
    for _, def in ipairs(getDefaultContactsConfig()) do
        if def.number == number then
            return def.service
        end
    end
    return nil
end

local function isSystemContactNumber(number)
    return getServiceByHotline(number) ~= nil
end

local LEGACY_DEFAULT_NUMBERS = { '110', '1313' }

local function migrateLegacyDefaultContacts(citizenid)
    if not citizenid then return end
    for _, num in ipairs(LEGACY_DEFAULT_NUMBERS) do
        MySQL.update.await('DELETE FROM fivempro_phone_contacts WHERE owner_citizenid = ? AND contact_number = ?', {
            citizenid, num,
        })
    end
    MySQL.update.await([[
        DELETE FROM fivempro_phone_contacts
        WHERE owner_citizenid = ? AND contact_number = '112' AND display_name = 'Greitoji pagalba'
    ]], { citizenid })
end

local function ensureDefaultContacts(citizenid)
    if not citizenid then return end
    migrateLegacyDefaultContacts(citizenid)
    for _, def in ipairs(getDefaultContactsConfig()) do
        local num = def.number
        local name = clampStr(def.name, 60)
        if num == '' or name == '' then goto continue end
        local existing = MySQL.single.await([[
            SELECT id FROM fivempro_phone_contacts
            WHERE owner_citizenid = ? AND contact_number = ?
            LIMIT 1
        ]], { citizenid, num })
        if existing then
            MySQL.update.await([[
                UPDATE fivempro_phone_contacts
                SET display_name = ?
                WHERE id = ? AND owner_citizenid = ?
            ]], { name, existing.id, citizenid })
        else
            MySQL.insert.await([[
                INSERT INTO fivempro_phone_contacts (owner_citizenid, display_name, contact_number)
                VALUES (?, ?, ?)
            ]], { citizenid, name, num })
        end
        ::continue::
    end
end

local function enrichContacts(rows)
    for i = 1, #rows do
        local row = rows[i]
        local service = getServiceByHotline(row.contact_number)
        row.is_system = service ~= nil
        if service then
            row.service = service
            for _, def in ipairs(getDefaultContactsConfig()) do
                if def.service == service then
                    row.system_icon = def.icon
                    break
                end
            end
        end
    end
    return rows
end

local function getAdCategories()
    local out = {}
    for _, cat in ipairs((Config.Phone and Config.Phone.AdCategories) or {}) do
        out[#out + 1] = {
            id = tostring(cat.id or ''),
            label = tostring(cat.label or cat.id or ''),
        }
    end
    if #out == 0 then
        out = {
            { id = 'all', label = 'Visi' },
            { id = 'other', label = 'Kita' },
        }
    end
    return out
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

--- Sistemos / â€žneÅ¾inomo numerio" SMS iÅ¡ kito resurso (pvz. mrp_drugs Dark Net).
--- Ä®raÅ¡o Å¾inutÄ™ Ä¯ veikÄ—jo pokalbiÅ³ istorijÄ… ir notifikuoja, jei Å¾aidÄ—jas online.
--- @param toCitizenid string   GavÄ—jo citizenid
--- @param fromNumber  string   Rodyti kaip siuntÄ—jo numerÄ¯ (pvz. '000000')
--- @param body        string   Å½inutÄ—s tekstas
--- @return boolean ok
exports('SendSystemSMS', function(toCitizenid, fromNumber, body)
    toCitizenid = tostring(toCitizenid or '')
    fromNumber = digitsOnly(fromNumber or '') 
    if fromNumber == '' then fromNumber = '000000' end
    body = clampStr(body or '', (Config.Phone and Config.Phone.maxMessageLength) or 320)
    if toCitizenid == '' or body == '' then return false end

    local toNumber = getNumberByCitizen(toCitizenid) or ''

    MySQL.insert.await([[
        INSERT INTO fivempro_phone_messages
        (from_citizenid, to_citizenid, from_number, to_number, body)
        VALUES (?, ?, ?, ?, ?)
    ]], { 'SYSTEM', toCitizenid, fromNumber, toNumber, body })

    local targetSrc = sourceByCitizen(toCitizenid)
    if targetSrc then
        TriggerClientEvent('mrp_phone:client:newMessageNotify', targetSrc, fromNumber)
        TriggerClientEvent('mrp_phone:client:refreshData', targetSrc)
    end
    return true
end)

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

local function dispatchEmergency(src, service, clientCoords)
    service = tostring(service or ''):lower()
    local cfg = Config.Emergency or {}
    local now = os.time()
    LastEmergencyCall[src] = LastEmergencyCall[src] or {}
    local last = tonumber(LastEmergencyCall[src][service]) or 0
    if now - last < (tonumber(cfg.callCooldownSec) or 45) then
        return TriggerClientEvent('QBCore:Notify', src, 'Palaukite prieÅ¡ kitÄ… skambutÄ¯.', 'error')
    end
    LastEmergencyCall[src][service] = now

    local c
    if type(clientCoords) == 'table' and clientCoords.x ~= nil and clientCoords.y ~= nil then
        c = vector3(clientCoords.x + 0.0, clientCoords.y + 0.0, (clientCoords.z or 0.0) + 0.0)
    else
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 then return end
        c = GetEntityCoords(ped)
    end
    local Player = getPlayer(src)
    if not Player then return end
    local callerName = getFullName(Player)
    local phone = ensurePhoneUser(Player.PlayerData.citizenid, callerName)

    local labels = {
        police = ('Policija: %s skambina (%s)'):format(callerName, phone),
        ems = ('Greitoji: %s skambina (%s)'):format(callerName, phone),
        taxi = ('Taksi: %s skambina (%s)'):format(callerName, phone),
        mechanic = ('Mechanikas: %s praÅ¡o pagalbos (%s)'):format(callerName, phone),
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
            elseif service == 'mechanic' then
                match = jn == (cfg.mechanicJob or 'mechanic')
            end
            if match then
                count = count + 1
                TriggerClientEvent('mrp_phone:client:serviceDispatch', P.PlayerData.source, {
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

    if GetResourceState('mrp_dispatch') == 'started' then
        exports['mrp_dispatch']:CreateDispatchCall(
            service == 'taxi' and 'mechanic' or service,
            'civilian_help',
            { x = c.x, y = c.y, z = c.z },
            title,
            src
        )
    end

    if count == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Å iuo metu niekas neatsiliepia (tarnyba ne duty).', 'error')
    else
        TriggerClientEvent('QBCore:Notify', src, ('Skambutis perduotas (%s pareigÅ«nÅ³).'):format(count), 'success')
    end
end

local function getPendingIncomingCallFor(src)
    for _, call in pairs(ActiveCalls) do
        if call.calleeSrc == src and not call.accepted then
            local fromName = ''
            local caller = getPlayer(call.callerSrc)
            if caller and caller.PlayerData and caller.PlayerData.charinfo then
                local c = caller.PlayerData.charinfo
                fromName = trim(('%s %s'):format(c.firstname or '', c.lastname or ''))
            end
            return {
                id = call.id,
                fromNumber = call.fromNumber,
                fromName = fromName,
            }
        end
    end
    return nil
end

local function getInitialDataFor(src)
    local citizenid, P = getCitizen(src)
    if not citizenid then return nil end
    local fullname = getFullName(P)
    local myNumber, profile = ensurePhoneUser(citizenid, fullname)
    ensureDefaultContacts(citizenid)
    ensureDefaultInstalledApps(citizenid)

    local contacts = MySQL.query.await([[
        SELECT id, display_name, contact_number
        FROM fivempro_phone_contacts
        WHERE owner_citizenid = ?
        ORDER BY display_name ASC, id ASC
    ]], { citizenid }) or {}
    contacts = enrichContacts(contacts)

    local msgs = MySQL.query.await([[
        SELECT id, from_number, to_number, body, created_at
        FROM fivempro_phone_messages
        WHERE from_citizenid = ? OR to_citizenid = ?
        ORDER BY id DESC
        LIMIT 120
    ]], { citizenid, citizenid }) or {}

    local ads = MySQL.query.await([[
        SELECT id, citizenid, author_name, phone_number, category, title, price, body, image_urls, created_at
        FROM fivempro_phone_ads
        ORDER BY id DESC
        LIMIT 120
    ]]) or {}

    local photos = {}
    if photosEnabled() then
        photos = MySQL.query.await([[
            SELECT id, is_front, created_at
            FROM fivempro_phone_photos
            WHERE citizenid = ?
            ORDER BY id DESC
            LIMIT 80
        ]], { citizenid }) or {}
    end

    local adProfile = MySQL.single.await([[
        SELECT username, bio, avatar_data, created_at
        FROM fivempro_phone_ad_profiles
        WHERE citizenid = ?
        LIMIT 1
    ]], { citizenid })

    local notesRows = MySQL.query.await([[
        SELECT id, title, body, created_at, updated_at
        FROM fivempro_phone_notes
        WHERE citizenid = ?
        ORDER BY updated_at DESC
        LIMIT ?
    ]], { citizenid, (Config.Phone and Config.Phone.maxNotes) or 50 }) or {}

    local notes = {}
    for _, row in ipairs(notesRows) do
        notes[#notes + 1] = {
            id = row.id,
            title = tostring(row.title or ''),
            body = tostring(row.body or ''),
            created_at = row.created_at,
            updated_at = row.updated_at,
        }
    end

    local posts = MySQL.query.await([[
        SELECT id, author_name, caption, image_url, likes, created_at
        FROM fivempro_phone_posts
        ORDER BY id DESC
        LIMIT 120
    ]]) or {}

    local hasAccount, username = ensurePhoneAccount(citizenid, fullname)
    local installed = getInstalledApps(citizenid)
    local availableApps = {}
    for _, app in ipairs((Config.Phone and Config.Phone.AppStoreApps) or {}) do
        local appId = tostring(app.id or '')
        if not photosEnabled() and (appId == 'camera' or appId == 'gallery') then
            goto continue_app
        end
        availableApps[#availableApps + 1] = {
            id = appId,
            label = tostring(app.label or app.id or ''),
            icon = tostring(app.icon or 'appstore'),
            description = tostring(app.description or ''),
            installed = installed[appId] == true,
            default = app.default == true,
        }
        ::continue_app::
    end

    local cash = 0
    local bank = 0
    if P and P.PlayerData and P.PlayerData.money then
        cash = tonumber(P.PlayerData.money.cash) or 0
        bank = tonumber(P.PlayerData.money.bank) or 0
    end

    syncCharinfoPhone(src, myNumber)

    return {
        ok = true,
        me = {
            number = myNumber,
            name = profile,
            citizenid = citizenid,
        },
        money = {
            cash = cash,
            bank = bank,
        },
        account = {
            hasAccount = hasAccount,
            username = username or '',
        },
        appStore = {
            availableApps = availableApps,
            installed = installed,
        },
        contacts = contacts,
        messagePreview = msgs,
        messageThreads = getMessageThreads(citizenid),
        ads = ads,
        adCategories = getAdCategories(),
        adProfile = adProfile and {
            username = tostring(adProfile.username or ''),
            bio = tostring(adProfile.bio or ''),
            hasAvatar = (PhotoStorage and PhotoStorage.hasAvatar(citizenid))
                or (adProfile.avatar_data ~= nil and adProfile.avatar_data ~= ''),
            created_at = adProfile.created_at,
        } or nil,
        photos = photos,
        notes = notes,
        notesOldDays = (Config.Phone and Config.Phone.notesOldDays) or 30,
        posts = posts,
        pendingIncomingCall = getPendingIncomingCallFor(src),
    }
end

QBCore.Functions.CreateCallback('mrp_phone:server:getInitialData', function(source, cb)
    local data = getInitialDataFor(source)
    cb(data or { ok = false })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:saveContact', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end
    local fullname = getFullName(P)
    ensurePhoneUser(citizenid, fullname)

    local maxContacts = (Config.Phone and Config.Phone.maxContacts) or 120
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM fivempro_phone_contacts WHERE owner_citizenid = ?', { citizenid }) or 0
    if tonumber(count) >= maxContacts then
        return cb({ ok = false, message = 'KontaktÅ³ limitas pasiektas.' })
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
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:updateContact', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end

    local contactId = tonumber(data and data.id)
    local name = clampStr(data and data.name or '', 60)
    local number = digitsOnly(data and data.number or '')
    if not contactId or name == '' or number == '' then
        return cb({ ok = false, message = 'Blogi duomenys.' })
    end

    local row = MySQL.single.await([[
        SELECT id, contact_number FROM fivempro_phone_contacts
        WHERE id = ? AND owner_citizenid = ? LIMIT 1
    ]], { contactId, citizenid })
    if not row then
        return cb({ ok = false, message = 'Kontaktas nerastas.' })
    end
    if isSystemContactNumber(row.contact_number) then
        return cb({ ok = false, message = 'Tarnybos kontakto redaguoti negalima.' })
    end

    MySQL.update.await([[
        UPDATE fivempro_phone_contacts
        SET display_name = ?, contact_number = ?
        WHERE id = ? AND owner_citizenid = ?
    ]], { name, number, contactId, citizenid })

    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:deleteContact', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end

    local contactId = tonumber(data and data.id)
    if not contactId then return cb({ ok = false, message = 'Blogi duomenys.' }) end

    local row = MySQL.single.await([[
        SELECT contact_number FROM fivempro_phone_contacts
        WHERE id = ? AND owner_citizenid = ? LIMIT 1
    ]], { contactId, citizenid })
    if not row then
        return cb({ ok = false, message = 'Kontaktas nerastas.' })
    end
    if isSystemContactNumber(row.contact_number) then
        return cb({ ok = false, message = 'Tarnybos kontakto paÅ¡alinti negalima.' })
    end

    MySQL.update.await('DELETE FROM fivempro_phone_contacts WHERE id = ? AND owner_citizenid = ?', {
        contactId, citizenid
    })
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:sendMessage', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local fullname = getFullName(P)
    local fromNumber = ensurePhoneUser(citizenid, fullname)
    local toNumber = digitsOnly(data and data.number or '')
    local body = clampStr(data and data.body or '', (Config.Phone and Config.Phone.maxMessageLength) or 320)

    if toNumber == '' or body == '' then
        return cb({ ok = false, message = 'Ä®vesk numerÄ¯ ir Å¾inutÄ™.' })
    end
    if toNumber == fromNumber then
        return cb({ ok = false, message = 'Negali raÅ¡yti sau.' })
    end
    if isSystemContactNumber(toNumber) then
        return cb({ ok = false, message = 'Å is numeris skirtas skambuÄiams, ne Å¾inutÄ—ms.' })
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
        TriggerClientEvent('mrp_phone:client:newMessageNotify', targetSrc, fromNumber)
        TriggerClientEvent('mrp_phone:client:refreshData', targetSrc)
    end

    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:getConversation', function(source, cb, data)
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

QBCore.Functions.CreateCallback('mrp_phone:server:createAd', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local fullname = getFullName(P)
    local number = ensurePhoneUser(citizenid, fullname)
    local title = clampStr(data and data.title or '', (Config.Phone and Config.Phone.maxAdTitleLength) or 48)
    local category = clampStr(data and data.category or 'other', 24):lower()
    local price = math.max(0, math.floor(tonumber(data and data.price) or 0))
    local body = clampStr(data and data.body or '', (Config.Phone and Config.Phone.maxAdLength) or 260)
    if body == '' then
        return cb({ ok = false, message = 'Skelbimas tuÅ¡Äias.' })
    end
    if title == '' then
        title = body:sub(1, math.min(48, #body))
    end
    local imageUrls = ''
    if type(data and data.imagePhotoIds) == 'table' then
        local parts = {}
        for _, pid in ipairs(data.imagePhotoIds) do
            local n = tonumber(pid)
            if n then
                local owned = MySQL.scalar.await(
                    'SELECT id FROM fivempro_phone_photos WHERE id = ? AND citizenid = ? LIMIT 1',
                    { n, citizenid }
                )
                if owned then parts[#parts + 1] = ('p:%s'):format(n) end
            end
        end
        imageUrls = table.concat(parts, '|')
    elseif type(data and data.imageUrls) == 'table' then
        local parts = {}
        for _, u in ipairs(data.imageUrls) do
            local s = clampStr(u, (Config.Phone and Config.Phone.maxImageUrlLength) or 500)
            if s ~= '' then parts[#parts + 1] = s end
        end
        imageUrls = table.concat(parts, '||')
    elseif data and data.imageUrl then
        imageUrls = clampStr(data.imageUrl, (Config.Phone and Config.Phone.maxImageUrlLength) or 500)
    end
    MySQL.insert.await([[
        INSERT INTO fivempro_phone_ads (citizenid, author_name, phone_number, category, title, price, body, image_urls)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], { citizenid, fullname, number, category, title, price, body, imageUrls })
    cb({ ok = true })
    local players = QBCore.Functions.GetQBPlayers()
    for sid in pairs(players) do
        TriggerClientEvent('mrp_phone:client:refreshData', sid)
    end
end)

local function normalizePhotoImageData(raw)
    local imageData = tostring(raw or '')
    imageData = imageData:match('^%s*(.-)%s*$') or ''
    if imageData == '' then return '' end

    if imageData:sub(1, 1) == '{' then
        local ok, parsed = pcall(json.decode, imageData)
        if ok and type(parsed) == 'table' and type(parsed.data) == 'string' then
            imageData = parsed.data:match('^%s*(.-)%s*$') or ''
        end
    end

    if imageData ~= '' and not imageData:find('^data:') then
        if imageData:sub(1, 3) == '/9j' then
            imageData = 'data:image/jpeg;base64,' .. imageData
        elseif imageData:sub(1, 8) == 'iVBORw0K' then
            imageData = 'data:image/png;base64,' .. imageData
        else
            imageData = 'data:image/jpeg;base64,' .. imageData
        end
    end

    return imageData
end

QBCore.Functions.CreateCallback('mrp_phone:server:savePhoto', function(source, cb, data)
    if not photosEnabled() then
        return cb({ ok = false, message = 'Telefono nuotraukos iÅ¡jungtos serveryje.' })
    end
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end
    local imageData = normalizePhotoImageData(data and data.imageData)
    local maxLen = (Config.Phone and Config.Phone.maxPhotoDataLength) or 750000
    if imageData == '' or #imageData < 32 then
        return cb({ ok = false, message = 'TuÅ¡Äia nuotrauka.' })
    end
    if #imageData > maxLen then
        return cb({ ok = false, message = 'Nuotrauka per didelÄ—. Bandyk dar kartÄ….' })
    end
    local maxPhotos = (Config.Phone and Config.Phone.maxPhotosPerUser) or 48
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM fivempro_phone_photos WHERE citizenid = ?', { citizenid }) or 0
    if tonumber(count) >= maxPhotos then
        local oldest = MySQL.single.await(
            'SELECT id, file_key FROM fivempro_phone_photos WHERE citizenid = ? ORDER BY id ASC LIMIT 1',
            { citizenid }
        )
        if oldest then
            if PhotoStorage and oldest.file_key then
                PhotoStorage.deletePhotoFile(oldest.file_key)
            end
            MySQL.update.await('DELETE FROM fivempro_phone_photos WHERE id = ?', { oldest.id })
        end
    end
    local isFront = (data and data.front == true) and 1 or 0
    local zoom = tonumber(data and data.zoom) or 1.0
    --- Pirma eilutÄ— be blob â€” tada failas ant disko
    local id = MySQL.insert.await([[
        INSERT INTO fivempro_phone_photos (citizenid, image_data, file_key, is_front, zoom_level)
        VALUES (?, NULL, '', ?, ?)
    ]], { citizenid, isFront, zoom })
    if not id then
        return cb({ ok = false, message = 'Nepavyko iÅ¡saugoti.' })
    end
    local fileKey = PhotoStorage and PhotoStorage.writePhoto(id, imageData)
    if not fileKey then
        MySQL.update.await('DELETE FROM fivempro_phone_photos WHERE id = ?', { id })
        return cb({ ok = false, message = 'Nepavyko Ä¯raÅ¡yti nuotraukos Ä¯ diskÄ….' })
    end
    MySQL.update.await('UPDATE fivempro_phone_photos SET file_key = ? WHERE id = ?', { fileKey, id })
    local newCount = MySQL.scalar.await('SELECT COUNT(*) FROM fivempro_phone_photos WHERE citizenid = ?', { citizenid }) or 0
    cb({ ok = true, id = id, count = tonumber(newCount) or 0 })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:getPhoto', function(source, cb, data)
    if not photosEnabled() then
        return cb({ ok = false, message = 'Telefono nuotraukos iÅ¡jungtos serveryje.' })
    end
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local photoId = tonumber(data and data.id)
    if not photoId then return cb({ ok = false }) end
    local row = MySQL.single.await([[
        SELECT id, image_data, file_key, is_front, created_at
        FROM fivempro_phone_photos
        WHERE id = ? AND citizenid = ?
        LIMIT 1
    ]], { photoId, citizenid })
    if not row then return cb({ ok = false, message = 'Nuotrauka nerasta.' }) end

    local imageData = ''
    if row.file_key and row.file_key ~= '' and PhotoStorage then
        imageData = PhotoStorage.readPhotoDataUrl(row.id, row.file_key)
    end
    if imageData == '' or #imageData < 32 then
        imageData = normalizePhotoImageData(row.image_data)
        --- Lazy migrate jei dar MySQL blob
        if imageData ~= '' and PhotoStorage then
            local key = PhotoStorage.writePhoto(row.id, imageData)
            if key then
                MySQL.update.await(
                    'UPDATE fivempro_phone_photos SET file_key = ?, image_data = NULL WHERE id = ?',
                    { key, row.id }
                )
            end
        end
    end
    if imageData == '' or #imageData < 32 then
        return cb({ ok = false, message = 'Nuotraukos duomenys sugadinti.' })
    end
    cb({
        ok = true,
        photo = {
            id = row.id,
            image = imageData,
            is_front = row.is_front == 1,
            created_at = row.created_at,
        },
    })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:deletePhoto', function(source, cb, data)
    if not photosEnabled() then
        return cb({ ok = false, message = 'Telefono nuotraukos iÅ¡jungtos serveryje.' })
    end
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local photoId = tonumber(data and data.id)
    if not photoId then return cb({ ok = false }) end
    local row = MySQL.single.await(
        'SELECT file_key FROM fivempro_phone_photos WHERE id = ? AND citizenid = ? LIMIT 1',
        { photoId, citizenid }
    )
    if row and PhotoStorage and row.file_key then
        PhotoStorage.deletePhotoFile(row.file_key)
    end
    MySQL.update.await('DELETE FROM fivempro_phone_photos WHERE id = ? AND citizenid = ?', { photoId, citizenid })
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:saveNotes', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end

    local noteId = tonumber(data and data.id)
    local title = clampStr(data and data.title or '', (Config.Phone and Config.Phone.maxNoteTitleLength) or 64)
    local body = tostring(data and data.body or '')
    local maxLen = (Config.Phone and Config.Phone.maxNotesLength) or 8000
    local maxNotes = (Config.Phone and Config.Phone.maxNotes) or 50

    if title == '' then
        return cb({ ok = false, message = 'Ä®veskite uÅ¾raÅ¡o pavadinimÄ….' })
    end
    if body == '' then
        return cb({ ok = false, message = 'UÅ¾raÅ¡as negali bÅ«ti tuÅ¡Äias.' })
    end
    if #body > maxLen then
        body = body:sub(1, maxLen)
    end

    if noteId then
        local owned = MySQL.scalar.await(
            'SELECT id FROM fivempro_phone_notes WHERE id = ? AND citizenid = ? LIMIT 1',
            { noteId, citizenid }
        )
        if not owned then
            return cb({ ok = false, message = 'UÅ¾raÅ¡as nerastas.' })
        end
        MySQL.update.await(
            'UPDATE fivempro_phone_notes SET title = ?, body = ? WHERE id = ? AND citizenid = ?',
            { title, body, noteId, citizenid }
        )
        return cb({ ok = true, note = { id = noteId, title = title, body = body } })
    end

    local count = MySQL.scalar.await(
        'SELECT COUNT(*) FROM fivempro_phone_notes WHERE citizenid = ?',
        { citizenid }
    ) or 0
    if tonumber(count) >= maxNotes then
        return cb({ ok = false, message = ('Galima iÅ¡saugoti ne daugiau kaip %d uÅ¾raÅ¡Å³.'):format(maxNotes) })
    end

    local newId = MySQL.insert.await(
        'INSERT INTO fivempro_phone_notes (citizenid, title, body) VALUES (?, ?, ?)',
        { citizenid, title, body }
    )
    cb({ ok = true, note = { id = newId, title = title, body = body } })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:deleteNote', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end
    local noteId = tonumber(data and data.id)
    if not noteId then return cb({ ok = false, message = 'UÅ¾raÅ¡as nerastas.' }) end
    MySQL.update.await('DELETE FROM fivempro_phone_notes WHERE id = ? AND citizenid = ?', { noteId, citizenid })
    cb({ ok = true })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:deleteOldNotes', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end

    local cfgDays = (Config.Phone and Config.Phone.notesOldDays) or 30
    local days = tonumber(data and data.olderThanDays) or cfgDays
    days = math.max(1, math.min(math.floor(days), 365))

    local deleted = MySQL.update.await(
        'DELETE FROM fivempro_phone_notes WHERE citizenid = ? AND updated_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
        { citizenid, days }
    ) or 0

    cb({ ok = true, deleted = tonumber(deleted) or 0, olderThanDays = days })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:saveAdProfile', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local username = clampStr(data and data.username or '', 24)
    local bio = clampStr(data and data.bio or '', 200)
    if username == '' then
        return cb({ ok = false, message = 'Ä®veskite vartotojo vardÄ….' })
    end
    local taken = MySQL.single.await([[
        SELECT citizenid FROM fivempro_phone_ad_profiles
        WHERE username = ? AND citizenid <> ? LIMIT 1
    ]], { username, citizenid })
    if taken then
        return cb({ ok = false, message = 'Vartotojo vardas uÅ¾imtas.' })
    end
    local avatar = data and data.avatarData
    if avatar ~= nil and avatar ~= '' then
        avatar = normalizePhotoImageData(avatar)
        local maxLen = (Config.Phone and Config.Phone.maxPhotoDataLength) or 750000
        if #avatar > maxLen then
            return cb({ ok = false, message = 'Avataras per didelis.' })
        end
        if PhotoStorage and not PhotoStorage.writeAvatar(citizenid, avatar) then
            return cb({ ok = false, message = 'Nepavyko iÅ¡saugoti avataro.' })
        end
        avatar = nil --- nebe Ä¯ MySQL
    else
        avatar = false --- nepaliesti
    end
    local exists = MySQL.single.await('SELECT id FROM fivempro_phone_ad_profiles WHERE citizenid = ? LIMIT 1', { citizenid })
    if exists then
        MySQL.update.await([[
            UPDATE fivempro_phone_ad_profiles SET username = ?, bio = ?, avatar_data = NULL WHERE citizenid = ?
        ]], { username, bio, citizenid })
    else
        MySQL.insert.await([[
            INSERT INTO fivempro_phone_ad_profiles (citizenid, username, bio, avatar_data)
            VALUES (?, ?, ?, NULL)
        ]], { citizenid, username, bio })
    end
    --- Jei avatar nebuvo atsiÅ³stas â€” palikti esamÄ… failÄ… (avatar == false)
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:getAdProfileAvatar', function(source, cb, data)
    local targetCid = clampStr(data and data.citizenid or '', 60)
    if targetCid == '' then return cb({ ok = false }) end
    local avatar = ''
    if PhotoStorage then
        avatar = PhotoStorage.readAvatarDataUrl(targetCid)
    end
    if avatar == '' then
        local row = MySQL.single.await([[
            SELECT avatar_data FROM fivempro_phone_ad_profiles WHERE citizenid = ? LIMIT 1
        ]], { targetCid })
        avatar = normalizePhotoImageData(row and row.avatar_data or '')
        if avatar ~= '' and PhotoStorage then
            PhotoStorage.writeAvatar(targetCid, avatar)
            MySQL.update.await('UPDATE fivempro_phone_ad_profiles SET avatar_data = NULL WHERE citizenid = ?', { targetCid })
        end
    end
    cb({ ok = true, avatar = avatar })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:deleteAd', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local adId = tonumber(data and data.adId)
    if not adId then return cb({ ok = false, message = 'Blogas ID.' }) end
    local row = MySQL.single.await('SELECT id FROM fivempro_phone_ads WHERE id = ? AND citizenid = ? LIMIT 1', {
        adId, citizenid
    })
    if not row then
        return cb({ ok = false, message = 'Skelbimas nerastas arba ne jÅ«sÅ³.' })
    end
    MySQL.update.await('DELETE FROM fivempro_phone_ads WHERE id = ? AND citizenid = ?', { adId, citizenid })
    cb({ ok = true })
    local players = QBCore.Functions.GetQBPlayers()
    for sid in pairs(players) do
        TriggerClientEvent('mrp_phone:client:refreshData', sid)
    end
end)

QBCore.Functions.CreateCallback('mrp_phone:server:createPost', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local fullname = getFullName(P)
    ensurePhoneUser(citizenid, fullname)
    local cap = clampStr(data and data.caption or '', (Config.Phone and Config.Phone.maxPostCaptionLength) or 260)
    local image = clampStr(data and data.imageUrl or '', (Config.Phone and Config.Phone.maxImageUrlLength) or 500)
    --- Galerijos nuotrauka: gallery:123 (tik savininko)
    local galleryId = tostring(image):match('^gallery:(%d+)$')
    if galleryId then
        if not photosEnabled() then
            return cb({ ok = false, message = 'Nuotraukos iÅ¡jungtos.' })
        end
        local owned = MySQL.scalar.await(
            'SELECT id FROM fivempro_phone_photos WHERE id = ? AND citizenid = ? LIMIT 1',
            { tonumber(galleryId), citizenid }
        )
        if not owned then
            return cb({ ok = false, message = 'Nuotrauka nerasta galerijoje.' })
        end
        image = ('gallery:%s'):format(galleryId)
    end
    if cap == '' and image == '' then
        return cb({ ok = false, message = 'Ä®raÅ¡as tuÅ¡Äias.' })
    end
    MySQL.insert.await([[
        INSERT INTO fivempro_phone_posts (citizenid, author_name, caption, image_url, likes)
        VALUES (?, ?, ?, ?, 0)
    ]], { citizenid, fullname, cap, image })
    cb({ ok = true })
    local players = QBCore.Functions.GetQBPlayers()
    for sid in pairs(players) do
        TriggerClientEvent('mrp_phone:client:refreshData', sid)
    end
end)

QBCore.Functions.CreateCallback('mrp_phone:server:likePost', function(source, cb, data)
    local postId = tonumber(data and data.postId)
    if not postId then return cb({ ok = false }) end
    MySQL.update.await('UPDATE fivempro_phone_posts SET likes = likes + 1 WHERE id = ?', { postId })
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:createAccount', function(source, cb, data)
    local citizenid, P = getCitizen(source)
    if not citizenid or not P then return cb({ ok = false, message = 'Å½aidÄ—jas nerastas' }) end
    local fullname = getFullName(P)
    ensurePhoneUser(citizenid, fullname)

    local username = clampStr(data and data.username or '', 24)
    local pass = clampStr(data and data.password or '', 64)
    if username == '' or pass == '' then
        return cb({ ok = false, message = 'UÅ¾pildyk username ir slaptaÅ¾odÄ¯.' })
    end
    local exists = MySQL.single.await('SELECT id FROM fivempro_phone_accounts WHERE citizenid = ? LIMIT 1', { citizenid })
    if exists then
        return cb({ ok = false, message = 'Paskyra jau sukurta.' })
    end
    local usernameTaken = MySQL.single.await('SELECT id FROM fivempro_phone_accounts WHERE username = ? LIMIT 1', { username })
    if usernameTaken then
        return cb({ ok = false, message = 'Username jau uÅ¾imtas.' })
    end
    --- bcrypt via FiveM natives (never store plaintext)
    local passhash = GetPasswordHash(pass)
    if not passhash or passhash == '' then
        return cb({ ok = false, message = 'Nepavyko uÅ¾Å¡ifruoti slaptaÅ¾odÅ¾io.' })
    end
    MySQL.insert.await('INSERT INTO fivempro_phone_accounts (citizenid, username, passhash) VALUES (?, ?, ?)', {
        citizenid, username, passhash
    })
    for _, app in ipairs((Config.Phone and Config.Phone.AppStoreApps) or {}) do
        if app.default == true then
            MySQL.insert.await('INSERT IGNORE INTO fivempro_phone_installed_apps (citizenid, app_id) VALUES (?, ?)', {
                citizenid, tostring(app.id)
            })
        end
    end
    ensureDefaultContacts(citizenid)
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:installApp', function(source, cb, data)
    local citizenid = getCitizen(source)
    if not citizenid then return cb({ ok = false }) end
    local appId = tostring(data and data.appId or '')
    if appId == '' then return cb({ ok = false, message = 'Blogas appId' }) end
    local allowed = false
    for _, app in ipairs((Config.Phone and Config.Phone.AppStoreApps) or {}) do
        if tostring(app.id) == appId then
            allowed = true
            break
        end
    end
    if not allowed then return cb({ ok = false, message = 'ProgramÄ—lÄ— neegzistuoja.' }) end
    if not photosEnabled() and (appId == 'camera' or appId == 'gallery') then
        return cb({ ok = false, message = 'Nuotraukos iÅ¡jungtos serveryje.' })
    end
    MySQL.insert.await('INSERT IGNORE INTO fivempro_phone_installed_apps (citizenid, app_id) VALUES (?, ?)', {
        citizenid, appId
    })
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

RegisterNetEvent('mrp_phone:server:startCall', function(data)
    local src = source
    local citizenid, P = getCitizen(src)
    if not citizenid or not P then return end
    local fromName = getFullName(P)
    local fromNumber = ensurePhoneUser(citizenid, fromName)
    local toNumber = digitsOnly(data and data.number or '')
    if toNumber == '' or toNumber == fromNumber then
        return TriggerClientEvent('QBCore:Notify', src, 'Neteisingas numeris.', 'error')
    end

    local service = getServiceByHotline(toNumber)
    if service then
        local ped = GetPlayerPed(src)
        local c = ped and ped ~= 0 and GetEntityCoords(ped) or vector3(0.0, 0.0, 0.0)
        dispatchEmergency(src, service, { x = c.x, y = c.y, z = c.z })
        return
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

    TriggerClientEvent('mrp_phone:client:callState', src, {
        id = callId,
        status = 'ringing',
        toNumber = toNumber,
    })
    TriggerClientEvent('mrp_phone:client:incomingCall', targetSrc, {
        id = callId,
        fromNumber = fromNumber,
        fromName = fromName,
    })

    SetTimeout(35000, function()
        local live = ActiveCalls[callId]
        if live and not live.accepted then
            endPhoneCall(live, 'ended')
        end
    end)
end)

RegisterNetEvent('mrp_phone:server:respondCall', function(data)
    local src = source
    local callId = tonumber(data and data.callId)
    local accept = data and data.accept == true
    local call = callId and ActiveCalls[callId]
    if not call then return end
    if src ~= call.calleeSrc then return end

    if not accept then
        endPhoneCall(call, 'rejected')
        return
    end

    call.accepted = true
    call.connectedAt = os.time()
    setPhoneCallVoice(call, call.id)
    TriggerClientEvent('mrp_phone:client:callState', call.callerSrc, {
        id = call.id,
        status = 'connected',
        peerNumber = call.toNumber,
    })
    TriggerClientEvent('mrp_phone:client:callState', call.calleeSrc, {
        id = call.id,
        status = 'connected',
        peerNumber = call.fromNumber,
    })
end)

RegisterNetEvent('mrp_phone:server:endCall', function(data)
    local src = source
    local callId = tonumber(data and data.callId)
    local call = callId and ActiveCalls[callId]
    if not call then return end
    if src ~= call.callerSrc and src ~= call.calleeSrc then return end
    endPhoneCall(call, 'ended')
end)

AddEventHandler('playerDropped', function()
    local src = source
    local ending = {}
    for _, call in pairs(ActiveCalls) do
        if call.callerSrc == src or call.calleeSrc == src then
            ending[#ending + 1] = call
        end
    end
    for i = 1, #ending do
        endPhoneCall(ending[i], 'ended')
    end
    DeathStartedAt[src] = nil
    LastEmergencyCall[src] = nil
    LastMedicRequest[src] = nil
end)

RegisterNetEvent('mrp_phone:server:emergencyCall', function(service, clientCoords)
    service = tostring(service or ''):lower()
    if service ~= 'police' and service ~= 'ems' and service ~= 'taxi' and service ~= 'mechanic' then return end
    dispatchEmergency(source, service, clientCoords)
end)

RegisterNetEvent('mrp_phone:server:reportDeath', function()
    local src = source
    DeathStartedAt[src] = os.time()
end)

RegisterNetEvent('mrp_phone:server:reportAlive', function()
    local src = source
    DeathStartedAt[src] = nil
end)

RegisterNetEvent('mrp_phone:server:hospitalWake', function()
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
    TriggerClientEvent('mrp_phone:client:hospitalWake', src, { x = hosp.x, y = hosp.y, z = hosp.z, w = hosp.w })
    TriggerClientEvent('QBCore:Notify', src, 'AtsikÄ—lei artimiausioje ligoninÄ—je.', 'success')
end)

RegisterNetEvent('mrp_phone:server:medicRequestFromDead', function()
    local src = source
    if not DeathStartedAt[src] then
        DeathStartedAt[src] = os.time()
    end
    local now = os.time()
    local last = tonumber(LastMedicRequest[src]) or 0
    local cd = (Config.Emergency and Config.Emergency.medicRequestCooldownSec) or 90
    if now - last < cd then
        return TriggerClientEvent('QBCore:Notify', src, 'Per daÅ¾nai â€“ palauk.', 'error')
    end
    LastMedicRequest[src] = now

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    local Player = getPlayer(src)
    local callerName = Player and getFullName(Player) or 'NeÅ¾inomas'
    local phone = ''
    if Player then
        phone = ensurePhoneUser(Player.PlayerData.citizenid, callerName)
    end

    local emCfg = Config.Emergency or {}
    if emCfg.policePanicOnMedicRequest ~= false and Player and Player.PlayerData and Player.PlayerData.job then
        local jn = Player.PlayerData.job.name
        local isPd = false
        for _, j in ipairs(emCfg.policeJobs or { 'police' }) do
            if jn == j then isPd = true break end
        end
        if isPd and GetResourceState('mrp_dispatch') == 'started' then
            local ok = exports['mrp_dispatch']:TriggerOfficerPanic(src)
            if ok then
                TriggerClientEvent('QBCore:Notify', src, 'PANIC signalas iÅ¡siÅ³stas policijai.', 'error')
            end
        end
    end

    local cfg = Config.Emergency or {}
    local title = ('MEDIC: %s praÅ¡o pagalbos (%s)'):format(callerName, phone)

    if GetResourceState('mrp_dispatch') == 'started' then
        exports['mrp_dispatch']:CreateDispatchCall(
            'ems',
            'civilian_help',
            { x = c.x, y = c.y, z = c.z },
            title,
            src
        )
    end

    local count = 0
    for _, P in pairs(QBCore.Functions.GetQBPlayers()) do
        if P and P.PlayerData and P.PlayerData.job and P.PlayerData.job.onduty then
            if P.PlayerData.job.name == (cfg.ambulanceJob or 'ambulance') then
                count = count + 1
                TriggerClientEvent('mrp_phone:client:serviceDispatch', P.PlayerData.source, {
                    service = 'ems',
                    x = c.x, y = c.y, z = c.z,
                    title = title,
                    caller = callerName,
                    phone = phone,
                    duration = tonumber(cfg.blipDurationMs) or 120000,
                    sprite = 153,
                    scale = 1.1,
                })
                TriggerClientEvent('QBCore:Notify', P.PlayerData.source, ('ðŸš‘ %s praÅ¡o pagalbos â€“ Å¾emÄ—lapyje taÅ¡kas.'):format(callerName), 'error', 10000)
            end
        end
    end
    if count == 0 then
        TriggerClientEvent('QBCore:Notify', src, 'Medikai ne duty arba nÄ—ra prisijungusiÅ³.', 'error')
    else
        TriggerClientEvent('QBCore:Notify', src, 'Medikai iÅ¡kviesti â€“ EMS pamatys tavo vietÄ… Å¾emÄ—lapyje ir gali atvykti.', 'success')
    end
end)

CreateThread(function()
    math.randomseed(os.time())
    --- Schema lives in server/core/db.lua (PhoneID tables). Legacy fivempro_phone_* wiped when Config.Phone.WipeLegacyTables.
    print('[mrp_phone] Skipping legacy table bootstrap (PhoneID core owns schema).')
end)


-- Legacy schema + duplicate useable item removed (PhoneID core).

