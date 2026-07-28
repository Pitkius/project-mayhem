#!/usr/bin/env bash
# Atnaujina FXServer artifact (Linux/proot) — reikalinga game build palaikymui (pvz. 3717).
# NELIEČIA: resources/, cfg/, cache/, server.cfg, txData/
set -euo pipefail

SERVER_DIR="${1:-/home/fivem/server}"
ARTIFACTS_BASE="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"

echo "[artifacts] server dir: ${SERVER_DIR}"
test -d "${SERVER_DIR}"

wait_for_fx_stop() {
  local i
  for i in $(seq 1 30); do
    if ! pgrep -f "FXServer" >/dev/null 2>&1; then
      return 0
    fi
    echo "[artifacts] Laukiama kol FXServer sustos (${i}/30)..."
    sleep 2
  done
  echo "[artifacts] FXServer vis dar veikia po 60s — bandome tęsti."
  return 0
}

wait_for_fx_stop

html="$(curl -fsSL "${ARTIFACTS_BASE}")"
build_folder="$(printf '%s' "${html}" | grep -oE 'panel-block is-active[^>]*href="\./([0-9]+-[a-f0-9]+)/fx\.tar\.xz"' | head -1 | grep -oE '[0-9]+-[a-f0-9]+' || true)"
if [ -z "${build_folder}" ]; then
  build_folder="$(printf '%s' "${html}" | grep -oE 'href="\./([0-9]+-[a-f0-9]+)/fx\.tar\.xz"' | head -1 | grep -oE '[0-9]+-[a-f0-9]+' || true)"
fi
if [ -z "${build_folder}" ]; then
  echo "[artifacts] Nepavyko rasti artifact nuorodos."
  exit 1
fi

build_num="${build_folder%%-*}"
download_url="${ARTIFACTS_BASE}${build_folder}/fx.tar.xz"
tmp_dir="$(mktemp -d)"
archive="${tmp_dir}/fx.tar.xz"
extract_dir="${tmp_dir}/extracted"

echo "[artifacts] Atsisiunčiamas build ${build_num}..."
curl -fsSL "${download_url}" -o "${archive}"
mkdir -p "${extract_dir}"
tar -xf "${archive}" -C "${extract_dir}"

artifact_root="${extract_dir}"
if [ -f "${extract_dir}/alpine/opt/cfx-server/FXServer" ]; then
  artifact_root="${extract_dir}"
elif find "${extract_dir}" -name FXServer -type f 2>/dev/null | head -1 | grep -q .; then
  artifact_root="${extract_dir}"
fi

exclude_dirs=(resources cfg cache crashes txData .git node_modules docs scripts tools)
exclude_files=(server.cfg .gitignore README.md)

echo "[artifacts] Kopijuojami binary į ${SERVER_DIR}..."
shopt -s dotglob
for entry in "${artifact_root}"/*; do
  name="$(basename "${entry}")"
  skip=0
  for d in "${exclude_dirs[@]}"; do
    if [ "${name}" = "${d}" ]; then skip=1; break; fi
  done
  for f in "${exclude_files[@]}"; do
    if [ "${name}" = "${f}" ]; then skip=1; break; fi
  done
  [ "${skip}" -eq 1 ] && continue

  if [ -d "${entry}" ]; then
    echo "  dir: ${name}"
    rsync -a --delete "${entry}/" "${SERVER_DIR}/${name}/"
  else
    echo "  file: ${name}"
    cp -f "${entry}" "${SERVER_DIR}/${name}"
  fi
done
shopt -u dotglob

rm -rf "${tmp_dir}"
echo "[artifacts] Atnaujinta į build ${build_num}."
