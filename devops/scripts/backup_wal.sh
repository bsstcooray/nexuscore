#!/usr/bin/env bash
# ============================================================================
# NexusCore WAL Archiving & Base Backup Script
# PostgreSQL 16 Point-in-Time Recovery (PITR) Setup
# ============================================================================

set -euo pipefail

BACKUP_DIR="/var/backups/nexuscore"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
PGUSER="nexus_admin"
PGDATABASE="nexuscore_db"

echo "[*] Starting NexusCore Base Backup at ${TIMESTAMP}..."
mkdir -p "${BACKUP_DIR}/base"
mkdir -p "${BACKUP_DIR}/wal_archive"

# Execute pg_basebackup with continuous WAL stream
pg_basebackup \
    -U "${PGUSER}" \
    -D "${BACKUP_DIR}/base/base_${TIMESTAMP}" \
    -Ft \
    -z \
    -P \
    -X stream

echo "[✓] Base backup successfully archived at ${BACKUP_DIR}/base/base_${TIMESTAMP}.tar.gz"
