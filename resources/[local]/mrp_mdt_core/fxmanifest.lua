fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mrp_mdt_core'
author 'MRP'
description 'MDT V2 core — Incident Engine, police + EMS + mechanic + evidence + telemetry (Phase 7 complete)'
version '2.0.0-phase7'

shared_scripts {
    'config.lua',
    'shared/incident_states.lua',
    'shared/permissions.lua',
    'shared/police_case.lua',
    'shared/medical_case.lua',
    'shared/mechanic_case.lua',
    'shared/evidence_case.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/audit.lua',
    'server/timeline.lua',
    'server/rbac.lua',
    'server/incident_engine.lua',
    'server/incident_links.lua',
    'server/modules/police.lua',
    'server/modules/medical.lua',
    'server/modules/mechanic.lua',
    'server/modules/evidence.lua',
    'server/modules/analytics.lua',
    'server/api.lua',
    'server/main.lua',
}

server_exports {
    --- Incident writes
    'CreateIncident',
    'TransitionIncident',
    'TransitionIncidentTo',
    'AssignIncidentCrew',
    'SyncDispatchCallStatus',
    --- Incident reads
    'GetIncident',
    'GetIncidentByPublicNumber',
    'GetIncidentByDispatchCall',
    'GetIncidentBundle',
    'GetIncidentTimeline',
    'ListIncidents',
    'ListIncidentsByCitizen',
    'ListIncidentsByPlate',
    --- Parties / vehicles / responding units junctions
    'AttachParty',
    'AttachVehicle',
    'AttachIncidentOfficer',
    'DetachParty',
    'DetachVehicle',
    'DetachIncidentOfficer',
    'ListIncidentParties',
    'ListIncidentVehicles',
    'ListIncidentOfficers',
    'ListOpenIncidentsForOfficer',
    'ListPartyRoles',
    'ListVehicleRoles',
    --- Police case (Phase 3)
    'CreatePoliceCase',
    'UpdatePoliceCase',
    'GetPoliceCase',
    'GetPoliceCaseBundle',
    'ListPoliceCases',
    'ResolveOfficerIncident',
    'SaveIncidentReport',
    'GetIncidentReport',
    'AddIncidentForce',
    'AddIncidentTool',
    'AddIncidentSeizedItem',
    'AddIncidentRef',
    'ListIncidentForce',
    'ListIncidentTools',
    'ListIncidentSeizedItems',
    'ListIncidentRefs',
    'GetPoliceCaseVocabulary',
    --- EMS medical case (Phase 4)
    'CreateMedicalCase',
    'UpdateMedicalCase',
    'GetMedicalCase',
    'GetMedicalCaseBundle',
    'ListMedicalCases',
    'ResolveMedicIncident',
    'SaveMedicalReport',
    'GetMedicalReport',
    'AddMedicalMed',
    'AddMedicalAction',
    'AddMedicalEquipment',
    'AddMedicalRef',
    'ListMedicalMeds',
    'ListMedicalActions',
    'ListMedicalEquipment',
    'ListMedicalRefs',
    'GetMedicalCaseVocabulary',
    --- Mechanic repair case (Phase 5)
    'CreateMechanicCase',
    'UpdateMechanicCase',
    'GetMechanicCase',
    'GetMechanicCaseBundle',
    'ListMechanicCases',
    'ResolveMechanicIncident',
    'SaveMechanicReport',
    'GetMechanicReport',
    'AddMechanicDiagnostic',
    'AddMechanicWork',
    'AddMechanicPart',
    'AddMechanicRef',
    'ListMechanicDiagnostics',
    'ListMechanicWork',
    'ListMechanicParts',
    'ListMechanicRefs',
    'GetMechanicCaseVocabulary',
    --- Evidence locker (Phase 6)
    'AddEvidenceItem',
    'SealEvidenceItem',
    'GetEvidenceItem',
    'ListEvidenceItems',
    'GetEvidenceVocabulary',
    --- History
    'AppendTimeline',
    'AuditLog',
    'AuditLogAsync',
    --- RBAC
    'HasPermission',
    'RequirePermission',
    --- State machine helpers
    'ListAllowedTransitions',
    'IsValidIncidentStatus',
    'MapDispatchStatus',
    'MapDispatchAction',
    'ShouldMirrorDispatchCalls',
    'ShouldSyncDispatchStatus',
    --- Analytics (Phase 7)
    'RecordTelemetry',
    'BeginMdtSession',
    'EndMdtSession',
    'FlushTelemetry',
    'GetMdtAnalyticsSummary',
}

dependencies {
    'oxmysql',
    'qb-core',
}
