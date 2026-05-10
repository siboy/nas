#!/bin/bash
# ==============================================================================
# archive-pull.sh (Linux/macOS/WSL/Git Bash)
# Equivalent dari archive-pull.ps1 untuk shell POSIX.
# ==============================================================================
set -euo pipefail

# Load .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../../.env"

if [ -f "${ENV_FILE}" ]; then
    set -a
    source "${ENV_FILE}"
    set +a
else
    echo "[ERROR] .env tidak ditemukan di ${ENV_FILE}"
    exit 1
fi

# Config
CONTABO_HOST="${CONTABO_HOST}"
CONTABO_USER="${CONTABO_USER}"
HDD_MOUNT="${HDD_MOUNT:-/mnt/nas}"
ARCHIVE_FOLDER="${ARCHIVE_FOLDER:-Archive-Ready}"
NC_USER="${NEXTCLOUD_ARCHIVE_USER:-admin}"
BW_LIMIT="${RCLONE_BWLIMIT:-0}"

echo ""
echo "=== Archive Pull (Contabo --> HDD Lokal) ==="
echo "Source: ${CONTABO_USER}@${CONTABO_HOST}:Archive-Ready/"
echo "Dest:   ${HDD_MOUNT}/nextcloud-archive/$(date +%Y-%m)/"
echo ""

# Verify HDD mounted
if [ ! -d "${HDD_MOUNT}" ]; then
    echo "[ERROR] HDD tidak ter-mount di ${HDD_MOUNT}"
    exit 1
fi

# Verify rclone
if ! command -v rclone &> /dev/null; then
    echo "[ERROR] rclone tidak terinstall. Install: curl https://rclone.org/install.sh | bash"
    exit 1
fi

# Setup destination
BATCH_FOLDER="$(date +%Y-%m)"
DEST_PATH="${HDD_MOUNT}/nextcloud-archive/${BATCH_FOLDER}"
mkdir -p "${DEST_PATH}"

REMOTE_PATH="/var/lib/docker/volumes/nas_nextcloud_data/_data/${NC_USER}/files/${ARCHIVE_FOLDER}"

# Pull
echo "[1/3] Pulling files via rclone..."
RCLONE_ARGS=(
    copy
    "contabo-sftp:${REMOTE_PATH}"
    "${DEST_PATH}"
    --progress
    --transfers=4
    --checkers=8
    --log-file="${DEST_PATH}/rclone.log"
    --log-level=INFO
)

if [ "${BW_LIMIT}" != "0" ]; then
    RCLONE_ARGS+=(--bwlimit="${BW_LIMIT}")
fi

rclone "${RCLONE_ARGS[@]}"

# Verify
echo ""
echo "[2/3] Verifying integrity..."
if ! rclone check "contabo-sftp:${REMOTE_PATH}" "${DEST_PATH}" --one-way --log-file="${DEST_PATH}/verify.log"; then
    echo "[ERROR] Verify gagal! Jangan run 'make archive-finalize' sampai fixed."
    exit 1
fi

# Summary
FILE_COUNT=$(find "${DEST_PATH}" -type f ! -name "*.log" | wc -l)
TOTAL_SIZE=$(du -sh "${DEST_PATH}" | cut -f1)

echo ""
echo "[3/3] Summary"
echo "  Files: ${FILE_COUNT}"
echo "  Size:  ${TOTAL_SIZE}"
echo "  Path:  ${DEST_PATH}"
echo ""
echo "=== Archive Pull SELESAI ==="
echo "Next: make archive-finalize"
