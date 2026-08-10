# mrpd21 — DISABLED (client crash)

`mrpd21.yft` / `mrpd21_hi.yft` are binary-corrupted (UTF-8 `EF BF BD` after RSC7 header).
Loading them crashes clients on build 3751 (`GTA5_b3751.exe+1695E12`, hash `tennis-venus-william`).

Archived out of live `data/` + `stream/` so FiveM does not register/stream the model.

## Re-enable

1. Restore **clean** `mrpd21.yft` + `mrpd21_hi.yft` from original pack backup.
2. Move `data/mrpd21` → `../../data/` and `stream/mrpd21` → `../../stream/`.
3. Re-add to ELS `vcf.lua`, `mrp_ltpd`, `mrp_siren_controller`, `mrp_garages`, dealership `shopEnabled`.
