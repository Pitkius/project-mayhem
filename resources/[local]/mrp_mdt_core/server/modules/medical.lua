--[[
  EMS medical case module (Phase 4).

  Owns the EMS-specific extension of an incident: case row, medical chart report,
  medications, actions, equipment and typed references (invoices).

  Rules:
  - The incident lifecycle stays with the Incident Engine. Nothing here writes
    `mdt_incidents.status` — callers go through TransitionIncident(To).
  - Core case data is normalized columns; JSON is only used for report extras.
  - Every write appends a timeline row so the case reads as a history.
]]

MdtMedical = MdtMedical or {}

local QBCore = exports['qb-core']:GetCoreObject()

local REPORT_KIND = 'medical'

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

local function emsIncident(incidentId)
    local incident = MdtIncidentEngine.Get(incidentId)
    if not incident then return nil, 'incident_not_found' end
    if tostring(incident.type) ~= 'ems' then return nil, 'not_ems_incident' end
    return incident
end

local function caseRow(incidentId)
    return MySQL.single.await('SELECT * FROM mdt_incident_medical WHERE incident_id = ?', { incidentId })
end

local function ensureCaseRow(incidentId)
    local row = caseRow(incidentId)
    if row then return row end
    MySQL.query.await(
        'INSERT IGNORE INTO mdt_incident_medical (incident_id) VALUES (?)',
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
        'UPDATE mdt_incident_medical SET invoice_total = ? WHERE incident_id = ?',
        { clampInt(total, 0, 2147483647, 0), incidentId }
    )
end

local function raiseCaseFlags(incidentId, flags)
    local sets, params = {}, {}
    if flags.transported ~= nil then
        sets[#sets + 1] = 'transported = ?'
        params[#params + 1] = (flags.transported == true or tonumber(flags.transported) == 1) and 1 or 0
    end
    if flags.disposition and MdtMedicalCase.IsDisposition(flags.disposition) then
        sets[#sets + 1] = "disposition = IF(disposition = 'pending', ?, disposition)"
        params[#params + 1] = flags.disposition
    end
    if #sets == 0 then return end
    params[#params + 1] = incidentId
    MySQL.update.await(
        ('UPDATE mdt_incident_medical SET %s WHERE incident_id = ?'):format(table.concat(sets, ', ')),
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

function MdtMedical.CreateCase(data)
    data = type(data) == 'table' and data or {}
    local src, cid, _ = actorOf({ source = data.source, citizenid = data.created_by })

    local incident, err = MdtIncidentEngine.Create({
        type = 'ems',
        status = data.status,
        priority = data.priority,
        service_job = 'ems',
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
    MdtMedical.UpdateCase(incident.id, {
        presentation_code = data.presentation_code,
        presentation_label = data.presentation_label,
        disposition = data.disposition,
        facility = data.facility,
        triage_level = data.triage_level,
        pulse = data.pulse,
        bp_systolic = data.bp_systolic,
        bp_diastolic = data.bp_diastolic,
        resp_rate = data.resp_rate,
        spo2 = data.spo2,
        gcs = data.gcs,
    }, { source = src, citizenid = cid, skipTimeline = true })

    if cid then
        MdtIncidentLinks.AttachOfficer(incident.id, {
            source = src,
            citizenid = cid,
            role = 'lead',
            service = 'ems',
        }, { source = src, citizenid = cid })
    end

    if MdtAnalytics then
        MdtAnalytics.Record('incident_created', {
            source = src,
            service = 'ems',
            actorCitizenid = cid,
            meta = { incident_id = incident.id, type = 'ems' },
        })
    end

    return MdtIncidentEngine.Get(incident.id)
end

function MdtMedical.UpdateCase(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = emsIncident(incidentId)
    if not incident then return nil, err end

    local before = ensureCaseRow(incident.id)
    if not before then return nil, 'case_row_missing' end

    local sets, params, changed = {}, {}, {}

    local textFields = {
        { column = 'presentation_code', limit = 64 },
        { column = 'presentation_label', limit = 255 },
        { column = 'facility', limit = 64 },
        { column = 'lead_medic_citizenid', limit = 64 },
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
        if not MdtMedicalCase.IsDisposition(disposition) then return nil, 'invalid_disposition' end
        sets[#sets + 1] = 'disposition = ?'
        params[#params + 1] = disposition
        changed.disposition = disposition
    end

    if data.triage_level ~= nil then
        local triage = tostring(data.triage_level):lower()
        if not MdtMedicalCase.IsTriage(triage) then return nil, 'invalid_triage' end
        sets[#sets + 1] = 'triage_level = ?'
        params[#params + 1] = triage
        changed.triage_level = triage
    end

    if data.transported ~= nil then
        local value = (data.transported == true or tonumber(data.transported) == 1) and 1 or 0
        sets[#sets + 1] = 'transported = ?'
        params[#params + 1] = value
        changed.transported = value
    end

    local vitals = {
        { column = 'pulse', min = 0, max = 300 },
        { column = 'bp_systolic', min = 0, max = 300 },
        { column = 'bp_diastolic', min = 0, max = 200 },
        { column = 'resp_rate', min = 0, max = 80 },
        { column = 'spo2', min = 0, max = 100 },
        { column = 'gcs', min = 3, max = 15 },
    }
    for _, field in ipairs(vitals) do
        if data[field.column] ~= nil then
            local value = clampInt(data[field.column], field.min, field.max, nil)
            sets[#sets + 1] = ('`%s` = ?'):format(field.column)
            params[#params + 1] = value
            changed[field.column] = value
        end
    end

    if #sets == 0 then return before end

    params[#params + 1] = incident.id
    MySQL.update.await(
        ('UPDATE mdt_incident_medical SET %s WHERE incident_id = ?'):format(table.concat(sets, ', ')),
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
    MdtAudit.LogAsync('incident.medical_update', {
        source = src,
        actorCitizenid = cid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = changed,
        dedupeKey = tostring(incident.id),
    })

    return caseRow(incident.id)
end

function MdtMedical.GetCase(incidentId)
    local incident, err = emsIncident(incidentId)
    if not incident then return nil, err end
    return caseRow(incident.id)
end

--[[ ------------------------------------------------------------------
  Report (kind = medical)
--------------------------------------------------------------------]]

function MdtMedical.GetReport(incidentId, kind)
    incidentId = tonumber(incidentId)
    if not incidentId then return nil end
    return MySQL.single.await(
        'SELECT * FROM mdt_incident_reports WHERE incident_id = ? AND kind = ?',
        { incidentId, str(kind, 32) or REPORT_KIND }
    )
end

function MdtMedical.SaveReport(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = emsIncident(incidentId)
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
    local existing = MdtMedical.GetReport(incident.id, kind)

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

    local row = MdtMedical.GetReport(incident.id, kind)
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
    MdtAudit.Log('incident.medical_report_save', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { kind = kind, revision = row and row.revision or 1, new = existing == nil },
    })

    return row
end

--[[ ------------------------------------------------------------------
  Meds / actions / equipment
--------------------------------------------------------------------]]

function MdtMedical.AddMed(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = emsIncident(incidentId)
    if not incident then return nil, err end

    local medCode = str(data.med_code, 64)
    local medLabel = str(data.med_label, 128)
    if not medLabel and not medCode then return nil, 'missing_med' end

    local route = tostring(data.route or 'iv'):lower()
    if not MdtMedicalCase.IsMedRoute(route) then return nil, 'invalid_route' end

    local src, cid, name = actorOf(actor)
    local patientCid = str(data.patient_citizenid, 64)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_medical_meds
            (incident_id, med_code, med_label, dose, route, patient_citizenid, patient_name,
             medic_citizenid, medic_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            medCode,
            medLabel or medCode,
            str(data.dose, 32),
            route,
            patientCid,
            subjectName(patientCid, data.patient_name),
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    MdtTimeline.Append(incident.id, 'med_administered', {
        source = src,
        actorCitizenid = cid,
        payload = {
            med_id = insertId,
            med_label = medLabel or medCode,
            dose = str(data.dose, 32),
            route = route,
            patient_citizenid = patientCid,
        },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_medical_meds WHERE id = ?', { insertId })
end

function MdtMedical.AddAction(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = emsIncident(incidentId)
    if not incident then return nil, err end

    local actionType = tostring(data.action_type or ''):lower()
    if not MdtMedicalCase.IsActionType(actionType) then return nil, 'invalid_action_type' end

    local src, cid, name = actorOf(actor)
    local patientCid = str(data.patient_citizenid, 64)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_medical_actions
            (incident_id, action_type, action_label, patient_citizenid, patient_name,
             medic_citizenid, medic_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            actionType,
            str(data.action_label, 128) or MdtMedicalCase.ACTION_TYPES[actionType],
            patientCid,
            subjectName(patientCid, data.patient_name),
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    if actionType == 'extrication' or actionType == 'oxygen' then
        raiseCaseFlags(incident.id, { disposition = 'treated_on_scene' })
    end

    MdtTimeline.Append(incident.id, 'medical_action', {
        source = src,
        actorCitizenid = cid,
        payload = {
            action_id = insertId,
            action_type = actionType,
            patient_citizenid = patientCid,
        },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_medical_actions WHERE id = ?', { insertId })
end

function MdtMedical.AddEquipment(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = emsIncident(incidentId)
    if not incident then return nil, err end

    local equipType = tostring(data.equipment_type or ''):lower()
    if not MdtMedicalCase.IsEquipmentType(equipType) then return nil, 'invalid_equipment_type' end

    local src, cid, name = actorOf(actor)
    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_incident_medical_equipment
            (incident_id, equipment_type, item_name, quantity, medic_citizenid, medic_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            equipType,
            str(data.item_name, 64),
            clampInt(data.quantity, 1, 999, 1),
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    ensureCaseRow(incident.id)
    MdtTimeline.Append(incident.id, 'equipment_used', {
        source = src,
        actorCitizenid = cid,
        payload = {
            equipment_id = insertId,
            equipment_type = equipType,
            item_name = str(data.item_name, 64),
        },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_medical_equipment WHERE id = ?', { insertId })
end

--[[ ------------------------------------------------------------------
  Typed references (invoices)
--------------------------------------------------------------------]]

function MdtMedical.AddRef(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = emsIncident(incidentId)
    if not incident then return nil, err end

    local refType = tostring(data.ref_type or ''):lower()
    if not MdtMedicalCase.IsRefType(refType) then return nil, 'invalid_ref_type' end

    local refId = str(data.ref_id, 64)
    local refTable = str(data.ref_table, 64) or MdtMedicalCase.RefTable(refType)
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
        raiseCaseFlags(incident.id, { disposition = 'treated_on_scene' })
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
    MdtAudit.LogAsync('incident.medical_ref_link', {
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

function MdtMedical.ListMeds(incidentId) return listFor('mdt_incident_medical_meds', incidentId) end
function MdtMedical.ListActions(incidentId) return listFor('mdt_incident_medical_actions', incidentId) end
function MdtMedical.ListEquipment(incidentId) return listFor('mdt_incident_medical_equipment', incidentId) end
function MdtMedical.ListRefs(incidentId) return listFor('mdt_incident_refs', incidentId) end

function MdtMedical.GetCaseBundle(incidentId, opts)
    local incident, err = emsIncident(incidentId)
    if not incident then return nil, err end

    local bundle = MdtIncidentEngine.GetBundle(incident.id, opts)
    if not bundle then return nil, 'not_found' end

    bundle.medical = ensureCaseRow(incident.id)
    bundle.report = MdtMedical.GetReport(incident.id, REPORT_KIND)
    bundle.meds = MdtMedical.ListMeds(incident.id)
    bundle.actions = MdtMedical.ListActions(incident.id)
    bundle.equipment = MdtMedical.ListEquipment(incident.id)
    bundle.refs = MdtMedical.ListRefs(incident.id)
    return bundle
end

function MdtMedical.ListCases(filters)
    filters = type(filters) == 'table' and filters or {}
    local rows = MdtIncidentEngine.List({
        type = 'ems',
        service_job = 'ems',
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
        ([[SELECT incident_id, presentation_code, presentation_label, disposition,
                  triage_level, transported, invoice_total, facility
           FROM mdt_incident_medical WHERE incident_id IN (%s)]]):format(table.concat(placeholders, ', ')),
        params
    ) or {}
    for _, case in ipairs(cases) do
        local row = byId[tostring(case.incident_id)]
        if row then row.medical = case end
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

function MdtMedical.ResolveForMedic(src, opts)
    opts = type(opts) == 'table' and opts or {}
    local _, cid = actorOf({ source = src })

    if opts.incidentId then
        local incident, err = emsIncident(opts.incidentId)
        if not incident then return nil, nil, err end
        if not opts.allowClosed and MdtIncidentStates.IsClosed(incident.status) then
            return nil, nil, 'incident_closed'
        end
        return incident, 'explicit'
    end

    if not cid then return nil, nil, 'no_citizenid' end

    local listed = MdtIncidentLinks.ListOpenIncidentsForOfficer(cid, { type = 'ems', limit = 1 })
    if listed[1] then return listed[1], 'unit' end

    local created = MdtIncidentEngine.List({
        type = 'ems',
        openOnly = true,
        created_by = cid,
        limit = 1,
    })
    if created[1] then return created[1], 'creator' end

    if not opts.autoCreate then return nil, nil, 'no_active_incident' end

    local ped = GetPlayerPed(src)
    local coords = (ped and ped ~= 0) and GetEntityCoords(ped) or nil
    local incident, err = MdtMedical.CreateCase({
        source = src,
        summary = opts.summary or 'Medicininis iškvietimas',
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

exports('CreateMedicalCase', function(data)
    return MdtMedical.CreateCase(data)
end)

exports('UpdateMedicalCase', function(incidentId, data, actor)
    return MdtMedical.UpdateCase(incidentId, data, actor)
end)

exports('GetMedicalCase', function(incidentId)
    return MdtMedical.GetCase(incidentId)
end)

exports('GetMedicalCaseBundle', function(incidentId, opts)
    return MdtMedical.GetCaseBundle(incidentId, opts)
end)

exports('ListMedicalCases', function(filters)
    return MdtMedical.ListCases(filters)
end)

exports('ResolveMedicIncident', function(src, opts)
    return MdtMedical.ResolveForMedic(src, opts)
end)

exports('SaveMedicalReport', function(incidentId, data, actor)
    return MdtMedical.SaveReport(incidentId, data, actor)
end)

exports('GetMedicalReport', function(incidentId, kind)
    return MdtMedical.GetReport(incidentId, kind)
end)

exports('AddMedicalMed', function(incidentId, data, actor)
    return MdtMedical.AddMed(incidentId, data, actor)
end)

exports('AddMedicalAction', function(incidentId, data, actor)
    return MdtMedical.AddAction(incidentId, data, actor)
end)

exports('AddMedicalEquipment', function(incidentId, data, actor)
    return MdtMedical.AddEquipment(incidentId, data, actor)
end)

exports('AddMedicalRef', function(incidentId, data, actor)
    return MdtMedical.AddRef(incidentId, data, actor)
end)

exports('ListMedicalMeds', function(incidentId)
    return MdtMedical.ListMeds(incidentId)
end)

exports('ListMedicalActions', function(incidentId)
    return MdtMedical.ListActions(incidentId)
end)

exports('ListMedicalEquipment', function(incidentId)
    return MdtMedical.ListEquipment(incidentId)
end)

exports('ListMedicalRefs', function(incidentId)
    return MdtMedical.ListRefs(incidentId)
end)

exports('GetMedicalCaseVocabulary', function()
    return MdtMedicalCase.Vocabulary()
end)
