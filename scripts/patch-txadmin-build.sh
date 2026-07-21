#!/usr/bin/env bash
# Įdeda sv_enforceGameBuild 3717 į txAdmin server.cfg failus (jei dar nėra).
set -euo pipefail

BUILD_LINE='sv_enforceGameBuild 3717'

for cfg in "$@"; do
  [ -f "$cfg" ] || continue
  if grep -q 'sv_enforceGameBuild' "$cfg"; then
    if grep -q 'sv_enforceGameBuild 3717' "$cfg"; then
      echo "[txadmin-build] OK: $cfg jau 3717"
    else
      sed -i 's/^sv_enforceGameBuild .*/sv_enforceGameBuild 3717/' "$cfg"
      echo "[txadmin-build] Atnaujinta į 3717: $cfg"
    fi
  else
    printf '\n%s\n' "$BUILD_LINE" >> "$cfg"
    echo "[txadmin-build] Pridėta 3717: $cfg"
  fi
done

echo "[txadmin-build] Baigta. txAdmin Additional Arguments turi būti tuščias arba +set sv_enforceGameBuild 3717 (ne 3788/3095)."
