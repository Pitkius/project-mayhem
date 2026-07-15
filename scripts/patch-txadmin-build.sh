#!/usr/bin/env bash
# Įdeda sv_enforceGameBuild 3788 į txAdmin server.cfg failus (jei dar nėra).
set -euo pipefail

BUILD_LINE='sv_enforceGameBuild 3788'
ROOT="${1:-/home/fivem}"

find "$ROOT" -path '*/txData/*/server.cfg' -type f 2>/dev/null | while read -r cfg; do
  if grep -q 'sv_enforceGameBuild' "$cfg"; then
    if grep -q 'sv_enforceGameBuild 3788' "$cfg"; then
      echo "[txadmin-build] OK: $cfg"
    else
      echo "[txadmin-build] Keičiamas senas build -> 3788: $cfg"
      sed -i 's/^sv_enforceGameBuild .*/sv_enforceGameBuild 3788/' "$cfg"
    fi
  else
    echo "[txadmin-build] Pridedama build eilutė: $cfg"
    printf '\n%s\n' "$BUILD_LINE" >> "$cfg"
  fi
done

echo "[txadmin-build] Baigta. txAdmin Additional Arguments turi būti tuščias arba +set sv_enforceGameBuild 3788 (ne senas 3095)."
