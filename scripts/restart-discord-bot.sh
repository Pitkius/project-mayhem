#!/usr/bin/env bash
# Restart Discord bot after deploy (idempotent).
set -euo pipefail

REPO_DIR="${REPO_DIR:-/home/fivem/FIVEMPROJEKTAS}"
BOT_DIR="${REPO_DIR}/discord-system/guardian-bot"
SERVICE_NAME="mrp-discord"

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

RUN_USER="$(detect_run_user)"
RUN_HOME="$(getent passwd "$RUN_USER" | cut -d: -f6)"
if [[ -z "$RUN_HOME" || ! -d "$RUN_HOME" ]]; then
  RUN_HOME="$(dirname "$REPO_DIR")"
fi
ENV_DST="${RUN_HOME}/.config/mrp-discord.env"

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

echo "[discord] npm install (user=$RUN_USER)..."
if [[ "$(id -u)" -eq 0 ]]; then
  if [[ "$RUN_USER" == "root" ]]; then
    bash -lc "cd '$BOT_DIR' && npm install --omit=dev"
  else
    sudo -u "$RUN_USER" bash -lc "cd '$BOT_DIR' && npm install --omit=dev"
  fi
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
