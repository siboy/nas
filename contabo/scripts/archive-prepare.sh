#!/bin/bash
# ==============================================================================
# archive-prepare.sh
# Pindah file lama (>3 bulan) ke folder Archive-Ready/ supaya siap di-pull oleh
# laptop rumah saat archive workflow jalan.
#
# Jalankan di Contabo VPS. Dipanggil dari laptop via `make archive-prepare`.
#
# Usage:
#   bash archive-prepare.sh <archive_folder_name> [--dry-run]
#
# Example:
#   bash archive-prepare.sh Archive-Ready
#   bash archive-prepare.sh Archive-Ready --dry-run
# ==============================================================================
set -euo pipefail

ARCHIVE_FOLDER="${1:-Archive-Ready}"
DRY_RUN="${2:-}"
NEXTCLOUD_CONTAINER="nas-nextcloud"
NEXTCLOUD_USER="${NEXTCLOUD_ARCHIVE_USER:-admin}"
NEXTCLOUD_DATA_BASE="/var/www/html/data/${NEXTCLOUD_USER}/files"
DAYS_OLD="${ARCHIVE_DAYS_OLD:-90}"

echo "=== Archive Prepare ==="
echo "Archive folder:    ${ARCHIVE_FOLDER}"
echo "User:              ${NEXTCLOUD_USER}"
echo "Min file age:      ${DAYS_OLD} days"
echo "Dry run:           ${DRY_RUN:-false}"
echo ""

# Pastikan container jalan
if ! docker ps --format '{{.Names}}' | grep -q "^${NEXTCLOUD_CONTAINER}$"; then
    echo "ERROR: Container ${NEXTCLOUD_CONTAINER} tidak jalan"
    exit 1
fi

# Pastikan folder Archive-Ready ada di Nextcloud
docker exec --user www-data ${NEXTCLOUD_CONTAINER} bash -c "
    mkdir -p '${NEXTCLOUD_DATA_BASE}/${ARCHIVE_FOLDER}'
"

# Cari file >DAYS_OLD hari yang BUKAN sudah di Archive-Ready dan BUKAN placeholder
echo "Searching files >${DAYS_OLD} days old..."
FILES_TO_ARCHIVE=$(docker exec --user www-data ${NEXTCLOUD_CONTAINER} bash -c "
    find '${NEXTCLOUD_DATA_BASE}' \
        -type f \
        -mtime +${DAYS_OLD} \
        ! -path '*/${ARCHIVE_FOLDER}/*' \
        ! -name '*.archived.json' \
        ! -name '.htaccess' \
        2>/dev/null
")

if [ -z "${FILES_TO_ARCHIVE}" ]; then
    echo "Tidak ada file yang memenuhi kriteria. Selesai."
    exit 0
fi

FILE_COUNT=$(echo "${FILES_TO_ARCHIVE}" | wc -l)
TOTAL_SIZE=$(echo "${FILES_TO_ARCHIVE}" | xargs -I{} docker exec --user www-data ${NEXTCLOUD_CONTAINER} stat -c%s "{}" 2>/dev/null | awk '{sum+=$1} END {print sum}')
TOTAL_SIZE_HUMAN=$(numfmt --to=iec-i --suffix=B "${TOTAL_SIZE}" 2>/dev/null || echo "${TOTAL_SIZE} bytes")

echo "Found ${FILE_COUNT} files, total size: ${TOTAL_SIZE_HUMAN}"
echo ""

if [ "${DRY_RUN}" = "--dry-run" ]; then
    echo "--- DRY RUN — files yang AKAN dipindah ---"
    echo "${FILES_TO_ARCHIVE}" | head -20
    [ "${FILE_COUNT}" -gt 20 ] && echo "... dan $((FILE_COUNT - 20)) file lainnya"
    echo ""
    echo "Untuk eksekusi nyata, jalankan tanpa --dry-run"
    exit 0
fi

# Move files ke Archive-Ready, preserve folder structure
echo "Moving files ke ${ARCHIVE_FOLDER}/..."
echo "${FILES_TO_ARCHIVE}" | while IFS= read -r filepath; do
    [ -z "${filepath}" ] && continue

    # Relative path dari files/
    rel_path="${filepath#${NEXTCLOUD_DATA_BASE}/}"
    dest_path="${NEXTCLOUD_DATA_BASE}/${ARCHIVE_FOLDER}/${rel_path}"
    dest_dir=$(dirname "${dest_path}")

    docker exec --user www-data ${NEXTCLOUD_CONTAINER} bash -c "
        mkdir -p '${dest_dir}' && mv '${filepath}' '${dest_path}'
    "
    echo "  -> ${rel_path}"
done

echo ""
echo "Trigger Nextcloud rescan..."
docker exec --user www-data ${NEXTCLOUD_CONTAINER} php occ files:scan --path="${NEXTCLOUD_USER}/files/${ARCHIVE_FOLDER}" --quiet

echo ""
echo "=== Archive Prepare SELESAI ==="
echo "${FILE_COUNT} file dipindah ke ${ARCHIVE_FOLDER}/, siap di-pull oleh laptop."
