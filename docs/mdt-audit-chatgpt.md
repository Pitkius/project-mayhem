# Project Mayhem — MDT auditas (ChatGPT brief)

**Data:** 2026-07-30  
**Repo:** Project Mayhem FiveM (custom QBCore)  
**Tikslas:** aptarti architektūrą, spragas, saugumą, UX ir roadmapą.  
**Metodas:** statinė kodo peržiūra (ne playtest). Faktus skirti nuo prielaidų.

---

## 0. MDT V2 Phase 1 (po audito)

**Statusas: scaffolding done** — žr. `docs/mdt-v2-architecture.md` ir `resources/[local]/mrp_mdt_core/`.

| P0 / Phase 1 | Statusas |
|--------------|----------|
| `mrp_mdt_core` Incident Engine + state machine + timeline + audit + RBAC | Done |
| `cctvTamper` net event užrakintas (export-only) | Done |
| `createServiceCall` auth (on-duty service member) | Done |
| Dispatch → soft `CreateIncident` mirror | Done |
| Trucking illegal alert → `CreateDispatchCall` export | Done |
| NUI 350ms poll pašalinimas | **Ne** (Phase 2+) |
| Incident UI tabs PD/EMS/Mech | **Ne** (Phase 3–5) |

---

## 1. Trumpa santrauka

Project Mayhem **neturi** `qb-mdt` / `ps-mdt`. MDT yra custom:

| Sistema | Resursas | Jobs |
|--------|----------|------|
| Policija | `mrp_ltpd` (NUI `html/mdt/`) | `police` |
| EMS + Mechanikai | `mrp_service_mdt` (bendras NUI) | `ambulance`, `mechanic` |
| Bendras backbone | `mrp_dispatch` | police / ems / mechanic |

Tai **Lietuvos ops tabletės** (paieška, baudos, paieškomumas, dispatch GPS, sąskaitos), **ne** pilnas US-stiliaus MDT (nėra BOLO, warrants, evidence chain, incident reports, medicininių kortelių, tow workflow).

---

## 2. Architektūra

```
Telefonas 113/111 ──► mrp_phone ──► mrp_dispatch:CreateDispatchCall
/emscall /mechcall ──► mrp_dispatch:server:createServiceCall
/mdt ──► mrp_ltpd NUI ──► QBCore callbacks (hasPerm) + mrp_dispatch snapshot/push
/emsmdt /mechmdt ──► mrp_service_mdt NUI ──► dispatch + fivempro_service_invoices
mrp_interrogation ──► exports['mrp_ltpd']:SaveInterrogationRecord
Service map tiles ──► nui://mrp_ltpd/html/mdt/asset/gtav_satellite_2048.png
```

### Policija (`mrp_ltpd`)
- Vienas `ui_page`: MDT + craft UI.
- Tabai: Asmuo, Transportas, Bauda, Paieška, Iškvietimai, Ekipažai, Žemėlapis, Areštai, Apklausos, CCTV, Bodycam.
- Auth: `job == police` + `onduty` + `grade >= Config.Permissions[key]`.
- SQL: `ltpd_profiles`, `ltpd_fines`, `ltpd_wanted`, `ltpd_wanted_history`, `ltpd_arrests`, `ltpd_fingerprints`, `ltpd_interrogations`, (+ reception lentelės ne MDT UI).

### EMS / Mechanic (`mrp_service_mdt`)
- Profiliai `Config.Services.ems` / `.mechanic` (skirtingi accent, presetai, crews).
- Tabai: Iškvietimai, Ekipažai (tik EMS), Žemėlapis, Sąskaitos.
- Mechanikams `enableCrews = false`.
- SQL: `fivempro_service_invoices` (nėra paid/status/society stulpelių).

### Dispatch (`mrp_dispatch`)
- In-memory calls/crews/units; live push ~300ms; snapshot callback.
- Audit log: `fivempro_dispatch_logs`.

---

## 3. Funkcijos pagal job

### Policija — kas veikia gerai
- Asmens / transporto paieška (full search nuo grade 3).
- Paieškomumas 0–5 + istorija.
- Baudos online (bank → cash).
- Apklausų istorija iš `mrp_interrogation`.
- Dispatch: priimti / enroute / arrived / done, ekipažai, šaukinys, PANIC.
- Ginklų licencija per `mrp_gunshop` (grade ≥ 3).
- Serveris per-callback tikrina `hasPerm`; oxmysql `?` parametrai.

### Policija — partial / broken / missing
| Funkcija | Statusas | Pastaba |
|----------|----------|---------|
| GPS žemėlapis MDT | Offline (config) | `Config.MdtMapMaintenance.enabled = true` — kodas yra |
| CCTV / bodycam | Offline (config) | `Config.Surveillance.MaintenanceMode = true` |
| Offline baudos | Partial | Įrašas DB be pinigų nuskaičiavimo |
| Areštai | Partial | Free-text JSON `notes`; nėra jail/inventory hook |
| Plate search | Partial | Tik exact plate |
| BOLO / warrants / evidence / reports | Missing | Nėra kode |
| Reception pareiškimai MDT | Missing | Lentelės + notify; nėra tabo |
| `traffic_radar` | Rezervas | Tik permission key |

### EMS — kas veikia
- `/emsmdt`, iškvietimai, ekipažai, live map, invoice presets, telefonas 113.

### EMS — spragos
- Nėra medicininių įrašų / hospital chart.
- UI neturi „Atvykta“ mygtuko (serveris `arrived` palaiko).
- Sąskaitos: pinigai nuimami, **niekur neįskaitomi** (society/boss).
- Offline citizenid → invoice INSERT be charge.
- Nėra tablet item / keybind (tik command).
- `canOpen` serveryje **netikrina duty** (client tikrina).

### Mechanic — kas veikia
- `/mechmdt`, calls, map, invoice presets (remontas/tow/tuning), telefonas 111.

### Mechanic — spragos
- Crews išjungti by design.
- Tow/impound workflow nėra (tik preset label).
- Shop/craft/stash ne MDT — atskiri resursai.
- Tik `jobs = { 'mechanic' }` — `mechanic2`/`mechanic3` neprijungti.
- Ta pati invoice ekonomikos problema (money sink).

---

## 4. Saugumas (severity)

### High / Critical
1. **`mrp_ltpd:server:cctvTamper`** — ~~bet kuris klientas gali išjungti kamerą~~ **FIXED (Phase 1):** net event blocked; use `TamperCctv` / `TamperCctvRadius` exports only (audited).
2. **`mrp_dispatch:server:createServiceCall`** — ~~nėra job/duty check~~ **FIXED (Phase 1):** requires on-duty member of that service; external scripts use `CreateDispatchCall` export.

### Medium
3. Offline fines/invoices kuria įrašus be apmokėjimo.
4. Invoice `RemoveMoney` be `AddMoney` į faction/boss funds.
5. `getMdtSnapshot` off-duty tam pačiam job → `readOnly`, bet leakina live unit pozicijas.
6. Fine/wanted/arrest/fingerprint be proximity (remote abuse by design).
7. Service MDT invoice history / canOpen be griežto duty.

### Low / OK
- SQL injection MDT keliuose: parameterized — OK.
- Service MDT `escapeHtml` — OK.
- PD callback auth modelis — solidus baseline.

---

## 5. Performance

| Problema | Detalė |
|----------|--------|
| NUI poll 350ms | Abu MDT `setInterval(refreshDispatch, 350)` |
| Live push ~300ms | `BlipRefreshMs` visiems on-duty |
| Local pos 150ms | `mdtPlayerPos` kol MDT atidarytas |
| Person search | LIKE + N+1 secondary queries |
| Invoice DB | LIMIT 25/30 — OK |

**Rekomendacija:** palikti live push, pašalinti/atsilaisvinti poll kai push veikia; throttle search.

---

## 6. UX

**PD:** tamsus slate + violet, Mayhem logo, LT tekstai, ~11 tabų vienoje eilėje (ankšta), dock „Kampas“, CRT surveillance overlay (kai maintenance off).

**EMS/Mech:** ta pati kalba, accent `#f87171` / `#fbbf24`, 4 tabai, crews UI su manual ID, sąskaitos per citizenid (nėra nearby picker). Dock CSS yra, JS neįjungia.

---

## 7. Integracijos (faktas)

| Sistema | Integruota? |
|---------|-------------|
| mrp_dispatch | Taip |
| mrp_interrogation | Taip (PD) |
| mrp_gunshop licenses | Taip (PD) |
| mrp_phone 113/111 | Taip |
| mrp_bossmenu / faction funds | Ne su invoice/fine |
| Jail | Ne per areštų MDT |
| Evidence locker | Ne MDT |
| Hospital revive / beds | Ne MDT (ambulance atskirai, revive stub) |
| Mechanic craft/stash | Ne MDT |

---

## 8. Prioritetinis backlog (pasiūlymas)

**P0**
- ~~Užrakinti `cctvTamper` (export-only).~~ Done (Phase 1).
- ~~Autorizuoti `createServiceCall` (job arba tik server-side iš phone).~~ Done (Phase 1).
- Incident Engine scaffold (`mrp_mdt_core`) — Done (Phase 1). See `docs/mdt-v2-architecture.md`.

**P1**
- Sąskaitas/baudas kredituoti į society / `mrp_faction_funds`.
- Offline billing: queue arba fail (ne free INSERT).
- Pašalinti redundant 350ms poll.

**P2**
- Po QA įjungti PD map + CCTV/bodycam (kodas jau yra).
- Service MDT „Atvykta“ mygtukas.
- `mechanic2/3` jei live naudojami.

**P3 (produkto sprendimai)**
- Reception tab PD MDT.
- Medicininiai įrašai / tow workflow.
- BOLO, warrants, evidence, incident reports (didelis scope).

---

## 9. Klausimai diskusijai su ChatGPT

1. Ar Mayhem nori likti „ops tablet“ lygyje, ar eiti į full case-management MDT?
2. Kaip turėtų veikti ekonomika: invoice → job account vs player tip vs state fee?
3. Ar CCTV tamper turi būti tik robbery resource export, ar leisti criminalų items?
4. Ar PD GPS map maintenance — RP (meras/finansavimas) ar tik tech debt?
5. Ar mechanic multi-job (`mechanic2/3`) realiai naudojami serveryje?
6. Ar areštai turėtų kviesti jail resource, ar likti RP notes?
7. Minimalus EMS „medical record“ MVP: kas privaloma vs nice-to-have?

---

## 10. Svarbūs failai

```
resources/[local]/mrp_mdt_core/     — MDT V2 Incident Engine (Phase 1)
resources/[local]/mrp_ltpd/          — PD MDT
resources/[local]/mrp_service_mdt/  — EMS/Mech MDT
resources/[local]/mrp_dispatch/     — shared dispatch
resources/[local]/mrp_interrogation/
resources/[local]/mrp_phone/        — 113/111
resources/[local]/mrp_ambulance/
docs/mdt-v2-architecture.md          — V2 roadmap
```
resources/[local]/mrp_mechanic/
```

**Canvas vizualizacija:** `canvases/mdt-audit.canvas.tsx` (Cursor Canvas šalia chato).

---

*Šis dokumentas skirtas įklijuoti į ChatGPT kaip kontekstą. Prašyk: „Remdamasis šiuo auditu, pasiūlyk 90 dienų MDT roadmapą su effort estimate“ arba „Sukurk threat model createServiceCall + cctvTamper“.*
