# mrp_mdt_core — MDT V2 Phase 7 (complete)

Incident-centric backbone for Project Mayhem PD / EMS / Mechanic tablets.

## Scope

| Included (Phase 1–7) | Not included (by design) |
|----------------------|--------------------------|
| Incident Engine (create / get / transition / assign) | Court, warrants, fire |
| Validated status state machine + multi-hop walking | Replacing `mrp_dispatch` in-memory calls |
| Append-only timeline + audit tables | |
| RBAC permission names + grade mapping | |
| Dispatch call status → incident state sync | |
| Read-only incident APIs (list / get / timeline / by citizen / by plate) | |
| Parties, vehicles & responding-unit junction writes | |
| Police / EMS / Mechanic cases + evidence locker | |
| Telemetry (`mdt_telemetry_events`) + analytics summary export | |
| Search cache + batch lookups (PD person search) | |
| Push-first dispatch refresh (1500 ms server / 2500 ms NUI fallback) | |

## Architecture

```
mrp_phone / scripts ──► mrp_dispatch:CreateDispatchCall  (live ops — unchanged)
                              │
                              ├── soft ► mrp_mdt_core:CreateIncident        (persistent case)
                              └── soft ► mrp_mdt_core:SyncDispatchCallStatus (lifecycle)

mrp_ltpd / mrp_service_mdt ──► still own their NUI + SQL domain tables
                              │
                              ├── AuditLog on sensitive actions (search / wanted / CCTV / bodycam)
                              └── HasPermission dual-checked next to legacy grade keys

Future: Court / Warrants ──► ONLY via Incident Engine + timeline
```

Modules must not write each other's domain tables. Cross-module communication goes through **exports on `mrp_mdt_core`**.

## Exports

### Incident writes

| Export | Purpose |
|--------|---------|
| `CreateIncident(data)` | Create row + timeline `incident_created` |
| `TransitionIncident(id, status, actor)` | Single validated state change |
| `TransitionIncidentTo(id, status, actor)` | Walks legal intermediate hops when steps were skipped |
| `AssignIncidentCrew(id, crewId, actor)` | Set crew; may auto `created→assigned` |
| `SyncDispatchCallStatus(callId, action, opts)` | Dispatch action → mapped incident state |

### Incident reads

| Export | Purpose |
|--------|---------|
| `GetIncident(id)` | Fetch by id |
| `GetIncidentByPublicNumber(number)` | Fetch by `INC-YYYYMMDD-####` |
| `GetIncidentByDispatchCall(callId)` | Fetch by mirrored dispatch call |
| `GetIncidentBundle(id, opts)` | Incident + timeline + parties + vehicles + officers + allowed transitions |
| `GetIncidentTimeline(id, limit)` | Timeline rows |
| `ListIncidents(filters)` | Filtered list (see below) |
| `ListIncidentsByCitizen(cid, opts)` | Via parties junction |
| `ListIncidentsByPlate(plate, opts)` | Via vehicles junction |

### Parties / vehicles / responding units

| Export | Purpose |
|--------|---------|
| `AttachParty(id, data, actor)` | Upsert `{ citizenid, role, display_name, notes }` |
| `AttachVehicle(id, data, actor)` | Upsert `{ plate, vin, model, role, notes }` |
| `AttachIncidentOfficer(id, data, actor)` | Upsert `{ source|citizenid, role, callsign, badge, service }`; never demotes an existing `lead` |
| `DetachParty(id, partyId, actor)` | Remove link (audited) |
| `DetachVehicle(id, vehicleId, actor)` | Remove link (audited) |
| `DetachIncidentOfficer(id, officerId, actor)` | Remove unit (audited) |
| `ListIncidentParties(id)` / `ListIncidentVehicles(id)` / `ListIncidentOfficers(id)` | Read links |
| `ListOpenIncidentsForOfficer(citizenid, opts)` | Open incidents a unit is listed on |
| `ListPartyRoles()` / `ListVehicleRoles()` | Allowed role keys |

### Police case (Phase 3)

| Export | Purpose |
|--------|---------|
| `CreatePoliceCase(data)` | Incident (`type='police'`) + case row + creator as `lead` |
| `UpdatePoliceCase(id, data, actor)` | Offence code/label, disposition, station, lead, flags |
| `GetPoliceCase(id)` / `GetPoliceCaseBundle(id, opts)` | Case row / full case (+ evidence[] Phase 6) |
| `ListPoliceCases(filters)` | `ListIncidents` filters, pinned to police, enriched with case + unit summary |
| `ResolveOfficerIncident(src, opts)` | "The case this officer is working on"; `autoCreate` optional |
| `SaveIncidentReport(id, data, actor)` / `GetIncidentReport(id, kind)` | Report upsert (`revision++`) / read |
| `AddIncidentForce(id, data, actor)` | Use-of-force row (+ raises `force_used` / `weapon_involved`) |
| `AddIncidentTool(id, data, actor)` | Equipment used on scene |
| `AddIncidentSeizedItem(id, data, actor)` | Seized property (storage / evidence handles) |
| `AddIncidentRef(id, data, actor)` | Typed pointer: fine / arrest / fingerprint / wanted / bodycam / cctv / photo / evidence / warrant |
| `ListIncidentForce/Tools/SeizedItems/Refs(id)` | Read child tables |
| `GetPoliceCaseVocabulary()` | Labels + role/category keys for the NUI |

### Evidence locker (Phase 6)

| Export | Purpose |
|--------|---------|
| `AddEvidenceItem(incidentId, data, actor)` | Log item + `mdt_incident_refs` evidence pointer + timeline |
| `SealEvidenceItem(evidenceId, actor)` | One-way seal + ref refresh + audit |
| `GetEvidenceItem(evidenceId)` / `ListEvidenceItems(incidentId)` | Read rows |
| `GetEvidenceVocabulary()` | Locker locations + categories for NUI |

### History / RBAC / helpers

| Export | Purpose |
|--------|---------|
| `AppendTimeline(id, eventType, opts)` | Append-only event |
| `AuditLog(action, opts)` | Append-only audit (synchronous) |
| `AuditLogAsync(action, opts)` | Fire-and-forget + optional `dedupeKey` for hot paths |
| `HasPermission(source, perm)` | RBAC check |
| `RequirePermission(source, perm)` | RBAC + notify |
| `ListAllowedTransitions(from)` | State machine edges |
| `IsValidIncidentStatus(status)` | Validate status key |
| `MapDispatchStatus(status)` / `MapDispatchAction(action)` | Dispatch → incident mapping |
| `ShouldMirrorDispatchCalls()` / `ShouldSyncDispatchStatus()` | Config toggles |

### CreateIncident `data` fields

`type`, `status` (default `created`), `priority`, `service_job`, `summary`, `location_label`, `location_x/y/z`, `created_by`, `assigned_crew`, `dispatch_call_id`, `source` (player), `skipTimeline`, `skipAudit`.

### ListIncidents `filters`

`type`, `status` (string or list), `openOnly`, `service_job`, `dispatch_call_id`, `assigned_crew`, `created_by`, `search` (public number / summary / location), `orderBy` (`id|created_at|updated_at|priority`), `desc`, `limit` (clamped to `Config.MaxListLimit`), `offset`.

## Read-only NUI callbacks (Phase 2)

All require `INCIDENT_VIEW` and are scoped to the caller's own service unless `Config.CrossServiceView` is on (admins always see everything).

| Callback | Args |
|----------|------|
| `mrp_mdt_core:server:getIncidentMeta` | — |
| `mrp_mdt_core:server:listIncidents` | `filters` |
| `mrp_mdt_core:server:getIncident` | `id` or `public_number` |
| `mrp_mdt_core:server:getIncidentTimeline` | `ref`, `limit` |
| `mrp_mdt_core:server:getIncidentsByCitizen` | `citizenid`, `opts` |
| `mrp_mdt_core:server:getIncidentsByPlate` | `plate`, `opts` |
| `mrp_mdt_core:server:getAllowedTransitions` | `ref` |

## Statuses

Happy path: `created → assigned → accepted → enroute → arrived → in_progress → completed → archived`

Exceptions: `cancelled`, `expired`, `duplicate`, `merged`, `rejected`, `timeout`

`TransitionIncidentTo` / `SyncDispatchCallStatus` use `MdtIncidentStates.PathTo` to walk the shortest **legal** route when a caller skips steps. Intermediate hops are restricted to the happy path, so a walk can never pass through `cancelled` / `rejected` on the way somewhere else. Each hop is a separate `status_changed` timeline row (`reason` suffixed `:auto_step`); one audit row is written per requested transition.

### Dispatch mapping

| `mrp_dispatch` action | Call status | Incident status |
|-----------------------|-------------|-----------------|
| *(created)* | `pending` | `created` |
| *(crew assigned)* | — | `assigned` |
| `accept` | `accepted` | `accepted` |
| `enroute` | `enroute` | `enroute` |
| `arrived` | `arrived` | `arrived` |
| `in_progress` | `in_progress` | `in_progress` |
| `done` | `done` | `completed` |
| `panic_off` | `done` | `completed` |
| `reject` | `rejected` | `rejected` (→ `cancelled` if already on scene) |
| `cancel` | `cancelled` | `cancelled` |
| `expire` | `expired` | `expired` |
| `timeout` (pruned while open) | — | `timeout` |
| `archive` (pruned when closed) | — | `archived` |

`MdtIncidentStates.ACTION_FALLBACK` handles the one case where the mapped status is
unreachable: a unit rejecting a call it already arrived at is recorded as `cancelled`,
so the incident still closes instead of hanging open until pruned.

Backwards moves are deliberately **not** walked — pressing "Vykstu" after "Atvykau"
leaves the incident at `arrived`, keeping the furthest progress actually reached.
Dispatch treats the resulting `transition_denied` as expected and stays quiet.

See `shared/incident_states.lua`.

## Permissions

Canonical names in `shared/permissions.lua`. Grade floors in `config.lua` mirror `mrp_ltpd` `Config.Permissions` (`legacyKey` + `mrp_bossmenu` override for police).

**qb-core job IDs:** EMS — `ambulance`; mechanics — `mechanic`, `mechanic2`, `mechanic3`, `beeker`, `bennys` (any `Shared.Jobs` row with `type = mechanic` matches RBAC rules keyed on `mechanic`). Mapped in `Config.JobServiceMap` for incident read scope and dispatch auto-attach.

Phase 2 migrates high-value PD callbacks to a **dual check** — `mrp_mdt_core` named permission **OR** the legacy grade key — so a missing core rule can never lock live PD out.

Phase 3 gates the PD case surface the same way: `INCIDENT_VIEW` (open the „Bylos" tab),
`MDT_REPORT` (case data, report, parties, vehicles, refs), `INCIDENT_TRANSITION` (status),
`MDT_FINE`, `MDT_ARREST`, `MDT_SEARCH` (nearby-player picker), `MDT_EVIDENCE` (seized items).
Archived cases reject every write.

## Ensure order

```
ensure oxmysql
ensure qb-core
ensure mrp_mdt_core    # before dispatch / ltpd / service_mdt
ensure mrp_dispatch
...
ensure mrp_ltpd
```

## SQL

`sql/mdt_v2.sql` — also auto-applied on resource start via `MySQL.ready`.

- Phase 2: no new tables.
- Phase 3: `mdt_incident_officers`, `mdt_incident_police`, `mdt_incident_reports`,
  `mdt_incident_force`, `mdt_incident_tools`, `mdt_incident_seized`, `mdt_incident_refs`.
- Phase 4: `mdt_incident_medical`, `mdt_incident_medical_meds`, `_actions`, `_equipment`.
- Phase 5: `mdt_incident_mechanic`, `mdt_incident_mechanic_diagnostics`, `_work`, `_parts`.

## Security

- `mrp_ltpd:server:cctvTamper` net event disabled — use `TamperCctv` / `TamperCctvRadius` exports only.
- `mrp_dispatch:server:createServiceCall` requires on-duty membership of that service (or `DISPATCH_CREATE_CALL` via core). External scripts must use `CreateDispatchCall` export.
- `mrp_dispatch:server:updateCallStatus` only accepts whitelisted actions.
- Read APIs are RBAC-gated and service-scoped server-side; client-supplied `service_job` cannot widen scope.
- Audited actions: incident create / transition / assign / party+vehicle link, case update, report save, force log, seized item, ref link, MDT open, person & vehicle search, wanted level, arrest note, fine issue, CCTV open, bodycam open, CCTV tamper, denied dispatch call.
- The nearby-player picker resolves identities **server-side**; the NUI only sends a player id and the server re-checks the distance before attaching anyone.

## Phase 6+

See `docs/mdt-v2-architecture.md` and `docs/mdt-v2-phases-plan.md`.
