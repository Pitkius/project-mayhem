# Auto-Deploy Setup (GitHub -> VPS)

This repository already includes GitHub Actions workflow at:

- `.github/workflows/deploy.yml`

It deploys on every push to `main`.
You can also run it manually from GitHub Actions (`workflow_dispatch`).

## One-time VPS bootstrap

Run this on VPS:

```bash
bash /home/fivem/server/scripts/setup-vps-autodeploy.sh
```

If the script file is not present yet, run from cloned repo root:

```bash
bash scripts/setup-vps-autodeploy.sh
```

## Required GitHub Secrets

Add these in repo settings (`Settings -> Secrets and variables -> Actions`):

- `VPS_HOST`
- `VPS_USER`
- `VPS_SSH_KEY`

Optional:

- use SSH port `22` (already hardcoded in workflow).

## Verification

1. Push a small change to `main`.
2. Open `Actions` tab in GitHub and confirm deploy job is green.
3. On VPS, verify service:

```bash
systemctl status fivem-txadmin --no-pager
```

## Quick Troubleshooting

- `Invalid workflow file` -> YAML syntax issue in `.github/workflows/deploy.yml`.
- `Permission denied (publickey)` -> wrong `VPS_SSH_KEY` or missing public key in `~/.ssh/authorized_keys`.
- `cd /home/fivem/server: No such file or directory` -> run bootstrap script first.
- `git pull --ff-only` fails -> VPS has local edits; commit/stash/reset on VPS clone.
