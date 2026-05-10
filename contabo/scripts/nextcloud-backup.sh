#!/bin/bash
# ==============================================================================
# nextcloud-backup.sh
# Backup database PostgreSQL + config Nextcloud ke folder ~/nas/backups/
# Bisa di-pull ke laptop nanti pakai rclone/scp.
# ==============================================================================
set -euo pipefail

BACKUP_DIR="${HOME}/nas/backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
NEXTCLOUD_CONTAINER="nas-nextcloud"
POSTGRES_CONTAINER="nas-postgres"
POSTGRES_USER="${POSTGRES_USER:-nextcloud}"
POSTGRES_DB="${POSTGRES_DB:-nextcloud}"

mkdir -p "${BACKUP_DIR}"

echo "=== Nextcloud Backup ==="
echo "Backup dir: ${BACKUP_DIR}"
echo "Timestamp:  ${TIMESTAMP}"
echo ""

# Step 1: Set Nextcloud ke maintenance mode
echo "[1/5] Enable maintenance mode..."
docker exec --user www-data ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --on

# Step 2: Backup database
echo "[2/5] Backup PostgreSQL database..."
docker exec ${POSTGRES_CONTAINER} pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" \
    | gzip > "${BACKUP_DIR}/nextcloud_db_${TIMESTAMP}.sql.gz"

# Step 3: Backup Nextcloud config
echo "[3/5] Backup config..."
docker cp ${NEXTCLOUD_CONTAINER}:/var/www/html/config "${BACKUP_DIR}/nextcloud_config_${TIMESTAMP}"
tar -czf "${BACKUP_DIR}/nextcloud_config_${TIMESTAMP}.tar.gz" -C "${BACKUP_DIR}" "nextcloud_config_${TIMESTAMP}"
rm -rf "${BACKUP_DIR}/nextcloud_config_${TIMESTAMP}"

# Step 4: Disable maintenance mode
echo "[4/5] Disable maintenance mode..."
docker exec --user www-data ${NEXTCLOUD_CONTAINER} php occ maintenance:mode --off

# Step 5: Cleanup old backups (keep last 7)
echo "[5/5] Cleanup old backups (keep 7 terbaru)..."
ls -t "${BACKUP_DIR}"/nextcloud_db_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm
ls -t "${BACKUP_DIR}"/nextcloud_config_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm

echo ""
echo "=== Backup SELESAI ==="
echo "DB backup:     ${BACKUP_DIR}/nextcloud_db_${TIMESTAMP}.sql.gz ($(du -h "${BACKUP_DIR}/nextcloud_db_${TIMESTAMP}.sql.gz" | cut -f1))"
echo "Config backup: ${BACKUP_DIR}/nextcloud_config_${TIMESTAMP}.tar.gz ($(du -h "${BACKUP_DIR}/nextcloud_config_${TIMESTAMP}.tar.gz" | cut -f1))"
echo ""
echo "Pull ke laptop dengan: scp -i ssh-keys/contabo_nas USER@HOST:~/nas/backups/* ./backups/"
