--[[
  MDT V2 Phase 4–5 — EMS medical + mechanic repair incident surface for Service MDT.

  Owns no tables. Every incident read/write goes through mrp_mdt_core exports.
]]

local QBCore = exports['qb-core']:GetCoreObject()

local CORE = 'mrp_mdt_core'

ServiceMdtIncidents = ServiceMdtIncidents or {}

local INCIDENT_SERVICES = { ems = true, mechanic = true }

local function sharedJobRow(jobName)
    local shared = QBCore.Shared and QBCore.Shared.Jobs or {}
    return shared[tostring(jobName or '')]
end

local function isEmsJobName(jobName)
    return tostring(jobName or '') == 'ambulance' or (sharedJobRow(jobName) or {}).type == 'ems'
end

local function isMechanicJobName(jobName)
    jobName = tostring(jobName or '')
    if jobName == 'mechanic' then return true end
    return (sharedJobRow(jobName) or {}).type == 'mechanic'
end

local function legacyJobMatches(jobName, legacyJob)
    legacyJob = tostring(legacyJob or '')
    if legacyJob == '' then return true end
    jobName = tostring(jobName or '')
    if jobName == legacyJob then return true end
    if legacyJob == 'mechanic' then return isMechanicJobName(jobName) end
    if legacyJob == 'ambulance' then return isEmsJobName(jobName) end
    return false
end

local function coreReady()
    return GetResourceState(CORE) == 'started'
end

local function coreCall(fnName, ...)
    if not coreReady() then return nil, 'core_offline' end
    local proxy = exports[CORE]
    local fn = proxy[fnName]
    if type(fn) ~= 'function' then return nil, 'core_export_missing' end
    local packed = table.pack(pcall(fn, proxy, ...))
    if not packed[1] then
        print(('[mrp_service_mdt] mdt_core:%s failed: %s'):format(fnName, tostring(packed[2])))
        return nil, 'core_error'
    end
    return packed[2], packed[3]
end

local function validService(service)
    return INCIDENT_SERVICES[tostring(service or '')] == true
end

local function hasPermV2(src, corePerm, legacyMinGrade, legacyJob)
    if coreReady() then
        local ok, allowed = pcall(function()
            return exports[CORE]:HasPermission(src, corePerm) == true
        end)
        if ok and allowed then return true end
    end
    if legacyMinGrade == nil then return false end
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData or not P.PlayerData.job then return false end
    if legacyJob and not legacyJobMatches(P.PlayerData.job.name, legacyJob) then return false end
    if corePerm ~= 'EMS_INCIDENT_VIEW' and corePerm ~= 'EMS_MDT_OPEN'
        and corePerm ~= 'MECH_INCIDENT_VIEW' and corePerm ~= 'MECH_MDT_OPEN'
        and P.PlayerData.job.onduty ~= true then
        return false
    end
    return (P.PlayerData.job.grade and P.PlayerData.job.grade.level or 0) >= legacyMinGrade
end

local function isEmsOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData or not P.PlayerData.job then return false end
    return isEmsJobName(P.PlayerData.job.name) and P.PlayerData.job.onduty == true
end

local function isMechanicOnDuty(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P or not P.PlayerData or not P.PlayerData.job then return false end
    return isMechanicJobName(P.PlayerData.job.name) and P.PlayerData.job.onduty == true
end

local function canView(src, service)
    if service == 'ems' then
        return hasPermV2(src, 'EMS_INCIDENT_VIEW', 0, 'ambulance') or hasPermV2(src, 'INCIDENT_VIEW', 0, 'ambulance')
    end
    if service == 'mechanic' then
        return hasPermV2(src, 'MECH_INCIDENT_VIEW', 0, 'mechanic') or hasPermV2(src, 'INCIDENT_VIEW', 0, 'mechanic')
    end
    return false
end

local function canReport(src, service)
    if service == 'ems' then return hasPermV2(src, 'EMS_MDT_REPORT', 0, 'ambulance') end
    if service == 'mechanic' then return hasPermV2(src, 'MECH_MDT_REPORT', 0, 'mechanic') end
    return false
end

local function canTransition(src, service)
    if service == 'ems' then return hasPermV2(src, 'EMS_INCIDENT_TRANSITION', 0, 'ambulance') end
    if service == 'mechanic' then return hasPermV2(src, 'MECH_INCIDENT_TRANSITION', 0, 'mechanic') end
    return false
end

local function canInvoice(src, service)
    if service == 'ems' then return hasPermV2(src, 'EMS_MDT_INVOICE', 0, 'ambulance') end
    if service == 'mechanic' then return hasPermV2(src, 'MECH_MDT_INVOICE', 0, 'mechanic') end
    return false
end

local function canCreate(src, service)
    if service == 'ems' then return hasPermV2(src, 'EMS_INCIDENT_CREATE', 0, 'ambulance') end
    if service == 'mechanic' then return hasPermV2(src, 'MECH_INCIDENT_CREATE', 0, 'mechanic') end
    return false
end

local function wiringCfg()
    return (Config.MdtIncidents or {})
end

local function partyRoleWhitelist(service)
    local cfg = wiringCfg()
    if service == 'mechanic' then
        return cfg.mechanicPartyRoles or {
            client = true, owner = true, driver = true, witness = true, other = true,
        }
    end
    return cfg.partyRoles or {
        patient = true, bystander = true, witness = true, driver = true, passenger = true, other = true,
    }
end

local function vehicleRoleWhitelist(service)
    local cfg = wiringCfg()
    if service == 'mechanic' then
        return cfg.mechanicVehicleRoles or {
            subject = true, towed = true, impounded = true, other = true,
        }
    end
    return { involved = true, other = true }
end

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

local function medicCitizenid(src)
    local P = QBCore.Functions.GetPlayer(src)
    return P and P.PlayerData and P.PlayerData.citizenid or nil
end

local function medicName(src)
    local P = QBCore.Functions.GetPlayer(src)
    if not P then return nil end
    local c = P.PlayerData.charinfo or {}
    local name = (tostring(c.firstname or '') .. ' ' .. tostring(c.lastname or ''))
        :gsub('^%s+', ''):gsub('%s+$', '')
    return name ~= '' and name or nil
end

local function writableIncident(ref, service)
    local incident = coreCall('GetIncident', tonumber(ref))
    if not incident and ref ~= nil then
        incident = coreCall('GetIncidentByPublicNumber', tostring(ref))
    end
    if not incident then return nil, 'Byla nerasta.' end
    if tostring(incident.type) ~= service then
        return nil, service == 'ems' and 'Ne EMS byla.' or 'Ne mechanikų byla.'
    end
    if tostring(incident.status) == 'archived' then return nil, 'Byla archyvuota — keitimai neleidžiami.' end
    return incident
end

local function actorFor(src)
    return { source = src, citizenid = medicCitizenid(src), resource = 'mrp_service_mdt' }
end

local function nearbyRadius()
    return math.min(60.0, math.max(2.0, tonumber(wiringCfg().nearbyRadius) or 20.0))
end

local function nearbyPlayers(src, service)
    local medicPed = GetPlayerPed(src)
    if not medicPed or medicPed == 0 then return {} end
    local origin = GetEntityCoords(medicPed)
    local radius = nearbyRadius()
    local out = {}
    local jobName = service == 'mechanic' and 'mechanic' or 'ambulance'

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
                            isMedic = isEmsJobName(job.name),
                            isMechanic = isMechanicJobName(job.name),
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

local function citizenidFromNearbySource(src, targetSource, service)
    targetSource = tonumber(targetSource)
    if not targetSource then return nil end
    for _, person in ipairs(nearbyPlayers(src, service)) do
        if person.source == targetSource then return person.citizenid, person.name end
    end
    return nil
end

--[[ ------------------------------------------------------------------
  Gameplay wiring
--------------------------------------------------------------------]]

function ServiceMdtIncidents.Resolve(src, opts)
    opts = type(opts) == 'table' and opts or {}
    local service = tostring(opts.service or 'ems')
    local resolveFn = service == 'mechanic' and 'ResolveMechanicIncident' or 'ResolveMedicIncident'
    local incident, origin = coreCall(resolveFn, src, {
        incidentId = tonumber(opts.incidentId),
        autoCreate = opts.autoCreate == true,
        summary = opts.summary,
    })
    if type(incident) ~= 'table' or not incident.id then return nil end
    return incident, origin
end

local function linkRef(incidentId, data, src, service)
    local fn = service == 'mechanic' and 'AddMechanicRef' or 'AddMedicalRef'
    return coreCall(fn, incidentId, data, actorFor(src))
end

local function attachParty(incidentId, citizenid, role, src, notes)
    if not citizenid then return nil end
    return coreCall('AttachParty', incidentId, {
        citizenid = citizenid,
        role = role,
        notes = notes,
    }, actorFor(src))
end

--- Invoice issued → invoice ref + client party + timeline.
function ServiceMdtIncidents.OnInvoiceIssued(src, info)
    info = type(info) == 'table' and info or {}
    local service = tostring(info.service or '')
    if service ~= 'ems' and service ~= 'mechanic' then return nil end

    local partyRole = service == 'mechanic' and 'client' or 'patient'
    local incident = ServiceMdtIncidents.Resolve(src, {
        service = service,
        incidentId = info.incidentId,
        autoCreate = info.incidentId == nil and wiringCfg().autoCreateOnInvoice ~= false,
        summary = ('Sąskaita: %s'):format(tostring(info.reason_label or '')),
    })
    if not incident then return nil end

    linkRef(incident.id, {
        ref_type = 'invoice',
        ref_id = info.invoiceId and tostring(info.invoiceId) or nil,
        citizenid = info.citizenid,
        amount = info.amount,
        label = info.reason_label or info.reason_code,
        meta = { reason_code = info.reason_code, plate = info.plate },
    }, src, service)
    attachParty(incident.id, info.citizenid, partyRole, src)

    if service == 'mechanic' and info.plate and info.plate ~= '' then
        coreCall('AttachVehicle', incident.id, {
            plate = info.plate,
            role = 'subject',
        }, actorFor(src))
    end

    return { id = incident.id, public_number = incident.public_number }
end

--[[ ------------------------------------------------------------------
  MDT incident cases tab (EMS + mechanic)
--------------------------------------------------------------------]]

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentMeta', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return cb({ ok = false, message = 'Netinkama tarnyba.' }) end
    if not canView(src, service) then return deny(cb) end
    if not coreReady() then
        return cb({ ok = false, message = 'MDT bylų sistema neaktyvi (mrp_mdt_core).' })
    end

    local vocabFn = service == 'mechanic' and 'GetMechanicCaseVocabulary' or 'GetMedicalCaseVocabulary'
    cb({
        ok = true,
        service = service,
        statusLabels = STATUS_LABELS,
        vocabulary = coreCall(vocabFn) or {},
        nearbyRadius = nearbyRadius(),
        permissions = {
            report = canReport(src, service),
            transition = canTransition(src, service),
            invoice = canInvoice(src, service),
            create = canCreate(src, service),
            search = canReport(src, service),
        },
        self = {
            citizenid = medicCitizenid(src),
            name = medicName(src),
        },
    })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentList', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb, 'Netinkama tarnyba.') end
    if not canView(src, service) then return deny(cb) end

    local listFn = service == 'mechanic' and 'ListMechanicCases' or 'ListMedicalCases'
    local rows = coreCall(listFn, {
        openOnly = data.openOnly == true,
        search = type(data.search) == 'string' and data.search:sub(1, 64) or nil,
        created_by = data.mine == true and medicCitizenid(src) or nil,
        limit = math.min(50, math.max(1, tonumber(data.limit) or 25)),
        offset = math.max(0, tonumber(data.offset) or 0),
    })
    if type(rows) ~= 'table' then
        return cb({ ok = false, message = 'Nepavyko užkrauti bylų.' })
    end
    cb({ ok = true, rows = rows })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentGet', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canView(src, service) then return deny(cb) end
    local ref = data.ref
    local incident = coreCall('GetIncident', tonumber(ref))
    if not incident and ref ~= nil then
        incident = coreCall('GetIncidentByPublicNumber', tostring(ref))
    end
    if type(incident) ~= 'table' then return cb({ ok = false, message = 'Byla nerasta.' }) end
    if tostring(incident.type) ~= service then
        return cb({ ok = false, message = service == 'ems' and 'Ne EMS byla.' or 'Ne mechanikų byla.' })
    end

    local bundleFn = service == 'mechanic' and 'GetMechanicCaseBundle' or 'GetMedicalCaseBundle'
    local bundle = coreCall(bundleFn, incident.id)
    if type(bundle) ~= 'table' then return cb({ ok = false, message = 'Nepavyko užkrauti bylos.' }) end
    cb({ ok = true, bundle = bundle })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentCreate', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canView(src, service) then return deny(cb) end
    if not canCreate(src, service) then return deny(cb, 'Nėra teisės kurti bylos.') end

    local summary = tostring(data.summary or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 512)
    if #summary < 3 then return cb({ ok = false, message = 'Įvesk trumpą bylos aprašymą.' }) end

    local createFn = service == 'mechanic' and 'CreateMechanicCase' or 'CreateMedicalCase'
    local payload = {
        source = src,
        summary = summary,
        priority = tonumber(data.priority),
        status = 'in_progress',
    }
    if service == 'ems' then
        payload.presentation_code = data.presentation_code
        payload.presentation_label = data.presentation_label
    else
        payload.fault_code = data.fault_code
        payload.fault_label = data.fault_label
    end

    local incident, err = coreCall(createFn, payload)
    if type(incident) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko sukurti bylos (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, incident = incident, message = ('Byla sukurta: %s'):format(incident.public_number) })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentTransition', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canView(src, service) then return deny(cb) end
    if not canTransition(src, service) then return deny(cb, 'Nėra teisės keisti bylos statuso.') end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local status = tostring(data.status or '')
    local reason = service == 'mechanic' and 'mdt_mechanic' or 'mdt_ems'
    local updated, err = coreCall('TransitionIncidentTo', incident.id, status, {
        source = src,
        citizenid = medicCitizenid(src),
        reason = reason,
    })
    if type(updated) ~= 'table' then
        return cb({ ok = false, message = ('Statusas nepakeistas (%s).'):format(tostring(err or 'neleidžiama')) })
    end
    cb({ ok = true, incident = updated, message = ('Statusas: %s'):format(STATUS_LABELS[updated.status] or updated.status) })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentUpdateCase', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local updateFn = service == 'mechanic' and 'UpdateMechanicCase' or 'UpdateMedicalCase'
    local payload
    if service == 'mechanic' then
        payload = {
            fault_code = data.fault_code,
            fault_label = data.fault_label,
            disposition = data.disposition,
            shop = data.shop,
            duration_minutes = data.duration_minutes,
            tow_requested = data.tow_requested,
            tow_completed = data.tow_completed,
            diagnostics_summary = data.diagnostics_summary,
            recommendations = data.recommendations,
        }
    else
        payload = {
            presentation_code = data.presentation_code,
            presentation_label = data.presentation_label,
            disposition = data.disposition,
            facility = data.facility,
            triage_level = data.triage_level,
            transported = data.transported,
            pulse = data.pulse,
            bp_systolic = data.bp_systolic,
            bp_diastolic = data.bp_diastolic,
            resp_rate = data.resp_rate,
            spo2 = data.spo2,
            gcs = data.gcs,
        }
    end

    local row, err = coreCall(updateFn, incident.id, payload, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko išsaugoti (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({
        ok = true,
        medical = service == 'ems' and row or nil,
        mechanic = service == 'mechanic' and row or nil,
        message = 'Bylos duomenys išsaugoti.',
    })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentSaveReport', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local saveFn = service == 'mechanic' and 'SaveMechanicReport' or 'SaveMedicalReport'
    local kind = service == 'mechanic' and 'mechanic' or 'medical'
    local row, err = coreCall(saveFn, incident.id, {
        title = data.title,
        body = data.body,
        kind = kind,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Raportas neišsaugotas (%s).'):format(tostring(err or 'klaida')) })
    end
    local label = service == 'mechanic' and 'Remonto kortelė' or 'Medicininė kortelė'
    cb({ ok = true, report = row, message = ('%s išsaugota (v%s).'):format(label, row.revision or 1) })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentNearby', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canView(src, service) then return deny(cb) end
    if not canReport(src, service) then return deny(cb, 'Nėra teisės ieškoti asmenų.') end
    cb({ ok = true, rows = nearbyPlayers(src, service), radius = nearbyRadius() })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAttachParty', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local defaultRole = service == 'mechanic' and 'client' or 'patient'
    local role = tostring(data.role or defaultRole):lower()
    if not partyRoleWhitelist(service)[role] then return cb({ ok = false, message = 'Neteisingas dalyvio tipas.' }) end

    local citizenid, name
    if data.targetSource ~= nil then
        citizenid, name = citizenidFromNearbySource(src, data.targetSource, service)
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

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentDetachParty', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local ok = coreCall('DetachParty', incident.id, tonumber(data.partyId), actorFor(src))
    cb({ ok = ok == true, message = ok == true and 'Dalyvis pašalintas.' or 'Nepavyko pašalinti.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAttachUnit', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if not validService(service) then return deny(cb) end
    if not canView(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local role = tostring(data.role or 'assist'):lower()
    local targetSource = tonumber(data.targetSource)

    if targetSource and targetSource ~= src and not canReport(src, service) then
        return deny(cb, service == 'mechanic' and 'Nėra teisės pridėti kitų mechanikų.' or 'Nėra teisės pridėti kitų medikų.')
    end

    local payload = { role = role, service = service }
    if targetSource and targetSource ~= src then
        local citizenid = citizenidFromNearbySource(src, targetSource, service)
        if not citizenid then return cb({ ok = false, message = 'Asmuo nebėra šalia.' }) end
        if service == 'ems' and not isEmsOnDuty(targetSource) then
            return cb({ ok = false, message = 'Tas asmuo ne EMS tarnyboje.' })
        end
        if service == 'mechanic' and not isMechanicOnDuty(targetSource) then
            return cb({ ok = false, message = 'Tas asmuo ne mechanikų tarnyboje.' })
        end
        payload.source = targetSource
        payload.citizenid = citizenid
    else
        payload.source = src
        payload.citizenid = medicCitizenid(src)
    end

    local row, err = coreCall('AttachIncidentOfficer', incident.id, payload, actorFor(src))
    if type(row) ~= 'table' then
        local unitLabel = service == 'mechanic' and 'mechaniko' or 'mediko'
        return cb({ ok = false, message = ('Nepavyko pridėti %s (%s).'):format(unitLabel, tostring(err or 'klaida')) })
    end
    local msgOk = service == 'mechanic' and 'Mechanikas pridėtas prie bylos.' or 'Medikas pridėtas prie bylos.'
    cb({ ok = true, unit = row, message = msgOk })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAddMed', function(src, cb, data)
    if tostring(data and data.service or '') ~= 'ems' then return deny(cb) end
    if not canReport(src, 'ems') then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId, 'ems')
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddMedicalMed', incident.id, {
        med_code = data.med_code,
        med_label = data.med_label,
        dose = data.dose,
        route = data.route,
        patient_citizenid = data.patient_citizenid,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti vaisto (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, med = row, message = 'Vaistas užfiksuotas.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAddAction', function(src, cb, data)
    if tostring(data and data.service or '') ~= 'ems' then return deny(cb) end
    if not canReport(src, 'ems') then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId, 'ems')
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddMedicalAction', incident.id, {
        action_type = data.action_type,
        patient_citizenid = data.patient_citizenid,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti procedūros (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, action = row, message = 'Procedūra užfiksuota.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAddEquipment', function(src, cb, data)
    if tostring(data and data.service or '') ~= 'ems' then return deny(cb) end
    if not canReport(src, 'ems') then return deny(cb) end
    data = type(data) == 'table' and data or {}

    local incident, msg = writableIncident(data.incidentId, 'ems')
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddMedicalEquipment', incident.id, {
        equipment_type = data.equipment_type,
        item_name = data.item_name,
        quantity = data.quantity,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti įrangos (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, equipment = row, message = 'Įranga užfiksuota.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAttachVehicle', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if service ~= 'mechanic' then return deny(cb, 'Tik mechanikams.') end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local plate = tostring(data.plate or ''):upper():gsub('%s+', ''):sub(1, 16)
    if plate == '' then return cb({ ok = false, message = 'Nurodyk numerius.' }) end

    local role = tostring(data.role or 'subject'):lower()
    if not vehicleRoleWhitelist(service)[role] then return cb({ ok = false, message = 'Neteisingas TP tipas.' }) end

    local row, err = coreCall('AttachVehicle', incident.id, {
        plate = plate,
        model = data.model,
        vin = data.vin,
        role = role,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko pridėti TP (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, vehicle = row, message = 'Transporto priemonė pridėta.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentDetachVehicle', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if service ~= 'mechanic' then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local ok = coreCall('DetachVehicle', incident.id, tonumber(data.vehicleId), actorFor(src))
    cb({ ok = ok == true, message = ok == true and 'TP pašalintas.' or 'Nepavyko pašalinti.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAddDiagnostic', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if service ~= 'mechanic' then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddMechanicDiagnostic', incident.id, {
        diag_type = data.diag_type,
        diag_code = data.diag_code,
        diag_label = data.diag_label,
        result = data.result,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti diagnostikos (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, diagnostic = row, message = 'Diagnostika užfiksuota.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAddWork', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if service ~= 'mechanic' then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddMechanicWork', incident.id, {
        work_type = data.work_type,
        work_label = data.work_label,
        duration_minutes = data.duration_minutes,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti darbo (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, work = row, message = 'Darbas užfiksuotas.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAddPart', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if service ~= 'mechanic' then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local row, err = coreCall('AddMechanicPart', incident.id, {
        part_code = data.part_code,
        part_label = data.part_label,
        part_category = data.part_category,
        quantity = data.quantity,
        notes = data.notes,
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko įrašyti dalies (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, part = row, message = 'Dalis užfiksuota.' })
end)

QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAddTowRef', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    local service = tostring(data.service or '')
    if service ~= 'mechanic' then return deny(cb) end
    if not canReport(src, service) then return deny(cb) end

    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end

    local label = tostring(data.label or 'Nutempimas'):sub(1, 255)
    local refId = tostring(data.ref_id or ('tow-' .. os.time())):sub(1, 64)
    local row, err = coreCall('AddMechanicRef', incident.id, {
        ref_type = 'tow',
        ref_id = refId,
        label = label,
        meta = { plate = data.plate, destination = data.destination },
    }, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko susieti nutempimo (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, ref = row, message = 'Nutempimas susietas su byla.' })
end)

-- Legacy EMS-only callback alias (incidentAttachMedic → incidentAttachUnit ems)
QBCore.Functions.CreateCallback('mrp_service_mdt:server:incidentAttachMedic', function(src, cb, data)
    data = type(data) == 'table' and data or {}
    data.service = 'ems'
    local service = 'ems'
    if not canView(src, service) then return deny(cb) end
    local incident, msg = writableIncident(data.incidentId, service)
    if not incident then return cb({ ok = false, message = msg }) end
    local role = tostring(data.role or 'assist'):lower()
    local targetSource = tonumber(data.targetSource)
    if targetSource and targetSource ~= src and not canReport(src, service) then
        return deny(cb, 'Nėra teisės pridėti kitų medikų.')
    end
    local payload = { role = role, service = service }
    if targetSource and targetSource ~= src then
        local citizenid = citizenidFromNearbySource(src, targetSource, service)
        if not citizenid then return cb({ ok = false, message = 'Medikas nebėra šalia.' }) end
        if not isEmsOnDuty(targetSource) then return cb({ ok = false, message = 'Tas asmuo ne EMS tarnyboje.' }) end
        payload.source = targetSource
        payload.citizenid = citizenid
    else
        payload.source = src
        payload.citizenid = medicCitizenid(src)
    end
    local row, err = coreCall('AttachIncidentOfficer', incident.id, payload, actorFor(src))
    if type(row) ~= 'table' then
        return cb({ ok = false, message = ('Nepavyko pridėti mediko (%s).'):format(tostring(err or 'klaida')) })
    end
    cb({ ok = true, medic = row, message = 'Medikas pridėtas prie bylos.' })
end)

exports('HasEmsIncidentPermission', function(src, corePerm, legacyMinGrade)
    return hasPermV2(src, corePerm, legacyMinGrade, 'ambulance')
end)

exports('HasMechanicIncidentPermission', function(src, corePerm, legacyMinGrade)
    return hasPermV2(src, corePerm, legacyMinGrade, 'mechanic')
end)

exports('IssueEmsInvoice', function(src, data)
    data = type(data) == 'table' and data or {}
    data.service = 'ems'
    return IssueServiceInvoice(src, data)
end)

exports('IssueMechanicInvoice', function(src, data)
    data = type(data) == 'table' and data or {}
    data.service = 'mechanic'
    return IssueServiceInvoice(src, data)
end)
