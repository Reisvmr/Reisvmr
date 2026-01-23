#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# Zabbix Full Backup
# - DB dump (mysql/postgres)
# - Configs + scripts + frontend
# - tar.gz package per run
# - retention: keep last 7
# - optional service stop
# =========================

# -------- CONFIG --------
BACKUP_DIR="/var/backups/zabbix"
LOG_DIR="/var/log/zabbix-backup"
LOCK_FILE="/var/lock/zabbix-full-backup.lock"

# DB config
DB_TYPE_FILE="/etc/zabbix-backup/db.type"   # mysql | postgres
DB_PASS_FILE="/etc/zabbix-backup/db.pass"

DB_HOST="127.0.0.1"
DB_PORT_MYSQL="3306"
DB_PORT_PG="5432"
DB_NAME="zabbix"
DB_USER="zabbix_backup"

MYSQL_BIN="/usr/bin/mysql"
MYSQLDUMP_BIN="/usr/bin/mysqldump"
PSQL_BIN="/usr/bin/psql"
PGDUMP_BIN="/usr/bin/pg_dump"

# Retention
KEEP_BACKUPS=7

# Compression
GZIP_BIN="/usr/bin/gzip"
GZIP_LEVEL=6
TAR_BIN="/usr/bin/tar"

# Optional: stop services (default: no)
STOP_SERVICES="no" # yes|no
SERVICES_TO_STOP=("zabbix-server" "zabbix-agent" "apache2" "httpd" "nginx" "php-fpm")

# What to include (will include only if exists)
INCLUDE_DIRS=(
  "/etc/zabbix"
  "/usr/lib/zabbix"
  "/usr/share/zabbix"
  "/var/lib/zabbix"
  "/etc/httpd"
  "/etc/apache2"
  "/etc/nginx"
  "/etc/php-fpm.d"
  "/etc/php-fpm"
  "/etc/php"
)
# -------- END CONFIG --------

umask 077
DATE_NOW="$(date +%F)"
TIME_NOW="$(date +%H%M%S)"
STAMP="${DATE_NOW}_${TIME_NOW}"
HOST="$(hostname -f 2>/dev/null || hostname)"

mkdir -p "${BACKUP_DIR}" "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/zabbix-backup_${DATE_NOW}.log"

log() { echo "[$(date +'%F %T')] $*" | tee -a "${LOG_FILE}"; }
die() { log "ERROR: $*"; exit 1; }

cleanup() {
  local code=$?
  if [[ "${STOP_SERVICES}" == "yes" ]]; then
    for svc in "${SERVICES_TO_STOP[@]}"; do
      systemctl start "$svc" >/dev/null 2>&1 || true
    done
  fi
  rm -f "${LOCK_FILE}" >/dev/null 2>&1 || true
  if [[ $code -eq 0 ]]; then
    log "Backup finalizado com SUCESSO."
  else
    log "Backup finalizado com ERRO (exit=${code})."
  fi
}
trap cleanup EXIT

if [[ -e "${LOCK_FILE}" ]]; then
  die "Lock existente (${LOCK_FILE}). Já existe um backup em execução?"
fi
echo "$$" > "${LOCK_FILE}"

[[ -r "${DB_TYPE_FILE}" ]] || die "DB_TYPE_FILE não pode ser lido: ${DB_TYPE_FILE}"
[[ -r "${DB_PASS_FILE}" ]] || die "DB_PASS_FILE não pode ser lido: ${DB_PASS_FILE}"
[[ -x "${GZIP_BIN}" ]] || die "gzip não encontrado: ${GZIP_BIN}"
[[ -x "${TAR_BIN}" ]] || die "tar não encontrado: ${TAR_BIN}"

DB_TYPE="$(tr -d ' \t\r\n' < "${DB_TYPE_FILE}" | tr '[:upper:]' '[:lower:]')"
DB_PASS="$(<"${DB_PASS_FILE}")"
[[ -n "${DB_PASS}" ]] || die "Senha vazia em ${DB_PASS_FILE}"

WORK_DIR="$(mktemp -d /tmp/zabbix-backup.XXXXXX)"
DB_DIR="${WORK_DIR}/db"
FILES_DIR="${WORK_DIR}/files"
mkdir -p "${DB_DIR}" "${FILES_DIR}"

log "Iniciando backup Zabbix | host=${HOST} | stamp=${STAMP} | db_type=${DB_TYPE}"
log "WORK_DIR=${WORK_DIR}"

if [[ "${STOP_SERVICES}" == "yes" ]]; then
  log "Parando serviços: ${SERVICES_TO_STOP[*]}"
  for svc in "${SERVICES_TO_STOP[@]}"; do
    systemctl stop "$svc" >/dev/null 2>&1 || true
  done
fi

# ---------- DB DUMP ----------
DB_OUT="${DB_DIR}/zabbix.sql"
DB_GZ="${DB_OUT}.gz"

if [[ "${DB_TYPE}" == "mysql" || "${DB_TYPE}" == "mariadb" ]]; then
  [[ -x "${MYSQL_BIN}" ]] || die "mysql não encontrado: ${MYSQL_BIN}"
  [[ -x "${MYSQLDUMP_BIN}" ]] || die "mysqldump não encontrado: ${MYSQLDUMP_BIN}"

  log "Testando conectividade MySQL..."
  "${MYSQL_BIN}" --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT_MYSQL}" -u "${DB_USER}" -p"${DB_PASS}" \
    -e "SELECT 1;" "${DB_NAME}" >/dev/null 2>&1 || die "Falha ao conectar no MySQL."

  log "Gerando dump MySQL (sem parar serviço, --single-transaction)..."
  "${MYSQLDUMP_BIN}" \
    --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT_MYSQL}" -u "${DB_USER}" -p"${DB_PASS}" \
    --single-transaction --quick --routines --triggers --events \
    --set-gtid-purged=OFF \
    "${DB_NAME}" > "${DB_OUT}"

elif [[ "${DB_TYPE}" == "postgres" || "${DB_TYPE}" == "postgresql" ]]; then
  [[ -x "${PSQL_BIN}" ]] || die "psql não encontrado: ${PSQL_BIN}"
  [[ -x "${PGDUMP_BIN}" ]] || die "pg_dump não encontrado: ${PGDUMP_BIN}"

  log "Testando conectividade PostgreSQL..."
  PGPASSWORD="${DB_PASS}" "${PSQL_BIN}" -h "${DB_HOST}" -p "${DB_PORT_PG}" -U "${DB_USER}" -d "${DB_NAME}" \
    -c "SELECT 1;" >/dev/null 2>&1 || die "Falha ao conectar no PostgreSQL."

  log "Gerando dump PostgreSQL (pg_dump)..."
  # Formato plain SQL para restore simples (psql)
  PGPASSWORD="${DB_PASS}" "${PGDUMP_BIN}" -h "${DB_HOST}" -p "${DB_PORT_PG}" -U "${DB_USER}" -d "${DB_NAME}" \
    --no-owner --no-privileges > "${DB_OUT}"
else
  die "DB_TYPE inválido em ${DB_TYPE_FILE}: '${DB_TYPE}' (use mysql|postgres)"
fi

"${GZIP_BIN}" -"${GZIP_LEVEL}" "${DB_OUT}"
[[ -s "${DB_GZ}" ]] || die "Dump do banco ficou vazio: ${DB_GZ}"
log "DB dump OK: ${DB_GZ}"

# ---------- FILES ----------
log "Coletando arquivos (somente os que existirem)..."
for d in "${INCLUDE_DIRS[@]}"; do
  if [[ -e "$d" ]]; then
    # espelha cada path para dentro de files/ com nome "safe"
    safe_name="$(echo "$d" | sed 's|^/||; s|/|_|g')"
    dest="${FILES_DIR}/${safe_name}"
    mkdir -p "${dest}"
    rsync -aHAX --numeric-ids "$d"/ "${dest}/" 2>/dev/null || true
    log "Incluído: $d -> ${dest}"
  fi
done

# ---------- PACKAGE ----------
OUT_TAR="${BACKUP_DIR}/zabbix_full_${STAMP}.tar"
OUT_TGZ="${OUT_TAR}.gz"
MANIFEST="${WORK_DIR}/manifest.txt"

{
  echo "host=${HOST}"
  echo "stamp=${STAMP}"
  echo "db_type=${DB_TYPE}"
  echo "db_name=${DB_NAME}"
  echo "db_host=${DB_HOST}"
  echo "included_dirs="
  for d in "${INCLUDE_DIRS[@]}"; do
    [[ -e "$d" ]] && echo " - $d"
  done
} > "${MANIFEST}"

log "Gerando pacote: ${OUT_TGZ}"
"${TAR_BIN}" -cf "${OUT_TAR}" -C "${WORK_DIR}" .
"${GZIP_BIN}" -"${GZIP_LEVEL}" "${OUT_TAR}"

[[ -s "${OUT_TGZ}" ]] || die "Pacote final ficou vazio: ${OUT_TGZ}"

# cleanup temp
rm -rf "${WORK_DIR}" >/dev/null 2>&1 || true

# ---------- RETENTION ----------
log "Aplicando retenção: manter somente os últimos ${KEEP_BACKUPS} backups em ${BACKUP_DIR}"
mapfile -t ALL < <(ls -1t "${BACKUP_DIR}"/zabbix_full_*.tar.gz 2>/dev/null || true)
if [[ "${#ALL[@]}" -gt "${KEEP_BACKUPS}" ]]; then
  for old in "${ALL[@]:${KEEP_BACKUPS}}"; do
    log "Removendo: ${old}"
    rm -f "${old}"
  done
else
  log "Nada para remover. Total: ${#ALL[@]}"
fi

log "OK. Backup criado em: ${OUT_TGZ}"
