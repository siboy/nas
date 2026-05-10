#!/bin/bash
# ==============================================================================
# monitor-storage.sh
# Cek pemakaian disk Contabo. Alert kalau > threshold (default 80%).
#
# Bisa dijalankan via cron di Contabo (tiap pagi):
#   0 8 * * * /root/nas/contabo/scripts/monitor-storage.sh
#
# Atau dari laptop via: make storage-alert
# ==============================================================================
set -euo pipefail

THRESHOLD="${STORAGE_ALERT_THRESHOLD:-80}"
EMAIL_TO="${ALERT_EMAIL:-}"
NEXTCLOUD_DATA_VOLUME="/var/lib/docker/volumes/nas_nextcloud_data/_data"

# Get disk usage percentage (root partition)
USAGE=$(df / | awk 'NR==2 {print int($5)}')
USAGE_HUMAN=$(df -h / | awk 'NR==2 {print $3"/"$2" ("$5" used)"}')

# Get Nextcloud data folder size
if [ -d "${NEXTCLOUD_DATA_VOLUME}" ]; then
    NC_SIZE=$(du -sh "${NEXTCLOUD_DATA_VOLUME}" 2>/dev/null | cut -f1)
else
    NC_SIZE="(folder belum ada)"
fi

echo "=== Storage Status (Contabo) ==="
echo "Root disk:        ${USAGE_HUMAN}"
echo "Nextcloud data:   ${NC_SIZE}"
echo "Threshold:        ${THRESHOLD}%"
echo ""

if [ "${USAGE}" -ge "${THRESHOLD}" ]; then
    echo "[!] ALERT: Disk usage ${USAGE}% >= threshold ${THRESHOLD}%"
    echo "[!] Saran: jalankan 'make archive-now' dari laptop untuk pindahkan file lama ke HDD"

    # Send email notification kalau email dikonfigurasi
    if [ -n "${EMAIL_TO}" ]; then
        echo "Sending alert email ke ${EMAIL_TO}..."
        cat <<EOF | mail -s "[NAS Contabo] Disk usage ${USAGE}%" "${EMAIL_TO}"
Disk usage di Contabo VPS sudah mencapai ${USAGE}%.

Detail:
- Root disk: ${USAGE_HUMAN}
- Nextcloud data: ${NC_SIZE}
- Threshold: ${THRESHOLD}%

Segera jalankan archive workflow dari laptop:
  make archive-now

Atau cek manual via:
  make storage-check
EOF
    fi

    exit 1
fi

echo "[OK] Disk usage masih di bawah threshold."
exit 0
