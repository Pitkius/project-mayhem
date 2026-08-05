#!/usr/bin/env bash
# One-time VPS setup: Discord bot as systemd service (24/7).
# Usage (on VPS as root or with sudo):
#   bash /home/fivem/FIVEMPROJEKTAS/scripts/setup-discord-bot.sh
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/fivem/FIVEMPROJEKTAS}"
BOT_DIR="${REPO_DIR}/discord-system/guardian-bot"
SERVICE_NAME="mrp-discord"
SERVICE_SRC="${REPO_DIR}/scripts/mrp-discord.service"
SERVICE_DST="/etc/systemd/system/${SERVICE_NAME}.service"

detect_run_user() {
  if [[ -n "${RUN_USER:-}" ]] && id -u "$RUN_USER" >/dev/null 2>&1; then
    echo "$RUN_USER"
    return
  fi
  local owner
  owner="$(stat -c '%U' "$REPO_DIR" 2>/dev/null || true)"
  if [[ -n "$owner" ]] && id -u "$owner" >/dev/null 2>&1; then
    echo "$owner"
    return
  fi
  for cand in fivem ubuntu debian root; do
    if id -u "$cand" >/dev/null 2>&1; then
      echo "$cand"
      return
    fi
  done
  echo "root"
}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Paleisk su sudo: sudo bash $0"
  exit 1
fi

if [[ ! -d "$BOT_DIR" ]]; then
  echo "Nerastas bot katalogas: $BOT_DIR"
  exit 1
fi

RUN_USER="$(detect_run_user)"
RUN_GROUP="$(id -gn "$RUN_USER")"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
if [[ -z "$RUN_HOME" || ! -d "$RUN_HOME" ]]; then
  RUN_HOME="$(dirname "$REPO_DIR")"
fi
ENV_DST="${RUN_HOME}/.config/mrp-discord.env"

echo "[setup] RUN_USER=$RUN_USER group=$RUN_GROUP home=$RUN_HOME"

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js nerastas. Diegiu Node 20..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

NODE_BIN="$(command -v node)"
NODE_MAJOR="$("$NODE_BIN" -p "process.versions.node.split('.')[0]")"
if [[ "$NODE_MAJOR" -lt 18 ]]; then
  echo "Reikia Node.js >= 18 (dabar: $("$NODE_BIN" -v))"
  exit 1
fi
echo "[setup] Node: $("$NODE_BIN" -v) ($NODE_BIN)"

mkdir -p "${RUN_HOME}/.config"
chown -R "$RUN_USER:$RUN_GROUP" "${RUN_HOME}/.config"

if [[ ! -f "$ENV_DST" ]]; then
  if [[ -f "$BOT_DIR/.env" ]]; then
    cp "$BOT_DIR/.env" "$ENV_DST"
    echo "[setup] Nukopijuotas $BOT_DIR/.env -> $ENV_DST"
  elif [[ -f "$BOT_DIR/.env.example" ]]; then
    cp "$BOT_DIR/.env.example" "$ENV_DST"
    echo "[setup] Sukurta $ENV_DST iš .env.example — ĮRAŠYK DISCORD_TOKEN ir DISCORD_CLIENT_ID!"
    echo "  nano $ENV_DST"
    exit 1
  else
    echo "Nerastas .env. Sukurk: $ENV_DST"
    exit 1
  fi
fi

if ! grep -qE '^DISCORD_TOKEN=.+' "$ENV_DST" || grep -q 'your_discord_bot_token' "$ENV_DST"; then
  echo "Užpildyk tikrą DISCORD_TOKEN faile: $ENV_DST"
  exit 1
fi

chown "$RUN_USER:$RUN_GROUP" "$ENV_DST"
chmod 600 "$ENV_DST"

echo "[setup] npm install..."
if [[ "$RUN_USER" == "root" ]]; then
  bash -lc "cd '$BOT_DIR' && npm install --omit=dev"
else
  sudo -u "$RUN_USER" bash -lc "cd '$BOT_DIR' && npm install --omit=dev"
fi

TMP_UNIT="$(mktemp)"
# Jei katalogo owneris nėra validus passwd user — root
EFFECTIVE_USER="$RUN_USER"
EFFECTIVE_GROUP="$RUN_GROUP"
if ! id -u "$RUN_USER" >/dev/null 2>&1; then
  echo "[setup] WARNING: user '$RUN_USER' neegzistuoja — servisas veiks kaip root"
  EFFECTIVE_USER=root
  EFFECTIVE_GROUP=root
fi

sed \
  -e "s|^User=.*|User=${EFFECTIVE_USER}|" \
  -e "s|^Group=.*|Group=${EFFECTIVE_GROUP}|" \
  -e "s|^WorkingDirectory=.*|WorkingDirectory=${BOT_DIR}|" \
  -e "s|^Environment=MRP_DISCORD_ENV_FILE=.*|Environment=MRP_DISCORD_ENV_FILE=${ENV_DST}|" \
  -e "s|^ExecStart=.*|ExecStart=/bin/bash ${BOT_DIR}/scripts/run-bot.sh|" \
  -e "s|^Documentation=.*|Documentation=file://${REPO_DIR}/discord-system/README.md|" \
  "$SERVICE_SRC" > "$TMP_UNIT"
chmod +x "${BOT_DIR}/scripts/run-bot.sh" || true
install -m 644 "$TMP_UNIT" "$SERVICE_DST"
rm -f "$TMP_UNIT"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"
sleep 2
systemctl --no-pager --full status "$SERVICE_NAME" || true

if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "[setup] OK — $SERVICE_NAME veikia 24/7 (Restart=always)."
  echo "Logai: journalctl -u $SERVICE_NAME -f"
else
  echo "[setup] FAIL — žiūrėk: journalctl -u $SERVICE_NAME -n 50 --no-pager"
  exit 1
fi
