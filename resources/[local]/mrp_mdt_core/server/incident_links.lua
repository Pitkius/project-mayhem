--- Incident ↔ person / vehicle / responding unit junction writes
--- (mdt_incident_parties, mdt_incident_vehicles, mdt_incident_officers).
--- Service-agnostic: the PD case module and the future EMS/Mech modules share these.

MdtIncidentLinks = MdtIncidentLinks or {}

local QBCore = exports['qb-core']:GetCoreObject()

local PARTY_ROLES = {
    subject = true,
    suspect = true,
    victim = true,
    witness = true,
    complainant = true,
    patient = true,
    client = true,
    driver = true,
    passenger = true,
    owner = true,
    officer = true,
    other = true,
}

local VEHICLE_ROLES = {
    involved = true,
    subject = true,
    suspect_vehicle = true,
    victim_vehicle = true,
    towed = true,
    impounded = true,
    recovered = true,
    patrol = true,
    evidence = true,
    other = true,
}

local function citizenIdOf(src)
    if not src or src < 1 then return nil end
    local p = QBCore.Functions.GetPlayer(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function playerFullName(playerData)
    local c = playerData and playerData.charinfo or nil
    if type(c) ~= 'table' then return nil end
    local name = (tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or ''))
        :gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or nil
end

local function normalizeCallsign(value)
    if value == nil then return nil end
    value = tostring(value):upper():gsub('[^A-Z0-9%-]', ''):sub(1, 16)
    return value ~= '' and value or nil
end

local function displayNameFor(citizenid)
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

local function normalizePlate(plate)
    if plate == nil then return nil end
    plate = tostring(plate):upper():gsub('%s+', ''):sub(1, 16)
    return plate ~= '' and plate or nil
end

local function incidentOrNil(incidentId)
    return MdtIncidentEngine.Get(incidentId)
end

--[[
  @param incidentId number
  @param data table { citizenid, role?, display_name?, notes? }
  @param actor table|nil { source, citizenid }
  @return table|nil row, string|nil err
]]
function MdtIncidentLinks.AttachParty(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    actor = type(actor) == 'table' and actor or {}

    local incident = incidentOrNil(incidentId)
    if not incident then return nil, 'incident_not_found' end

    local citizenid = data.citizenid and tostring(data.citizenid):sub(1, 64) or nil
    local role = tostring(data.role or 'subject'):lower()
    if not PARTY_ROLES[role] then return nil, 'invalid_role' end
    if (not citizenid or citizenid == '') and not data.display_name then
        return nil, 'missing_identity'
    end

    local notes = data.notes and tostring(data.notes):sub(1, 512) or nil
    local displayName = data.display_name and tostring(data.display_name):sub(1, 128)
        or displayNameFor(citizenid)

    --- One row per (incident, citizen, role); re-attaching refreshes name/notes instead of duplicating.
    local existing
    if citizenid then
        existing = MySQL.single.await(
            'SELECT id FROM mdt_incident_parties WHERE incident_id = ? AND citizenid = ? AND role = ? LIMIT 1',
            { incident.id, citizenid, role }
        )
    end

    local rowId
    if existing and existing.id then
        MySQL.update.await(
            'UPDATE mdt_incident_parties SET display_name = ?, notes = COALESCE(?, notes) WHERE id = ?',
            { displayName, notes, existing.id }
        )
        rowId = existing.id
    else
        rowId = MySQL.insert.await(
            [[INSERT INTO mdt_incident_parties (incident_id, citizenid, role, display_name, notes)
              VALUES (?, ?, ?, ?, ?)]],
            { incident.id, citizenid, role, displayName, notes }
        )
        if not rowId then return nil, 'insert_failed' end
    end

    local actorCid = actor.citizenid or citizenIdOf(actor.source)
    MdtTimeline.Append(incident.id, existing and 'party_updated' or 'party_attached', {
        source = actor.source,
        actorCitizenid = actorCid,
        payload = { party_id = rowId, citizenid = citizenid, role = role, display_name = displayName },
    })
    MdtAudit.Log('incident.party_attach', {
        source = actor.source,
        actorCitizenid = actorCid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { party_id = rowId, citizenid = citizenid, role = role },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_parties WHERE id = ?', { rowId })
end

--[[
  @param incidentId number
  @param data table { plate, vin?, model?, role?, notes? }
  @param actor table|nil { source, citizenid }
  @return table|nil row, string|nil err
]]
function MdtIncidentLinks.AttachVehicle(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    actor = type(actor) == 'table' and actor or {}

    local incident = incidentOrNil(incidentId)
    if not incident then return nil, 'incident_not_found' end

    local plate = normalizePlate(data.plate)
    local vin = data.vin and tostring(data.vin):sub(1, 64) or nil
    if not plate and not vin then return nil, 'missing_identity' end

    local role = tostring(data.role or 'involved'):lower()
    if not VEHICLE_ROLES[role] then return nil, 'invalid_role' end

    local model = data.model and tostring(data.model):sub(1, 64) or nil
    if not model and plate then
        local vehRow = MySQL.single.await(
            'SELECT vehicle FROM player_vehicles WHERE plate = ? LIMIT 1',
            { plate }
        )
        model = vehRow and vehRow.vehicle or nil
    end
    local notes = data.notes and tostring(data.notes):sub(1, 512) or nil

    local existing
    if plate then
        existing = MySQL.single.await(
            'SELECT id FROM mdt_incident_vehicles WHERE incident_id = ? AND plate = ? AND role = ? LIMIT 1',
            { incident.id, plate, role }
        )
    end

    local rowId
    if existing and existing.id then
        MySQL.update.await(
            [[UPDATE mdt_incident_vehicles
              SET vin = COALESCE(?, vin), model = COALESCE(?, model), notes = COALESCE(?, notes)
              WHERE id = ?]],
            { vin, model, notes, existing.id }
        )
        rowId = existing.id
    else
        rowId = MySQL.insert.await(
            [[INSERT INTO mdt_incident_vehicles (incident_id, plate, vin, model, role, notes)
              VALUES (?, ?, ?, ?, ?, ?)]],
            { incident.id, plate, vin, model, role, notes }
        )
        if not rowId then return nil, 'insert_failed' end
    end

    local actorCid = actor.citizenid or citizenIdOf(actor.source)
    MdtTimeline.Append(incident.id, existing and 'vehicle_updated' or 'vehicle_attached', {
        source = actor.source,
        actorCitizenid = actorCid,
        payload = { vehicle_id = rowId, plate = plate, vin = vin, model = model, role = role },
    })
    MdtAudit.Log('incident.vehicle_attach', {
        source = actor.source,
        actorCitizenid = actorCid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { vehicle_id = rowId, plate = plate, role = role },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_vehicles WHERE id = ?', { rowId })
end

--- Junction rows are corrections, not history — removal is audited, timeline keeps the trace.
function MdtIncidentLinks.DetachParty(incidentId, partyId, actor)
    actor = type(actor) == 'table' and actor or {}
    local incident = incidentOrNil(incidentId)
    if not incident then return false, 'incident_not_found' end
    partyId = tonumber(partyId)
    if not partyId then return false, 'invalid_party' end

    local row = MySQL.single.await(
        'SELECT * FROM mdt_incident_parties WHERE id = ? AND incident_id = ?',
        { partyId, incident.id }
    )
    if not row then return false, 'not_found' end

    local removed = MySQL.update.await(
        'DELETE FROM mdt_incident_parties WHERE id = ? AND incident_id = ?',
        { partyId, incident.id }
    )
    if not removed or removed < 1 then return false, 'not_found' end

    local actorCid = actor.citizenid or citizenIdOf(actor.source)
    MdtTimeline.Append(incident.id, 'party_detached', {
        source = actor.source,
        actorCitizenid = actorCid,
        payload = { party_id = partyId, citizenid = row.citizenid, role = row.role },
    })
    MdtAudit.Log('incident.party_detach', {
        source = actor.source,
        actorCitizenid = actorCid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { party_id = partyId, citizenid = row.citizenid, role = row.role },
    })
    return true
end

function MdtIncidentLinks.DetachVehicle(incidentId, vehicleId, actor)
    actor = type(actor) == 'table' and actor or {}
    local incident = incidentOrNil(incidentId)
    if not incident then return false, 'incident_not_found' end
    vehicleId = tonumber(vehicleId)
    if not vehicleId then return false, 'invalid_vehicle' end

    local row = MySQL.single.await(
        'SELECT * FROM mdt_incident_vehicles WHERE id = ? AND incident_id = ?',
        { vehicleId, incident.id }
    )
    if not row then return false, 'not_found' end

    local removed = MySQL.update.await(
        'DELETE FROM mdt_incident_vehicles WHERE id = ? AND incident_id = ?',
        { vehicleId, incident.id }
    )
    if not removed or removed < 1 then return false, 'not_found' end

    local actorCid = actor.citizenid or citizenIdOf(actor.source)
    MdtTimeline.Append(incident.id, 'vehicle_detached', {
        source = actor.source,
        actorCitizenid = actorCid,
        payload = { vehicle_id = vehicleId, plate = row.plate, role = row.role },
    })
    MdtAudit.Log('incident.vehicle_detach', {
        source = actor.source,
        actorCitizenid = actorCid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { vehicle_id = vehicleId, plate = row.plate, role = row.role },
    })
    return true
end

--[[
  Responding unit (officer / medic / mechanic) on an incident.
  One row per (incident, citizenid): re-attaching refreshes callsign and can promote
  a role, but never demotes a `lead` that was already recorded.

  @param incidentId number
  @param data table { citizenid|source, role?, callsign?, badge?, display_name?, service?, notes? }
  @param actor table|nil { source, citizenid, resource }
  @return table|nil row, string|nil err
]]
function MdtIncidentLinks.AttachOfficer(incidentId, data, actor)
    data = type(data) == 'table' and data or {}
    actor = type(actor) == 'table' and actor or {}

    local incident = incidentOrNil(incidentId)
    if not incident then return nil, 'incident_not_found' end

    local unitSource = tonumber(data.source)
    local Player = unitSource and unitSource > 0 and QBCore.Functions.GetPlayer(unitSource) or nil
    local citizenid = data.citizenid and tostring(data.citizenid):sub(1, 64)
        or (Player and Player.PlayerData.citizenid)
    if not citizenid or citizenid == '' then return nil, 'missing_identity' end

    local role = tostring(data.role or 'assist'):lower()
    if not MdtPoliceCase.IsOfficerRole(role) then return nil, 'invalid_role' end

    local service = data.service and tostring(data.service):sub(1, 32) or nil
    if not service and Player then
        local jobName = Player.PlayerData.job and tostring(Player.PlayerData.job.name) or nil
        service = jobName and (Config.JobServiceMap or {})[jobName] or nil
    end
    service = service or tostring(incident.service_job or 'police'):sub(1, 32)

    local displayName = data.display_name and tostring(data.display_name):sub(1, 128)
        or (Player and playerFullName(Player.PlayerData))
        or displayNameFor(citizenid)
    local callsign = normalizeCallsign(data.callsign)
        or (Player and normalizeCallsign(Player.PlayerData.metadata and Player.PlayerData.metadata.callsign))
    local badge = data.badge and tostring(data.badge):sub(1, 16) or nil
    local notes = data.notes and tostring(data.notes):sub(1, 512) or nil

    local existing = MySQL.single.await(
        'SELECT id, role FROM mdt_incident_officers WHERE incident_id = ? AND citizenid = ? LIMIT 1',
        { incident.id, citizenid }
    )

    local rowId
    if existing and existing.id then
        --- A unit that already owns the case keeps `lead` when it re-registers as backup.
        local keepRole = existing.role == 'lead' and role ~= 'lead'
        MySQL.update.await(
            [[UPDATE mdt_incident_officers
              SET display_name = COALESCE(?, display_name),
                  callsign = COALESCE(?, callsign),
                  badge = COALESCE(?, badge),
                  role = ?,
                  notes = COALESCE(?, notes)
              WHERE id = ?]],
            { displayName, callsign, badge, keepRole and existing.role or role, notes, existing.id }
        )
        rowId = existing.id
        --- Nothing new to record when a unit re-registers with the same role.
        if keepRole or existing.role == role then
            return MySQL.single.await('SELECT * FROM mdt_incident_officers WHERE id = ?', { rowId })
        end
    else
        rowId = MySQL.insert.await(
            [[INSERT INTO mdt_incident_officers
                (incident_id, citizenid, display_name, callsign, badge, service, role, notes)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?)]],
            { incident.id, citizenid, displayName, callsign, badge, service, role, notes }
        )
        if not rowId then return nil, 'insert_failed' end
    end

    local actorCid = actor.citizenid or citizenIdOf(actor.source) or citizenid
    MdtTimeline.Append(incident.id, existing and 'officer_role_changed' or 'officer_attached', {
        source = actor.source,
        actorCitizenid = actorCid,
        payload = {
            officer_id = rowId,
            citizenid = citizenid,
            display_name = displayName,
            callsign = callsign,
            role = role,
            service = service,
        },
    })

    return MySQL.single.await('SELECT * FROM mdt_incident_officers WHERE id = ?', { rowId })
end

function MdtIncidentLinks.DetachOfficer(incidentId, officerId, actor)
    actor = type(actor) == 'table' and actor or {}
    local incident = incidentOrNil(incidentId)
    if not incident then return false, 'incident_not_found' end
    officerId = tonumber(officerId)
    if not officerId then return false, 'invalid_officer' end

    local row = MySQL.single.await(
        'SELECT * FROM mdt_incident_officers WHERE id = ? AND incident_id = ?',
        { officerId, incident.id }
    )
    if not row then return false, 'not_found' end

    local removed = MySQL.update.await(
        'DELETE FROM mdt_incident_officers WHERE id = ? AND incident_id = ?',
        { officerId, incident.id }
    )
    if not removed or removed < 1 then return false, 'not_found' end

    local actorCid = actor.citizenid or citizenIdOf(actor.source)
    MdtTimeline.Append(incident.id, 'officer_detached', {
        source = actor.source,
        actorCitizenid = actorCid,
        payload = { officer_id = officerId, citizenid = row.citizenid, role = row.role },
    })
    MdtAudit.Log('incident.officer_detach', {
        source = actor.source,
        actorCitizenid = actorCid,
        resource = actor.resource or 'mrp_mdt_core',
        target = tostring(incident.id),
        meta = { officer_id = officerId, citizenid = row.citizenid, role = row.role },
    })
    return true
end

function MdtIncidentLinks.ListOfficers(incidentId)
    incidentId = tonumber(incidentId)
    if not incidentId then return {} end
    return MySQL.query.await(
        [[SELECT id, incident_id, citizenid, display_name, callsign, badge, service, role, notes, created_at
          FROM mdt_incident_officers
          WHERE incident_id = ?
          ORDER BY (role = 'lead') DESC, (role = 'supervisor') DESC, id ASC
          LIMIT 100]],
        { incidentId }
    ) or {}
end

--- Open incidents a unit is currently listed on (newest first).
function MdtIncidentLinks.ListOpenIncidentsForOfficer(citizenid, opts)
    citizenid = citizenid and tostring(citizenid):sub(1, 64) or nil
    if not citizenid or citizenid == '' then return {} end
    opts = type(opts) == 'table' and opts or {}

    local where = { 'o.citizenid = ?' }
    local params = { citizenid }
    if opts.type then
        where[#where + 1] = 'i.type = ?'
        params[#params + 1] = tostring(opts.type)
    end

    local placeholders = {}
    for status in pairs(MdtIncidentStates.CLOSED) do
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = status
    end
    where[#where + 1] = ('i.status NOT IN (%s)'):format(table.concat(placeholders, ', '))

    params[#params + 1] = math.min(50, math.max(1, tonumber(opts.limit) or 10))
    return MySQL.query.await(
        ([[SELECT i.*, o.role AS officer_role, o.callsign AS officer_callsign
           FROM mdt_incident_officers o
           INNER JOIN mdt_incidents i ON i.id = o.incident_id
           WHERE %s
           ORDER BY i.id DESC
           LIMIT ?]]):format(table.concat(where, ' AND ')),
        params
    ) or {}
end

function MdtIncidentLinks.ListParties(incidentId)
    incidentId = tonumber(incidentId)
    if not incidentId then return {} end
    return MySQL.query.await(
        [[SELECT id, incident_id, citizenid, role, display_name, notes, created_at
          FROM mdt_incident_parties
          WHERE incident_id = ?
          ORDER BY id ASC
          LIMIT 200]],
        { incidentId }
    ) or {}
end

function MdtIncidentLinks.ListVehicles(incidentId)
    incidentId = tonumber(incidentId)
    if not incidentId then return {} end
    return MySQL.query.await(
        [[SELECT id, incident_id, plate, vin, model, role, notes, created_at
          FROM mdt_incident_vehicles
          WHERE incident_id = ?
          ORDER BY id ASC
          LIMIT 200]],
        { incidentId }
    ) or {}
end

function MdtIncidentLinks.PartyRoles()
    local out = {}
    for role in pairs(PARTY_ROLES) do out[#out + 1] = role end
    table.sort(out)
    return out
end

function MdtIncidentLinks.VehicleRoles()
    local out = {}
    for role in pairs(VEHICLE_ROLES) do out[#out + 1] = role end
    table.sort(out)
    return out
end

exports('AttachParty', function(incidentId, data, actor)
    return MdtIncidentLinks.AttachParty(incidentId, data, actor)
end)

exports('AttachVehicle', function(incidentId, data, actor)
    return MdtIncidentLinks.AttachVehicle(incidentId, data, actor)
end)

exports('DetachParty', function(incidentId, partyId, actor)
    return MdtIncidentLinks.DetachParty(incidentId, partyId, actor)
end)

exports('DetachVehicle', function(incidentId, vehicleId, actor)
    return MdtIncidentLinks.DetachVehicle(incidentId, vehicleId, actor)
end)

exports('AttachIncidentOfficer', function(incidentId, data, actor)
    return MdtIncidentLinks.AttachOfficer(incidentId, data, actor)
end)

exports('DetachIncidentOfficer', function(incidentId, officerId, actor)
    return MdtIncidentLinks.DetachOfficer(incidentId, officerId, actor)
end)

exports('ListIncidentOfficers', function(incidentId)
    return MdtIncidentLinks.ListOfficers(incidentId)
end)

exports('ListOpenIncidentsForOfficer', function(citizenid, opts)
    return MdtIncidentLinks.ListOpenIncidentsForOfficer(citizenid, opts)
end)

exports('ListIncidentParties', function(incidentId)
    return MdtIncidentLinks.ListParties(incidentId)
end)

exports('ListIncidentVehicles', function(incidentId)
    return MdtIncidentLinks.ListVehicles(incidentId)
end)

exports('ListPartyRoles', function()
    return MdtIncidentLinks.PartyRoles()
end)

exports('ListVehicleRoles', function()
    return MdtIncidentLinks.VehicleRoles()
end)
