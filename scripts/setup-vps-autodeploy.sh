#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${1:-https://github.com/Pitkius/project-mayhem.git}"
SERVER_DIR="${2:-/home/fivem/server}"
SERVICE_NAME="${3:-fivem-txadmin}"

echo "[1/4] Preparing server directory: ${SERVER_DIR}"
mkdir -p "${SERVER_DIR}"

if [ ! -d "${SERVER_DIR}/.git" ]; then
  echo "[2/4] Cloning repository..."
  rm -rf "${SERVER_DIR:?}"/*
  git clone "${REPO_URL}" "${SERVER_DIR}"
else
  echo "[2/4] Repository already exists, updating remote and pulling..."
  git -C "${SERVER_DIR}" remote set-url origin "${REPO_URL}"
  git -C "${SERVER_DIR}" fetch origin
  git -C "${SERVER_DIR}" checkout main
fi

echo "[3/4] Pulling latest main branch..."
git -C "${SERVER_DIR}" pull --ff-only origin main

echo "[4/4] Restarting service: ${SERVICE_NAME}"
systemctl restart "${SERVICE_NAME}"
systemctl is-active --quiet "${SERVICE_NAME}"

echo "Auto-deploy bootstrap complete."
