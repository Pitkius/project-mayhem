--[[
  PhoneID data layer — overrides getInitialData + key CRUD after legacy main.lua.
  Last CreateCallback registration wins in QBCore.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function requireSession(src)
    local s = PhoneSession.Require(src)
    if not s then return nil, nil, 'Sesija neaktyvi — įvesk PIN.' end
    local row = PhoneCore.GetById(s.phoneId)
    if not row then return nil, nil, 'Telefonas nerastas.' end
    return s, row
end

local function trim(s)
    return tostring(s or ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function clampStr(s, maxLen)
    s = trim(s)
    if #s > maxLen then s = s:sub(1, maxLen) end
    return s
end

local function digitsOnly(s)
    return tostring(s or ''):gsub('%D+', '')
end

local function getFullName(player)
    if not player then return 'Player' end
    local c = player.PlayerData.charinfo or {}
    local full = trim((tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or '')))
    return full ~= '' and full or 'Player'
end

local function sourceByCitizen(citizenid)
    for sid, player in pairs(QBCore.Functions.GetQBPlayers()) do
        if player and player.PlayerData and player.PlayerData.citizenid == citizenid then
            return sid, player
        end
    end
    return nil, nil
end

--- Prefer owner's active legal phone; else any phone owned by citizen.
local function findPhoneIdForCitizen(citizenid)
    local row = MySQL.single.await([[
        SELECT phone_id, phone_number FROM mrp_phones
        WHERE owner_citizenid = ? AND phone_type = 'legal' AND status = 'active'
        ORDER BY created_at DESC LIMIT 1
    ]], { citizenid })
    if row then return row.phone_id, tostring(row.phone_number) end
    row = MySQL.single.await([[
        SELECT phone_id, phone_number FROM mrp_phones
        WHERE owner_citizenid = ? AND status = 'active'
        ORDER BY created_at DESC LIMIT 1
    ]], { citizenid })
    if row then return row.phone_id, tostring(row.phone_number) end
    return nil, nil
end

exports('SendSystemSMS', function(toCitizenid, fromNumber, body)
    toCitizenid = tostring(toCitizenid or '')
    fromNumber = digitsOnly(fromNumber or '')
    if fromNumber == '' then fromNumber = '000000' end
    body = clampStr(body or '', (Config.Phone and Config.Phone.maxMessageLength) or 320)
    if toCitizenid == '' or body == '' then return false end

    local phoneId = select(1, findPhoneIdForCitizen(toCitizenid))
    if not phoneId then
        -- No device yet — soft fail (intro SMS waits until phone owned)
        return false
    end

    MySQL.insert.await([[
        INSERT INTO mrp_phone_messages (phone_id, thread_number, direction, body, from_number, read_flag)
        VALUES (?, ?, 'in', ?, ?, 0)
    ]], { phoneId, fromNumber, body, fromNumber })

    local targetSrc = sourceByCitizen(toCitizenid)
    if targetSrc then
        TriggerClientEvent('mrp_phone:client:newMessageNotify', targetSrc, fromNumber)
        TriggerClientEvent('mrp_phone:client:refreshData', targetSrc)
    end
    return true
end)

local function buildInitial(src)
    local s, row, err = requireSession(src)
    if not s then return { ok = false, message = err or 'Sesija neaktyvi' } end
    local phoneId = s.phoneId
    local P = QBCore.Functions.GetPlayer(src)
    local fullname = getFullName(P)
    local phoneType = PhoneTypes.Normalize(row.phone_type)

    local contacts = MySQL.query.await([[
        SELECT id, name AS display_name, number AS contact_number, service, icon, is_default
        FROM mrp_phone_contacts WHERE phone_id = ? ORDER BY name ASC, id ASC
    ]], { phoneId }) or {}

    local msgs = MySQL.query.await([[
        SELECT id, from_number, thread_number AS to_number, body, created_at, direction
        FROM mrp_phone_messages WHERE phone_id = ? ORDER BY id DESC LIMIT 120
    ]], { phoneId }) or {}

    local threads, seen = {}, {}
    for _, m in ipairs(msgs) do
        local peer = tostring(m.to_number or m.from_number or '')
        if m.direction == 'in' then peer = tostring(m.from_number or '') end
        if peer ~= '' and not seen[peer] then
            seen[peer] = true
            threads[#threads + 1] = {
                peer_number = peer,
                last_body = tostring(m.body or ''),
                last_at = m.created_at,
                direction = m.direction,
            }
        end
    end

    local notesRows = MySQL.query.await([[
        SELECT id, title, body, created_at, updated_at FROM mrp_phone_notes
        WHERE phone_id = ? ORDER BY updated_at DESC LIMIT ?
    ]], { phoneId, (Config.Phone and Config.Phone.maxNotes) or 50 }) or {}

    local photos = {}
    if Config.Phone and Config.Phone.enablePhotos then
        photos = MySQL.query.await([[
            SELECT id, image_url, created_at FROM mrp_phone_photos
            WHERE phone_id = ? ORDER BY id DESC LIMIT 80
        ]], { phoneId }) or {}
    end

    local ads = MySQL.query.await([[
        SELECT id, phone_id AS citizenid, title, body, category, price, image_url, created_at
        FROM mrp_phone_ads ORDER BY id DESC LIMIT 120
    ]]) or {}

    local posts = MySQL.query.await([[
        SELECT id, author_name, caption, image_url, likes, created_at
        FROM mrp_phone_posts ORDER BY id DESC LIMIT 120
    ]]) or {}

    local installed = {}
    local instRows = MySQL.query.await('SELECT app_id FROM mrp_phone_installed_apps WHERE phone_id = ?', { phoneId }) or {}
    for _, r in ipairs(instRows) do installed[tostring(r.app_id)] = true end
    for appId, on in pairs(PhoneApps.LegalDefaults or {}) do
        if on then installed[appId] = true end
    end

    local availableApps = {}
    if phoneType == PhoneTypes.LEGAL then
        for _, app in ipairs((Config.Phone and Config.Phone.AppStoreApps) or {}) do
            local appId = tostring(app.id or '')
            availableApps[#availableApps + 1] = {
                id = appId,
                label = tostring(app.label or appId),
                icon = tostring(app.icon or 'appstore'),
                description = tostring(app.description or ''),
                installed = installed[appId] == true,
                default = app.default == true,
            }
        end
    else
        for _, app in ipairs(PhoneApps.ListForType(PhoneTypes.DARKNET)) do
            availableApps[#availableApps + 1] = {
                id = app.id, label = app.label, icon = app.icon,
                description = '', installed = true, default = true,
            }
        end
    end

    local cash, bank = 0, 0
    if P and P.PlayerData and P.PlayerData.money then
        cash = tonumber(P.PlayerData.money.cash) or 0
        bank = tonumber(P.PlayerData.money.bank) or 0
    end

    return {
        ok = true,
        phoneType = phoneType,
        phoneId = phoneId,
        me = {
            number = tostring(row.phone_number),
            name = fullname,
            citizenid = P and P.PlayerData.citizenid or '',
            imei = tostring(row.imei),
            simId = tostring(row.sim_id),
        },
        money = { cash = cash, bank = bank },
        account = { hasAccount = true, username = fullname },
        appStore = { availableApps = availableApps, installed = installed },
        contacts = contacts,
        messagePreview = msgs,
        messageThreads = threads,
        ads = ads,
        adCategories = (Config.Phone and Config.Phone.AdCategories) or {},
        photos = photos,
        notes = notesRows,
        notesOldDays = (Config.Phone and Config.Phone.notesOldDays) or 30,
        posts = posts,
        pendingIncomingCall = nil,
    }
end

QBCore.Functions.CreateCallback('mrp_phone:server:getInitialData', function(source, cb)
    cb(buildInitial(source))
end)

QBCore.Functions.CreateCallback('mrp_phone:server:saveContact', function(source, cb, data)
    local s = PhoneSession.Require(source)
    if not s then return cb({ ok = false, message = 'Sesija neaktyvi.' }) end
    local name = clampStr(data and data.name or '', 60)
    local number = digitsOnly(data and data.number or '')
    if name == '' or number == '' then return cb({ ok = false, message = 'Blogi duomenys.' }) end
    local maxContacts = (Config.Phone and Config.Phone.maxContacts) or 120
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM mrp_phone_contacts WHERE phone_id = ?', { s.phoneId }) or 0
    if tonumber(count) >= maxContacts then
        return cb({ ok = false, message = 'Kontaktų limitas pasiektas.' })
    end
    MySQL.insert.await(
        'INSERT INTO mrp_phone_contacts (phone_id, name, number) VALUES (?, ?, ?)',
        { s.phoneId, name, number }
    )
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

QBCore.Functions.CreateCallback('mrp_phone:server:sendMessage', function(source, cb, data)
    local s, row = requireSession(source)
    if not s then return cb({ ok = false, message = 'Sesija neaktyvi.' }) end
    local toNumber = digitsOnly(data and data.number or data and data.toNumber or '')
    local body = clampStr(data and data.body or data and data.message or '', (Config.Phone and Config.Phone.maxMessageLength) or 320)
    if toNumber == '' or body == '' then return cb({ ok = false, message = 'Blogi duomenys.' }) end

    MySQL.insert.await([[
        INSERT INTO mrp_phone_messages (phone_id, thread_number, direction, body, from_number, read_flag)
        VALUES (?, ?, 'out', ?, ?, 1)
    ]], { s.phoneId, toNumber, body, tostring(row.phone_number) })

    local peer = PhoneCore.GetByNumber(toNumber)
    if peer then
        MySQL.insert.await([[
            INSERT INTO mrp_phone_messages (phone_id, thread_number, direction, body, from_number, read_flag)
            VALUES (?, ?, 'in', ?, ?, 0)
        ]], { peer.phone_id, tostring(row.phone_number), body, tostring(row.phone_number) })
        if peer.owner_citizenid then
            local targetSrc = sourceByCitizen(peer.owner_citizenid)
            if targetSrc then
                TriggerClientEvent('mrp_phone:client:newMessageNotify', targetSrc, tostring(row.phone_number))
                TriggerClientEvent('mrp_phone:client:refreshData', targetSrc)
            end
        end
    end
    cb({ ok = true })
    TriggerClientEvent('mrp_phone:client:refreshData', source)
end)

print('[mrp_phone] PhoneID data layer active.')
