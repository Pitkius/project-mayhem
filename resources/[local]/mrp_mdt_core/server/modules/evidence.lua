--[[
  Evidence locker module (Phase 6).

  Chain-of-custody rows in `mdt_evidence_items`, linked to police incidents via
  `mdt_incident_refs` (ref_type = evidence, ref_table = mdt_evidence_items).

  Rules:
  - Append-only logging; sealing is one-way.
  - Incident lifecycle stays with the Incident Engine.
  - Every write appends timeline + audit.
]]

MdtEvidence = MdtEvidence or {}

local QBCore = exports['qb-core']:GetCoreObject()

local REF_TABLE = 'mdt_evidence_items'

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

local function itemRow(evidenceId)
    return MySQL.single.await('SELECT * FROM mdt_evidence_items WHERE id = ? LIMIT 1', { evidenceId })
end

local function linkEvidenceRef(incidentId, evidenceId, data, actor)
    local label = str(data.label, 255)
        or str(data.item_label, 128)
        or str(data.item_name, 64)
    return MdtPolice.AddRef(incidentId, {
        ref_type = 'evidence',
        ref_id = tostring(evidenceId),
        ref_table = REF_TABLE,
        label = label,
        meta = {
            locker_slot = str(data.locker_slot, 32),
            location = str(data.location, 64),
            sealed = data.sealed == true or data.sealed == 1,
        },
    }, actor)
end

--[[
  @param data table { item_name, item_label?, quantity?, description?, location?,
                      locker_slot?, category?, notes? }
  @return table|nil row, string|nil err
]]
function MdtEvidence.AddItem(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    local incident, err = policeIncident(incidentId)
    if not incident then return nil, err end
    if MdtIncidentStates.IsClosed(incident.status) then return nil, 'incident_closed' end

    local itemName = str(data.item_name, 64)
    if not itemName then return nil, 'missing_item' end

    local location = tostring(data.location or 'mrpd_main'):lower()
    if not MdtEvidenceCase.IsLockerLocation(location) then return nil, 'invalid_location' end

    local category = tostring(data.category or 'other'):lower()
    if not MdtEvidenceCase.IsCategory(category) then return nil, 'invalid_category' end

    local src, cid, name = actorOf(actor)
    local qty = clampInt(data.quantity, 1, 999999, 1)

    local insertId = MySQL.insert.await(
        [[INSERT INTO mdt_evidence_items
            (incident_id, item_name, item_label, quantity, description, location, locker_slot,
             category, logged_by_citizenid, logged_by_name, notes)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]],
        {
            incident.id,
            itemName,
            str(data.item_label, 128),
            qty,
            str(data.description, 512),
            location,
            str(data.locker_slot, 32),
            category,
            cid,
            name,
            str(data.notes, 512),
        }
    )
    if not insertId then return nil, 'insert_failed' end

    linkEvidenceRef(incident.id, insertId, data, actor)

    MdtTimeline.Append(incident.id, 'evidence_logged', {
        source = src,
        actorCitizenid = cid,
        payload = {
            evidence_id = insertId,
            item_name = itemName,
            quantity = qty,
            location = location,
            locker_slot = str(data.locker_slot, 32),
        },
    })
    MdtAudit.Log('evidence.log', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(insertId),
        meta = { incident_id = incident.id, item_name = itemName, location = location },
    })

    return itemRow(insertId)
end

--- One-way seal — chain of custody lock.
function MdtEvidence.SealItem(evidenceId, actor)
    evidenceId = tonumber(evidenceId)
    if not evidenceId then return nil, 'invalid_id' end

    local row = itemRow(evidenceId)
    if not row then return nil, 'not_found' end
    if tonumber(row.sealed) == 1 then return row, 'already_sealed' end

    local incident, err = policeIncident(row.incident_id)
    if not incident then return nil, err end
    if MdtIncidentStates.IsClosed(incident.status) then return nil, 'incident_closed' end

    local src, cid, name = actorOf(actor)
    MySQL.update.await(
        [[UPDATE mdt_evidence_items
          SET sealed = 1, sealed_by_citizenid = ?, sealed_by_name = ?, sealed_at = CURRENT_TIMESTAMP
          WHERE id = ? AND sealed = 0]],
        { cid, name, evidenceId }
    )

    row = itemRow(evidenceId)
    linkEvidenceRef(incident.id, evidenceId, {
        item_name = row.item_name,
        item_label = row.item_label,
        locker_slot = row.locker_slot,
        location = row.location,
        sealed = true,
        label = ('Užplombuota: %s'):format(row.item_label or row.item_name),
    }, actor)

    MdtTimeline.Append(incident.id, 'evidence_sealed', {
        source = src,
        actorCitizenid = cid,
        payload = {
            evidence_id = evidenceId,
            item_name = row.item_name,
            locker_slot = row.locker_slot,
        },
    })
    MdtAudit.Log('evidence.seal', {
        source = src,
        actorCitizenid = cid,
        resource = (type(actor) == 'table' and actor.resource) or 'mrp_mdt_core',
        target = tostring(evidenceId),
        meta = { incident_id = incident.id },
    })

    return row
end

function MdtEvidence.GetItem(evidenceId)
    evidenceId = tonumber(evidenceId)
    if not evidenceId then return nil end
    return itemRow(evidenceId)
end

function MdtEvidence.ListForIncident(incidentId)
    incidentId = tonumber(incidentId)
    if not incidentId then return {} end
    return MySQL.query.await(
        'SELECT * FROM mdt_evidence_items WHERE incident_id = ? ORDER BY id ASC LIMIT 200',
        { incidentId }
    ) or {}
end

exports('AddEvidenceItem', function(incidentId, data, actor)
    return MdtEvidence.AddItem(incidentId, data, actor)
end)

exports('SealEvidenceItem', function(evidenceId, actor)
    return MdtEvidence.SealItem(evidenceId, actor)
end)

exports('GetEvidenceItem', function(evidenceId)
    return MdtEvidence.GetItem(evidenceId)
end)

exports('ListEvidenceItems', function(incidentId)
    return MdtEvidence.ListForIncident(incidentId)
end)

exports('GetEvidenceVocabulary', function()
    return MdtEvidenceCase.Vocabulary()
end)
