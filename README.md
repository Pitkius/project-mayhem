# FiveM QBCore Project (Local Start)

Minimalus startinis projektas FiveM serveriui su QBCore kryptimi ir `Lua` resursais.

## 1) Ko reikia lokaliai

- Įdiegto `FXServer` (txAdmin / artifacts)
- Atsisiųsto `cfx-server-data` (arba savo server-data struktūros)
- Įdiegtos duomenų bazės (`MariaDB` arba `MySQL`)

## 2) Projekto struktūra

- `server.cfg` - pagrindinis serverio config
- `resources/[local]/fivempro_basics/` - tavo pirmas custom Lua resource

## 3) Ką pridėti pirmam test startui

Kadangi QBCore naudoja išorinius resursus, pridėk į `resources` bent:

- `oxmysql`
- `qb-core`
- `qb-target`
- `qb-menu`
- `qb-input`
- `qb-inventory`
- `fivempro_charcreator` + `fivempro_spawnfix` (personažų kūrimas / prisijungimas)
- `qb-apartments` (nebūtina)

## 4) Paleidimas

1. Paleisk DB
2. `server.cfg` susitvarkyk:
   - `sv_licenseKey`
   - `endpoint_add_tcp` / `endpoint_add_udp` (jei reikia)
   - DB jungtį
3. Paleisk serverį per txAdmin arba `FXServer.exe +exec server.cfg`

### Artifacts / txAdmin atnaujinimas (Windows)

Jei matai „artifact End of Support“ arba seną txAdmin versiją:

1. Sustabdyk serverį txAdmin panelėje
2. Paleisk: `powershell -ExecutionPolicy Bypass -File scripts/update-fivem-artifacts.ps1`
3. Paleisk serverį iš naujo

Skriptas atnaujina tik `FXServer.exe` + `citizen/` (neliečia `resources/`, `cfg/`).

## 5) Testas

Resource `fivempro_basics` automatiškai:
- užsikrovus serveriui išspausdina log žinutę
- žaidėjui prisijungus siunčia chat welcome žinutę

Resource `fivempro_hud` rodo:
- gyvybes juostą
- maisto ir vandens juostas (QBCore metadata)
- šarvų juostą tik tada, kai armor > 0

