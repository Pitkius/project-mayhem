--- MDT V2 Incident state machine (shared — validated on server).
--- Canonical status keys are lowercase snake_case; UI may map to LT labels later.

MdtIncidentStates = MdtIncidentStates or {}

MdtIncidentStates.STATUSES = {
    created = true,
    assigned = true,
    accepted = true,
    enroute = true,
    arrived = true,
    in_progress = true,
    completed = true,
    archived = true,
    cancelled = true,
    expired = true,
    duplicate = true,
    merged = true,
    rejected = true,
    timeout = true,
}

--- Happy-path + exception edges. Keys = from-status, values = set of allowed to-status.
MdtIncidentStates.TRANSITIONS = {
    created = {
        assigned = true,
        accepted = true, -- direct accept without formal assign (dispatch-style)
        cancelled = true,
        expired = true,
        duplicate = true,
        merged = true,
        rejected = true,
        timeout = true,
    },
    assigned = {
        accepted = true,
        cancelled = true,
        expired = true,
        duplicate = true,
        merged = true,
        rejected = true,
        timeout = true,
        created = true, -- unassign / requeue
    },
    accepted = {
        enroute = true,
        arrived = true, -- skip enroute when already on scene
        in_progress = true,
        cancelled = true,
        rejected = true,
        timeout = true,
        assigned = true, -- reassign
    },
    enroute = {
        arrived = true,
        in_progress = true,
        cancelled = true,
        timeout = true,
        accepted = true, -- fallback
    },
    arrived = {
        in_progress = true,
        completed = true,
        cancelled = true,
        timeout = true,
    },
    in_progress = {
        completed = true,
        cancelled = true,
        timeout = true,
    },
    completed = {
        archived = true,
        merged = true, -- rare post-close merge note
    },
    archived = {},
    cancelled = {
        archived = true,
    },
    expired = {
        archived = true,
    },
    duplicate = {
        archived = true,
        merged = true,
    },
    merged = {
        archived = true,
    },
    rejected = {
        archived = true,
    },
    timeout = {
        archived = true,
    },
}

--- Terminal (no further gameplay transitions except archive).
MdtIncidentStates.TERMINAL = {
    archived = true,
}

--- Statuses that mean "no further gameplay work" (closed_at is stamped).
MdtIncidentStates.CLOSED = {
    completed = true,
    cancelled = true,
    expired = true,
    duplicate = true,
    merged = true,
    rejected = true,
    timeout = true,
    archived = true,
}

--[[
  Happy-path order. Only these statuses may be used as *intermediate* hops when
  auto-walking a multi-step transition (see PathTo), so a sync can never route a
  call through cancelled/rejected/duplicate on its way somewhere else.
]]
MdtIncidentStates.PROGRESSION = {
    'created',
    'assigned',
    'accepted',
    'enroute',
    'arrived',
    'in_progress',
    'completed',
    'archived',
}

local PROGRESSION_RANK = {}
for i, status in ipairs(MdtIncidentStates.PROGRESSION) do
    PROGRESSION_RANK[status] = i
end

--- Map legacy mrp_dispatch call statuses → incident statuses.
MdtIncidentStates.FROM_DISPATCH = {
    pending = 'created',
    accepted = 'accepted',
    enroute = 'enroute',
    arrived = 'arrived',
    in_progress = 'in_progress',
    rejected = 'rejected',
    cancelled = 'cancelled',
    expired = 'expired',
    done = 'completed',
}

--- Map mrp_dispatch `updateCallStatus` actions → incident statuses.
MdtIncidentStates.FROM_DISPATCH_ACTION = {
    accept = 'accepted',
    enroute = 'enroute',
    arrived = 'arrived',
    in_progress = 'in_progress',
    done = 'completed',
    panic_off = 'completed',
    reject = 'rejected',
    cancel = 'cancelled',
    expire = 'expired',
    timeout = 'timeout',
    archive = 'archived',
}

--[[
  Closest legal outcome when the mapped status cannot be reached from where the
  incident already is. A unit "rejecting" a call it has already arrived at is a
  cancellation, not a refusal — without this the incident would stay open until pruned.
]]
MdtIncidentStates.ACTION_FALLBACK = {
    rejected = 'cancelled',
}

function MdtIncidentStates.IsClosed(status)
    return status ~= nil and MdtIncidentStates.CLOSED[tostring(status)] == true
end

--- @param dispatchStatus string  mrp_dispatch call.status
--- @return string|nil incident status
function MdtIncidentStates.MapDispatchStatus(dispatchStatus)
    return MdtIncidentStates.FROM_DISPATCH[tostring(dispatchStatus or '')]
end

--- @param action string  mrp_dispatch updateCallStatus action
--- @return string|nil incident status
function MdtIncidentStates.MapDispatchAction(action)
    return MdtIncidentStates.FROM_DISPATCH_ACTION[tostring(action or '')]
end

function MdtIncidentStates.IsValid(status)
    return status ~= nil and MdtIncidentStates.STATUSES[tostring(status)] == true
end

function MdtIncidentStates.CanTransition(fromStatus, toStatus)
    fromStatus = tostring(fromStatus or '')
    toStatus = tostring(toStatus or '')
    if not MdtIncidentStates.IsValid(fromStatus) or not MdtIncidentStates.IsValid(toStatus) then
        return false
    end
    if fromStatus == toStatus then return false end
    local edges = MdtIncidentStates.TRANSITIONS[fromStatus]
    return edges ~= nil and edges[toStatus] == true
end

function MdtIncidentStates.AllowedFrom(fromStatus)
    fromStatus = tostring(fromStatus or '')
    local edges = MdtIncidentStates.TRANSITIONS[fromStatus] or {}
    local out = {}
    for status, ok in pairs(edges) do
        if ok then out[#out + 1] = status end
    end
    table.sort(out)
    return out
end

--- Deterministic neighbour order: happy-path first (by PROGRESSION rank), then alphabetical.
local function sortedEdges(fromStatus)
    local out = MdtIncidentStates.AllowedFrom(fromStatus)
    table.sort(out, function(a, b)
        local ra, rb = PROGRESSION_RANK[a], PROGRESSION_RANK[b]
        if ra and rb and ra ~= rb then return ra < rb end
        if ra and not rb then return true end
        if rb and not ra then return false end
        return a < b
    end)
    return out
end

--[[
  Shortest legal walk from `fromStatus` to `toStatus`.

  Dispatch and MDT UIs let a unit skip steps (e.g. press "Atvykau" on a call that is
  still `created`). Instead of loosening the state machine, we walk the graph so every
  hop stays a legal transition and every hop is recorded on the timeline.

  Intermediate hops are restricted to PROGRESSION so a walk can never silently pass
  through an exception state such as `cancelled` or `rejected`.

  @param fromStatus string
  @param toStatus string
  @return table|nil path  ordered list of statuses to apply (excludes fromStatus), nil if unreachable
]]
function MdtIncidentStates.PathTo(fromStatus, toStatus)
    fromStatus = tostring(fromStatus or '')
    toStatus = tostring(toStatus or '')
    if not MdtIncidentStates.IsValid(fromStatus) or not MdtIncidentStates.IsValid(toStatus) then
        return nil
    end
    if fromStatus == toStatus then return {} end

    local queue = { fromStatus }
    local head = 1
    local prev = { [fromStatus] = false }

    while head <= #queue do
        local current = queue[head]
        head = head + 1
        for _, nextStatus in ipairs(sortedEdges(current)) do
            if prev[nextStatus] == nil then
                if nextStatus == toStatus then
                    local path = { toStatus }
                    local node = current
                    while node and node ~= fromStatus do
                        table.insert(path, 1, node)
                        node = prev[node]
                    end
                    return path
                end
                --- Only happy-path statuses may be traversed on the way to the target.
                if PROGRESSION_RANK[nextStatus] then
                    prev[nextStatus] = current
                    queue[#queue + 1] = nextStatus
                end
            end
        end
    end
    return nil
end

--[[
  Target status for a dispatch action, given where the incident already is.
  Falls back per ACTION_FALLBACK when the mapped status is unreachable; a backwards
  move (e.g. "vykstu" after "atvykau") stays unreachable on purpose — the incident
  keeps the furthest progress it actually reached.

  @param fromStatus string current incident status
  @param action string dispatch action
  @return string|nil target, string|nil replacedTarget  (set when a fallback was used)
]]
function MdtIncidentStates.ResolveDispatchTarget(fromStatus, action)
    local target = MdtIncidentStates.MapDispatchAction(action)
    if not target then return nil end
    fromStatus = tostring(fromStatus or '')
    if fromStatus == target or MdtIncidentStates.PathTo(fromStatus, target) then
        return target
    end
    local fallback = MdtIncidentStates.ACTION_FALLBACK[target]
    if fallback and (fromStatus == fallback or MdtIncidentStates.PathTo(fromStatus, fallback)) then
        return fallback, target
    end
    return target
end
