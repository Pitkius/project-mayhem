--- Incident Engine — sole write path for mdt_incidents (create / get / transition / assign).

MdtIncidentEngine = MdtIncidentEngine or {}

local QBCore = exports['qb-core']:GetCoreObject()

local daySeq = { day = '', n = 0 }

local function citizenIdOf(src)
    if not src or src < 1 then return nil end
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function nextPublicNumber()
    local day = os.date('!%Y%m%d')
    if daySeq.day ~= day then
        daySeq.day = day
        local like = (Config.PublicNumberPrefix or 'INC') .. '-' .. day .. '-%'
        local row = MySQL.single.await(
            [[SELECT public_number FROM mdt_incidents
              WHERE public_number LIKE ?
              ORDER BY id DESC LIMIT 1]],
            { like }
        )
        local last = 0
        if row and row.public_number then
            last = tonumber(tostring(row.public_number):match('-(%d+)$')) or 0
        end
        daySeq.n = last
    end
    daySeq.n = daySeq.n + 1
    return ('%s-%s-%04d'):format(Config.PublicNumberPrefix or 'INC', day, daySeq.n)
end

local function normalizeType(t)
    t = tostring(t or 'other'):lower()
    local allowed = { police = true, ems = true, mechanic = true, fire = true, civil = true, other = true }
    return allowed[t] and t or 'other'
end

local function rowFromId(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await('SELECT * FROM mdt_incidents WHERE id = ?', { id })
end

local CLOSED_STATUSES = MdtIncidentStates.CLOSED

--- @param data table
---   type, status?, priority?, service_job?, summary?, location_label?,
---   location_x/y/z?, created_by?, assigned_crew?, dispatch_call_id?,
---   source? (player for actor), skipTimeline?, skipAudit?
--- @return table|nil incident, string|nil err
function MdtIncidentEngine.Create(data)
    data = type(data) == 'table' and data or {}
    local status = tostring(data.status or 'created')
    if not MdtIncidentStates.IsValid(status) then
        return nil, 'invalid_status'
    end

    local createdBy = data.created_by or citizenIdOf(data.source)
    local publicNumber = nextPublicNumber()
    local incidentType = normalizeType(data.type)
    local priority = math.max(0, math.min(5, tonumber(data.priority) or 2))
    local serviceJob = data.service_job and tostring(data.service_job):sub(1, 32) or nil
    if not serviceJob and Config.ServiceIncidentType then
        for service, t in pairs(Config.ServiceIncidentType) do
            if t == incidentType then
                serviceJob = service
                break
            end
        end
    end

    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incidents
            (public_number, type, status, priority, service_job, summary, location_label,
             location_x, location_y, location_z, created_by, assigned_crew, dispatch_call_id, closed_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            publicNumber,
            incidentType,
            status,
            priority,
            serviceJob,
            data.summary and tostring(data.summary):sub(1, 512) or nil,
            data.location_label and tostring(data.location_label):sub(1, 255) or nil,
            data.location_x ~= nil and (tonumber(data.location_x) + 0.0) or nil,
            data.location_y ~= nil and (tonumber(data.location_y) + 0.0) or nil,
            data.location_z ~= nil and (tonumber(data.location_z) + 0.0) or nil,
            createdBy,
            data.assigned_crew and tostring(data.assigned_crew):sub(1, 64) or nil,
            data.dispatch_call_id and tostring(data.dispatch_call_id):sub(1, 32) or nil,
            CLOSED_STATUSES[status] and os.date('!%Y-%m-%d %H:%M:%S') or nil,
        }
    )
    if not insertId then return nil, 'insert_failed' end

    if not data.skipTimeline then
        MdtTimeline.Append(insertId, 'incident_created', {
            source = data.source,
            actorCitizenid = createdBy,
            payload = {
                public_number = publicNumber,
                type = incidentType,
                status = status,
                dispatch_call_id = data.dispatch_call_id,
            },
        })
    end

    if not data.skipAudit then
        MdtAudit.Log('incident.create', {
            source = data.source,
            actorCitizenid = createdBy,
            resource = 'mrp_mdt_core',
            target = tostring(insertId),
            meta = { public_number = publicNumber, type = incidentType, status = status },
        })
    end

    return rowFromId(insertId)
end

function MdtIncidentEngine.Get(id)
    return rowFromId(id)
end

function MdtIncidentEngine.GetByPublicNumber(publicNumber)
    if not publicNumber or publicNumber == '' then return nil end
    return MySQL.single.await('SELECT * FROM mdt_incidents WHERE public_number = ?', { tostring(publicNumber) })
end

function MdtIncidentEngine.GetByDispatchCallId(callId)
    if not callId or callId == '' then return nil end
    return MySQL.single.await(
        'SELECT * FROM mdt_incidents WHERE dispatch_call_id = ? ORDER BY id DESC LIMIT 1',
        { tostring(callId) }
    )
end

--- @param id number
--- @param newStatus string
--- @param actor table|nil { source, citizenid, reason, skipTimeline?, skipAudit? }
--- @return table|nil, string|nil err
function MdtIncidentEngine.Transition(id, newStatus, actor)
    actor = type(actor) == 'table' and actor or {}
    newStatus = tostring(newStatus or '')
    local row = rowFromId(id)
    if not row then return nil, 'not_found' end
    if not MdtIncidentStates.IsValid(newStatus) then return nil, 'invalid_status' end
    if not MdtIncidentStates.CanTransition(row.status, newStatus) then
        return nil, 'transition_denied'
    end

    local closedAt = CLOSED_STATUSES[newStatus] and os.date('!%Y-%m-%d %H:%M:%S') or nil
    local affected = MySQL.update.await(
        [[UPDATE mdt_incidents
          SET status = ?, closed_at = COALESCE(?, closed_at)
          WHERE id = ? AND status = ?]],
        { newStatus, closedAt, row.id, row.status }
    )
    if not affected or affected < 1 then
        return nil, 'race_or_missing'
    end

    local actorCid = actor.citizenid or citizenIdOf(actor.source)
    if not actor.skipTimeline then
        MdtTimeline.Append(row.id, 'status_changed', {
            source = actor.source,
            actorCitizenid = actorCid,
            payload = {
                from = row.status,
                to = newStatus,
                reason = actor.reason,
            },
        })
    end
    if not actor.skipAudit then
        MdtAudit.Log('incident.transition', {
            source = actor.source,
            actorCitizenid = actorCid,
            resource = 'mrp_mdt_core',
            target = tostring(row.id),
            meta = { from = row.status, to = newStatus, reason = actor.reason },
        })
    end

    return rowFromId(row.id)
end

--[[
  Transition towards `targetStatus`, walking legal intermediate hops when the caller
  skipped steps (dispatch lets a unit press "Atvykau" on a still-`created` call).
  Every hop goes through Transition(), so each one is validated + timelined.

  @param id number
  @param targetStatus string
  @param actor table|nil { source, citizenid, reason, skipTimeline?, skipAudit? }
  @return table|nil incident, string|nil err, table|nil appliedSteps
]]
function MdtIncidentEngine.TransitionTo(id, targetStatus, actor)
    actor = type(actor) == 'table' and actor or {}
    targetStatus = tostring(targetStatus or '')
    if not MdtIncidentStates.IsValid(targetStatus) then return nil, 'invalid_status' end

    local maxSteps = math.max(1, tonumber(Config.MaxTransitionWalkSteps) or 4)
    local applied = {}

    --- Two crew members can act on the same call at once; recompute the walk if we lose the CAS.
    for _ = 1, 3 do
        local row = rowFromId(id)
        if not row then return nil, 'not_found' end
        if row.status == targetStatus then return row, nil, applied end

        local path = MdtIncidentStates.PathTo(row.status, targetStatus)
        if not path or #path == 0 then return nil, 'transition_denied' end
        if #path > maxSteps then return nil, 'transition_path_too_long' end

        local raced = false
        for index, step in ipairs(path) do
            local updated, err = MdtIncidentEngine.Transition(id, step, {
                source = actor.source,
                citizenid = actor.citizenid,
                --- Intermediate hops are marked so the timeline shows they were auto-walked.
                reason = index < #path and ((actor.reason or 'transition') .. ':auto_step') or actor.reason,
                skipTimeline = actor.skipTimeline,
                --- One audit row per requested transition, not per intermediate hop.
                skipAudit = actor.skipAudit or index < #path,
            })
            if not updated then
                if err ~= 'race_or_missing' then
                    return nil, err or 'transition_failed', applied
                end
                raced = true
                break
            end
            applied[#applied + 1] = step
        end
        if not raced then
            return rowFromId(id), nil, applied
        end
    end

    --- Someone else may have driven it to the same place; that still counts as success.
    local final = rowFromId(id)
    if final and final.status == targetStatus then return final, nil, applied end
    return nil, 'race_or_missing', applied
end

--- Dispatch actions that mean "this unit is working the call" (→ listed on the incident).
local ENGAGING_ACTIONS = {
    accept = true,
    enroute = true,
    arrived = true,
    in_progress = true,
    done = true,
}

--[[
  Record the acting unit on the incident so later PD/EMS actions (fines, arrests,
  reports) can resolve "the incident I am working" without the UI passing an id.
  Never fails the caller: a missing unit row must not block a status change.
]]
local function registerDispatchUnit(incidentId, action, opts)
    if Config.AutoAttachDispatchUnits == false then return end
    if not ENGAGING_ACTIONS[tostring(action or '')] then return end
    local src = tonumber(opts.source)
    if not src or src < 1 then return end

    local ok, err = pcall(function()
        --- First unit on the call owns the case until someone reassigns the role.
        local existing = MdtIncidentLinks.ListOfficers(incidentId)
        MdtIncidentLinks.AttachOfficer(incidentId, {
            source = src,
            citizenid = opts.citizenid,
            role = #existing == 0 and 'lead' or 'assist',
        }, { source = src, citizenid = opts.citizenid })
    end)
    if not ok then
        print(('[mrp_mdt_core] dispatch unit register failed: %s'):format(tostring(err)))
    end
end

--[[
  Sync an mrp_dispatch call to its mirrored incident.
  Mapping table lives in shared/incident_states.lua so dispatch stays dumb.

  @param callId string  mrp_dispatch call id (C-00001)
  @param action string  updateCallStatus action (accept/enroute/arrived/done/reject/...)
  @param opts table|nil { source, citizenid, incidentId?, reason? }
  @return table|nil incident, string|nil err
]]
function MdtIncidentEngine.SyncDispatchCall(callId, action, opts)
    if Config.SyncDispatchStatus == false then return nil, 'sync_disabled' end
    opts = type(opts) == 'table' and opts or {}

    if not MdtIncidentStates.MapDispatchAction(action) then return nil, 'unmapped_action' end

    local row
    if opts.incidentId then
        row = rowFromId(opts.incidentId)
    end
    if not row then
        row = MdtIncidentEngine.GetByDispatchCallId(callId)
    end
    if not row then return nil, 'incident_not_found' end

    local targetStatus, replaced = MdtIncidentStates.ResolveDispatchTarget(row.status, action)
    local reason = opts.reason or ('dispatch:' .. tostring(action))
    if replaced then
        reason = ('%s:as_%s'):format(reason, targetStatus)
    end

    registerDispatchUnit(row.id, action, opts)

    return MdtIncidentEngine.TransitionTo(row.id, targetStatus, {
        source = opts.source,
        citizenid = opts.citizenid,
        reason = reason,
    })
end

--- @param id number
--- @param crewId string|nil
--- @param actor table|nil
function MdtIncidentEngine.AssignCrew(id, crewId, actor)
    actor = type(actor) == 'table' and actor or {}
    local row = rowFromId(id)
    if not row then return nil, 'not_found' end

    crewId = crewId and tostring(crewId):sub(1, 64) or nil
    if row.assigned_crew == crewId then return row end

    MySQL.update.await('UPDATE mdt_incidents SET assigned_crew = ? WHERE id = ?', { crewId, row.id })

    local actorCid = actor.citizenid or citizenIdOf(actor.source)
    if not actor.skipTimeline then
        MdtTimeline.Append(row.id, crewId and 'crew_assigned' or 'crew_cleared', {
            source = actor.source,
            actorCitizenid = actorCid,
            payload = { assigned_crew = crewId, previous_crew = row.assigned_crew },
        })
    end
    if not actor.skipAudit then
        MdtAudit.Log('incident.assign_crew', {
            source = actor.source,
            actorCitizenid = actorCid,
            resource = 'mrp_mdt_core',
            target = tostring(row.id),
            meta = { assigned_crew = crewId, previous_crew = row.assigned_crew },
        })
    end

    --- Auto-move Created → Assigned when first crew is set.
    if crewId and row.status == 'created' then
        local updated, err = MdtIncidentEngine.Transition(row.id, 'assigned', {
            source = actor.source,
            citizenid = actor.citizenid,
            reason = 'crew_assigned',
            skipAudit = true,
        })
        if updated then return updated end
        if err and err ~= 'transition_denied' then
            print(('[mrp_mdt_core] assign auto-transition failed: %s'):format(err))
        end
    end

    return rowFromId(row.id)
end

--[[ ------------------------------------------------------------------
  Read-only query surface (Phase 2). No mutation, parameterized only.
--------------------------------------------------------------------]]

local LIST_SORTABLE = {
    id = 'i.id',
    created_at = 'i.created_at',
    updated_at = 'i.updated_at',
    priority = 'i.priority',
}

local CLOSED_STATUS_LIST = {}
for status in pairs(CLOSED_STATUSES) do
    CLOSED_STATUS_LIST[#CLOSED_STATUS_LIST + 1] = status
end
table.sort(CLOSED_STATUS_LIST)

--[[
  @param filters table|nil
    type, status (string|table), service_job, dispatch_call_id, assigned_crew,
    created_by, openOnly (bool), search (public_number/summary), orderBy, desc,
    limit, offset
  @return table rows
]]
function MdtIncidentEngine.List(filters)
    filters = type(filters) == 'table' and filters or {}

    local where, params = { '1 = 1' }, {}

    if filters.type then
        where[#where + 1] = 'i.type = ?'
        params[#params + 1] = normalizeType(filters.type)
    end

    if type(filters.status) == 'table' then
        local placeholders, seen = {}, {}
        for _, status in ipairs(filters.status) do
            status = tostring(status)
            if MdtIncidentStates.IsValid(status) and not seen[status] then
                seen[status] = true
                placeholders[#placeholders + 1] = '?'
                params[#params + 1] = status
            end
        end
        if #placeholders > 0 then
            where[#where + 1] = ('i.status IN (%s)'):format(table.concat(placeholders, ', '))
        end
    elseif filters.status and MdtIncidentStates.IsValid(filters.status) then
        where[#where + 1] = 'i.status = ?'
        params[#params + 1] = tostring(filters.status)
    end

    if filters.openOnly then
        local placeholders = {}
        for _, status in ipairs(CLOSED_STATUS_LIST) do
            placeholders[#placeholders + 1] = '?'
            params[#params + 1] = status
        end
        where[#where + 1] = ('i.status NOT IN (%s)'):format(table.concat(placeholders, ', '))
    end

    --- Fixed order keeps the generated SQL stable (statement cache friendly).
    for _, column in ipairs({ 'service_job', 'dispatch_call_id', 'assigned_crew', 'created_by' }) do
        local value = filters[column]
        if value ~= nil and value ~= '' then
            where[#where + 1] = ('i.%s = ?'):format(column)
            params[#params + 1] = tostring(value):sub(1, 64)
        end
    end

    if filters.search and filters.search ~= '' then
        --- Escape LIKE wildcards so a user query can never widen the scan.
        local needle = tostring(filters.search):sub(1, 64):gsub('([%%_\\])', '\\%1')
        where[#where + 1] = '(i.public_number LIKE ? OR i.summary LIKE ? OR i.location_label LIKE ?)'
        params[#params + 1] = '%' .. needle .. '%'
        params[#params + 1] = '%' .. needle .. '%'
        params[#params + 1] = '%' .. needle .. '%'
    end

    local orderColumn = LIST_SORTABLE[tostring(filters.orderBy or 'id')] or LIST_SORTABLE.id
    local direction = filters.desc == false and 'ASC' or 'DESC'
    local limit = math.min(tonumber(Config.MaxListLimit) or 100, math.max(1, tonumber(filters.limit) or 50))
    local offset = math.max(0, math.floor(tonumber(filters.offset) or 0))
    params[#params + 1] = limit
    params[#params + 1] = offset

    return MySQL.query.await(
        ([[SELECT i.* FROM mdt_incidents i
           WHERE %s
           ORDER BY %s %s
           LIMIT ? OFFSET ?]]):format(table.concat(where, ' AND '), orderColumn, direction),
        params
    ) or {}
end

--- Incidents where a citizen is a listed party (parties stub table).
function MdtIncidentEngine.ListByCitizen(citizenid, opts)
    citizenid = citizenid and tostring(citizenid):sub(1, 64) or nil
    if not citizenid or citizenid == '' then return {} end
    opts = type(opts) == 'table' and opts or {}
    local limit = math.min(tonumber(Config.MaxListLimit) or 100, math.max(1, tonumber(opts.limit) or 50))

    return MySQL.query.await(
        [[SELECT i.*, p.role AS party_role, p.notes AS party_notes
          FROM mdt_incident_parties p
          INNER JOIN mdt_incidents i ON i.id = p.incident_id
          WHERE p.citizenid = ?
          ORDER BY i.id DESC
          LIMIT ?]],
        { citizenid, limit }
    ) or {}
end

--- Incidents referencing a plate (vehicles stub table).
function MdtIncidentEngine.ListByPlate(plate, opts)
    plate = plate and tostring(plate):upper():gsub('%s+', ''):sub(1, 16) or nil
    if not plate or plate == '' then return {} end
    opts = type(opts) == 'table' and opts or {}
    local limit = math.min(tonumber(Config.MaxListLimit) or 100, math.max(1, tonumber(opts.limit) or 50))

    return MySQL.query.await(
        [[SELECT i.*, v.role AS vehicle_role, v.notes AS vehicle_notes
          FROM mdt_incident_vehicles v
          INNER JOIN mdt_incidents i ON i.id = v.incident_id
          WHERE v.plate = ?
          ORDER BY i.id DESC
          LIMIT ?]],
        { plate, limit }
    ) or {}
end

--- Everything a future MDT incident view needs in one round trip.
function MdtIncidentEngine.GetBundle(id, opts)
    local row = rowFromId(id)
    if not row then return nil, 'not_found' end
    opts = type(opts) == 'table' and opts or {}
    return {
        incident = row,
        timeline = MdtTimeline.List(row.id, opts.timelineLimit),
        parties = MdtIncidentLinks.ListParties(row.id),
        vehicles = MdtIncidentLinks.ListVehicles(row.id),
        officers = MdtIncidentLinks.ListOfficers(row.id),
        allowedTransitions = MdtIncidentStates.AllowedFrom(row.status),
        closed = MdtIncidentStates.IsClosed(row.status),
    }
end

exports('CreateIncident', function(data)
    return MdtIncidentEngine.Create(data)
end)

exports('GetIncident', function(id)
    return MdtIncidentEngine.Get(id)
end)

exports('GetIncidentByPublicNumber', function(publicNumber)
    return MdtIncidentEngine.GetByPublicNumber(publicNumber)
end)

exports('GetIncidentByDispatchCall', function(callId)
    return MdtIncidentEngine.GetByDispatchCallId(callId)
end)

exports('ListIncidents', function(filters)
    return MdtIncidentEngine.List(filters)
end)

exports('ListIncidentsByCitizen', function(citizenid, opts)
    return MdtIncidentEngine.ListByCitizen(citizenid, opts)
end)

exports('ListIncidentsByPlate', function(plate, opts)
    return MdtIncidentEngine.ListByPlate(plate, opts)
end)

exports('GetIncidentBundle', function(id, opts)
    return MdtIncidentEngine.GetBundle(id, opts)
end)

exports('GetIncidentTimeline', function(id, limit)
    return MdtTimeline.List(id, limit)
end)

exports('TransitionIncident', function(id, newStatus, actor)
    return MdtIncidentEngine.Transition(id, newStatus, actor)
end)

--- Walks legal intermediate hops when the caller skipped steps.
exports('TransitionIncidentTo', function(id, targetStatus, actor)
    return MdtIncidentEngine.TransitionTo(id, targetStatus, actor)
end)

exports('SyncDispatchCallStatus', function(callId, action, opts)
    return MdtIncidentEngine.SyncDispatchCall(callId, action, opts)
end)

exports('AssignIncidentCrew', function(id, crewId, actor)
    return MdtIncidentEngine.AssignCrew(id, crewId, actor)
end)

exports('ListAllowedTransitions', function(fromStatus)
    return MdtIncidentStates.AllowedFrom(fromStatus)
end)

exports('IsValidIncidentStatus', function(status)
    return MdtIncidentStates.IsValid(status)
end)

exports('MapDispatchStatus', function(dispatchStatus)
    return MdtIncidentStates.MapDispatchStatus(dispatchStatus)
end)

exports('MapDispatchAction', function(action)
    return MdtIncidentStates.MapDispatchAction(action)
end)

exports('ShouldMirrorDispatchCalls', function()
    return Config.MirrorDispatchCalls ~= false
end)

exports('ShouldSyncDispatchStatus', function()
    return Config.SyncDispatchStatus ~= false
end)
