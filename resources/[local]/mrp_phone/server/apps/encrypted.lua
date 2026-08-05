--[[
  Encrypted Messages app — phone_id scoped.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local function requireDarknet(src)
    local s = PhoneSession.Require(src)
    if not s then return nil, 'Sesija neaktyvi.' end
    if s.phoneType ~= 'darknet' then return nil, 'Tik DarkNet.' end
    return s
end

QBCore.Functions.CreateCallback('mrp_phone:server:encryptedList', function(src, cb)
    local s, err = requireDarknet(src)
    if not s then return cb({ ok = false, message = err, threads = {} }) end
    local threads = MySQL.query.await([[
        SELECT t.id, t.peer_label, t.updated_at,
          (SELECT body FROM mrp_phone_encrypted_messages m WHERE m.thread_id = t.id ORDER BY m.id DESC LIMIT 1) AS last_body
        FROM mrp_phone_encrypted_threads t
        WHERE t.phone_id = ?
        ORDER BY t.updated_at DESC
        LIMIT 50
    ]], { s.phoneId }) or {}
    cb({ ok = true, threads = threads })
end)

QBCore.Functions.CreateCallback('mrp_phone:server:encryptedSend', function(src, cb, data)
    local s, err = requireDarknet(src)
    if not s then return cb({ ok = false, message = err }) end
    local label = tostring(data and data.peerLabel or ''):gsub('^%s+', ''):gsub('%s+$', '')
    local body = tostring(data and data.body or '')
    if label == '' or body == '' then return cb({ ok = false, message = 'Tuščia.' }) end
    if #body > 320 then body = body:sub(1, 320) end
    local thread = MySQL.single.await(
        'SELECT id FROM mrp_phone_encrypted_threads WHERE phone_id = ? AND peer_label = ? LIMIT 1',
        { s.phoneId, label }
    )
    local threadId = thread and thread.id
    if not threadId then
        threadId = MySQL.insert.await(
            'INSERT INTO mrp_phone_encrypted_threads (phone_id, peer_label) VALUES (?, ?)',
            { s.phoneId, label }
        )
    end
    MySQL.insert.await(
        'INSERT INTO mrp_phone_encrypted_messages (thread_id, phone_id, direction, body) VALUES (?, ?, ?, ?)',
        { threadId, s.phoneId, 'out', body }
    )
    cb({ ok = true })
end)
