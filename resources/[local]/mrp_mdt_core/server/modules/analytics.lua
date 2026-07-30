--- Phase 7: batched MDT telemetry (open/close, tabs, dispatch, fines, incidents).
--- Inserts are rate-limited and flushed on an interval — not per NUI poll tick.

MdtAnalytics = MdtAnalytics or {}

local QBCore = exports['qb-core']:GetCoreObject()

local pending = {}
local rateAt = {}
local openSessions = {}

local function cfg()
    return Config.Telemetry or {}
end

local function enabled()
    return cfg().Enabled ~= false
end

local function citizenIdOf(src)
    if not src or src < 1 then return nil end
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function normalizeEvent(eventType)
    return tostring(eventType or ''):sub(1, 64)
end

local function rateKey(actor, eventType)
    return ('%s:%s'):format(tostring(actor or ''), eventType)
end

local function isRateLimited(actor, eventType)
    local window = tonumber(cfg().RateLimitMs) or 100
    if window <= 0 then return false end
    local key = rateKey(actor, eventType)
    local now = GetGameTimer()
    local last = rateAt[key] or 0
    if now - last < window then return true end
    rateAt[key] = now
    return false
end

local function encodeMeta(meta)
    if meta == nil then return nil end
    if type(meta) == 'string' then return meta:sub(1, 4096) end
    local ok, encoded = pcall(json.encode, meta)
    return ok and encoded or nil
end

--- Queue one row; flushed asynchronously.
function MdtAnalytics.Record(eventType, opts)
    if not enabled() then return false end
    eventType = normalizeEvent(eventType)
    if eventType == '' then return false end

    opts = type(opts) == 'table' and opts or {}
    local src = tonumber(opts.source)
    local actor = opts.actorCitizenid or citizenIdOf(src)
    if isRateLimited(actor or src, eventType) then return false end

    pending[#pending + 1] = {
        event_type = eventType,
        service = opts.service and tostring(opts.service):sub(1, 32) or nil,
        actor_citizenid = actor and tostring(actor):sub(1, 64) or nil,
        value_num = opts.value_num ~= nil and tonumber(opts.value_num) or nil,
        meta = encodeMeta(opts.meta),
    }

    local maxBatch = tonumber(cfg().MaxBatchSize) or 50
    if #pending >= maxBatch then
        MdtAnalytics.Flush()
    end
    return true
end

function MdtAnalytics.BeginSession(src, opts)
    src = tonumber(src)
    if not src or src < 1 then return end
    opts = type(opts) == 'table' and opts or {}
    openSessions[src] = {
        openedAt = GetGameTimer(),
        service = opts.service and tostring(opts.service):sub(1, 32) or nil,
        citizenid = opts.citizenid or citizenIdOf(src),
    }
    MdtAnalytics.Record('mdt_open', {
        source = src,
        service = opts.service,
        actorCitizenid = opts.citizenid,
    })
end

function MdtAnalytics.EndSession(src, opts)
    src = tonumber(src)
    if not src or src < 1 then return end
    opts = type(opts) == 'table' and opts or {}

    local session = openSessions[src]
    openSessions[src] = nil
    if not session then return end

    local durationMs = GetGameTimer() - (session.openedAt or GetGameTimer())
    local minMs = tonumber(cfg().SessionCloseMinMs) or 500
    if durationMs < minMs then return end

    MdtAnalytics.Record('mdt_close', {
        source = src,
        service = opts.service or session.service,
        actorCitizenid = session.citizenid,
        value_num = durationMs,
        meta = {
            service = opts.service or session.service,
            duration_ms = durationMs,
            reason = opts.reason,
        },
    })
end

function MdtAnalytics.Flush()
    if #pending == 0 then return 0 end
    if GetResourceState('oxmysql') ~= 'started' then
        pending = {}
        return 0
    end

    local batch = pending
    pending = {}

    local values = {}
    local params = {}
    for _, row in ipairs(batch) do
        values[#values + 1] = '(?, ?, ?, ?, ?)'
        params[#params + 1] = row.event_type
        params[#params + 1] = row.service
        params[#params + 1] = row.actor_citizenid
        params[#params + 1] = row.value_num
        params[#params + 1] = row.meta
    end

    local ok, err = pcall(function()
        MySQL.insert.await(
            ('INSERT INTO mdt_telemetry_events (event_type, service, actor_citizenid, value_num, meta) VALUES %s')
                :format(table.concat(values, ', ')),
            params
        )
    end)

    if not ok then
        print(('[mrp_mdt_core] telemetry flush failed: %s'):format(tostring(err)))
        --- Re-queue at front (cap to avoid unbounded growth).
        local cap = tonumber(cfg().MaxBatchSize) or 50
        for i = math.min(#batch, cap), 1, -1 do
            table.insert(pending, 1, batch[i])
        end
        return 0
    end

    return #batch
end

--- @param from string|nil ISO datetime or nil = last 7 days
--- @param to string|nil ISO datetime or nil = now
function MdtAnalytics.Summary(from, to)
    if GetResourceState('oxmysql') ~= 'started' then
        return { ok = false, message = 'db_unavailable' }
    end

    local fromSql = from and tostring(from):sub(1, 32) or nil
    local toSql = to and tostring(to):sub(1, 32) or nil
    if not fromSql then
        fromSql = os.date('!%Y-%m-%d %H:%M:%S', os.time() - 7 * 86400)
    end

    local where = 'WHERE created_at >= ?'
    local params = { fromSql }
    if toSql then
        where = where .. ' AND created_at <= ?'
        params[#params + 1] = toSql
    end

    local counts = MySQL.query.await(
        ('SELECT event_type, service, COUNT(*) AS cnt, AVG(value_num) AS avg_value FROM mdt_telemetry_events %s GROUP BY event_type, service ORDER BY cnt DESC')
            :format(where),
        params
    ) or {}

    local sessions = MySQL.single.await(
        ('SELECT COUNT(*) AS closes, AVG(value_num) AS avg_duration_ms, MAX(value_num) AS max_duration_ms FROM mdt_telemetry_events %s AND event_type = ?')
            :format(where),
        (function()
            local p = { table.unpack(params) }
            p[#p + 1] = 'mdt_close'
            return p
        end)()
    )

    return {
        ok = true,
        from = fromSql,
        to = toSql,
        byEvent = counts,
        mdtSessions = {
            closes = sessions and tonumber(sessions.closes) or 0,
            avgDurationMs = sessions and tonumber(sessions.avg_duration_ms) or nil,
            maxDurationMs = sessions and tonumber(sessions.max_duration_ms) or nil,
        },
    }
end

CreateThread(function()
    local flushMs = math.max(1000, tonumber(cfg().FlushIntervalMs) or 5000)
    while true do
        Wait(flushMs)
        MdtAnalytics.Flush()
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    MdtAnalytics.EndSession(src, { reason = 'disconnect' })
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    MdtAnalytics.Flush()
end)

exports('RecordTelemetry', function(eventType, opts)
    return MdtAnalytics.Record(eventType, opts)
end)

exports('BeginMdtSession', function(src, opts)
    return MdtAnalytics.BeginSession(src, opts)
end)

exports('EndMdtSession', function(src, opts)
    return MdtAnalytics.EndSession(src, opts)
end)

exports('FlushTelemetry', function()
    return MdtAnalytics.Flush()
end)

exports('GetMdtAnalyticsSummary', function(from, to)
    return MdtAnalytics.Summary(from, to)
end)
