--- Append-only audit log. No UPDATE/DELETE from gameplay APIs.

MdtAudit = MdtAudit or {}

local QBCore = exports['qb-core']:GetCoreObject()

local function citizenIdOf(src)
    if not src or src < 1 then return nil end
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function playerEndpoint(src)
    if not src or src < 1 then return nil end
    local ep = GetPlayerEndpoint(src)
    if not ep or ep == '' then return nil end
    --- Strip port if present (ip:port)
    return tostring(ep):match('^([^:]+)') or tostring(ep)
end

--- @param action string
--- @param opts table|nil { source, actorCitizenid, resource, target, meta }
--- @return number|nil insertId
function MdtAudit.Log(action, opts)
    action = tostring(action or '')
    if action == '' then return nil end
    opts = type(opts) == 'table' and opts or {}

    local src = tonumber(opts.source)
    local actor = opts.actorCitizenid or citizenIdOf(src)
    local resource = opts.resource and tostring(opts.resource):sub(1, 64) or GetCurrentResourceName()
    local target = opts.target and tostring(opts.target):sub(1, 128) or nil
    local meta = opts.meta
    if meta ~= nil and type(meta) ~= 'string' then
        local ok, encoded = pcall(json.encode, meta)
        meta = ok and encoded or nil
    end

    if GetResourceState('oxmysql') ~= 'started' then
        print(('[mrp_mdt_core] audit (no db): %s resource=%s target=%s'):format(action, resource, tostring(target)))
        return nil
    end

    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_audit_log (actor_citizenid, action, resource, target, meta, ip, source)
          VALUES (?, ?, ?, ?, ?, ?, ?)]],
        {
            actor,
            action:sub(1, 64),
            resource,
            target,
            meta,
            src and playerEndpoint(src) or opts.ip,
            src,
        }
    )
    return insertId
end

--[[
  Fire-and-forget variant for hot read paths (searches, profile opens, camera opens).
  `dedupeKey` collapses repeats from the same actor inside Config.AuditDedupeWindowMs
  so a UI that re-queries on every keystroke cannot flood the log.
]]
local lastLogged = {} --- @type table<string, number>
local lastSweepAt = 0

local function sweepDedupe(now, window)
    if now - lastSweepAt < window * 4 then return end
    lastSweepAt = now
    for key, at in pairs(lastLogged) do
        if now - at > window * 4 then lastLogged[key] = nil end
    end
end

--- @param action string
--- @param opts table|nil  Log() opts + { dedupeKey?, dedupeWindowMs? }
function MdtAudit.LogAsync(action, opts)
    opts = type(opts) == 'table' and opts or {}

    if opts.dedupeKey then
        local window = math.max(0, tonumber(opts.dedupeWindowMs) or tonumber(Config.AuditDedupeWindowMs) or 5000)
        if window > 0 then
            local key = ('%s|%s|%s'):format(tostring(action), tostring(opts.source or opts.actorCitizenid or '?'), tostring(opts.dedupeKey))
            local now = GetGameTimer()
            local previous = lastLogged[key]
            if previous and now - previous < window then return false end
            lastLogged[key] = now
            sweepDedupe(now, window)
        end
    end

    --- Resolve actor before detaching: the player may drop before the insert runs.
    local resolved = {
        source = opts.source,
        actorCitizenid = opts.actorCitizenid or citizenIdOf(tonumber(opts.source)),
        resource = opts.resource,
        target = opts.target,
        meta = opts.meta,
        ip = opts.ip or playerEndpoint(tonumber(opts.source)),
    }
    CreateThread(function()
        MdtAudit.Log(action, resolved)
    end)
    return true
end

exports('AuditLog', function(action, opts)
    return MdtAudit.Log(action, opts)
end)

exports('AuditLogAsync', function(action, opts)
    return MdtAudit.LogAsync(action, opts)
end)
