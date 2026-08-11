# Mayhem ESC Dashboard

React + TypeScript + Vite NUI. Mayhem violet brand (`#a78bfa`), LT UI.

## Scope (fazė 1)

| Puslapis | Turinys |
|---|---|
| Pagrindinis | Player, valiuta, serveris, naujienos |
| Žemėlapis | Placeholder + filtrai; mygtukas → native GTA map |
| RP Pass | Level / FREE + PREMIUM track |
| Misijos | Daily / Weekly / Monthly |
| Dieninis | Dėžės + playtime + misijų skaičius |

## Crate unlock (Dienos / Savaitės dėžė)

Tunable in `shared/config.lua` → `Config.Crates`:

| Gate | Default |
|---|---|
| Daily playtime | 120 min (2h) |
| Daily missions | 3 completed today |
| Weekly playtime | 600 min (10h) |
| Weekly missions | 12 completed this week |

**There is no `mrp_missions` resource.** Mission completions are counted via:

- `mrp_trucking` — delivery complete
- `mrp_gangs` — gang mission complete (eligible participants)
- `mrp_jobs` — job session end with reason `complete`
- Export: `exports['mrp_dashboard']:RecordMissionComplete(src, sourceTag)`

Server enforces both playtime and mission count on claim.
| Premium | Importai · Dėžės · VIP |
| Apdovanojimai / Renginiai / Reitingas / Profilis | Inbox, events, top 10, stats |
| Nustatymai | HUD / pranešimai / garsas / kalba (NUI stub) |

ESC blokuoja native pause; Map/Settings native lieka kaip optional mygtukai puslapiuose.

## Browser preview

```bat
cd resources\[local]\mrp_dashboard\web
npm run dev
```

## Build

```bat
npm run build
```

Kopijuoja single-file `html/index.html`.

## In-game

- `ensure mrp_dashboard` (`cfg/30_custom.cfg`)
- **ESC** / **F10** / `/dashboard`
