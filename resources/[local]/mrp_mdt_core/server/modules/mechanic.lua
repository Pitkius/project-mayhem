--[[
  Mechanic repair case module (Phase 5).

  Owns the mechanic-specific extension of an incident: case row, repair report,
  diagnostics, work performed, parts replaced and typed references (invoices, tow).

  Rules:
  - The incident lifecycle stays with the Incident Engine. Nothing here writes
    `mdt_incidents.status` — callers go through TransitionIncident(To).
  - Core case data is normalized columns; JSON is only used for report extras.
  - Every write appends a timeline row so the case reads as a history.
]]

MdtMechanic = MdtMechanic or {}

local QBCore = exports['qb-core']:GetCoreObject()

local REPORT_KIND = 'mechanic'

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

local function mechanicIncident(incidentId)
    local incident = MdtIncidentEngine.Get(incidentId)
    if not incident then return nil, 'incident_not_found' end
    if tostring(incident.type) ~= 'mechanic' then return nil, 'not_mechanic_incident' end
    return incident
end

local function caseRow(incidentId)
    return MySQL.single.await('SELECT * FROM mdt_incident_mechanic WHERE incident_id = ?', { incidentId })
end

local function ensureCaseRow(incidentId)
    local row = caseRow(incidentId)
    if row then return row end
    MySQL.query.await(
        'INSERT IGNORE INTO mdt_incident_mechanic (incident_id) VALUES (?)',
        { incidentId }
    )
    return caseRow(incidentId)
end

local function recomputeInvoiceTotal(incidentId)
    local total = MySQL.scalar.await(
        [[SELECT COALESCE(SUM(amount), 0) FROM mdt_incident_refs
          WHERE incident_id = ? AND ref_type = 'invoice']],
        { incidentId }
    )
    MySQL.update.await(
        'UPDATE mdt_incident_mechanic SET invoice_total = ? WHERE incident_id = ?',
        { clampInt(total, 0, 2147483647, 0), incidentId }
    )
end

local function raiseCaseFlags(incidentId, flags)
    local sets, params = {}, {}
    if flags.tow_requested ~= nil then
        sets[#sets + 1] = 'tow_requested = ?'
        params[#params + 1] = (flags.tow_requested == true or tonumber(flags.tow_requested) == 1) and 1 or 0
    end
    if flags.tow_completed ~= nil then
        sets[#sets + 1] = 'tow_completed = ?'
        params[#params + 1] = (flags.tow_completed == true or tonumber(flags.tow_completed) == 1) and 1 or 0
    end
    if flags.disposition and MdtMechanicCase.IsDisposition(flags.disposition) then
        sets[#sets + 1] = "disposition = IF(disposition = 'pending', ?, disposition)"
        params[#params + 1] = flags.disposition
    end
    if #sets == 0 then return end
    params[#params + 1] = incidentId
    MySQL.update.await(
        ('UPDATE mdt_incident_mechanic SET %s WHERE incident_id = ?'):format(table.concat(sets, ', ')),
        params
    )
end

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

--[[ ------------------------------------------------------------------
  Case row
--------------------------------------------------------------------]]

function MdtMechanic.CreateCase(data)
    data = type(data) == 'table' and data or {}
    local src, cid, _ = actorOf({ source = data.source, citizenid = data.created_by })

    local incident, err = MdtIncidentEngine.Create({
        type = 'mechanic',
        status = data.status,
        priority = data.priority,
        service_job = 'mechanic',
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
    MdtMechanic.UpdateCase(incident.id, {
        fault_code = data.fault_code,
        fault_label = data.fault_label,
        disposition = data.disposition,
        shop = data.shop,
        duration_minutes = data.duration_minutes,
        tow_requested = data.tow_requested,
        recommendations = data.recommendations,
        diagnostics_summary = data.diagnostics_summary,
    }, { source = src, citizenid = cid, skipTimeline = true })

    if cid then
        MdtIncidentLinks.AttachOfficer(incident.id, {
            source = src,
            citizenid = cid,
            role = 'lead',
            service = 'mechanic',
        }, { source = src, citizenid = cid })
    end

    if MdtAnalytics then
        MdtAnalytics.Record('incident_created', {
            source = src,
            service = 'mechanic',
            actorCitizenid = cid,
            meta = { incident_id = incident.id, type = 'mechanic' },
        })
    end

    return MdtIncidentEngine.Get(incident.id)
end

function MdtMechanic.UpdateCase(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = mechanicIncident(incidentId)
    if not incident then return nil, err end

    local before = ensureCaseRow(incident.id)
    if not before then return nil, 'case_row_missing' end

    local sets, params, changed = {}, {}, {}

    local textFields = {
        { column = 'fault_code', limit = 64 },
        { column = 'fault_label', limit = 255 },
        { column = 'shop', limit = 64 },
        { column = 'lead_mechanic_citizenid', limit = 64 },
        { column = 'lead_callsign', limit = 16 },
        { column = 'diagnostics_summary', limit = 512 },
        { column = 'recommendations', limit = 1024 },
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
        if not MdtMechanicCase.IsDisposition(disposition) then return nil, 'invalid_disposition' end
        sets[#sets + 1] = 'disposition = ?'
        params[#params + 1] = disposition
        changed.disposition = disposition
    end

    if data.tow_requested ~= nil then
        local value = (data.tow_requested == true or tonumber(data.tow_requested) == 1) and 1 or 0
        sets[#sets + 1] = 'tow_requested = ?'
        params[#params + 1] = value
        changed.tow_requested = value
    end

    if data.tow_completed ~= nil then
        local value = (data.tow_completed == true or tonumber(data.tow_completed) == 1) and 1 or 0
        sets[#sets + 1] = 'tow_completed = ?'
        params[#params + 1] = value
        changed.tow_completed = value
    end

    if data.duration_minutes ~= nil then
        local value = clampInt(data.duration_minutes, 0, 9999, nil)
        sets[#sets + 1] = 'duration_minutes = ?'
        params[#params + 1] = value
        changed.duration_minutes = value
    end

    if #sets == 0 then return before end

    params[#params + 1] = incident.id
    MySQL.update.await(
        ('UPDATE mdt_incident_mechanic SET %s WHERE incident_id = ?'):format(table.concat(sets, ', ')),
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
    MdtAudit.LogAsync('incident.mechanic_update', {
        source = src,
        actorCitizenid = cid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = changed,
        dedupeKey = tostring(incident.id),
    })

    return caseRow(incident.id)
end

function MdtMechanic.GetCase(incidentId)
    local incident, err = mechanicIncident(incidentId)
    if not incident then return nil, err end
    return caseRow(incident.id)
end

--[[ ------------------------------------------------------------------
  Report (kind = mechanic)
--------------------------------------------------------------------]]

function MdtMechanic.GetReport(incidentId, kind)
    incidentId = tonumber(incidentId)
    if not incidentId then return nil end
    return MySQL.single.await(
        'SELECT * FROM mdt_incident_reports WHERE incident_id = ? AND kind = ?',
        { incidentId, str(kind, 32) or REPORT_KIND }
    )
end

function MdtMechanic.SaveReport(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = mechanicIncident(incidentId)
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
    local existing = MdtMechanic.GetReport(incident.id, kind)

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

    local row = MdtMechanic.GetReport(incident.id, kind)
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
    MdtAudit.Log('incident.mechanic_report_save', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { kind = kind, revision = row and row.revision or 1, new = existing == nil },
    })

    return row
end

--[[ ------------------------------------------------------------------
  Diagnostics / work / parts
--------------------------------------------------------------------]]

function MdtMechanic.AddDiagnostic(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = mechanicIncident(incidentId)
    if not incident then return nil, err end

    local diagType = tostring(data.diag_type or ''):lower()
    if not MdtMechanicCase.IsDiagType(diagType) then return nil, 'invalid_diag_type' end

    local result = tostring(data.result or 'unknown'):lower()
    if not MdtMechanicCase.IsDiagResult(result) then return nil, 'invalid_diag_result' end

    local src, cid, name = actorOf(actor)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_mechanic_diagnostics
            (incident_id, diag_code, diag_label, diag_type, result,
             mechanic_citizenid, mechanic_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            str(data.diag_code, 64),
            str(data.diag_label, 128) or MdtMechanicCase.DIAG_TYPES[diagType],
            diagType,
            result,
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    MdtTimeline.Append(incident.id, 'diagnostic_logged', {
        source = src,
        actorCitizenid = cid,
        payload = { diagnostic_id = insertId, diag_type = diagType, result = result },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_mechanic_diagnostics WHERE id = ?', { insertId })
end

function MdtMechanic.AddWork(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = mechanicIncident(incidentId)
    if not incident then return nil, err end

    local workType = tostring(data.work_type or ''):lower()
    if not MdtMechanicCase.IsWorkType(workType) then return nil, 'invalid_work_type' end

    local src, cid, name = actorOf(actor)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_mechanic_work
            (incident_id, work_type, work_label, duration_minutes,
             mechanic_citizenid, mechanic_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            workType,
            str(data.work_label, 128) or MdtMechanicCase.WORK_TYPES[workType],
            clampInt(data.duration_minutes, 0, 9999, nil),
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    if workType == 'tow_hook' then
        raiseCaseFlags(incident.id, { tow_requested = true, disposition = 'towed' })
    else
        raiseCaseFlags(incident.id, { disposition = 'repaired_on_scene' })
    end

    MdtTimeline.Append(incident.id, 'repair_work', {
        source = src,
        actorCitizenid = cid,
        payload = { work_id = insertId, work_type = workType },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_mechanic_work WHERE id = ?', { insertId })
end

function MdtMechanic.AddPart(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = mechanicIncident(incidentId)
    if not incident then return nil, err end

    local category = tostring(data.part_category or 'other'):lower()
    if not MdtMechanicCase.IsPartCategory(category) then return nil, 'invalid_part_category' end

    local partLabel = str(data.part_label, 128)
    if not partLabel and not str(data.part_code, 64) then return nil, 'missing_part' end

    local src, cid, name = actorOf(actor)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_mechanic_parts
            (incident_id, part_code, part_label, part_category, quantity,
             mechanic_citizenid, mechanic_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            str(data.part_code, 64),
            partLabel or str(data.part_code, 64),
            category,
            clampInt(data.quantity, 1, 999, 1),
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    MdtTimeline.Append(incident.id, 'part_replaced', {
        source = src,
        actorCitizenid = cid,
        payload = { part_id = insertId, part_label = partLabel, part_category = category },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_mechanic_parts WHERE id = ?', { insertId })
end

--[[ ------------------------------------------------------------------
  Typed references (invoices, tow stub)
--------------------------------------------------------------------]]

function MdtMechanic.AddRef(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = mechanicIncident(incidentId)
    if not incident then return nil, err end

    local refType = tostring(data.ref_type or ''):lower()
    if not MdtMechanicCase.IsRefType(refType) then return nil, 'invalid_ref_type' end

    local refId = str(data.ref_id, 64)
    local refTable = str(data.ref_table, 64) or MdtMechanicCase.RefTable(refType)
    local citizenid = str(data.citizenid, 64)
    local label = str(data.label, 255)
    local amount = data.amount ~= nil and clampInt(data.amount, 0, 2147483647, nil) or nil

    local meta = data.meta
    if meta ~= nil and type(meta) ~= 'string' then
        local ok, encoded = pcall(json.encode, meta)
        meta = ok and encoded or nil
    end

    local src, cid = actorOf(actor)

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
    if refType == 'invoice' then
        recomputeInvoiceTotal(incident.id)
        raiseCaseFlags(incident.id, { disposition = 'repaired_on_scene' })
    elseif refType == 'tow' then
        raiseCaseFlags(incident.id, { tow_requested = true, tow_completed = true, disposition = 'towed' })
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
    MdtAudit.LogAsync('incident.mechanic_ref_link', {
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

function MdtMechanic.ListDiagnostics(incidentId) return listFor('mdt_incident_mechanic_diagnostics', incidentId) end
function MdtMechanic.ListWork(incidentId) return listFor('mdt_incident_mechanic_work', incidentId) end
function MdtMechanic.ListParts(incidentId) return listFor('mdt_incident_mechanic_parts', incidentId) end
function MdtMechanic.ListRefs(incidentId) return listFor('mdt_incident_refs', incidentId) end

function MdtMechanic.GetCaseBundle(incidentId, opts)
    local incident, err = mechanicIncident(incidentId)
    if not incident then return nil, err end

    local bundle = MdtIncidentEngine.GetBundle(incident.id, opts)
    if not bundle then return nil, 'not_found' end

    bundle.mechanic = ensureCaseRow(incident.id)
    bundle.report = MdtMechanic.GetReport(incident.id, REPORT_KIND)
    bundle.diagnostics = MdtMechanic.ListDiagnostics(incident.id)
    bundle.work = MdtMechanic.ListWork(incident.id)
    bundle.parts = MdtMechanic.ListParts(incident.id)
    bundle.refs = MdtMechanic.ListRefs(incident.id)
    return bundle
end

function MdtMechanic.ListCases(filters)
    filters = type(filters) == 'table' and filters or {}
    local rows = MdtIncidentEngine.List({
        type = 'mechanic',
        service_job = 'mechanic',
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
        ([[SELECT incident_id, fault_code, fault_label, disposition,
                  tow_requested, tow_completed, duration_minutes, invoice_total, shop
           FROM mdt_incident_mechanic WHERE incident_id IN (%s)]]):format(table.concat(placeholders, ', ')),
        params
    ) or {}
    for _, case in ipairs(cases) do
        local row = byId[tostring(case.incident_id)]
        if row then row.mechanic = case end
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

function MdtMechanic.ResolveForMechanic(src, opts)
    opts = type(opts) == 'table' and opts or {}
    local _, cid = actorOf({ source = src })

    if opts.incidentId then
        local incident, err = mechanicIncident(opts.incidentId)
        if not incident then return nil, nil, err end
        if not opts.allowClosed and MdtIncidentStates.IsClosed(incident.status) then
            return nil, nil, 'incident_closed'
        end
        return incident, 'explicit'
    end

    if not cid then return nil, nil, 'no_citizenid' end

    local listed = MdtIncidentLinks.ListOpenIncidentsForOfficer(cid, { type = 'mechanic', limit = 1 })
    if listed[1] then return listed[1], 'unit' end

    local created = MdtIncidentEngine.List({
        type = 'mechanic',
        openOnly = true,
        created_by = cid,
        limit = 1,
    })
    if created[1] then return created[1], 'creator' end

    if not opts.autoCreate then return nil, nil, 'no_active_incident' end

    local ped = GetPlayerPed(src)
    local coords = (ped and ped ~= 0) and GetEntityCoords(ped) or nil
    local incident, err = MdtMechanic.CreateCase({
        source = src,
        summary = opts.summary or 'Mechanikų iškvietimas',
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
  Exports
--------------------------------------------------------------------]]

exports('CreateMechanicCase', function(data)
    return MdtMechanic.CreateCase(data)
end)

exports('UpdateMechanicCase', function(incidentId, data, actor)
    return MdtMechanic.UpdateCase(incidentId, data, actor)
end)

exports('GetMechanicCase', function(incidentId)
    return MdtMechanic.GetCase(incidentId)
end)

exports('GetMechanicCaseBundle', function(incidentId, opts)
    return MdtMechanic.GetCaseBundle(incidentId, opts)
end)

exports('ListMechanicCases', function(filters)
    return MdtMechanic.ListCases(filters)
end)

exports('ResolveMechanicIncident', function(src, opts)
    return MdtMechanic.ResolveForMechanic(src, opts)
end)

exports('SaveMechanicReport', function(incidentId, data, actor)
    return MdtMechanic.SaveReport(incidentId, data, actor)
end)

exports('GetMechanicReport', function(incidentId, kind)
    return MdtMechanic.GetReport(incidentId, kind)
end)

exports('AddMechanicDiagnostic', function(incidentId, data, actor)
    return MdtMechanic.AddDiagnostic(incidentId, data, actor)
end)

exports('AddMechanicWork', function(incidentId, data, actor)
    return MdtMechanic.AddWork(incidentId, data, actor)
end)

exports('AddMechanicPart', function(incidentId, data, actor)
    return MdtMechanic.AddPart(incidentId, data, actor)
end)

exports('AddMechanicRef', function(incidentId, data, actor)
    return MdtMechanic.AddRef(incidentId, data, actor)
end)

exports('ListMechanicDiagnostics', function(incidentId)
    return MdtMechanic.ListDiagnostics(incidentId)
end)

exports('ListMechanicWork', function(incidentId)
    return MdtMechanic.ListWork(incidentId)
end)

exports('ListMechanicParts', function(incidentId)
    return MdtMechanic.ListParts(incidentId)
end)

exports('ListMechanicRefs', function(incidentId)
    return MdtMechanic.ListRefs(incidentId)
end)

exports('GetMechanicCaseVocabulary', function()
    return MdtMechanicCase.Vocabulary()
end)
