#!/bin/bash
# ==============================================================================
# create-shortcuts.sh
# Setelah file di-pull oleh laptop ke HDD, ganti file mentah di Contabo dengan
# placeholder .archived.json yang berisi metadata file.
#
# Skenario 2: User browse Nextcloud lihat folder lengkap, file lama berupa
# placeholder kecil yang menjelaskan dimana file aslinya tersimpan.
#
# Jalankan di Contabo. Dipanggil dari laptop via `make archive-finalize`
# SETELAH `make archive-pull` sukses (file sudah di HDD lokal).
# ==============================================================================
set -euo pipefail

ARCHIVE_FOLDER="${1:-Archive-Ready}"
NEXTCLOUD_CONTAINER="nas-nextcloud"
NEXTCLOUD_USER="${NEXTCLOUD_ARCHIVE_USER:-admin}"
NEXTCLOUD_DATA_BASE="/var/www/html/data/${NEXTCLOUD_USER}/files"
ARCHIVE_DEST_LABEL="${ARCHIVE_DEST_LABEL:-HDD External Laptop Rumah}"
ARCHIVE_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ARCHIVE_BATCH_ID=$(date +"%Y-%m")

echo "=== Create Shortcuts (Replace files with .archived.json placeholders) ==="
echo "Archive folder:    ${ARCHIVE_FOLDER}"
echo "Batch ID:          ${ARCHIVE_BATCH_ID}"
echo ""

# Cari semua file di Archive-Ready yang BUKAN placeholder
FILES=$(docker exec --user www-data ${NEXTCLOUD_CONTAINER} bash -c "
    find '${NEXTCLOUD_DATA_BASE}/${ARCHIVE_FOLDER}' \
        -type f \
        ! -name '*.archived.json' \
        2>/dev/null
")

if [ -z "${FILES}" ]; then
    echo "Tidak ada file untuk dijadikan placeholder."
    exit 0
fi

FILE_COUNT=$(echo "${FILES}" | wc -l)
echo "Processing ${FILE_COUNT} files..."

echo "${FILES}" | while IFS= read -r filepath; do
    [ -z "${filepath}" ] && continue

    rel_path="${filepath#${NEXTCLOUD_DATA_BASE}/}"
    filename=$(basename "${filepath}")

    # Get metadata
    SIZE=$(docker exec --user www-data ${NEXTCLOUD_CONTAINER} stat -c%s "${filepath}")
    MTIME=$(docker exec --user www-data ${NEXTCLOUD_CONTAINER} stat -c%y "${filepath}")
    MIME=$(docker exec --user www-data ${NEXTCLOUD_CONTAINER} file -b --mime-type "${filepath}" 2>/dev/null || echo "application/octet-stream")

    # Build placeholder JSON
    PLACEHOLDER_JSON=$(cat <<EOF
{
  "archived": true,
  "original_filename": "${filename}",
  "original_path": "${rel_path}",
  "original_size_bytes": ${SIZE},
  "original_mtime": "${MTIME}",
  "original_mime": "${MIME}",
  "archive_date": "${ARCHIVE_DATE}",
  "archive_batch": "${ARCHIVE_BATCH_ID}",
  "stored_at": "${ARCHIVE_DEST_LABEL}",
  "restore_instructions": "File ini sudah dipindah ke HDD external. Hubungi admin atau akses FileBrowser saat laptop nyala (jam 19:00-23:00 WIB) untuk download.",
  "filebrowser_url": "https://files.yourdomain.com/files/${rel_path}"
}
EOF
)

    # Replace original file dengan placeholder
    PLACEHOLDER_NAME="${filepath}.archived.json"
    docker exec --user www-data ${NEXTCLOUD_CONTAINER} bash -c "
        echo '${PLACEHOLDER_JSON}' > '${PLACEHOLDER_NAME}' && rm '${filepath}'
    "

    echo "  [archived] ${rel_path}"
done

echo ""
echo "Trigger Nextcloud rescan untuk update DB..."
docker exec --user www-data ${NEXTCLOUD_CONTAINER} php occ files:scan --path="${NEXTCLOUD_USER}/files/${ARCHIVE_FOLDER}" --quiet

echo ""
echo "=== Create Shortcuts SELESAI ==="
echo "${FILE_COUNT} file diganti dengan placeholder .archived.json"
