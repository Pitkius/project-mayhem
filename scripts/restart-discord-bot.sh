#!/usr/bin/env bash
# Restart Discord bot after deploy (idempotent).
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/fivem/FIVEMPROJEKTAS}"
BOT_DIR="${REPO_DIR}/discord-system/guardian-bot"
SERVICE_NAME="mrp-discord"
ENV_DST="/home/fivem/.config/mrp-discord.env"
RUN_USER="${RUN_USER:-fivem}"

if [[ ! -d "$BOT_DIR" ]]; then
  echo "[discord] skip — nėra $BOT_DIR"
  exit 0
fi

if [[ ! -f "/etc/systemd/system/${SERVICE_NAME}.service" ]] && ! systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "[discord] skip — servisas neįdiegtas (paleisk setup-discord-bot.sh)"
  exit 0
fi

if [[ ! -f "$ENV_DST" ]]; then
  echo "[discord] WARNING: nėra $ENV_DST — botas gali nepasileisti"
fi

echo "[discord] npm install..."
if [[ "$(id -u)" -eq 0 ]]; then
  sudo -u "$RUN_USER" bash -lc "cd '$BOT_DIR' && npm install --omit=dev"
  systemctl restart "$SERVICE_NAME"
else
  bash -lc "cd '$BOT_DIR' && npm install --omit=dev"
  sudo -n systemctl restart "$SERVICE_NAME"
fi

sleep 2
if systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "[discord] $SERVICE_NAME active"
else
  echo "[discord] WARNING: $SERVICE_NAME neaktyvus"
  systemctl --no-pager status "$SERVICE_NAME" || true
  journalctl -u "$SERVICE_NAME" -n 30 --no-pager || true
  exit 1
fi
