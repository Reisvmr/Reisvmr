#!/usr/bin/env bash
set -Eeuo pipefail

# =========================
# GLPI DB Backup (MySQL/MariaDB)
# - Daily cron-friendly execution
# - Weekly FULL dump (mysqldump)
# - Daily INCREMENTAL via binlog copy (real incremental)
# - No service stop
# - Keep last 7 backup days (directories)
# =========================

# -------- CONFIG --------
BACKUP_ROOT="/var/backups/glpi-db"
LOG_DIR="/var/log/glpi-backup"
LOCK_FILE="/var/lock/glpi-db-backup.lock"

# DB
DB_HOST="127.0.0.1"
DB_PORT="3306"
DB_NAME="glpi10"
DB_USER="glpi_backup"
DB_PASS_FILE="/etc/glpi-backup/db.pass"

MYSQL_BIN="/usr/bin/mysql"
MYSQLDUMP_BIN="/usr/bin/mysqldump"

# Weekly full day (1=Mon ... 7=Sun). Default: Sunday=7
FULL_DOW=7

# Retention: keep only last N day-folders
KEEP_DAYS=7

# Compression
GZIP_BIN="/usr/bin/gzip"
GZIP_LEVEL=6
# -------- END CONFIG --------

umask 077

DATE_NOW="$(date +%F)"
TIME_NOW="$(date +%H%M%S)"
STAMP="${DATE_NOW}_${TIME_NOW}"
HOST="$(hostname -f 2>/dev/null || hostname)"
DOW="$(date +%u)"  # 1..7

mkdir -p "${BACKUP_ROOT}" "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/glpi-db-backup_${DATE_NOW}.log"

log() { echo "[$(date +'%F %T')] $*" | tee -a "${LOG_FILE}"; }
die() { log "ERROR: $*"; exit 1; }

cleanup() {
  local code=$?
  rm -f "${LOCK_FILE}" >/dev/null 2>&1 || true
  if [[ $code -eq 0 ]]; then
    log "Backup finalizado com SUCESSO."
  else
    log "Backup finalizado com ERRO (exit=${code})."
  fi
}
trap cleanup EXIT

# lock
if [[ -e "${LOCK_FILE}" ]]; then
  die "Lock existente (${LOCK_FILE}). Já existe um backup em execução?"
fi
echo "$$" > "${LOCK_FILE}"

# sanity
[[ -r "${DB_PASS_FILE}" ]] || die "DB_PASS_FILE não pode ser lido: ${DB_PASS_FILE}"
[[ -x "${MYSQL_BIN}" ]] || die "mysql bin não encontrado/executável: ${MYSQL_BIN}"
[[ -x "${MYSQLDUMP_BIN}" ]] || die "mysqldump bin não encontrado/executável: ${MYSQLDUMP_BIN}"
[[ -x "${GZIP_BIN}" ]] || die "gzip bin não encontrado/executável: ${GZIP_BIN}"

DB_PASS="$(<"${DB_PASS_FILE}")"
[[ -n "${DB_PASS}" ]] || die "Senha vazia em ${DB_PASS_FILE}"

MODE="INCR"
if [[ "${DOW}" -eq "${FULL_DOW}" ]]; then
  MODE="FULL"
fi

DAY_DIR="${BACKUP_ROOT}/${DATE_NOW}"
mkdir -p "${DAY_DIR}"

log "Iniciando backup DB GLPI | host=${HOST} | mode=${MODE} | date=${DATE_NOW}"

# test DB
log "Testando conectividade..."
"${MYSQL_BIN}" --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
  -e "SELECT 1;" "${DB_NAME}" >/dev/null 2>&1 || die "Falha ao conectar no banco."

# Get binlog base path and current position (for restore mapping)
log "Coletando estado do binlog..."
BINLOG_VARS="$("${MYSQL_BIN}" --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
  -N -e "SHOW VARIABLES LIKE 'log_bin'; SHOW VARIABLES LIKE 'log_bin_basename';" 2>/dev/null || true)"

LOG_BIN_ENABLED="$(echo "${BINLOG_VARS}" | awk '$1=="log_bin"{print $2}' | head -n 1 || true)"
BINLOG_BASE="$(echo "${BINLOG_VARS}" | awk '$1=="log_bin_basename"{print $2}' | head -n 1 || true)"

MASTER_STATUS="$("${MYSQL_BIN}" --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
  -N -e "SHOW MASTER STATUS;" 2>/dev/null || true)"
BINLOG_FILE="$(echo "${MASTER_STATUS}" | awk '{print $1}' | head -n 1 || true)"
BINLOG_POS="$(echo "${MASTER_STATUS}" | awk '{print $2}' | head -n 1 || true)"

# ---------- FULL weekly ----------
if [[ "${MODE}" == "FULL" ]]; then
  FULL_OUT="${DAY_DIR}/glpi_full_${STAMP}.sql"
  FULL_GZ="${FULL_OUT}.gz"

  log "Gerando FULL dump: ${FULL_GZ}"
  # --single-transaction: consistente sem parar serviço (InnoDB)
  # --master-data=2: grava linha com CHANGE MASTER (comentada) com file/pos (ajuda no restore)
  "${MYSQLDUMP_BIN}" \
    --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
    --single-transaction --quick --routines --triggers --events \
    --set-gtid-purged=OFF \
    --master-data=2 \
    "${DB_NAME}" > "${FULL_OUT}"

  "${GZIP_BIN}" -"${GZIP_LEVEL}" "${FULL_OUT}"
  [[ -s "${FULL_GZ}" ]] || die "FULL dump ficou vazio: ${FULL_GZ}"

  log "FULL dump OK."
else
  log "Hoje não é dia de FULL (DOW=${DOW})."
fi

# ---------- INCR daily via binlog copy ----------
INCR_DIR="${DAY_DIR}/binlogs"
mkdir -p "${INCR_DIR}"

if [[ "${LOG_BIN_ENABLED}" == "ON" && -n "${BINLOG_BASE}" ]]; then
  log "Binlog habilitado. Fazendo FLUSH LOGS e copiando binlogs do dia."

  # Rotaciona: fecha binlog atual e abre um novo
  "${MYSQL_BIN}" --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
    -e "FLUSH BINARY LOGS;" >/dev/null

  # Rebusca status após flush (pra registrar o novo current)
  MASTER_STATUS2="$("${MYSQL_BIN}" --protocol=tcp -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
    -N -e "SHOW MASTER STATUS;" 2>/dev/null || true)"
  BINLOG_FILE2="$(echo "${MASTER_STATUS2}" | awk '{print $1}' | head -n 1 || true)"
  BINLOG_POS2="$(echo "${MASTER_STATUS2}" | awk '{print $2}' | head -n 1 || true)"

  BINLOG_DIR="$(dirname "${BINLOG_BASE}")"

  log "Copiando binlogs de ${BINLOG_DIR} para ${INCR_DIR}"
  cp -a "${BINLOG_DIR}/"mysql-bin.* "${INCR_DIR}/" 2>/dev/null || true
  cp -a "${BINLOG_DIR}/"*.index "${INCR_DIR}/" 2>/dev/null || true

  find "${INCR_DIR}" -type f -name "mysql-bin.*" -not -name "*.gz" -print0 | xargs -0 -r "${GZIP_BIN}" -"${GZIP_LEVEL}"

  {
    echo "host=${HOST}"
    echo "date=${DATE_NOW}"
    echo "time=${TIME_NOW}"
    echo "mode=${MODE}"
    echo "db=${DB_NAME}"
    echo "binlog_enabled=${LOG_BIN_ENABLED}"
    echo "binlog_basename=${BINLOG_BASE}"
    echo "master_status_before_flush_file=${BINLOG_FILE}"
    echo "master_status_before_flush_pos=${BINLOG_POS}"
    echo "master_status_after_flush_file=${BINLOG_FILE2}"
    echo "master_status_after_flush_pos=${BINLOG_POS2}"
  } > "${DAY_DIR}/manifest_${STAMP}.txt"

  log "Incremental via binlog OK."
else
  log "ATENÇÃO: binlog NÃO habilitado (log_bin=${LOG_BIN_ENABLED:-desconhecido})."
  log "Sem binlog, incremental real não existe. Você vai depender só do FULL semanal."
  {
    echo "host=${HOST}"
    echo "date=${DATE_NOW}"
    echo "time=${TIME_NOW}"
    echo "mode=${MODE}"
    echo "db=${DB_NAME}"
    echo "binlog_enabled=${LOG_BIN_ENABLED:-unknown}"
    echo "binlog_basename=${BINLOG_BASE:-unknown}"
    echo "note=Sem binlog não há incremental real; considere habilitar log_bin"
  } > "${DAY_DIR}/manifest_${STAMP}.txt"
fi

# ---------- RETENTION (keep last 7 day folders) ----------
log "Aplicando retenção: manter somente os últimos ${KEEP_DAYS} dias em ${BACKUP_ROOT}"
mapfile -t DAYS < <(ls -1dt "${BACKUP_ROOT}"/20??-??-?? 2>/dev/null || true)

if [[ "${#DAYS[@]}" -gt "${KEEP_DAYS}" ]]; then
  for old in "${DAYS[@]:${KEEP_DAYS}}"; do
    log "Removendo: ${old}"
    rm -rf --one-file-system "${old}"
  done
else
  log "Nada para remover. Total dias: ${#DAYS[@]}"
fi

log "OK. Backup do dia em: ${DAY_DIR}"
