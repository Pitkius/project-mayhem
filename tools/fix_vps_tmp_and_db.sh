#!/bin/bash
# FiveM / Hostinger VPS — atlaisvina /tmp (tmpfs), nukreipia MySQL temp į diską,
# prideda trūkstamas DB kolonas. Paleisk kaip root:
#   bash fix_vps_tmp_and_db.sh
set -euo pipefail

echo "=== 1) Diskas prieš ==="
df -h / /tmp

echo ""
echo "=== 2) Kas užima /tmp (top) ==="
du -xh /tmp 2>/dev/null | sort -h | tail -20 || true

echo ""
echo "=== 3) Valau senus failus /tmp (>1h) ==="
# Neliečiame socketų / dabartinių locked failų agresyviai — tik failus senesnius nei 60 min
find /tmp -xdev -type f -mmin +60 -print -delete 2>/dev/null || true
find /tmp -xdev -type d -empty -mmin +60 -delete 2>/dev/null || true

# Jei vis dar >90% — agresyvesnis valymas (išskyrus systemd-private*)
USED=$(df -P /tmp | awk 'NR==2{gsub(/%/,"",$5); print $5}')
if [ "${USED:-0}" -ge 90 ]; then
  echo "/tmp vis dar ~${USED}% — valau daugiau (atsargiai)..."
  find /tmp -xdev -type f ! -name 'systemd*' ! -path '*/systemd-private*' -mmin +5 -print -delete 2>/dev/null || true
fi

echo ""
echo "=== 4) MySQL tmpdir → /var/tmp/mysql (diskas, ne RAM tmpfs) ==="
mkdir -p /var/tmp/mysql
# MariaDB/MySQL user
if id mysql >/dev/null 2>&1; then
  chown mysql:mysql /var/tmp/mysql
elif id mysql >/dev/null 2>&1; then
  chown mysql:mysql /var/tmp/mysql
fi
chmod 1777 /var/tmp/mysql

CNF_DIR=""
for d in /etc/mysql/mariadb.conf.d /etc/mysql/mysql.conf.d /etc/my.cnf.d; do
  if [ -d "$d" ]; then CNF_DIR="$d"; break; fi
done

if [ -n "$CNF_DIR" ]; then
  cat > "$CNF_DIR/99-tmpdir-disk.cnf" <<'EOF'
[mysqld]
tmpdir = /var/tmp/mysql
EOF
  echo "Parašyta: $CNF_DIR/99-tmpdir-disk.cnf"
else
  echo "WARN: neradau mysql conf.d — pridėk rankiniu: tmpdir=/var/tmp/mysql"
fi

echo ""
echo "=== 5) Restart MySQL/MariaDB ==="
if systemctl is-active --quiet mariadb 2>/dev/null; then
  systemctl restart mariadb
elif systemctl is-active --quiet mysql 2>/dev/null; then
  systemctl restart mysql
else
  echo "WARN: neradau mysql/mariadb service — restartink rankiniu"
fi

echo ""
echo "=== 6) DB kolonų migracija (ignore Duplicate column) ==="
# Prisitaikyk prie savo DB user/pass/db jei skiriasi
DB_USER="${DB_USER:-fivem}"
DB_PASS="${DB_PASS:-StiprusSlaptazodis123!}"
DB_NAME="${DB_NAME:-fivempro}"

run_sql() {
  mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" -e "$1" 2>&1 | grep -v "Using a password" || true
}

run_sql "ALTER TABLE fivempro_gangs ADD COLUMN secondary_color_hex VARCHAR(16) NOT NULL DEFAULT '#FFFFFF';"
run_sql "ALTER TABLE fivempro_gangs ADD COLUMN owner_citizenid VARCHAR(64) NULL;"
run_sql "ALTER TABLE fivempro_gangs ADD COLUMN parent_gang_id INT NULL DEFAULT NULL;"
run_sql "ALTER TABLE fivempro_gangs ADD COLUMN warnings INT NOT NULL DEFAULT 0;"
run_sql "ALTER TABLE fivempro_gang_turfs ADD COLUMN influence INT NOT NULL DEFAULT 0;"
run_sql "ALTER TABLE ltpd_profiles ADD COLUMN craft_level TINYINT NOT NULL DEFAULT 1;"
run_sql "ALTER TABLE ltpd_profiles ADD COLUMN crafts_at_level INT NOT NULL DEFAULT 0;"

echo ""
echo "=== 7) Diskas po ==="
df -h / /tmp
echo ""
echo "DONE. Dabar restartink FiveM (txAdmin) arba: ensure mrp_gangs / ensure mrp_ltpd"
