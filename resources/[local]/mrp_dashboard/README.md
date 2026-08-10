# Mayhem ESC Dashboard

React + TypeScript + Vite NUI. Mayhem violet brand (`#a78bfa`), LT UI.

## Scope (fazė 1)

| Puslapis | Turinys |
|---|---|
| Pagrindinis | Player, valiuta, serveris, naujienos |
| Žemėlapis | Placeholder + filtrai; mygtukas → native GTA map |
| RP Pass | Level / FREE + PREMIUM track |
| Misijos | Daily / Weekly / Monthly |
| Dieninis | Dėžės + playtime/misija |
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
