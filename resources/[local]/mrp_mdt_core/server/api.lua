--- Read-only incident API for MDT NUIs (Phase 2). No writes here.
--- Every callback is RBAC-gated server-side; clients never send trusted fields.

local QBCore = exports['qb-core']:GetCoreObject()

local function playerOf(src)
    return QBCore.Functions.GetPlayer(src)
end

local function isAdmin(src)
    for _, perm in ipairs(Config.AdminBypassPermissions or {}) do
        if QBCore.Functions.HasPermission(src, perm) then return true end
    end
    return false
end

--[[
  Which service_job rows a viewer may read.
  Police see police incidents, EMS see ems, mechanics see mechanic — unless
  Config.CrossServiceView is on, or the viewer is an admin.
  @return string|nil serviceJob  nil = unrestricted
]]
local function viewScope(src)
    if Config.CrossServiceView == true or isAdmin(src) then return nil end
    local Player = playerOf(src)
    local job = Player and Player.PlayerData and Player.PlayerData.job
    return job and (Config.JobServiceMap or {})[tostring(job.name)] or '__none__'
end

local function inScope(incident, scope)
    if not scope then return true end
    if scope == '__none__' then return false end
    return tostring(incident.service_job or '') == scope
end

local function deny(cb, msg)
    return cb({ ok = false, msg = msg or 'Nėra teisės.' })
end

--- Only whitelisted, sanitized filters reach the query builder.
local function sanitizeFilters(raw, scope)
    raw = type(raw) == 'table' and raw or {}
    local filters = {
        type = raw.type,
        status = raw.status,
        openOnly = raw.openOnly == true,
        dispatch_call_id = raw.dispatch_call_id,
        assigned_crew = raw.assigned_crew,
        search = raw.search,
        orderBy = raw.orderBy,
        desc = raw.desc,
        limit = raw.limit,
        offset = raw.offset,
    }
    --- Scope wins over anything the client asked for.
    filters.service_job = scope ~= '__none__' and (scope or raw.service_job) or nil
    return filters
end

QBCore.Functions.CreateCallback('mrp_mdt_core:server:getIncidentMeta', function(src, cb)
    if not MdtRbac.HasPermission(src, 'INCIDENT_VIEW') then return deny(cb) end
    cb({
        ok = true,
        statuses = MdtIncidentStates.STATUSES,
        progression = MdtIncidentStates.PROGRESSION,
        closedStatuses = MdtIncidentStates.CLOSED,
        partyRoles = MdtIncidentLinks.PartyRoles(),
        vehicleRoles = MdtIncidentLinks.VehicleRoles(),
        scope = viewScope(src),
        permissions = {
            view = true,
            create = MdtRbac.HasPermission(src, 'INCIDENT_CREATE'),
            assign = MdtRbac.HasPermission(src, 'INCIDENT_ASSIGN'),
            transition = MdtRbac.HasPermission(src, 'INCIDENT_TRANSITION'),
            close = MdtRbac.HasPermission(src, 'INCIDENT_CLOSE'),
        },
    })
end)

QBCore.Functions.CreateCallback('mrp_mdt_core:server:listIncidents', function(src, cb, filters)
    if not MdtRbac.HasPermission(src, 'INCIDENT_VIEW') then return deny(cb) end
    local scope = viewScope(src)
    if scope == '__none__' then return deny(cb) end

    local ok, rows = pcall(MdtIncidentEngine.List, sanitizeFilters(filters, scope))
    if not ok then
        print(('[mrp_mdt_core] listIncidents failed: %s'):format(tostring(rows)))
        return cb({ ok = false, msg = 'Užklausos klaida.' })
    end

    MdtAudit.LogAsync('incident.list', {
        source = src,
        resource = 'mrp_mdt_core',
        target = tostring(scope or 'all'),
        meta = { count = #rows, search = type(filters) == 'table' and filters.search or nil },
        dedupeKey = 'list',
    })
    cb({ ok = true, rows = rows, scope = scope })
end)

--- @param ref number|string  incident id or public_number (INC-YYYYMMDD-0001)
local function resolveIncident(ref)
    if ref == nil then return nil end
    local asId = tonumber(ref)
    if asId then return MdtIncidentEngine.Get(asId) end
    return MdtIncidentEngine.GetByPublicNumber(ref)
end

QBCore.Functions.CreateCallback('mrp_mdt_core:server:getIncident', function(src, cb, ref)
    if not MdtRbac.HasPermission(src, 'INCIDENT_VIEW') then return deny(cb) end
    local incident = resolveIncident(ref)
    if not incident then return cb({ ok = false, msg = 'Byla nerasta.' }) end
    if not inScope(incident, viewScope(src)) then return deny(cb, 'Kitos tarnybos byla.') end

    local bundle = MdtIncidentEngine.GetBundle(incident.id)
    MdtAudit.LogAsync('incident.view', {
        source = src,
        resource = 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { public_number = incident.public_number, status = incident.status },
        dedupeKey = tostring(incident.id),
    })
    cb({ ok = true, bundle = bundle })
end)

QBCore.Functions.CreateCallback('mrp_mdt_core:server:getIncidentTimeline', function(src, cb, ref, limit)
    if not MdtRbac.HasPermission(src, 'INCIDENT_VIEW') then return deny(cb) end
    local incident = resolveIncident(ref)
    if not incident then return cb({ ok = false, msg = 'Byla nerasta.' }) end
    if not inScope(incident, viewScope(src)) then return deny(cb, 'Kitos tarnybos byla.') end
    cb({ ok = true, rows = MdtTimeline.List(incident.id, limit) })
end)

QBCore.Functions.CreateCallback('mrp_mdt_core:server:getIncidentsByCitizen', function(src, cb, citizenid, opts)
    if not MdtRbac.HasPermission(src, 'INCIDENT_VIEW') then return deny(cb) end
    local scope = viewScope(src)
    if scope == '__none__' then return deny(cb) end

    local rows = MdtIncidentEngine.ListByCitizen(citizenid, opts)
    local visible = {}
    for _, row in ipairs(rows) do
        if inScope(row, scope) then visible[#visible + 1] = row end
    end

    MdtAudit.LogAsync('incident.lookup_citizen', {
        source = src,
        resource = 'mrp_mdt_core',
        target = citizenid and tostring(citizenid) or nil,
        meta = { count = #visible },
        dedupeKey = tostring(citizenid),
    })
    cb({ ok = true, rows = visible })
end)

QBCore.Functions.CreateCallback('mrp_mdt_core:server:getIncidentsByPlate', function(src, cb, plate, opts)
    if not MdtRbac.HasPermission(src, 'INCIDENT_VIEW') then return deny(cb) end
    local scope = viewScope(src)
    if scope == '__none__' then return deny(cb) end

    local rows = MdtIncidentEngine.ListByPlate(plate, opts)
    local visible = {}
    for _, row in ipairs(rows) do
        if inScope(row, scope) then visible[#visible + 1] = row end
    end

    MdtAudit.LogAsync('incident.lookup_plate', {
        source = src,
        resource = 'mrp_mdt_core',
        target = plate and tostring(plate) or nil,
        meta = { count = #visible },
        dedupeKey = tostring(plate),
    })
    cb({ ok = true, rows = visible })
end)

QBCore.Functions.CreateCallback('mrp_mdt_core:server:analyticsSummary', function(src, cb, from, to)
    if not isAdmin(src) and not MdtRbac.HasPermission(src, 'MDT_ADMIN') then
        return deny(cb, 'Tik administratoriams.')
    end
    cb(MdtAnalytics and MdtAnalytics.Summary(from, to) or { ok = false, message = 'analytics_unavailable' })
end)

QBCore.Functions.CreateCallback('mrp_mdt_core:server:getAllowedTransitions', function(src, cb, ref)
    if not MdtRbac.HasPermission(src, 'INCIDENT_VIEW') then return deny(cb) end
    local incident = resolveIncident(ref)
    if not incident then return cb({ ok = false, msg = 'Byla nerasta.' }) end
    if not inScope(incident, viewScope(src)) then return deny(cb, 'Kitos tarnybos byla.') end
    cb({
        ok = true,
        status = incident.status,
        allowed = MdtIncidentStates.AllowedFrom(incident.status),
        canTransition = MdtRbac.HasPermission(src, 'INCIDENT_TRANSITION'),
    })
end)
