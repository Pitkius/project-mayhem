Config = Config or {}

--- Public incident numbers: INC-YYYYMMDD-####
Config.PublicNumberPrefix = 'INC'

--- Soft link from mrp_dispatch createCall → CreateIncident (Phase 1).
--- Set false to disable without removing the engine.
Config.MirrorDispatchCalls = true

--- Phase 2: mrp_dispatch call status changes → TransitionIncident.
--- Set false to keep create-only mirroring.
Config.SyncDispatchStatus = true

--[[
  Max legal hops TransitionTo() may auto-walk when a caller skips steps
  (e.g. dispatch "arrived" on a still-created call → accepted → arrived).
  Guards against a mapping mistake walking the whole graph.
]]
Config.MaxTransitionWalkSteps = 4

--- Hard ceiling for read-only list APIs (client-supplied limits are clamped to this).
Config.MaxListLimit = 100

--[[
  Phase 3: a unit that accepts / drives / closes a dispatch call is recorded on the
  mirrored incident (mdt_incident_officers). This is what lets a later fine or arrest
  find "the case I am working on" without the UI passing an incident id.
]]
Config.AutoAttachDispatchUnits = true

--- Hard cap for a written incident report body (mdt_incident_reports.body).
Config.MaxReportLength = 20000

--[[
  Read scope for the incident API: false = a viewer only sees their own service's
  incidents (police/ems/mechanic per JobServiceMap). Admins always see everything.
]]
Config.CrossServiceView = false

--- Collapse repeated audit rows from the same actor+target inside this window (ms).
Config.AuditDedupeWindowMs = 5000

--- Admin ACE / QBCore permissions that bypass grade gates.
Config.AdminBypassPermissions = { 'admin', 'god' }

--- Job → service_job used on mdt_incidents.service_job
Config.JobServiceMap = {
    police = 'police',
    ambulance = 'ems',
    mechanic = 'mechanic',
    mechanic2 = 'mechanic',
    mechanic3 = 'mechanic',
    beeker = 'mechanic',
    bennys = 'mechanic',
}

--- Incident type defaults when creating from a service key.
Config.ServiceIncidentType = {
    police = 'police',
    ems = 'ems',
    mechanic = 'mechanic',
    fire = 'fire',
    civil = 'civil',
}

--[[
  RBAC rules: permission → list of { job, minGrade, requireDuty }.
  Mirrors existing mrp_ltpd Config.Permissions grade floors + service_mdt invoice grades.
  mrp_bossmenu grade overrides are consulted at runtime in server/rbac.lua when available.
]]
Config.PermissionRules = {
    MDT_OPEN = {
        { job = 'police', minGrade = 0, requireDuty = true, legacyKey = 'mdt_open' },
    },
    MDT_SEARCH = {
        { job = 'police', minGrade = 0, requireDuty = true, legacyKey = 'mdt_search_basic' },
    },
    MDT_SEARCH_FULL = {
        { job = 'police', minGrade = 3, requireDuty = true, legacyKey = 'mdt_search_full' },
    },
    MDT_EDIT = {
        { job = 'police', minGrade = 1, requireDuty = true, legacyKey = 'mdt_wanted' },
    },
    MDT_FINE = {
        { job = 'police', minGrade = 1, requireDuty = true, legacyKey = 'mdt_fine' },
    },
    MDT_WANTED = {
        { job = 'police', minGrade = 2, requireDuty = true, legacyKey = 'mdt_wanted' },
    },
    MDT_ARREST = {
        { job = 'police', minGrade = 2, requireDuty = true, legacyKey = 'mdt_arrest_record' },
    },
    MDT_REPORT = {
        { job = 'police', minGrade = 2, requireDuty = true, legacyKey = 'mdt_arrest_record' },
    },
    MDT_BODYCAM = {
        { job = 'police', minGrade = 0, requireDuty = true, legacyKey = 'mdt_bodycam' },
    },
    MDT_CCTV = {
        { job = 'police', minGrade = 0, requireDuty = true, legacyKey = 'mdt_cctv' },
    },
    MDT_EVIDENCE = {
        --- Phase 2+ evidence UI; floor matches arrest/report for now.
        { job = 'police', minGrade = 2, requireDuty = true, legacyKey = 'mdt_arrest_record' },
    },
    MDT_LICENSE = {
        { job = 'police', minGrade = 3, requireDuty = true, legacyKey = 'mdt_weapon_license' },
    },
    MDT_FINGERPRINT = {
        { job = 'police', minGrade = 1, requireDuty = true, legacyKey = 'mdt_fingerprint' },
    },
    MDT_INTERROGATION = {
        { job = 'police', minGrade = 2, requireDuty = true, legacyKey = 'mdt_interrogation' },
    },
    MDT_ADMIN = {
        { job = 'police', minGrade = 7, requireDuty = true, legacyKey = 'boss_menu' },
    },

    INCIDENT_CREATE = {
        { job = 'police', minGrade = 0, requireDuty = true },
        { job = 'ambulance', minGrade = 0, requireDuty = true },
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },
    INCIDENT_VIEW = {
        { job = 'police', minGrade = 0, requireDuty = false },
        { job = 'ambulance', minGrade = 0, requireDuty = false },
        { job = 'mechanic', minGrade = 0, requireDuty = false },
    },
    INCIDENT_ASSIGN = {
        { job = 'police', minGrade = 0, requireDuty = true },
        { job = 'ambulance', minGrade = 0, requireDuty = true },
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },
    INCIDENT_TRANSITION = {
        { job = 'police', minGrade = 0, requireDuty = true },
        { job = 'ambulance', minGrade = 0, requireDuty = true },
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },
    INCIDENT_CLOSE = {
        { job = 'police', minGrade = 0, requireDuty = true },
        { job = 'ambulance', minGrade = 0, requireDuty = true },
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },

    EMS_MDT_OPEN = {
        { job = 'ambulance', minGrade = 0, requireDuty = false },
    },
    EMS_MDT_INVOICE = {
        { job = 'ambulance', minGrade = 0, requireDuty = true },
    },
    EMS_MDT_REPORT = {
        { job = 'ambulance', minGrade = 0, requireDuty = true },
    },
    EMS_INCIDENT_VIEW = {
        { job = 'ambulance', minGrade = 0, requireDuty = false },
    },
    EMS_INCIDENT_CREATE = {
        { job = 'ambulance', minGrade = 0, requireDuty = true },
    },
    EMS_INCIDENT_TRANSITION = {
        { job = 'ambulance', minGrade = 0, requireDuty = true },
    },

    MECH_MDT_OPEN = {
        { job = 'mechanic', minGrade = 0, requireDuty = false },
    },
    MECH_MDT_INVOICE = {
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },
    MECH_MDT_REPORT = {
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },
    MECH_INCIDENT_VIEW = {
        { job = 'mechanic', minGrade = 0, requireDuty = false },
    },
    MECH_INCIDENT_CREATE = {
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },
    MECH_INCIDENT_TRANSITION = {
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },

    DISPATCH_CREATE_CALL = {
        { job = 'police', minGrade = 0, requireDuty = true },
        { job = 'ambulance', minGrade = 0, requireDuty = true },
        { job = 'mechanic', minGrade = 0, requireDuty = true },
    },
}

--- Phase 7: telemetry (batched inserts, not per poll tick).
Config.Telemetry = {
    Enabled = true,
    FlushIntervalMs = 5000,
    MaxBatchSize = 50,
    RateLimitMs = 100,
    --- Ignore very short MDT sessions (accidental open/close).
    SessionCloseMinMs = 500,
}

--- Phase 7: search cache + list query tuning (used by PD search and core list APIs).
Config.Performance = {
    SearchCacheTtlSec = 20,
    SearchCacheMaxEntries = 128,
}

--- Default NUI / client refresh knobs (overridable per tablet in mrp_ltpd / mrp_service_mdt).
Config.MdtRefreshDefaults = {
    --- Fallback NUI dispatch poll when live push is stale (ms).
    DispatchPollMs = 2500,
    --- Skip poll ticks while mrp_dispatch push is fresh (ms since last push).
    PushStaleMs = 3500,
    --- Longer poll interval while push is active (ms); set 0 to disable poll entirely when push fresh.
    DispatchPollPushMs = 8000,
    DisablePollWhenPushActive = true,
    PlayerPosIntervalMs = 750,
    PlayerPosMinMoveM = 2.5,
}
