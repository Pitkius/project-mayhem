# MDT V2 Architecture

**Status:** Phase 7 complete — MDT V2 all phases done (2026-07-30)  
**Core resource:** `resources/[local]/mrp_mdt_core`

## Design principles

1. **Incident is the core object** — not fines, not dispatch blips.
2. **Loose coupling** — PD / EMS / Mech / Court / Evidence talk only through the Incident Engine exports (+ timeline).
3. **Validated lifecycle** — statuses are a state machine (`shared/incident_states.lua`), not free-form strings.
4. **Immutable history** — timeline + audit are append-only from gameplay.
5. **RBAC** — named permissions (`MDT_FINE`, …) mapped from job + grade + duty (legacy grade keys preserved).

## Phase 1 (done)

- [x] `mrp_mdt_core` resource + SQL (`mdt_incidents`, timeline, audit, parties/vehicles stubs)
- [x] Exports: Create / Get / Transition / Assign / AppendTimeline / AuditLog / HasPermission
- [x] Ensure order: `mrp_mdt_core` before `mrp_dispatch` / tablets
- [x] Soft mirror: dispatch `createCall` → `CreateIncident` (toggle `Config.MirrorDispatchCalls`)
- [x] Security P0: lock `cctvTamper` net event; authorize `createServiceCall`; trucking uses `CreateDispatchCall` export
- [x] Audit hooks: CCTV tamper (export), blocked tamper net, denied createServiceCall, PD fine issue
- [x] Polling left intact (comment/hook only)

## Phase 2 (done)

- [x] State machine used for **real** transitions, not just create — `TransitionIncidentTo` walks the shortest legal route when a unit skips steps (`MdtIncidentStates.PathTo`)
- [x] `mrp_dispatch` call status changes → `SyncDispatchCallStatus` (see mapping table below), incl. panic, reject, prune/timeout and archive paths
- [x] Dispatch crew → `AssignIncidentCrew` (auto `created → assigned`)
- [x] Read-only incident APIs: `ListIncidents`, `GetIncidentBundle`, `GetIncidentTimeline`, `ListIncidentsByCitizen`, `ListIncidentsByPlate` + RBAC-gated QBCore callbacks for the future NUI
- [x] Parties / vehicles junction writes via `AttachParty` / `AttachVehicle` (+ detach, role whitelists, upsert instead of duplicates)
- [x] `AuditLog` widened: MDT open, person search, vehicle search, wanted level, arrest note, CCTV open, bodycam open (append-only, deduped on hot paths)
- [x] `HasPermission` dual-checked (core RBAC **OR** legacy grade key) on `issueFine`, `setWanted`, `addArrestNote`, `searchPerson`, `searchVehicle`, `cctvWatch`, `bodycamWatch`
- [x] `updateCallStatus` hardened to a whitelist of known actions
- [x] Polling left intact (Phase 7)

### Dispatch → incident status mapping

| `mrp_dispatch` action | Call status | Incident status |
|-----------------------|-------------|-----------------|
| *(call created)* | `pending` | `created` |
| *(crew assigned to call)* | — | `assigned` |
| `accept` | `accepted` | `accepted` |
| `enroute` | `enroute` | `enroute` |
| `arrived` | `arrived` | `arrived` |
| `in_progress` (reserved, no UI yet) | `in_progress` | `in_progress` |
| `done` | `done` | `completed` |
| `panic_off` | `done` | `completed` |
| `reject` | `rejected` | `rejected`, or `cancelled` if the unit already arrived |
| `cancel` (reserved) | `cancelled` | `cancelled` |
| `expire` (reserved) | `expired` | `expired` |
| pruned from live dispatch while open | — | `timeout` |
| pruned from live dispatch when closed | — | `archived` |

Skipped steps are auto-walked: e.g. `arrived` on a still-`created` call becomes
`created → accepted → arrived`, with each hop validated and timelined
(`reason` suffixed `:auto_step`) and one audit row for the requested change.

Two deliberate asymmetries:

- **No regression.** `enroute` after `arrived` has no legal walk, so the incident keeps the furthest progress it reached. Dispatch treats the denial as expected.
- **Reject fallback.** `rejected` is unreachable once a unit is on scene, so `MdtIncidentStates.ACTION_FALLBACK` maps it to `cancelled` — otherwise the incident would hang open until pruned.

## Phase 3 (done) — PD incident (byla)

A police case is the incident row **plus normalized child tables** — never a JSON blob.
The incident lifecycle stays with the Incident Engine; the PD module owns only the
police extension.

### Schema

| Table | Holds | Notes |
|-------|-------|-------|
| `mdt_incident_officers` | responding units: citizenid, callsign, badge, service, role | service-agnostic (Phase 4/5 crews reuse it), unique per (incident, citizen) |
| `mdt_incident_police` | case extension: offence code/label, disposition, lead officer, station, `arrest_made` / `force_used` / `weapon_involved`, `fine_total` | 1:1 with a police incident, created lazily |
| `mdt_incident_reports` | written report: title, `body` (MEDIUMTEXT), `meta` JSON extras, author, `revision` | unique per (incident, `kind`) so Phase 4 can add a medical chart |
| `mdt_incident_force` | use of force: type, tool, subject, injuries, medical called | append-only |
| `mdt_incident_tools` | equipment used on scene: type, item, quantity | append-only |
| `mdt_incident_seized` | seized property: item, quantity, category, from whom, `storage_ref` / `evidence_ref` | evidence locker owns the refs in Phase 6 |
| `mdt_incident_refs` | typed pointers to rows owned by other resources: `fine`, `arrest`, `fingerprint`, `wanted`, `interrogation` + stubs `bodycam`, `cctv`, `photo`, `evidence`, `warrant` | `ref_table` + `ref_id` + optional `amount`; unique per (incident, type, ref_id) |

`fine_total` is recomputed from the linked `fine` refs, so it can never drift from the
fine rows. Flags are only ever raised (`force_used`, `weapon_involved`, `arrest_made`),
and `disposition` auto-moves only while it is still `pending` — an explicit officer
decision is never overwritten.

Vocabulary (dispositions, force ladder, injuries, tools, seized categories, ref types,
officer/party/vehicle roles) lives in `shared/police_case.lua`, so the NUI renders exactly
what the server validates against.

### Server

- `server/modules/police.lua` (`MdtPolice`) — case row, report upsert, force/tools/seized,
  typed refs, `GetPoliceCaseBundle`, `ListPoliceCases`, `ResolveForOfficer`.
- `server/incident_links.lua` — officer junction (`AttachIncidentOfficer` / detach / list /
  `ListOpenIncidentsForOfficer`) next to the Phase 2 parties/vehicles writes.
- Dispatch engagement (`accept` / `enroute` / `arrived` / `in_progress` / `done`) registers the
  acting unit on the mirrored incident (`Config.AutoAttachDispatchUnits`). This is what lets a
  later fine or arrest resolve *"the case I am working on"* without the UI passing an id.
- `mrp_ltpd/server/mdt_incidents.lua` — the PD surface: NUI callbacks + `LtpdMdtIncidents.On*`
  gameplay hooks. It owns no incident tables and only calls `mrp_mdt_core` exports.

### Wired PD actions

| Action | Effect on the case |
|--------|--------------------|
| `issueFine` (MDT „Bauda" tab **or** case UI) | `fine` ref (+ amount → `fine_total`), offender attached as `suspect`, timeline; only auto-creates a case if `Config.MdtIncidents.autoCreateOnFine` |
| arrest note | `suspect` party + `arrest` ref, `arrest_made` + disposition `arrest`, timeline; opens a case when the officer has none |
| fingerprint scan | `fingerprint` ref + `suspect` party on the active case (never creates one) |
| wanted level change | `wanted_updated` timeline entry + `wanted` ref |

Resolution order for actions that carry no incident id: explicit id → open case the officer
is listed on → open case the officer opened → optional auto-create.

Both fines and arrests now have a **single server write path**
(`IssuePoliceFine` / `AddPoliceArrestRecord` exports), used by the legacy tabs and the case UI,
so money handling, the `ltpd_*` row, audit and the incident link can never drift apart.

### MDT UI — „Bylos" tab

`mrp_ltpd/html/mdt/` (`index.html` `#panel-incidents`, `incidents.js`, `.inc-*` styles):
list of open/recent PD cases (search, *only open*, *only mine*), new-case form, and a detail
view with status transitions, offence/disposition, officers, parties (nearby-player picker),
vehicles, force, tools, seized items, refs, the report editor and a read-only timeline.
Incident numbers come from the core (`INC-YYYYMMDD-####`).

RBAC per action: `INCIDENT_VIEW` (open the tab), `MDT_REPORT` (case data, report, parties,
vehicles, refs), `INCIDENT_TRANSITION` (status), `MDT_FINE`, `MDT_ARREST`, `MDT_SEARCH`
(nearby picker), `MDT_EVIDENCE` (seized). Each is dual-checked (core permission **or** legacy
grade key), and archived cases are read-only.

## Phase 4 (done) — EMS medical incident (byla)

An EMS case is the incident row **plus normalized medical child tables** — mirroring Phase 3 PD
patterns. Lifecycle stays with the Incident Engine; the medical module owns only the EMS extension.

### Schema

| Table | Holds | Notes |
|-------|-------|-------|
| `mdt_incident_medical` | case extension: presentation, disposition, triage, facility, vitals, `transported`, `invoice_total` | 1:1 with an ems incident |
| `mdt_incident_medical_meds` | medications: code/label, dose, route, patient, medic | append-only |
| `mdt_incident_medical_actions` | procedures: action_type, patient, medic | append-only |
| `mdt_incident_medical_equipment` | equipment used: type, item, quantity | append-only |
| `mdt_incident_officers` | medics on scene (`service='ems'`) | reused from Phase 3 |
| `mdt_incident_reports` | medical chart (`kind='medical'`) | reused from Phase 3 |
| `mdt_incident_refs` | `invoice` → `fivempro_service_invoices` | `invoice_total` derived from refs |

Vocabulary lives in `shared/medical_case.lua`.

### Server

- `server/modules/medical.lua` (`MdtMedical`) — case row, chart, meds/actions/equipment, refs,
  `GetMedicalCaseBundle`, `ListMedicalCases`, `ResolveForMedic`.
- `mrp_service_mdt/server/mdt_incidents.lua` — EMS MDT surface + `OnInvoiceIssued` gameplay hook.
- `IssueServiceInvoice` — single write path for EMS invoices (money + DB row + incident link).

### MDT UI — EMS „Bylos" tab

`mrp_service_mdt/html/` (`incidents.js`, `#panel-incidents`): list/detail for EMS medics only.
Mechanic MDT unchanged (no incidents tab).

RBAC: `EMS_INCIDENT_VIEW`, `EMS_MDT_REPORT`, `EMS_INCIDENT_CREATE`, `EMS_INCIDENT_TRANSITION`,
`EMS_MDT_INVOICE` (+ legacy grade fallback via service config).

## Phase 5 (done) — Mechanic repair incident (byla)

A mechanic case is the incident row **plus normalized repair child tables** — mirroring Phase 4 EMS
patterns. Lifecycle stays with the Incident Engine; the mechanic module owns only the repair extension.

### Schema

| Table | Holds | Notes |
|-------|-------|-------|
| `mdt_incident_mechanic` | case extension: fault, disposition, shop, tow flags, duration, `invoice_total`, diagnostics summary, recommendations | 1:1 with a mechanic incident |
| `mdt_incident_mechanic_diagnostics` | diagnostic checks: type, result, label | append-only |
| `mdt_incident_mechanic_work` | work performed: type, label, duration | append-only |
| `mdt_incident_mechanic_parts` | parts replaced: label, category, quantity | append-only |
| `mdt_incident_officers` | mechanics on scene (`service='mechanic'`) | reused from Phase 3 |
| `mdt_incident_reports` | repair chart (`kind='mechanic'`) | reused from Phase 3 |
| `mdt_incident_refs` | `invoice` → `fivempro_service_invoices`, `tow` stub | `invoice_total` derived from refs |
| `mdt_incident_parties` | client / owner / driver | reused junction |
| `mdt_incident_vehicles` | subject vehicle plate | reused junction |

Vocabulary lives in `shared/mechanic_case.lua`.

### Server

- `server/modules/mechanic.lua` (`MdtMechanic`) — case row, chart, diagnostics/work/parts, refs,
  `GetMechanicCaseBundle`, `ListMechanicCases`, `ResolveForMechanic`.
- `mrp_service_mdt/server/mdt_incidents.lua` — Service MDT surface + `OnInvoiceIssued` for EMS and mechanic.
- `IssueServiceInvoice` — single write path for mechanic invoices (money + DB row + incident link).

### MDT UI — Mechanic „Bylos" tab

`mrp_service_mdt/html/` (`mechanic_incidents.js`, `#panel-incidents`): list/detail for mechanics only.
EMS tab unchanged.

RBAC: `MECH_INCIDENT_VIEW`, `MECH_MDT_REPORT`, `MECH_INCIDENT_CREATE`, `MECH_INCIDENT_TRANSITION`,
`MECH_MDT_INVOICE` (+ legacy grade fallback via service config).

## Phase 6 (done) — Evidence, Bodycam, CCTV

Evidence locker, surveillance hardening, and incident linking — foundation for court/forensics later.

### Schema

| Table | Holds | Notes |
|-------|-------|-------|
| `mdt_evidence_items` | chain-of-custody: item, qty, description, location, locker_slot, category, logged_by, sealed | 1:N per police incident |
| `mdt_incident_refs` | `evidence` → `mdt_evidence_items`, `cctv` / `bodycam` session handles | reused from Phase 3 |

Vocabulary: `shared/evidence_case.lua` (locker locations, categories).

### Server

- `server/modules/evidence.lua` (`MdtEvidence`) — add / seal / list; auto `AddIncidentRef` on log.
- `GetPoliceCaseBundle` includes `evidence[]` alongside refs.
- `mrp_ltpd/server/surveillance.lua` — RBAC dual-check on list + watch; audit opens; refs linked on
  `cctvWatch` / `bodycamWatch` when `incidentId` passed or officer has active case.
- `Config.Surveillance.MdtV2EnableSurveillance` bypasses `MaintenanceMode` for duty PD MDT tabs.
- `TamperCctv` / `TamperCctvRadius` exports only — net event blocked (P0).

### MDT UI — PD „Bylos" evidence + surveillance refs

`incidents.js`: evidence locker section (add / list / seal), grouped refs for CCTV/bodycam/evidence,
buttons to open CCTV/bodycam tabs with `window.mrpMdtActiveIncidentId` context (auto-ref on watch).

RBAC: `MDT_EVIDENCE` (locker writes), `MDT_CCTV`, `MDT_BODYCAM` (surveillance tabs + auto-link).

## Phase 7 (done) — Analytics, performance, optimization

| Area | Change |
|------|--------|
| Telemetry | `mdt_telemetry_events` + batched `RecordTelemetry` / session open-close duration |
| Dispatch push | `BlipRefreshMs` 1500 ms; NUI poll 2500 ms fallback, skipped when `dispatchLive` fresh |
| Player GPS NUI | 750 ms + meaningful-move threshold (2.5 m) |
| Person search | 20 s result cache; batch wanted/fines/vehicles lookups |
| Indexes | `idx_service_status_created` on `mdt_incidents`; documented optional `players` / `ltpd_fines` keys |

Config knobs: `mrp_mdt_core` `Config.Telemetry` / `Config.Performance`; `Config.MdtPerformance` on PD + Service MDT tablets.

Admin read: `GetMdtAnalyticsSummary(from, to)` export or `mrp_mdt_core:server:analyticsSummary` callback.

## Intentional non-integrations (TODO)

| Item | Why deferred |
|------|----------------|
| Incident → dispatch reverse sync | Dispatch calls stay the live source of truth; the incident is the record |
| Replace `mrp_ltpd` `hasPerm` with core RBAC everywhere | Avoid breaking live PD; Phase 2 dual-checks the high-value callbacks first |
| Evidence / Court resources | Phase 6 evidence locker done; court module deferred |
| Bodycam / CCTV / photo refs auto-linked | Phase 6: CCTV/bodycam auto-link on watch; photo still manual stub |
| Seized items moved into an inventory locker | Phase 6 evidence locker owns refs; seized row keeps `storage_ref` bridge |
| Remove 350ms NUI poll | **Done (Phase 7)** — 2500 ms fallback + push-aware skip; map still live via dispatch push |
| Society credit for fines/invoices | Economic P1 from audit — separate from Incident Engine |
| Hard `dependency` on core from dispatch | Soft `GetResourceState` so dispatch still boots alone |

## Consumer cheat-sheet

```lua
-- Create
local inc = exports['mrp_mdt_core']:CreateIncident({
    type = 'police',
    summary = 'Apiplėšimas',
    location_x = x, location_y = y, location_z = z,
    source = src,
})

-- Transition (single legal edge) / walk towards a target status
exports['mrp_mdt_core']:TransitionIncident(inc.id, 'enroute', { source = src })
exports['mrp_mdt_core']:TransitionIncidentTo(inc.id, 'completed', { source = src, reason = 'closed_on_scene' })

-- Link people / vehicles / units
exports['mrp_mdt_core']:AttachParty(inc.id, { citizenid = cid, role = 'suspect' }, { source = src })
exports['mrp_mdt_core']:AttachVehicle(inc.id, { plate = 'ABC123', role = 'suspect_vehicle' }, { source = src })
exports['mrp_mdt_core']:AttachIncidentOfficer(inc.id, { source = src, role = 'lead' }, { source = src })

-- Read
local bundle = exports['mrp_mdt_core']:GetIncidentBundle(inc.id)
local open = exports['mrp_mdt_core']:ListIncidents({ service_job = 'police', openOnly = true, limit = 25 })

-- Police case (Phase 3)
local case = exports['mrp_mdt_core']:CreatePoliceCase({ source = src, summary = 'Apiplėšimas', status = 'in_progress' })
local active = exports['mrp_mdt_core']:ResolveOfficerIncident(src, { autoCreate = true, summary = 'Areštas' })
exports['mrp_mdt_core']:SaveIncidentReport(case.id, { title = 'Raportas', body = '...' }, { source = src })
exports['mrp_mdt_core']:AddIncidentForce(case.id, { force_type = 'taser', injuries = 'minor' }, { source = src })
exports['mrp_mdt_core']:AddIncidentRef(case.id, { ref_type = 'fine', ref_id = fineId, amount = 500 }, { source = src })
local full = exports['mrp_mdt_core']:GetPoliceCaseBundle(case.id)  -- + police/report/force/tools/seized/refs

-- EMS medical case (Phase 4)
local emsCase = exports['mrp_mdt_core']:CreateMedicalCase({ source = src, summary = 'Trauma vietoje', status = 'in_progress' })
local emsActive = exports['mrp_mdt_core']:ResolveMedicIncident(src, { autoCreate = true, summary = 'Skubi pagalba' })
exports['mrp_mdt_core']:SaveMedicalReport(emsCase.id, { title = 'Kortelė', body = '...', kind = 'medical' }, { source = src })
exports['mrp_mdt_core']:AddMedicalMed(emsCase.id, { med_label = 'Morfinas', dose = '5mg', route = 'iv' }, { source = src })
exports['mrp_mdt_core']:AddMedicalRef(emsCase.id, { ref_type = 'invoice', ref_id = invoiceId, amount = 750 }, { source = src })
local emsFull = exports['mrp_mdt_core']:GetMedicalCaseBundle(emsCase.id)

-- Mechanic repair case (Phase 5)
local mechCase = exports['mrp_mdt_core']:CreateMechanicCase({ source = src, summary = 'Gedimas kelyje', status = 'in_progress' })
local mechActive = exports['mrp_mdt_core']:ResolveMechanicIncident(src, { autoCreate = true, summary = 'Nutempimas' })
exports['mrp_mdt_core']:SaveMechanicReport(mechCase.id, { title = 'Kortelė', body = '...', kind = 'mechanic' }, { source = src })
exports['mrp_mdt_core']:AddMechanicDiagnostic(mechCase.id, { diag_type = 'obd_scan', result = 'fail' }, { source = src })
exports['mrp_mdt_core']:AddMechanicWork(mechCase.id, { work_type = 'repair', duration_minutes = 45 }, { source = src })
exports['mrp_mdt_core']:AddMechanicPart(mechCase.id, { part_label = 'Starteris', part_category = 'electrical' }, { source = src })
exports['mrp_mdt_core']:AddMechanicRef(mechCase.id, { ref_type = 'invoice', ref_id = invoiceId, amount = 850 }, { source = src })
local mechFull = exports['mrp_mdt_core']:GetMechanicCaseBundle(mechCase.id)

-- Evidence locker (Phase 6)
exports['mrp_mdt_core']:AddEvidenceItem(case.id, { item_name = 'weapon_pistol', locker_slot = 'A-12', location = 'mrpd_weapons' }, { source = src })
exports['mrp_mdt_core']:SealEvidenceItem(evidenceId, { source = src })
local evidence = exports['mrp_mdt_core']:ListEvidenceItems(case.id)

-- Timeline / audit
exports['mrp_mdt_core']:AppendTimeline(inc.id, 'note_added', { source = src, payload = { text = '...' } })
exports['mrp_mdt_core']:AuditLog('custom.action', { source = src, target = tostring(inc.id) })
exports['mrp_mdt_core']:AuditLogAsync('mdt.search', { source = src, target = q, dedupeKey = q })

-- RBAC
if not exports['mrp_mdt_core']:HasPermission(src, 'MDT_FINE') then return end

-- Analytics (Phase 7)
exports['mrp_mdt_core']:RecordTelemetry('custom_event', { source = src, service = 'police', meta = { foo = 1 } })
local summary = exports['mrp_mdt_core']:GetMdtAnalyticsSummary('2026-07-01', nil)
```

## Related docs

- `docs/mdt-audit-chatgpt.md` — pre-V2 audit
- `resources/[local]/mrp_mdt_core/README.md` — resource README
