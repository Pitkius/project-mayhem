#!/usr/bin/env bash
# =============================================================================
# MySQL/MariaDB daily backup for FiveM VPS (txAdmin-friendly)
# =============================================================================
#
# Install (cron, every day at 04:00):
#   chmod +x /home/fivem/server/scripts/backup-mysql.sh
#   cp /home/fivem/server/scripts/backup-mysql.env.example \
#      /home/fivem/.config/mrp-mysql-backup.env
#   chmod 600 /home/fivem/.config/mrp-mysql-backup.env
#   # edit credentials, then:
#   crontab -u fivem -e
#   0 4 * * * /home/fivem/server/scripts/backup-mysql.sh
#
# txAdmin: Scheduled Restarts → custom command, or system cron as above (preferred).
#
# Retention policy (defaults):
#   1) Keep the newest KEEP_DAILY (7) dumps.
#   2) From older dumps, keep up to KEEP_WEEKLY (4) — newest file per ISO week.
#   3) Delete anything older than MAX_AGE_DAYS (35).
#   4) If total size > MAX_TOTAL_MB (2048), delete oldest until under the cap
#      (never delete the newest dump in that pass).
#
# Restore one-liner:
#   gunzip -c /home/fivem/backups/mysql/fivempro_YYYY-MM-DD_HHMMSS.sql.gz \
#     | mysql -u USER -p DATABASE
#
# Env file search order:
#   $BACKUP_ENV, ~/.config/mrp-mysql-backup.env, <repo>/scripts/backup-mysql.env
#
# Credentials: MYSQL_* vars, MYSQL_CONNECTION_STRING, or MYSQL_CFG (oxmysql URI).
# Optional: BACKUP_DISCORD_WEBHOOK for success/failure ping.
#
# Flags:
#   --dry-run        log actions only (no dump / no delete)
#   --cleanup-only   run retention only
#   --self-test      create fake dumps and verify retention logic, then exit
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

DRY_RUN=0
CLEANUP_ONLY=0
SELF_TEST=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --cleanup-only) CLEANUP_ONLY=1 ;;
    --self-test) SELF_TEST=1 ;;
    -h|--help)
      sed -n '2,40p' "$0"
      exit 0
      ;;
  esac
done

load_env_file() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
  return 0
}

if [[ -n "${BACKUP_ENV:-}" ]]; then
  load_env_file "$BACKUP_ENV" || { echo "BACKUP_ENV not found: $BACKUP_ENV" >&2; exit 1; }
else
  load_env_file "${HOME}/.config/mrp-mysql-backup.env" \
    || load_env_file "${SCRIPT_DIR}/backup-mysql.env" \
    || true
fi

BACKUP_DIR="${BACKUP_DIR:-/home/fivem/backups/mysql}"
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
MAX_AGE_DAYS="${MAX_AGE_DAYS:-35}"
MAX_TOTAL_MB="${MAX_TOTAL_MB:-2048}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
MYSQL_DATABASE="${MYSQL_DATABASE:-}"
MYSQL_CFG="${MYSQL_CFG:-}"
LOG_FILE="${LOG_FILE:-${BACKUP_DIR}/backup.log}"

urldecode() {
  local s="${1//+/ }"
  printf '%b' "${s//%/\\x}"
}

parse_mysql_uri() {
  local uri="$1"
  uri="${uri#\"}"
  uri="${uri%\"}"
  uri="${uri%;}"
  # mysql://user:pass@host:port/db?params  OR  mysql://user:pass@host/db
  if [[ ! "$uri" =~ ^mysql://([^:]+):([^@]+)@([^:/]+)(:([0-9]+))?/([^?]+) ]]; then
    echo "Cannot parse MYSQL_CONNECTION_STRING / cfg URI" >&2
    return 1
  fi
  MYSQL_USER="$(urldecode "${BASH_REMATCH[1]}")"
  MYSQL_PASSWORD="$(urldecode "${BASH_REMATCH[2]}")"
  MYSQL_HOST="${BASH_REMATCH[3]}"
  MYSQL_PORT="${BASH_REMATCH[5]:-3306}"
  MYSQL_DATABASE="${BASH_REMATCH[6]}"
  MYSQL_DATABASE="${MYSQL_DATABASE%%\?*}"
}

read_cfg_connection_string() {
  local cfg="$1"
  local line raw
  line="$(grep -E '^\s*set\s+mysql_connection_string\s+' "$cfg" | tail -1 || true)"
  [[ -n "$line" ]] || { echo "No mysql_connection_string in $cfg" >&2; return 1; }
  raw="$(sed -E 's/^\s*set\s+mysql_connection_string\s+//; s/\r$//' <<<"$line")"
  raw="${raw#\"}"
  raw="${raw%\"}"
  parse_mysql_uri "$raw"
}

resolve_credentials() {
  if [[ -n "${MYSQL_CONNECTION_STRING:-}" ]]; then
    parse_mysql_uri "$MYSQL_CONNECTION_STRING"
  elif [[ -n "$MYSQL_CFG" ]]; then
    read_cfg_connection_string "$MYSQL_CFG"
  elif [[ -z "$MYSQL_USER" || -z "$MYSQL_PASSWORD" || -z "$MYSQL_DATABASE" ]]; then
    # Last resort: common cfg path next to repo
    local guess
    for guess in \
      "${REPO_DIR}/cfg/00_base.cfg" \
      "${MYSQL_CFG_DEFAULT:-}"
    do
      [[ -n "$guess" && -f "$guess" ]] || continue
      if read_cfg_connection_string "$guess" 2>/dev/null; then
        return 0
      fi
    done
  fi

  if [[ -z "$MYSQL_USER" || -z "$MYSQL_PASSWORD" || -z "$MYSQL_DATABASE" ]]; then
    echo "Missing DB credentials. Set MYSQL_USER/MYSQL_PASSWORD/MYSQL_DATABASE," >&2
    echo "or MYSQL_CONNECTION_STRING, or MYSQL_CFG, or create:" >&2
    echo "  ${HOME}/.config/mrp-mysql-backup.env  (see scripts/backup-mysql.env.example)" >&2
    return 1
  fi
}

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
  printf '%s\n' "$msg" | tee -a "$LOG_FILE"
}

notify_discord() {
  local text="$1"
  local url="${BACKUP_DISCORD_WEBHOOK:-}"
  [[ -n "$url" ]] || return 0
  command -v curl >/dev/null 2>&1 || return 0
  # Minimal JSON escape for quotes/backslashes/newlines
  local esc="${text//\\/\\\\}"
  esc="${esc//\"/\\\"}"
  esc="${esc//$'\n'/\\n}"
  curl -fsS -H 'Content-Type: application/json' \
    -d "{\"content\":\"${esc}\"}" \
    "$url" >/dev/null 2>&1 || true
}

# List backup files newest-first (one path per line).
list_backups() {
  local dir="$1"
  find "$dir" -maxdepth 1 -type f -name '*.sql.gz' -printf '%T@ %p\n' 2>/dev/null \
    | sort -nr \
    | awk '{ $1=""; sub(/^ /,""); print }'
}

iso_week_key() {
  # portable: prefer GNU date -r; fallback to stat
  local f="$1"
  if date -r "$f" '+%G-W%V' >/dev/null 2>&1; then
    date -r "$f" '+%G-W%V'
  else
    date -d "@$(stat -c %Y "$f")" '+%G-W%V'
  fi
}

file_age_days() {
  local f="$1"
  local now mtime
  now="$(date +%s)"
  if mtime="$(stat -c %Y "$f" 2>/dev/null)"; then
    :
  elif mtime="$(stat -f %m "$f" 2>/dev/null)"; then
    :
  else
    echo 0
    return
  fi
  echo $(( (now - mtime) / 86400 ))
}

# Decide which files to delete; prints paths to delete.
plan_deletions() {
  local dir="$1"
  local -a files=()
  local -A keep=()
  local -A week_kept=()
  local f i week age size total

  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    files+=("$f")
  done < <(list_backups "$dir")

  # 1) newest KEEP_DAILY
  for ((i = 0; i < ${#files[@]} && i < KEEP_DAILY; i++)); do
    keep["${files[$i]}"]=1
  done

  # 2) up to KEEP_WEEKLY older files, one per ISO week
  local weekly_count=0
  for ((i = KEEP_DAILY; i < ${#files[@]}; i++)); do
    f="${files[$i]}"
    week="$(iso_week_key "$f")"
    if [[ -z "${week_kept[$week]:-}" && "$weekly_count" -lt "$KEEP_WEEKLY" ]]; then
      week_kept["$week"]=1
      keep["$f"]=1
      weekly_count=$((weekly_count + 1))
    fi
  done

  # 3) age cap — drop from keep if too old (except always protect newest)
  for f in "${files[@]}"; do
    [[ -n "${keep[$f]:-}" ]] || continue
    [[ "$f" == "${files[0]:-}" ]] && continue
    age="$(file_age_days "$f")"
    if [[ "$age" -gt "$MAX_AGE_DAYS" ]]; then
      unset 'keep[$f]'
    fi
  done

  # Emit non-kept as deletions (oldest first for size pass bookkeeping)
  local -a delete=()
  for ((i = ${#files[@]} - 1; i >= 0; i--)); do
    f="${files[$i]}"
    if [[ -z "${keep[$f]:-}" ]]; then
      delete+=("$f")
    fi
  done

  # 4) size cap: while over budget, delete oldest remaining kept (not newest)
  total=0
  for f in "${files[@]}"; do
    if [[ -n "${keep[$f]:-}" ]]; then
      size="$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f")"
      total=$((total + size))
    fi
  done
  local max_bytes=$((MAX_TOTAL_MB * 1024 * 1024))
  if [[ "$total" -gt "$max_bytes" ]]; then
    for ((i = ${#files[@]} - 1; i >= 1; i--)); do
      [[ "$total" -le "$max_bytes" ]] && break
      f="${files[$i]}"
      [[ -n "${keep[$f]:-}" ]] || continue
      size="$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f")"
      unset 'keep[$f]'
      delete+=("$f")
      total=$((total - size))
    done
  fi

  printf '%s\n' "${delete[@]+"${delete[@]}"}"
}

run_cleanup() {
  local dir="$1"
  local f count=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "DRY-RUN delete: $f"
    else
      rm -f -- "$f"
      log "Deleted old backup: $(basename "$f")"
    fi
    count=$((count + 1))
  done < <(plan_deletions "$dir")
  log "Cleanup done (removed ${count} file(s)). keep_daily=${KEEP_DAILY} keep_weekly=${KEEP_WEEKLY} max_age_days=${MAX_AGE_DAYS} max_total_mb=${MAX_TOTAL_MB}"
}

write_defaults_file() {
  local path="$1"
  umask 077
  cat >"$path" <<EOF
[client]
host=${MYSQL_HOST}
port=${MYSQL_PORT}
user=${MYSQL_USER}
password=${MYSQL_PASSWORD}
EOF
}

run_dump() {
  local stamp out tmp defaults dump_rc
  stamp="$(date '+%Y-%m-%d_%H%M%S')"
  out="${BACKUP_DIR}/${MYSQL_DATABASE}_${stamp}.sql.gz"
  tmp="${out}.partial"
  defaults="$(mktemp)"
  trap 'rm -f -- "$defaults" "$tmp"' RETURN

  write_defaults_file "$defaults"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "DRY-RUN dump would write: $out"
    return 0
  fi

  # Prefer mariadb-dump if present
  local dumper="mysqldump"
  command -v mariadb-dump >/dev/null 2>&1 && dumper="mariadb-dump"
  command -v mysqldump >/dev/null 2>&1 || command -v mariadb-dump >/dev/null 2>&1 \
    || { log "ERROR: mysqldump/mariadb-dump not found"; return 1; }

  set +e
  "$dumper" --defaults-extra-file="$defaults" \
    --single-transaction --routines --triggers --events --hex-blob \
    --default-character-set=utf8mb4 \
    "$MYSQL_DATABASE" | gzip -c >"$tmp"
  dump_rc=${PIPESTATUS[0]}
  set -e

  if [[ "$dump_rc" -ne 0 ]] || [[ ! -s "$tmp" ]]; then
    rm -f -- "$tmp"
    log "ERROR: dump failed (rc=${dump_rc}) for database=${MYSQL_DATABASE}"
    notify_discord "❌ MySQL backup FAILED (${MYSQL_DATABASE})"
    return 1
  fi

  mv -f -- "$tmp" "$out"
  log "OK: created $(basename "$out") ($(du -h "$out" | awk '{print $1}'))"
  notify_discord "✅ MySQL backup OK: $(basename "$out")"
}

run_self_test() {
  local tdir
  tdir="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf -- '$tdir'" EXIT
  BACKUP_DIR="$tdir"
  LOG_FILE="${tdir}/backup.log"
  KEEP_DAILY=7
  KEEP_WEEKLY=4
  MAX_AGE_DAYS=35
  MAX_TOTAL_MB=1

  local i
  # 20 fake dumps: ages 0..19 days
  for i in $(seq 0 19); do
    local f="${tdir}/db_$(printf '%02d' "$i").sql.gz"
    # ~100KB each so size cap engages
    dd if=/dev/zero of="$f" bs=1024 count=100 status=none 2>/dev/null \
      || dd if=/dev/zero of="$f" bs=1024 count=100 2>/dev/null
    touch -d "$i days ago" "$f" 2>/dev/null \
      || touch -t "$(date -v-"${i}"d '+%Y%m%d%H%M' 2>/dev/null || date -d "$i days ago" '+%Y%m%d%H%M')" "$f"
  done

  local before after
  before="$(find "$tdir" -name '*.sql.gz' | wc -l | tr -d ' ')"
  DRY_RUN=0
  run_cleanup "$tdir"
  after="$(find "$tdir" -name '*.sql.gz' | wc -l | tr -d ' ')"

  echo "self-test: before=${before} after=${after}"
  # Expect at most KEEP_DAILY + KEEP_WEEKLY, and size/age caps may reduce further
  if [[ "$after" -gt $((KEEP_DAILY + KEEP_WEEKLY)) ]]; then
    echo "FAIL: too many files retained ($after)" >&2
    exit 1
  fi
  if [[ "$after" -lt 1 ]]; then
    echo "FAIL: newest backup should survive" >&2
    exit 1
  fi
  # newest (age 0) must remain
  if [[ ! -f "${tdir}/db_00.sql.gz" ]]; then
    echo "FAIL: newest dump deleted" >&2
    exit 1
  fi
  echo "self-test: OK (retention + caps)"
}

# --- main (skip when sourced) ---
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ "$SELF_TEST" -eq 1 ]]; then
    run_self_test
    exit 0
  fi

  mkdir -p "$BACKUP_DIR"
  LOG_FILE="${LOG_FILE:-${BACKUP_DIR}/backup.log}"

  if [[ "$CLEANUP_ONLY" -eq 0 ]]; then
    resolve_credentials
    log "Starting backup host=${MYSQL_HOST} db=${MYSQL_DATABASE} dir=${BACKUP_DIR}"
    run_dump
  else
    log "Cleanup-only mode dir=${BACKUP_DIR}"
  fi

  run_cleanup "$BACKUP_DIR"
  log "Finished."
  exit 0
fi
