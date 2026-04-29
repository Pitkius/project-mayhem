# FIVEMPROJEKTAS Structure

## Main Layout

- `server.cfg` - entrypoint config that loads modular cfg files.
- `cfg/` - split server configuration by purpose.
- `resources/[qb]/` - framework resources (QBCore ecosystem).
- `resources/[cfx-default]/` - default CFX resources.
- `resources/[local]/` - custom project resources (`fivempro_*`).

## Config Files

- `cfg/00_base.cfg` - base server/network/database/admin settings.
- `cfg/10_core.cfg` - core CFX resources.
- `cfg/20_qb.cfg` - QBCore dependency order.
- `cfg/30_custom.cfg` - custom project resources.

## Team Workflow

1. Edit only files under `resources/`, `cfg/`, `server.cfg`, and docs.
2. Keep runtime files (`cache`, binaries, node_modules) out of git.
3. Deploy from git to VPS after merge.
