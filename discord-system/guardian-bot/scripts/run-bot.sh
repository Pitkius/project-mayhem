#!/usr/bin/env bash
# Krauna KEY=VALUE iš env failo BE bash source (saugu su {members}, tarpais ir t.t.)
set -euo pipefail

BOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${MRP_DISCORD_ENV_FILE:-/home/fivem/.config/mrp-discord.env}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "[mrp-discord] Nerastas env: $ENV_FILE" >&2
  exit 1
fi

load_env_file() {
  local file="$1"
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    # trim CR
    line="${line%$'\r'}"
    # skip empty / comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" == *"="* ]] || continue
    key="${line%%=*}"
    value="${line#*=}"
    # trim key
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"
    # strip surrounding quotes on value
    if [[ "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    export "$key=$value"
  done < "$file"
}

cd "$BOT_DIR"
load_env_file "$ENV_FILE"

if [[ -z "${DISCORD_TOKEN:-}" ]]; then
  echo "[mrp-discord] DISCORD_TOKEN tuščias ($ENV_FILE)" >&2
  exit 1
fi

# Nuimti atsitiktinius whitespace
DISCORD_TOKEN="$(printf '%s' "$DISCORD_TOKEN" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
export DISCORD_TOKEN

exec /usr/bin/node src/index.js
