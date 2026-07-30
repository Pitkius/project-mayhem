# MDT V2 — etapų planas (vykdoma be pertraukos)

Specifikacija: Incident-centrinė Operations Management System.  
Phase 1 (architektūra / `mrp_mdt_core`) — **DONE**.  
Phase 2 (dispatch↔incident sync, read-only API) — **DONE**.  
Phase 3 (PD byla + MDT „Bylos" skirtukas) — **DONE**.

| Etapas | Fokusas | Modelis (agent) | Statusas |
|--------|---------|-----------------|----------|
| 1 | Backend architektūra, Engine scaffold, RBAC, audit, P0 security | — | Done |
| 2 | Dispatch↔Incident sync, state machine usage, timeline/audit wire, read-only APIs | Opus high | Done |
| 3 | PD Incident byla (parties, vehicles, fines/arrest/force link, MDT UI) | Opus high | Done |
| 4 | EMS Incident / medical byla | Opus high | Done |
| 5 | Mechanic Incident / repair byla | Opus high | Done |
| 6 | Evidence, Bodycam, CCTV (enable + harden + link to incidents) | Opus high | Done |
| 7 | Analytics, event-driven push, search/cache/indexes | Sonnet / Opus | Done |

## Phase 2 rezultatas

- `mrp_dispatch` iškvietimo statusų pokyčiai → `SyncDispatchCallStatus` (accept / enroute / arrived / done / reject / panic_off + prune → timeout / archived).
- Praleisti žingsniai automatiškai pereinami legaliu maršrutu (`MdtIncidentStates.PathTo`), kiekvienas žingsnis — atskiras timeline įrašas.
- Ekipažas iš dispatch → `AssignIncidentCrew` (auto `created → assigned`).
- Read-only API: `ListIncidents`, `GetIncidentBundle`, `GetIncidentTimeline`, `ListIncidentsByCitizen`, `ListIncidentsByPlate` + RBAC callbackai būsimam NUI.
- `AttachParty` / `AttachVehicle` (+ detach) — parties/vehicles lentelės rašomos jau dabar.
- Audit išplėstas: MDT atidarymas, asmens/transporto paieška, paieškomumas, arešto įrašas, CCTV/bodycam atidarymas.
- RBAC dual-check (core permission **ARBA** legacy grade key) high-value PD callbackuose.
- **Nepakeista:** PD/EMS/Mech MDT UI, evidence locker, 350 ms polling.

## Phase 3 rezultatas (PD byla)

**Schema** (`mrp_mdt_core/sql/mdt_v2.sql`, tos pačios lentelės kuriamos ir `server/main.lua`
starte) — atskiri normalizuoti stulpeliai, ne vienas JSON:

- `mdt_incident_officers` — pareigūnai byloje (citizenid, šaukinys, ženklas, rolė, `service`);
  bendra ir EMS/mechanikams (4–5 etapai).
- `mdt_incident_police` — bylos priedas: kvalifikacija (kodas + tekstas), sprendimas, bylos
  vadovas, nuovada, `arrest_made` / `force_used` / `weapon_involved`, `fine_total`.
- `mdt_incident_reports` — raportas (antraštė, tekstas, `meta`, autorius, revizija); unikalus
  per (byla, `kind`), todėl 4 etapas gali dėti medicininę kortelę.
- `mdt_incident_force` / `mdt_incident_tools` / `mdt_incident_seized` — jėgos naudojimas,
  naudotos priemonės, paimti objektai.
- `mdt_incident_refs` — tipuotos nuorodos į kitų resursų įrašus: `fine`, `arrest`,
  `fingerprint`, `wanted`, `interrogation` + stubai `bodycam`, `cctv`, `photo`, `evidence`,
  `warrant`.
- Phase 2 incidentas + parties/vehicles nepakeisti.

**Serveris**

- `mrp_mdt_core/server/modules/police.lua` — bylos duomenys, raporto upsert, force/tools/seized,
  nuorodos, `GetPoliceCaseBundle`, `ListPoliceCases`, `ResolveForOfficer` (statusą keičia tik
  Incident Engine).
- `mrp_mdt_core/shared/police_case.lua` — bendras žodynas (sprendimai, jėgos laiptai,
  sužalojimai, priemonės, kategorijos, rolės), kurį naudoja ir serveris, ir NUI.
- `mrp_ltpd/server/mdt_incidents.lua` — PD paviršius: NUI callbackai + `LtpdMdtIncidents.On*`.
  Savo lentelių neturi, viską daro per core exportus.
- Dispatch iškvietimo priėmimas / vykimas / atvykimas / uždarymas įrašo pareigūną į
  `mdt_incident_officers` — todėl vėlesnė bauda ar areštas žino „kurią bylą dirbu".

**Prijungti PD veiksmai:** bauda → `fine` nuoroda + suma + įtariamasis; arešto įrašas →
`suspect` dalyvis + `arrest` nuoroda + `arrest_made`; atspaudai → `fingerprint` nuoroda;
paieškomumas → laiko juostos įrašas. Baudai ir areštui dabar yra **vienas rašymo kelias**
(`IssuePoliceFine` / `AddPoliceArrestRecord`), naudojamas ir senų skirtukų, ir bylos UI.

**UI:** naujas „Bylos" skirtukas (`html/mdt/index.html` `#panel-incidents`, `incidents.js`,
`.inc-*` stiliai) — sąrašas su paieška / „tik atviros" / „tik mano", naujos bylos forma ir
detalus vaizdas (statusas, kvalifikacija, pareigūnai, dalyviai su šalia esančių asmenų
parinkimu, TP, jėga, priemonės, paimti objektai, nuorodos, raportas, laiko juosta).
Bylos numeris — iš core (`INC-YYYYMMDD-####`). Seni skirtukai nepakeisti.

**RBAC:** `INCIDENT_VIEW` (skirtukas), `MDT_REPORT` (bylos duomenys, raportas, dalyviai, TP,
nuorodos), `INCIDENT_TRANSITION` (statusas), `MDT_FINE`, `MDT_ARREST`, `MDT_SEARCH` (šalia
esantys), `MDT_EVIDENCE` (paimti objektai) — visi dual-check; archyvuota byla tik skaitymui.

- **Nepakeista:** Mechanikų bylos (5), pilna įkalčių saugykla (6), polling (7).

## Phase 4 rezultatas (EMS medicininė byla)

**Schema** (`mdt_incident_medical` + `mdt_incident_medical_meds` / `_actions` / `_equipment`):
- EMS bylos priedas: skundas (kodas + tekstas), sprendimas, triažas, įstaiga, vitaliniai,
  `transported`, `invoice_total` (iš `invoice` refs).
- Vaistai, procedūros, įranga — atskiros append-only lentelės su normalizuotais stulpeliais.
- Pakartotinai naudojama: `mdt_incident_officers` (medikai, `service='ems'`),
  `mdt_incident_reports` (`kind='medical'`), `mdt_incident_refs` (`ref_type='invoice'` →
  `fivempro_service_invoices`).

**Serveris**

- `mrp_mdt_core/server/modules/medical.lua` — bylos duomenys, kortelė, vaistai/procedūros/įranga,
  nuorodos, `GetMedicalCaseBundle`, `ListMedicalCases`, `ResolveForMedic`.
- `mrp_mdt_core/shared/medical_case.lua` — bendras žodynas (triažas, skundai, procedūros, vaistų
  route, įranga, rolės).
- `mrp_service_mdt/server/mdt_incidents.lua` — EMS paviršius: NUI callbackai +
  `ServiceMdtIncidents.OnInvoiceIssued`. Mechanikams neaktyvu.
- Dispatch engagement (accept / enroute / …) registruoja mediką per esamą
  `Config.AutoAttachDispatchUnits` → `mdt_incident_officers`.

**Prijungti EMS veiksmai:** sąskaita (`IssueServiceInvoice`) → `invoice` ref + suma →
`invoice_total` + pacientas kaip `patient` + timeline; vienas rašymo kelias MDT „Sąskaitos"
skirtukui ir bylai.

**UI:** EMS Service MDT „Bylos" skirtukas (`html/incidents.js`, `.inc-*` stiliai) — sąrašas,
nauja byla, detalus vaizdas (statusas, triažas, vitaliniai, medikai, pacientai, vaistai,
procedūros, įranga, sąskaitos, medicininė kortelė, laiko juosta).

**RBAC:** `EMS_INCIDENT_VIEW`, `EMS_MDT_REPORT`, `EMS_INCIDENT_CREATE`, `EMS_INCIDENT_TRANSITION`,
`EMS_MDT_INVOICE` + `INCIDENT_VIEW` fallback; archyvuota byla tik skaitymui.

**Darbo ID:** `ambulance` (qb-core `type = ems`).

- **Nepakeista:** evidence (6), polling (7).

## Phase 5 rezultatas (Mechanic remonto byla)

**Schema** (`mdt_incident_mechanic` + `mdt_incident_mechanic_diagnostics` / `_work` / `_parts`):
- Mechanikų bylos priedas: gedimas (kodas + tekstas), sprendimas, dirbtuvės, `tow_requested` /
  `tow_completed`, `duration_minutes`, `invoice_total`, `diagnostics_summary`, `recommendations`.
- Diagnostika, atlikti darbai, pakeistos dalys — atskiros append-only lentelės su normalizuotais stulpeliais.
- Pakartotinai naudojama: `mdt_incident_officers` (mechanikai, `service='mechanic'`),
  `mdt_incident_reports` (`kind='mechanic'`), `mdt_incident_refs` (`invoice`, `tow` stub),
  `mdt_incident_parties` (klientas), `mdt_incident_vehicles` (remontuojamas TP).

**Serveris**

- `mrp_mdt_core/server/modules/mechanic.lua` — bylos duomenys, kortelė, diagnostika/darbai/dalys,
  nuorodos, `GetMechanicCaseBundle`, `ListMechanicCases`, `ResolveForMechanic`.
- `mrp_mdt_core/shared/mechanic_case.lua` — bendras žodynas (gedimai, diagnostika, darbai, dalys, rolės).
- `mrp_service_mdt/server/mdt_incidents.lua` — EMS + mechanic paviršius + `OnInvoiceIssued` abiem tarnyboms.
- Dispatch engagement registruoja mechaniką per esamą `Config.AutoAttachDispatchUnits`.

**Prijungti mechanic veiksmai:** sąskaita (`IssueServiceInvoice`) → `invoice` ref + suma →
`invoice_total` + klientas kaip `client` + TP (jei nurodytas) + timeline; vienas rašymo kelias
MDT „Sąskaitos" skirtukui ir bylai. Nutempimo stub — `tow` ref per bylų UI.

**UI:** Mechanikų Service MDT „Bylos" skirtukas (`html/mechanic_incidents.js`, `.inc-*` stiliai) —
sąrašas, nauja byla, detalus vaizdas (statusas, gedimas, klientai, TP, diagnostika, darbai, dalys,
sąskaitos/nutempimas, remonto kortelė, laiko juosta). EMS bylų UI nepakeistas.

**RBAC:** `MECH_INCIDENT_VIEW`, `MECH_MDT_REPORT`, `MECH_INCIDENT_CREATE`, `MECH_INCIDENT_TRANSITION`,
`MECH_MDT_INVOICE` + `INCIDENT_VIEW` fallback; archyvuota byla tik skaitymui.

**Darbo ID (qb-core):** EMS — `ambulance`; mechanikai — `mechanic`, `mechanic2`, `mechanic3`, `beeker`, `bennys`
(visi `Shared.Jobs` su `type = mechanic`). RBAC ir dispatch naudoja tą patį sąrašą per `JobServiceMap` /
`Config.Services[].jobs`.

- **Nepakeista:** polling (7).

## Phase 6 rezultatas (Evidence, Bodycam, CCTV)

**Schema** (`mdt_evidence_items`):
- Įkalčių saugykla: `item_name`, `quantity`, `description`, `location`, `locker_slot`, `category`,
  `logged_by_*`, `sealed` / `sealed_by_*` / `sealed_at` — grandinės apsaugos laukai.
- Nuorodos per `mdt_incident_refs` (`ref_type='evidence'`, `ref_table='mdt_evidence_items'`).
- CCTV / bodycam peržiūros taip pat prisegamos kaip `cctv` / `bodycam` refs (auto arba su `incidentId`).

**Serveris**

- `mrp_mdt_core/server/modules/evidence.lua` — `AddEvidenceItem`, `SealEvidenceItem`, `ListEvidenceItems`,
  `GetEvidenceVocabulary`; timeline `evidence_logged` / `evidence_sealed` + audit.
- `mrp_ltpd/server/surveillance.lua` — `MdtV2EnableSurveillance` + `IsMaintenance()` vartai; RBAC
  `MDT_CCTV` / `MDT_BODYCAM` list + watch; audit `cctv.open` / `bodycam.open`; auto-ref ant aktyvios bylos.
- `cctvTamper` lieka export-only (P0).

**UI:** PD „Bylos" — „Įkalčių saugykla" sekcija (pridėti / sąrašas / užplombuoti), refs grupuojami
(CCTV/bodycam/įkalčiai), mygtukai atidaryti CCTV/bodycam skirtukus su bylos kontekstu.

**Konfigūracija:** `Config.Surveillance.MdtV2EnableSurveillance = true` — įjungia MDT stebėjimą net kai
`MaintenanceMode = true` (RP „finansavimas“); abu `false` — pilnas outage overlay.

- **Phase 7:** analytics, push-tuned refresh, search cache/indexes — **DONE** (žr. below).

## Phase 7 rezultatas (Analytics, performance, optimization)

**Telemetrija** (`mdt_telemetry_events`, `server/modules/analytics.lua`):
- Įvykiai: `mdt_open` / `mdt_close` (trukmė ms), `tab_switch`, `dispatch_accept` / `dispatch_reject`,
  `fine_issued`, `report_created`, `incident_created` (EMS/mechanic).
- Įrašai kaupiami eilėje ir flush kas ~5 s (rate-limit 100 ms / actor / event).
- Eksportai: `RecordTelemetry`, `BeginMdtSession`, `EndMdtSession`, `GetMdtAnalyticsSummary(from,to)`.
- Admin callback: `mrp_mdt_core:server:analyticsSummary` (MDT_ADMIN arba admin ACE).

**Našumas — dispatch / MDT push**:
- `mrp_dispatch` `BlipRefreshMs`: 300 → **1500** (server push).
- NUI fallback poll: 350 ms → **2500 ms**; kai gaunamas `dispatchLive`, poll praleidžiamas ~3.5 s
  (arba intervalas 8000 ms) — žr. `Config.MdtPerformance` (`mrp_ltpd`, `mrp_service_mdt`).
- Kliento pozicija: 150 ms → **750 ms** + siuntimas tik judėjus ≥2.5 m.

**Paieška**:
- Trumpas cache (20 s, iki 128 raktų) identiškoms PD `searchPerson` užklausoms.
- Batch `IN (...)` wanted / fines / vehicles — ne N+1 per rezultatą.
- Indeksas `mdt_incidents (service_job, status, created_at)`; SQL komentarai `ltpd_fines` / `players`.

**Konfigūracija**: `mrp_mdt_core` `Config.Telemetry`, `Config.Performance`, `Config.MdtRefreshDefaults`;
per-tablet override — `Config.MdtPerformance` LTPD / Service MDT.

- **MDT V2 visi 7 etapai — DONE.** Court/Fire ir kt. neimplementuota ( sąmoningai ).

## Taisyklės

- Vienas etapas baigtas → tik tada kitas.
- Moduliai nepriklausomi; komunikacija per Incident Engine.
- Jokio „quick fix“ / laikino kodo.
- UI tik nuo 3 etapo ten, kur reikia incident workflow.
- Commit/push tik kai user paprašo.
