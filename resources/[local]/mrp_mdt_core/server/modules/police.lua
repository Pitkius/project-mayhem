--[[
  Police case module (Phase 3).

  Owns the PD-specific extension of an incident: case row, written report,
  use-of-force, tools, seized property and typed references (fines, arrests,
  fingerprints, bodycam/CCTV/photo/evidence handles).

  Rules:
  - The incident lifecycle stays with the Incident Engine. Nothing here writes
    `mdt_incidents.status` — callers go through TransitionIncident(To).
  - Core case data is normalized columns; JSON is only used for report extras.
  - Every write appends a timeline row so the case reads as a history.
]]

MdtPolice = MdtPolice or {}

local QBCore = exports['qb-core']:GetCoreObject()

local REPORT_KIND = 'police'

local function clampInt(value, min, max, fallback)
    local n = tonumber(value)
    if not n then return fallback end
    n = math.floor(n)
    if n < min then return min end
    if n > max then return max end
    return n
end

local function str(value, limit)
    if value == nil then return nil end
    local s = tostring(value)
    if s == '' then return nil end
    return s:sub(1, limit)
end

local function actorOf(actor)
    actor = type(actor) == 'table' and actor or {}
    local src = tonumber(actor.source)
    local cid = actor.citizenid
    local name = actor.name
    if src and src > 0 and (not cid or not name) then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            cid = cid or Player.PlayerData.citizenid
            if not name then
                local c = Player.PlayerData.charinfo or {}
                local full = (tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or ''))
                    :gsub('^%s+', ''):gsub('%s+$', '')
                name = full ~= '' and full or nil
            end
        end
    end
    return src, cid, name
end

--- @return table|nil incident, string|nil err
local function policeIncident(incidentId)
    local incident = MdtIncidentEngine.Get(incidentId)
    if not incident then return nil, 'incident_not_found' end
    if tostring(incident.type) ~= 'police' then return nil, 'not_police_incident' end
    return incident
end

local function caseRow(incidentId)
    return MySQL.single.await('SELECT * FROM mdt_incident_police WHERE incident_id = ?', { incidentId })
end

--- Case row is created lazily: dispatch-mirrored incidents only get one when PD touches them.
local function ensureCaseRow(incidentId)
    local row = caseRow(incidentId)
    if row then return row end
    MySQL.query.await(
        'INSERT IGNORE INTO mdt_incident_police (incident_id) VALUES (?)',
        { incidentId }
    )
    return caseRow(incidentId)
end

--- Keep `fine_total` derived from the linked fine rows so it can never drift.
local function recomputeFineTotal(incidentId)
    local total = MySQL.scalar.await(
        [[SELECT COALESCE(SUM(amount), 0) FROM mdt_incident_refs
          WHERE incident_id = ? AND ref_type = 'fine']],
        { incidentId }
    )
    MySQL.update.await(
        'UPDATE mdt_incident_police SET fine_total = ? WHERE incident_id = ?',
        { clampInt(total, 0, 2147483647, 0), incidentId }
    )
end

--- Only lifts flags / moves `pending` forward; an explicit officer decision is never overwritten.
local function raiseCaseFlags(incidentId, flags)
    local sets, params = {}, {}
    for _, column in ipairs({ 'arrest_made', 'force_used', 'weapon_involved' }) do
        if flags[column] then
            sets[#sets + 1] = ('`%s` = 1'):format(column)
        end
    end
    if flags.disposition and MdtPoliceCase.IsDisposition(flags.disposition) then
        sets[#sets + 1] = "disposition = IF(disposition = 'pending', ?, disposition)"
        params[#params + 1] = flags.disposition
    end
    if #sets == 0 then return end
    params[#params + 1] = incidentId
    MySQL.update.await(
        ('UPDATE mdt_incident_police SET %s WHERE incident_id = ?'):format(table.concat(sets, ', ')),
        params
    )
end

--[[ ------------------------------------------------------------------
  Case row
--------------------------------------------------------------------]]

--[[
  @param data table  Incident Engine Create() fields, `type` forced to police
    + optional case fields (offence_code, offence_label, disposition, station)
  @return table|nil incident, string|nil err
]]
function MdtPolice.CreateCase(data)
    data = type(data) == 'table' and data or {}
    local src, cid, _ = actorOf({ source = data.source, citizenid = data.created_by })

    local incident, err = MdtIncidentEngine.Create({
        type = 'police',
        status = data.status,
        priority = data.priority,
        service_job = 'police',
        summary = data.summary,
        location_label = data.location_label,
        location_x = data.location_x,
        location_y = data.location_y,
        location_z = data.location_z,
        dispatch_call_id = data.dispatch_call_id,
        created_by = cid,
        source = src,
    })
    if not incident then return nil, err or 'create_failed' end

    ensureCaseRow(incident.id)
    MdtPolice.UpdateCase(incident.id, {
        offence_code = data.offence_code,
        offence_label = data.offence_label,
        disposition = data.disposition,
        station = data.station,
    }, { source = src, citizenid = cid, skipTimeline = true })

    --- Whoever opens the case owns it until the role is reassigned.
    if cid then
        MdtIncidentLinks.AttachOfficer(incident.id, {
            source = src,
            citizenid = cid,
            role = 'lead',
        }, { source = src, citizenid = cid })
    end

    return MdtIncidentEngine.Get(incident.id)
end

--[[
  @param data table { offence_code?, offence_label?, disposition?, station?,
                      lead_officer_citizenid?, lead_callsign?,
                      arrest_made?, force_used?, weapon_involved? }
  @return table|nil case row, string|nil err
]]
function MdtPolice.UpdateCase(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end

    local before = ensureCaseRow(incident.id)
    if not before then return nil, 'case_row_missing' end

    local sets, params, changed = {}, {}, {}

    local textFields = {
        { column = 'offence_code', limit = 64 },
        { column = 'offence_label', limit = 255 },
        { column = 'station', limit = 64 },
        { column = 'lead_officer_citizenid', limit = 64 },
        { column = 'lead_callsign', limit = 16 },
    }
    for _, field in ipairs(textFields) do
        if data[field.column] ~= nil then
            local value = str(data[field.column], field.limit)
            sets[#sets + 1] = ('`%s` = ?'):format(field.column)
            params[#params + 1] = value
            changed[field.column] = value
        end
    end

    if data.disposition ~= nil then
        local disposition = tostring(data.disposition):lower()
        if not MdtPoliceCase.IsDisposition(disposition) then return nil, 'invalid_disposition' end
        sets[#sets + 1] = 'disposition = ?'
        params[#params + 1] = disposition
        changed.disposition = disposition
    end

    for _, column in ipairs({ 'arrest_made', 'force_used', 'weapon_involved' }) do
        if data[column] ~= nil then
            local value = (data[column] == true or tonumber(data[column]) == 1) and 1 or 0
            sets[#sets + 1] = ('`%s` = ?'):format(column)
            params[#params + 1] = value
            changed[column] = value
        end
    end

    if #sets == 0 then return before end

    params[#params + 1] = incident.id
    MySQL.update.await(
        ('UPDATE mdt_incident_police SET %s WHERE incident_id = ?'):format(table.concat(sets, ', ')),
        params
    )

    actor = type(actor) == 'table' and actor or {}
    local src, cid = actorOf(actor)
    if not actor.skipTimeline then
        MdtTimeline.Append(incident.id, 'case_updated', {
            source = src,
            actorCitizenid = cid,
            payload = changed,
        })
    end
    MdtAudit.LogAsync('incident.case_update', {
        source = src,
        actorCitizenid = cid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = changed,
        dedupeKey = tostring(incident.id),
    })

    return caseRow(incident.id)
end

function MdtPolice.GetCase(incidentId)
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end
    return caseRow(incident.id)
end

--[[ ------------------------------------------------------------------
  Report
--------------------------------------------------------------------]]

function MdtPolice.GetReport(incidentId, kind)
    incidentId = tonumber(incidentId)
    if not incidentId then return nil end
    return MySQL.single.await(
        'SELECT * FROM mdt_incident_reports WHERE incident_id = ? AND kind = ?',
        { incidentId, str(kind, 32) or REPORT_KIND }
    )
end

--[[
  Upsert the written report. `meta` holds structured extras only (checkboxes,
  scene conditions) — the narrative itself is the `body` column.

  @param data table { title?, body, meta?, kind? }
  @return table|nil row, string|nil err
]]
function MdtPolice.SaveReport(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end

    local kind = str(data.kind, 32) or REPORT_KIND
    local body = data.body ~= nil and tostring(data.body):sub(1, tonumber(Config.MaxReportLength) or 20000) or nil
    local title = str(data.title, 255)
    if (not body or body:gsub('%s+', '') == '') and not title then
        return nil, 'empty_report'
    end

    local meta = data.meta
    if meta ~= nil and type(meta) ~= 'string' then
        local ok, encoded = pcall(json.encode, meta)
        meta = ok and encoded or nil
    end

    local src, cid, name = actorOf(actor)
    local existing = MdtPolice.GetReport(incident.id, kind)

    if existing then
        MySQL.update.await(
            [[UPDATE mdt_incident_reports
              SET title = ?, body = ?, meta = COALESCE(?, meta),
                  updated_by_citizenid = ?, revision = revision + 1
              WHERE id = ?]],
            { title, body, meta, cid, existing.id }
        )
    else
        local insertId = MySQL.insert.await(
            [[INSERT INTO mdt_incident_reports
                (incident_id, kind, title, body, meta, author_citizenid, author_name, updated_by_citizenid)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
            { incident.id, kind, title, body, meta, cid, name, cid }
        )
        if not insertId then return nil, 'insert_failed' end
    end

    local row = MdtPolice.GetReport(incident.id, kind)
    ensureCaseRow(incident.id)

    MdtTimeline.Append(incident.id, existing and 'report_updated' or 'report_filed', {
        source = src,
        actorCitizenid = cid,
        payload = {
            kind = kind,
            title = title,
            revision = row and row.revision or 1,
            length = body and #body or 0,
        },
    })
    MdtAudit.Log('incident.report_save', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { kind = kind, revision = row and row.revision or 1, new = existing == nil },
    })

    if not existing and MdtAnalytics then
        MdtAnalytics.Record('report_created', {
            source = src,
            service = 'police',
            actorCitizenid = cid,
            meta = { incident_id = incident.id, kind = kind },
        })
    end

    return row
end

--[[ ------------------------------------------------------------------
  Force / tools / seized property
--------------------------------------------------------------------]]

local function subjectName(citizenid, provided)
    local given = str(provided, 128)
    if given then return given end
    if not citizenid then return nil end
    local online = QBCore.Functions.GetPlayerByCitizenId(citizenid)
    local charinfo
    if online then
        charinfo = online.PlayerData.charinfo
    else
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
        if row and row.charinfo then
            local ok, decoded = pcall(json.decode, row.charinfo)
            charinfo = ok and decoded or nil
        end
    end
    if type(charinfo) ~= 'table' then return nil end
    local name = (tostring(charinfo.firstname or '') .. ' ' .. tostring(charinfo.lastname or ''))
        :gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or nil
end

--[[
  @param data table { force_type, subject_citizenid?, subject_name?, tool?,
                      injuries?, medical_called?, notes? }
  @return table|nil row, string|nil err
]]
function MdtPolice.AddForce(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end

    local forceType = tostring(data.force_type or ''):lower()
    if not MdtPoliceCase.IsForceType(forceType) then return nil, 'invalid_force_type' end
    local injuries = tostring(data.injuries or 'none'):lower()
    if not MdtPoliceCase.IsInjury(injuries) then return nil, 'invalid_injuries' end

    local src, cid, name = actorOf(actor)
    local subjectCid = str(data.subject_citizenid, 64)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_force
            (incident_id, subject_citizenid, subject_name, force_type, tool, injuries,
             medical_called, officer_citizenid, officer_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            subjectCid,
            subjectName(subjectCid, data.subject_name),
            forceType,
            str(data.tool, 64),
            injuries,
            (data.medical_called == true or tonumber(data.medical_called) == 1) and 1 or 0,
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    raiseCaseFlags(incident.id, {
        force_used = forceType ~= 'none',
        weapon_involved = MdtPoliceCase.ARMED_FORCE_TYPES[forceType] == true,
    })

    MdtTimeline.Append(incident.id, 'force_logged', {
        source = src,
        actorCitizenid = cid,
        payload = {
            force_id = insertId,
            force_type = forceType,
            subject_citizenid = subjectCid,
            injuries = injuries,
            tool = str(data.tool, 64),
        },
    })
    MdtAudit.Log('incident.force_log', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { force_type = forceType, injuries = injuries, subject = subjectCid },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_force WHERE id = ?', { insertId })
end

--- @param data table { tool_type, item_name?, quantity?, notes? }
function MdtPolice.AddTool(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end

    local toolType = tostring(data.tool_type or ''):lower()
    if not MdtPoliceCase.IsToolType(toolType) then return nil, 'invalid_tool_type' end

    local src, cid, name = actorOf(actor)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_tools
            (incident_id, tool_type, item_name, quantity, officer_citizenid, officer_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            toolType,
            str(data.item_name, 64),
            clampInt(data.quantity, 1, 999, 1),
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    MdtTimeline.Append(incident.id, 'tool_logged', {
        source = src,
        actorCitizenid = cid,
        payload = { tool_id = insertId, tool_type = toolType, item_name = str(data.item_name, 64) },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_tools WHERE id = ?', { insertId })
end

--[[
  @param data table { item_name, item_label?, quantity?, category?, from_citizenid?,
                      from_name?, storage_ref?, evidence_ref?, notes? }
]]
function MdtPolice.AddSeized(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end

    local itemName = str(data.item_name, 64)
    if not itemName then return nil, 'missing_item' end
    local category = tostring(data.category or 'other'):lower()
    if not MdtPoliceCase.IsSeizedCategory(category) then return nil, 'invalid_category' end

    local src, cid, name = actorOf(actor)
    local fromCid = str(data.from_citizenid, 64)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_seized
            (incident_id, from_citizenid, from_name, item_name, item_label, quantity, category,
             storage_ref, evidence_ref, officer_citizenid, officer_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            fromCid,
            subjectName(fromCid, data.from_name),
            itemName,
            str(data.item_label, 128),
            clampInt(data.quantity, 1, 999999, 1),
            category,
            str(data.storage_ref, 64),
            str(data.evidence_ref, 64),
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    MdtTimeline.Append(incident.id, 'item_seized', {
        source = src,
        actorCitizenid = cid,
        payload = {
            seized_id = insertId,
            item_name = itemName,
            category = category,
            quantity = clampInt(data.quantity, 1, 999999, 1),
            from_citizenid = fromCid,
        },
    })
    MdtAudit.Log('incident.seized_log', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { item_name = itemName, category = category, from = fromCid },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_seized WHERE id = ?', { insertId })
end

--[[ ------------------------------------------------------------------
  Typed references (fines, arrests, fingerprints, media handles)
--------------------------------------------------------------------]]

--[[
  @param data table { ref_type, ref_id?, ref_table?, citizenid?, label?, amount?, meta? }
  @return table|nil row, string|nil err
]]
function MdtPolice.AddRef(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end

    local refType = tostring(data.ref_type or ''):lower()
    if not MdtPoliceCase.IsRefType(refType) then return nil, 'invalid_ref_type' end

    local refId = str(data.ref_id, 64)
    local refTable = str(data.ref_table, 64) or MdtPoliceCase.RefTable(refType)
    local citizenid = str(data.citizenid, 64)
    local label = str(data.label, 255)
    local amount = data.amount ~= nil and clampInt(data.amount, 0, 2147483647, nil) or nil

    local meta = data.meta
    if meta ~= nil and type(meta) ~= 'string' then
        local ok, encoded = pcall(json.encode, meta)
        meta = ok and encoded or nil
    end

    local src, cid = actorOf(actor)

    --- Same reference linked twice (double click, retry) refreshes instead of duplicating.
    local existing
    if refId then
        existing = MySQL.single.await(
            'SELECT id FROM mdt_incident_refs WHERE incident_id = ? AND ref_type = ? AND ref_id = ? LIMIT 1',
            { incident.id, refType, refId }
        )
    end

    local rowId
    if existing and existing.id then
        MySQL.update.await(
            [[UPDATE mdt_incident_refs
              SET citizenid = COALESCE(?, citizenid), label = COALESCE(?, label),
                  amount = COALESCE(?, amount), meta = COALESCE(?, meta)
              WHERE id = ?]],
            { citizenid, label, amount, meta, existing.id }
        )
        rowId = existing.id
    else
        rowId = MySQL.insert.await(
            [[INSERT INTO mdt_incident_refs
                (incident_id, ref_type, ref_table, ref_id, citizenid, label, amount, meta, created_by)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]],
            { incident.id, refType, refTable, refId, citizenid, label, amount, meta, cid }
        )
        if not rowId then return nil, 'insert_failed' end
    end

    ensureCaseRow(incident.id)
    if refType == 'fine' then
        recomputeFineTotal(incident.id)
        raiseCaseFlags(incident.id, { disposition = 'citation' })
    elseif refType == 'arrest' then
        raiseCaseFlags(incident.id, { arrest_made = true, disposition = 'arrest' })
    end

    if not existing then
        MdtTimeline.Append(incident.id, 'ref_linked', {
            source = src,
            actorCitizenid = cid,
            payload = {
                ref_row_id = rowId,
                ref_type = refType,
                ref_id = refId,
                citizenid = citizenid,
                label = label,
                amount = amount,
            },
        })
    end
    MdtAudit.LogAsync('incident.ref_link', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { ref_type = refType, ref_id = refId, citizenid = citizenid, amount = amount },
        dedupeKey = ('%s|%s|%s'):format(incident.id, refType, tostring(refId)),
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_refs WHERE id = ?', { rowId })
end

--[[ ------------------------------------------------------------------
  Reads
--------------------------------------------------------------------]]

local function listFor(table_, incidentId, limit)
    incidentId = tonumber(incidentId)
    if not incidentId then return {} end
    return MySQL.query.await(
        ('SELECT * FROM `%s` WHERE incident_id = ? ORDER BY id ASC LIMIT ?'):format(table_),
        { incidentId, limit or 200 }
    ) or {}
end

function MdtPolice.ListForce(incidentId) return listFor('mdt_incident_force', incidentId) end
function MdtPolice.ListTools(incidentId) return listFor('mdt_incident_tools', incidentId) end
function MdtPolice.ListSeized(incidentId) return listFor('mdt_incident_seized', incidentId) end
function MdtPolice.ListRefs(incidentId) return listFor('mdt_incident_refs', incidentId) end

--- Full case in one round trip: core bundle + every PD child table.
function MdtPolice.GetCaseBundle(incidentId, opts)
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end

    local bundle = MdtIncidentEngine.GetBundle(incident.id, opts)
    if not bundle then return nil, 'not_found' end

    bundle.police = ensureCaseRow(incident.id)
    bundle.report = MdtPolice.GetReport(incident.id, REPORT_KIND)
    bundle.force = MdtPolice.ListForce(incident.id)
    bundle.tools = MdtPolice.ListTools(incident.id)
    bundle.seized = MdtPolice.ListSeized(incident.id)
    bundle.refs = MdtPolice.ListRefs(incident.id)
    if MdtEvidence and MdtEvidence.ListForIncident then
        bundle.evidence = MdtEvidence.ListForIncident(incident.id)
    else
        bundle.evidence = {}
    end
    return bundle
end

--[[
  Police incident list for the MDT. Filters are the engine's, with `type` and
  `service_job` pinned to police, enriched with the case row summary.
]]
function MdtPolice.ListCases(filters)
    filters = type(filters) == 'table' and filters or {}
    local rows = MdtIncidentEngine.List({
        type = 'police',
        service_job = 'police',
        status = filters.status,
        openOnly = filters.openOnly == true,
        assigned_crew = filters.assigned_crew,
        created_by = filters.created_by,
        dispatch_call_id = filters.dispatch_call_id,
        search = filters.search,
        orderBy = filters.orderBy,
        desc = filters.desc,
        limit = filters.limit,
        offset = filters.offset,
    })
    if #rows == 0 then return rows end

    local placeholders, params = {}, {}
    local byId = {}
    for _, row in ipairs(rows) do
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = row.id
        byId[tostring(row.id)] = row
    end

    local cases = MySQL.query.await(
        ([[SELECT incident_id, offence_code, offence_label, disposition,
                  arrest_made, force_used, weapon_involved, fine_total
           FROM mdt_incident_police WHERE incident_id IN (%s)]]):format(table.concat(placeholders, ', ')),
        params
    ) or {}
    for _, case in ipairs(cases) do
        local row = byId[tostring(case.incident_id)]
        if row then row.police = case end
    end

    local units = MySQL.query.await(
        ([[SELECT incident_id, COUNT(*) AS unit_count,
                  GROUP_CONCAT(COALESCE(NULLIF(callsign, ''), display_name) ORDER BY id SEPARATOR ', ') AS unit_labels
           FROM mdt_incident_officers WHERE incident_id IN (%s)
           GROUP BY incident_id]]):format(table.concat(placeholders, ', ')),
        params
    ) or {}
    for _, unit in ipairs(units) do
        local row = byId[tostring(unit.incident_id)]
        if row then
            row.unit_count = tonumber(unit.unit_count) or 0
            row.unit_labels = unit.unit_labels
        end
    end

    return rows
end

--[[
  Resolve "the case this officer is working on" for gameplay actions that carry no
  incident id (fine issued from the person tab, arrest note, fingerprint scan).

  Order: explicit id → open case the officer is listed on → open case the officer
  opened → optional auto-create.

  @param src number
  @param opts table|nil { incidentId?, autoCreate?, summary?, reason?, allowClosed? }
  @return table|nil incident, string origin ('explicit'|'unit'|'creator'|'created'), string|nil err
]]
function MdtPolice.ResolveForOfficer(src, opts)
    opts = type(opts) == 'table' and opts or {}
    local _, cid = actorOf({ source = src })

    if opts.incidentId then
        local incident, err = policeIncident(opts.incidentId)
        if not incident then return nil, nil, err end
        if not opts.allowClosed and MdtIncidentStates.IsClosed(incident.status) then
            return nil, nil, 'incident_closed'
        end
        return incident, 'explicit'
    end

    if not cid then return nil, nil, 'no_citizenid' end

    local listed = MdtIncidentLinks.ListOpenIncidentsForOfficer(cid, { type = 'police', limit = 1 })
    if listed[1] then return listed[1], 'unit' end

    local created = MdtIncidentEngine.List({
        type = 'police',
        openOnly = true,
        created_by = cid,
        limit = 1,
    })
    if created[1] then return created[1], 'creator' end

    if not opts.autoCreate then return nil, nil, 'no_active_incident' end

    local ped = GetPlayerPed(src)
    local coords = (ped and ped ~= 0) and GetEntityCoords(ped) or nil
    local incident, err = MdtPolice.CreateCase({
        source = src,
        summary = opts.summary or 'Policijos byla',
        location_x = coords and coords.x or nil,
        location_y = coords and coords.y or nil,
        location_z = coords and coords.z or nil,
        status = 'in_progress',
        priority = opts.priority,
    })
    if not incident then return nil, nil, err or 'create_failed' end
    return incident, 'created'
end

--[[ ------------------------------------------------------------------
  Exports (PD resources talk to the case only through these)
--------------------------------------------------------------------]]

exports('CreatePoliceCase', function(data)
    return MdtPolice.CreateCase(data)
end)

exports('UpdatePoliceCase', function(incidentId, data, actor)
    return MdtPolice.UpdateCase(incidentId, data, actor)
end)

exports('GetPoliceCase', function(incidentId)
    return MdtPolice.GetCase(incidentId)
end)

exports('GetPoliceCaseBundle', function(incidentId, opts)
    return MdtPolice.GetCaseBundle(incidentId, opts)
end)

exports('ListPoliceCases', function(filters)
    return MdtPolice.ListCases(filters)
end)

exports('ResolveOfficerIncident', function(src, opts)
    return MdtPolice.ResolveForOfficer(src, opts)
end)

exports('SaveIncidentReport', function(incidentId, data, actor)
    return MdtPolice.SaveReport(incidentId, data, actor)
end)

exports('GetIncidentReport', function(incidentId, kind)
    return MdtPolice.GetReport(incidentId, kind)
end)

exports('AddIncidentForce', function(incidentId, data, actor)
    return MdtPolice.AddForce(incidentId, data, actor)
end)

exports('AddIncidentTool', function(incidentId, data, actor)
    return MdtPolice.AddTool(incidentId, data, actor)
end)

exports('AddIncidentSeizedItem', function(incidentId, data, actor)
    return MdtPolice.AddSeized(incidentId, data, actor)
end)

exports('AddIncidentRef', function(incidentId, data, actor)
    return MdtPolice.AddRef(incidentId, data, actor)
end)

exports('ListIncidentRefs', function(incidentId)
    return MdtPolice.ListRefs(incidentId)
end)

exports('ListIncidentForce', function(incidentId)
    return MdtPolice.ListForce(incidentId)
end)

exports('ListIncidentTools', function(incidentId)
    return MdtPolice.ListTools(incidentId)
end)

exports('ListIncidentSeizedItems', function(incidentId)
    return MdtPolice.ListSeized(incidentId)
end)

exports('GetPoliceCaseVocabulary', function()
    return MdtPoliceCase.Vocabulary()
end)
