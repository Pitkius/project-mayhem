--- System-only immutable timeline. Gameplay must not UPDATE/DELETE rows.

MdtTimeline = MdtTimeline or {}

local QBCore = exports['qb-core']:GetCoreObject()

local function actorFromSource(src)
    if not src or src < 1 then return nil, nil end
    local p = QBCore.Functions.GetPlayer(src)
    if not p then return nil, nil end
    local c = p.PlayerData.charinfo or {}
    local name = (tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
    if name == '' then name = p.PlayerData.citizenid end
    return p.PlayerData.citizenid, name
end

--- @param incidentId number
--- @param eventType string
--- @param opts table|nil { source, actorCitizenid, actorName, payload }
--- @return number|nil insertId
function MdtTimeline.Append(incidentId, eventType, opts)
    incidentId = tonumber(incidentId)
    eventType = tostring(eventType or '')
    if not incidentId or incidentId < 1 or eventType == '' then
        return nil, 'invalid_args'
    end
    opts = type(opts) == 'table' and opts or {}

    local actorCid = opts.actorCitizenid
    local actorName = opts.actorName
    if opts.source and (not actorCid or not actorName) then
        local cid, name = actorFromSource(opts.source)
        actorCid = actorCid or cid
        actorName = actorName or name
    end

    local payload = opts.payload
    if payload ~= nil and type(payload) ~= 'string' then
        local ok, encoded = pcall(json.encode, payload)
        payload = ok and encoded or nil
    end

    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_timeline (incident_id, event_type, actor_citizenid, actor_name, payload)
          VALUES (?, ?, ?, ?, ?)]],
        {
            incidentId,
            eventType:sub(1, 64),
            actorCid,
            actorName and tostring(actorName):sub(1, 128) or nil,
            payload,
        }
    )
    return insertId
end

--- Read helpers for Phase 2+ UI (no mutation).
function MdtTimeline.List(incidentId, limit)
    incidentId = tonumber(incidentId)
    if not incidentId then return {} end
    limit = math.min(500, math.max(1, tonumber(limit) or 100))
    return MySQL.query.await(
        [[SELECT id, incident_id, event_type, actor_citizenid, actor_name, payload, created_at
          FROM mdt_incident_timeline
          WHERE incident_id = ?
          ORDER BY id ASC
          LIMIT ?]],
        { incidentId, limit }
    ) or {}
end

exports('AppendTimeline', function(incidentId, eventType, opts)
    return MdtTimeline.Append(incidentId, eventType, opts)
end)
