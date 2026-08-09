# Mayhem ESC Dashboard

React + TypeScript + Vite NUI. Mock data frontend; Lua bridge stubs for later backend.

## Browser preview

```bat
cd resources\[local]\mrp_dashboard\web
..\..\..\..\.tools\node-v22.18.0-win-x64\npm.cmd run dev
```

Atidaro http://localhost:5174 — UI matosi be FiveM.

## Build (po UI pakeitimų)

```bat
..\..\..\..\.tools\node-v22.18.0-win-x64\npm.cmd run build
```

Kopijuoja single-file `html/index.html` FiveM resursui.

## In-game

- `ensure mrp_dashboard` (jau `cfg/30_custom.cfg`)
- **ESC** arba **F10** arba `/dashboard`
