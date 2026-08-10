# Repo regression restore (2026-08-10)

## Root cause

Commit `6fdba075` ("Ship pending gangs tablet, jail, PD/ARAS craft…") overwrote / deleted large amounts of finished custom work while shipping unrelated pending assets. Notable losses:

- Custom **radial qb-target** (UI + client)
- **HUD theme** pipeline (`mrp_hud` ui_theme / theme_nui_consumer, `mrp_fonts` theme.js/css)
- **qb-core notify** themed styles
- **mrp_mechanic** workshop / craft / field-repair UI pieces

Some resources (chopshop, burglary, furniture, elevators) were intentionally left out of this checkout (`cfg/30_custom.cfg` comments) and were **not** auto-restored here.

## Restored in this fix

From pre-wipe tree `6fdba075^`:

- `resources/[qb]/qb-target/**`
- `resources/[local]/mrp_hud/client/ui_theme.lua`
- `resources/[local]/mrp_hud/client/theme_nui_consumer.lua`
- `resources/[local]/mrp_fonts/html/theme.js` + `theme.css`
- `resources/[qb]/qb-core/html/js/notify.js` + `css/notify.css`
- Mechanic workshop/craft/field/material + html/web dist

fxmanifests re-wired for `mrp_hud`, `mrp_fonts`, `mrp_mechanic`.
