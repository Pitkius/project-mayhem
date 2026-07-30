--[[
  MDT V2 Phase 3 — PD incident (byla) surface for the LTPD MDT.

  This file owns no tables. Every incident read/write goes through mrp_mdt_core
  exports so the Incident Engine stays the single write path for case data, and
  `mrp_ltpd` keeps owning only its own PD tables (fines, arrests, fingerprints).

  Two consumers:
  - the MDT „Bylos" tab (QBCore callbacks below), and
  - existing PD gameplay actions, through `LtpdMdtIncidents.On*` (called from
    server/main.lua after the action itself succeeded).
]]

local QBCore = exports['qb-core']:GetCoreObject()

local CORE = 'mrp_mdt_core'

LtpdMdtIncidents = LtpdMdtIncidents or {}

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

--[[
  Uniform, non-throwing call into mrp_mdt_core.
  A core hiccup (resource restarting, export renamed) must never break the MDT or
  the PD action that triggered the write.

  @return any result, string|nil err
]]
local function coreCall(fnName, ...)
    if not coreReady() then return nil, 'core_offline' end
    local proxy = exports[CORE]
    local fn = proxy[fnName]
    if type(fn) ~= 'function' then return nil, 'core_export_missing' end
    local packed = table.pack(pcall(fn, proxy, ...))
    if not packed[1] then
        print(('[mrp_ltpd] mdt_core:%s failed: %s'):format(fnName, tostring(packed[2])))
        return nil, 'core_error'
    end
    return packed[2], packed[3]
end

local function hasPermV2(src, legacyKey, corePerm)
    return exports['mrp_ltpd']:HasLtpdPermissionV2(src, legacyKey, corePerm) == true
end

local function isOnDuty(src)
    return exports['mrp_ltpd']:IsLtpdOnDuty(src) == true
end

--- Permission gates for the case UI (legacy grade key OR core RBAC name).
local function canView(src) return isOnDuty(src) and hasPermV2(src, 'mdt_open', 'INCIDENT_VIEW') end
local function canReport(src) return hasPermV2(src, 'mdt_arrest_record', 'MDT_REPORT') end
local function canTransition(src) return hasPermV2(src, 'mdt_arrest_record', 'INCIDENT_TRANSITION') end
local function canFine(src) return hasPermV2(src, 'mdt_fine', 'MDT_FINE') end
local function canArrest(src) return hasPermV2(src, 'mdt_arrest_record', 'MDT_ARREST') end
local function canSearch(src) return hasPermV2(src, 'mdt_search_basic', 'MDT_SEARCH') end
local function canEvidence(src) return hasPermV2(src, 'mdt_arrest_record', 'MDT_EVIDENCE') end
local function canBodycam(src) return hasPermV2(src, 'mdt_bodycam', 'MDT_BODYCAM') end
local function canCctv(src) return hasPermV2(src, 'mdt_cctv', 'MDT_CCTV') end

--- Aplinkosaugos kvalifikacijos pasiūlymai bylų formoje (iš baudų katalogo).
local function aplinkosaugaOffenceSuggestions()
    local out = {}
    for _, p in ipairs(Config.FinePresets or {}) do
        if p.category == 'aplinkosauga' and p.label then
            out[#out + 1] = {
                label = p.label,
                code = p.code,
                category = 'aplinkosauga',
            }
        end
    end
    return out
end

local function evidenceVocab()
    return coreCall('GetEvidenceVocabulary') or {}
end

local function wiringCfg()
    return (Config.MdtIncidents or {})
end

local function partyRoleWhitelist()
    return (wiringCfg().partyRoles) or {
        suspect = true, victim = true, witness = true, complainant = true,
        driver = true, passenger = true, owner = true, other = true,
    }
end

local function vehicleRoleWhitelist()
    return (wiringCfg().vehicleRoles) or {
        suspect_vehicle = true, victim_vehicle = true, involved = true,
        towed = true, impounded = true, recovered = true, evidence = true,
    }
end

--- LT labels for the incident state machine (canonical keys stay in core).
local STATUS_LABELS = {
    created = 'Sukurta',
    assigned = 'Priskirta',
    accepted = 'Priimta',
    enroute = 'Vykstama',
    arrived = 'Vietoje',
    in_progress = 'Vykdoma',
    completed = 'Baigta',
    archived = 'Archyvuota',
    cancelled = 'Atšaukta',
    expired = 'Pasibaigė',
    duplicate = 'Dublikatas',
    merged = 'Sujungta',
    rejected = 'Atmesta',
    timeout = 'Nutrūko',
}

local function deny(cb, msg)
    return cb({ ok = false, message = msg or 'Nėra teisės.' })
end

local function officerCitizenid(src)
    local P = QBCore.Functions.GetPlayer(src)
    return P and P.PlayerData and P.PlayerData.citizenid or nil
end

local function officerName(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    local c = P.PlayerData.charinfo or {}
    local name = (tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or ''))
        :gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or nil
end

--- Archived cases are history: no more writes, reads stay open.
local function writableIncident(ref)
    local incident = coreCall('GetIncident', tonumber(ref))
    if not incident and ref ~= nil then
        incident = coreCall('GetIncidentByPublicNumber', tostring(ref))
    end
    if not incident then return nil, 'Byla nerasta.' end
    if tostring(incident.type) ~= 'police' then return nil, 'Ne policijos byla.' end
    if tostring(incident.status) == 'archived' then return nil, 'Byla archyvuota — keitimai neleidžiami.' end
    return incident
end

local function actorFor(src)
    return { source = src, citizenid = officerCitizenid(src), resource = 'mrp_ltpd' }
end

--[[ ------------------------------------------------------------------
  Nearby people (party picker) — server decides who is actually in range.
--------------------------------------------------------------------]]

local function nearbyRadius()
    return math.min(60.0, math.max(2.0, tonumber(wiringCfg().nearbyRadius) or 20.0))
end

local function nearbyPlayers(src)
    local officerPed = GetPlayerPed(src)
    if not officerPed or officerPed == 0 then return {} end
    local origin = GetEntityCoords(officerPed)
    local radius = nearbyRadius()
    local out = {}

    for _, id in ipairs(QBCore.Functions.GetPlayers() or {}) do
        local pid = tonumber(id)
        if pid and pid ~= src then
            local ped = GetPlayerPed(pid)
            if ped and ped ~= 0 then
                local dist = #(GetEntityCoords(ped) - origin)
                if dist <= radius then
                    local Player = QBCore.Functions.GetPlayer(pid)
                    if Player then
                        local charinfo = Player.PlayerData.charinfo or {}
                        local job = Player.PlayerData.job or {}
                        out[#out + 1] = {
                            source = pid,
                            citizenid = Player.PlayerData.citizenid,
                            name = (tostring(charinfo.firstname or '') .. ' ' .. tostring(charinfo.lastname or ''))
                                :gsub('^%s+', ''):gsub('%s+$', ''),
                            distance = math.floor(dist * 10 + 0.5) / 10,
                            job = job.name,
                            isOfficer = job.name == Config.JobName,
                            onduty = job.onduty == true,
                            callsign = Player.PlayerData.metadata and Player.PlayerData.metadata.callsign or nil,
                        }
                    end
                end
            end
        end
    end

    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end

--- @return string|nil citizenid  nil when the id is not a player in range
local function citizenidFromNearbySource(src, targetSource)
    targetSource = tonumber(targetSource)
    if not targetSource then return nil end
    for _, person in ipairs(nearbyPlayers(src)) do
        if person.source == targetSource then return person.citizenid, person.name end
    end
    return nil
end

--[[ ------------------------------------------------------------------
  Gameplay wiring (called from server/main.lua after the action succeeded)
--------------------------------------------------------------------]]

--[[
  Resolve the case a PD action belongs to.
  @param src number
  @param opts table { incidentId?, autoCreate?, summary? }
  @return table|nil incident, string|nil origin
]]
function LtpdMdtIncidents.Resolve(src, opts)
    opts = type(opts) == 'table' and opts or {}
    local incident, origin = coreCall('ResolveOfficerIncident', src, {
        incidentId = tonumber(opts.incidentId),
        autoCreate = opts.autoCreate == true,
        summary = opts.summary,
    })
    if type(incident) ~= 'table' or not incident.id then return nil end
    return incident, origin
end

local function linkRef(incidentId, data, src)
    return coreCall('AddIncidentRef', incidentId, data, actorFor(src))
end

local function attachParty(incidentId, citizenid, role, src, notes)
    if not citizenid then return nil end
    return coreCall('AttachParty', incidentId, {
        citizenid = citizenid,
        role = role,
        notes = notes,
    }, actorFor(src))
end

--[[
  Fine issued (MDT „Bauda" tab or the case UI) → fine reference + offender party.
  Never auto-creates a case unless configured: a parking ticket should not open a byla.

  @param info table { citizenid, amount, reason_code, reason_label, fineId, incidentId? }
  @return table|nil { id, public_number }
]]
function LtpdMdtIncidents.OnFineIssued(src, info)
    info = type(info) == 'table' and info or {}
    local incident = LtpdMdtIncidents.Resolve(src, {
        incidentId = info.incidentId,
        autoCreate = info.incidentId == nil and wiringCfg().autoCreateOnFine == true,
        summary = ('Bauda: %s'):format(tostring(info.reason_label or '')),
    })
    if not incident then return nil end

    linkRef(incident.id, {
        ref_type = 'fine',
        ref_id = info.fineId and tostring(info.fineId) or nil,
        citizenid = info.citizenid,
        amount = info.amount,
        label = info.reason_label or info.reason_code,
        meta = { reason_code = info.reason_code },
    }, src)
    attachParty(incident.id, info.citizenid, 'suspect', src)

    return { id = incident.id, public_number = incident.public_number }
end

--[[
  Arrest record → suspect party + arrest reference (case disposition becomes `arrest`).
  Serious event: opens a case when the officer has none, per config.
]]
function LtpdMdtIncidents.OnArrest(src, info)
    info = type(info) == 'table' and info or {}
    local incident = LtpdMdtIncidents.Resolve(src, {
        incidentId = info.incidentId,
        autoCreate = info.incidentId == nil and wiringCfg().autoCreateOnArrest ~= false,
        summary = ('Areštas: %s'):format(tostring(info.reason or '')),
    })
    if not incident then return nil end

    attachParty(incident.id, info.citizenid, 'suspect', src, info.reason)
    linkRef(incident.id, {
        ref_type = 'arrest',
        ref_id = info.arrestId and tostring(info.arrestId) or nil,
        citizenid = info.citizenid,
        label = info.reason,
        meta = { sentence = info.sentence },
    }, src)

    return { id = incident.id, public_number = incident.public_number }
end

--- Fingerprints collected → reference on the active case (no case is created for a scan).
function LtpdMdtIncidents.OnFingerprint(src, info)
    info = type(info) == 'table' and info or {}
    local incident = LtpdMdtIncidents.Resolve(src, { incidentId = info.incidentId })
    if not incident then return nil end

    linkRef(incident.id, {
        ref_type = 'fingerprint',
        ref_id = info.citizenid and tostring(info.citizenid) or nil,
        citizenid = info.citizenid,
        label = info.name,
        meta = { fingerprint = info.fingerprint },
    }, src)
    attachParty(incident.id, info.citizenid, 'suspect', src)

    return { id = incident.id, public_number = incident.public_number }
end

--- Wanted level changed → timeline entry (+ pointer to the wanted row) on the active case.
function LtpdMdtIncidents.OnWantedChange(src, info)
    info = type(info) == 'table' and info or {}
    local incident = LtpdMdtIncidents.Resolve(src, { incidentId = info.incidentId })
    if not incident then return nil end

    coreCall('AppendTimeline', incident.id, 'wanted_updated', {
        source = src,
        payload = {
            citizenid = info.citizenid,
            level = info.level,
            reason = info.reason,
        },
    })
    linkRef(incident.id, {
        ref_type = 'wanted',
        ref_id = info.citizenid and tostring(info.citizenid) or nil,
        citizenid = info.citizenid,
        label = ('Paieškomumas %s'):format(tostring(info.level or 0)),
        meta = { level = info.level, reason = info.reason },
    }, src)

    return { id = incident.id, public_number = incident.public_number }
end

--[[ ------------------------------------------------------------------
  MDT „Bylos" tab
--------------------------------------------------------------------]]

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentMeta', function(src, cb)
    if not canView(src) then return deny(cb) end
    if not coreReady() then
        return cb({ ok = false, message = 'MDT bylų sistema neaktyvi (mrp_mdt_core).' })
    end

    cb({
        ok = true,
        statusLabels = STATUS_LABELS,
        vocabulary = coreCall('GetPoliceCaseVocabulary') or {},
        evidenceVocabulary = evidenceVocab(),
        offenceSuggestions = aplinkosaugaOffenceSuggestions(),
        nearbyRadius = nearbyRadius(),
        permissions = {
            report = canReport(src),
            transition = canTransition(src),
            fine = canFine(src),
            arrest = canArrest(src),
            search = canSearch(src),
            evidence = canEvidence(src),
            bodycam = canBodycam(src),
            cctv = canCctv(src),
        },
        self = {
            citizenid = officerCitizenid(src),
            name = officerName(src),
        },
    })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentList', function(src, cb, filters)
    if not canView(src) then return deny(cb) end
    filters = type(filters) == 'table' and filters or {}

    local rows = coreCall('ListPoliceCases', {
        openOnly = filters.openOnly == true,
        search = type(filters.search) == 'string' and filters.search:sub(1, 64) or nil,
        created_by = filters.mine == true and officerCitizenid(src) or nil,
        limit = math.min(50, math.max(1, tonumber(filters.limit) or 25)),
        offset = math.max(0, tonumber(filters.offset) or 0),
    })
    if type(rows) ~= 'table' then
        return cb({ ok = false, message = 'Nepavyko užkrauti bylų.' })
    end
    cb({ ok = true, rows = rows })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentGet', function(src, cb, ref)
    if not canView(src) then return deny(cb) end
    local incident = coreCall('GetIncident', tonumber(ref))
    if not incident and ref ~= nil then
        incident = coreCall('GetIncidentByPublicNumber', tostring(ref))
    end
    if type(incident) ~= 'table' then return cb({ ok = false, message = 'Byla nerasta.' }) end
    if tostring(incident.type) ~= 'police' then return cb({ ok = false, message = 'Ne policijos byla.' }) end

    local bundle = coreCall('GetPoliceCaseBundle', incident.id)
    if type(bundle) ~= 'table' then return cb({ ok = false, message = 'Nepavyko užkrauti bylos.' }) end
    cb({ ok = true, bundle = bundle })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentCreate', function(src, cb, data)
    if not canView(src) then return deny(cb) end
    if not canReport(src) then return deny(cb, 'Nėra teisės kurti bylos.') end
    data = type(data) == 'table' and data or {}

    local summary = tostring(data.summary or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 512)
    if #summary < 3 then return cb({ ok = false, message = 'Įvesk trumpą bylos aprašymą.' }) end

    local incident, err = coreCall('CreatePoliceCase', {
        source = src,
        summary = summary,
        offence_code = data.offence_code,
        offence_label = data.offence_label,
        priority = tonumber(data.priority),
        status = 'in_progress',
    })
    if type(incident) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko sukurti bylos (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, incident = incident, message = ('Byla sukurta: %s'):format(incident.public_number) })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentTransition', function(src, cb, data)
    if not canView(src) then return deny(cb) end
    if not canTransition(src) then return deny(cb, 'Nėra teisės keisti bylos statuso.') end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local status = tostring(data.status or '')
    local updated, err = coreCall('TransitionIncidentTo', incident.id, status, {
        source = src,
        citizenid = officerCitizenid(src),
        reason = 'mdt_pd',
    })
    if type(updated) ~= 'table' then
        return cb({ ok = false, message = ('Statusas nepakeistas (%s).'):format(tostring(err or 'neleidžiama')) })
    end
    cb({ ok = true, incident = updated, message = ('Statusas: %s'):format(STATUS_LABELS[updated.status] or updated.status) })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentUpdateCase', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('UpdatePoliceCase', incident.id, {
        offence_code = data.offence_code,
        offence_label = data.offence_label,
        disposition = data.disposition,
        station = data.station,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko išsaugoti (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, police = row, message = 'Bylos duomenys išsaugoti.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentSaveReport', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('SaveIncidentReport', incident.id, {
        title = data.title,
        body = data.body,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Raportas neišsaugotas (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, report = row, message = ('Raportas išsaugotas (v%s).'):format(row.revision or 1) })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentNearby', function(src, cb)
    if not canView(src) then return deny(cb) end
    if not canSearch(src) then return deny(cb, 'Nėra teisės ieškoti asmenų.') end
    cb({ ok = true, rows = nearbyPlayers(src), radius = nearbyRadius() })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAttachParty', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local role = tostring(data.role or 'suspect'):lower()
    if not partyRoleWhitelist()[role] then return cb({ ok = false, message = 'Neteisingas dalyvio tipas.' }) end

    local citizenid, name
    if data.targetSource ~= nil then
        --- Picked from the nearby list: the server re-checks the distance itself.
        citizenid, name = citizenidFromNearbySource(src, data.targetSource)
        if not citizenid then return cb({ ok = false, message = 'Asmuo nebėra šalia.' }) end
    else
        citizenid = tostring(data.citizenid or ''):gsub('%s+', ''):sub(1, 64)
        if citizenid == '' then return cb({ ok = false, message = 'Nurodyk citizenid.' }) end
        local exists = MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
        if not exists then return cb({ ok = false, message = 'Citizenid nerastas.' }) end
    end

    local row, err = coreCall('AttachParty', incident.id, {
        citizenid = citizenid,
        display_name = name,
        role = role,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko pridėti (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, party = row, message = 'Dalyvis pridėtas.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentDetachParty', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local ok = coreCall('DetachParty', incident.id, tonumber(data.partyId), actorFor(src))
    cb({ ok = ok == true, message = ok == true and 'Dalyvis pašalintas.' or 'Nepavyko pašalinti.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAttachVehicle', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local role = tostring(data.role or 'involved'):lower()
    if not vehicleRoleWhitelist()[role] then return cb({ ok = false, message = 'Neteisingas TP tipas.' }) end

    local plate = tostring(data.plate or ''):upper():gsub('%s+', ''):sub(1, 16)
    if #plate < 2 then return cb({ ok = false, message = 'Nurodyk numerius.' }) end

    local row, err = coreCall('AttachVehicle', incident.id, {
        plate = plate,
        role = role,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko pridėti TP (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, vehicle = row, message = 'Transporto priemonė pridėta.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentDetachVehicle', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local ok = coreCall('DetachVehicle', incident.id, tonumber(data.vehicleId), actorFor(src))
    cb({ ok = ok == true, message = ok == true and 'TP pašalinta.' or 'Nepavyko pašalinti.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAttachOfficer', function(src, cb, data)
    if not canView(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local role = tostring(data.role or 'assist'):lower()
    local targetSource = tonumber(data.targetSource)

    --- Joining yourself needs no report right; adding another unit does.
    if targetSource and targetSource ~= src and not canReport(src) then
        return deny(cb, 'Nėra teisės pridėti kitų pareigūnų.')
    end

    local payload = { role = role }
    if targetSource and targetSource ~= src then
        local citizenid = citizenidFromNearbySource(src, targetSource)
        if not citizenid then return cb({ ok = false, message = 'Pareigūnas nebėra šalia.' }) end
        if not exports['mrp_ltpd']:IsLtpdOnDuty(targetSource) then
            return cb({ ok = false, message = 'Tas asmuo ne policijos tarnyboje.' })
        end
        payload.source = targetSource
        payload.citizenid = citizenid
    else
        payload.source = src
        payload.citizenid = officerCitizenid(src)
    end

    local row, err = coreCall('AttachIncidentOfficer', incident.id, payload, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko pridėti pareigūno (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, officer = row, message = 'Pareigūnas pridėtas prie bylos.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAddForce', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddIncidentForce', incident.id, {
        force_type = data.force_type,
        subject_citizenid = data.subject_citizenid,
        tool = data.tool,
        injuries = data.injuries,
        medical_called = data.medical_called,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti jėgos naudojimo (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, force = row, message = 'Jėgos naudojimas užfiksuotas.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAddTool', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddIncidentTool', incident.id, {
        tool_type = data.tool_type,
        item_name = data.item_name,
        quantity = data.quantity,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti priemonės (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, tool = row, message = 'Priemonė užfiksuota.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAddSeized', function(src, cb, data)
    if not canEvidence(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddIncidentSeizedItem', incident.id, {
        item_name = data.item_name,
        item_label = data.item_label,
        quantity = data.quantity,
        category = data.category,
        from_citizenid = data.from_citizenid,
        storage_ref = data.storage_ref,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti paimto objekto (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, seized = row, message = 'Paimtas objektas užfiksuotas.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAddEvidence', function(src, cb, data)
    if not canEvidence(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddEvidenceItem', incident.id, {
        item_name = data.item_name,
        item_label = data.item_label,
        quantity = data.quantity,
        description = data.description,
        location = data.location,
        locker_slot = data.locker_slot,
        category = data.category,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti įkalčio (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, evidence = row, message = 'Įkaltis įrašytas į saugyklą.' })
end)

QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentSealEvidence', function(src, cb, data)
    if not canEvidence(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local evidenceId = tonumber(data.evidenceId)
    if not evidenceId then return cb({ ok = false, message = 'Neteisingas įkalčio ID.' }) end

    if data.incidentId then
        local incident, msg = writableIncident(data.incidentId)
        if not incident then return cb({ ok = false, message = msg }) end
        local item = coreCall('GetEvidenceItem', evidenceId)
        if type(item) ~= 'table' or tonumber(item.incident_id) ~= tonumber(incident.id) then
            return cb({ ok = false, message = 'Įkaltis nepriklauso šiai bylai.' })
        end
    end

    local row, err = coreCall('SealEvidenceItem', evidenceId, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko užplombuoti (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, evidence = row, message = err == 'already_sealed' and 'Jau užplombuota.' or 'Įkaltis užplombuotas.' })
end)

--[[
  Media / evidence handles. Phase 6 owns evidence locker rows; bodycam/CCTV auto-link
  on watch when an incident id is passed or the officer has an active case.
]]
QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAddRef', function(src, cb, data)
    if not canReport(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local refType = tostring(data.ref_type or ''):lower()
    local STUB_ALLOWED = { bodycam = true, cctv = true, photo = true, warrant = true, other = true }
    if not STUB_ALLOWED[refType] then return cb({ ok = false, message = 'Šio tipo įrašo negalima pridėti rankiniu būdu.' }) end

    local row, err = coreCall('AddIncidentRef', incident.id, {
        ref_type = refType,
        ref_id = data.ref_id,
        citizenid = data.citizenid,
        label = data.label,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko prisegti (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, ref = row, message = 'Nuoroda prisegta prie bylos.' })
end)

--[[
  Fine issued straight from the case: the money + ltpd_fines row go through the same
  server function as the „Bauda" tab, then the fine is linked to this case.
]]
QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentIssueFine', function(src, cb, data)
    if not canFine(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local result = exports['mrp_ltpd']:IssuePoliceFine(src, {
        citizenid = data.citizenid,
        amount = data.amount,
        reason_code = data.reason_code,
        reason_label = data.reason_label,
        incidentId = incident.id,
    })
    cb(result or { ok = false, message = 'Baudos išrašyti nepavyko.' })
end)

--- Arrest record straight from the case (same write path as the „Areštai" tab).
QBCore.Functions.CreateCallback('mrp_ltpd:server:incidentAddArrest', function(src, cb, data)
    if not canArrest(src) then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId)
    if not incident then return cb({ ok = false, message = msg }) end

    local result = exports['mrp_ltpd']:AddPoliceArrestRecord(src, {
        citizenid = data.citizenid,
        reason = data.reason,
        sentence = data.sentence,
        notes = data.notes,
        incidentId = incident.id,
    })
    cb(result or { ok = false, message = 'Arešto įrašo išsaugoti nepavyko.' })
end)
