#!/bin/bash
# ==============================================================================
# install-prereqs.sh
# Install Docker, rclone, jq, dan tools lain yang dibutuhkan di Contabo VPS
# Dijalankan dari laptop via: make setup-contabo
# ==============================================================================
set -euo pipefail

echo "=== Install prerequisites di Contabo VPS ==="

# Update package list
apt-get update

# Install basic tools
apt-get install -y \
    curl \
    wget \
    jq \
    rsync \
    htop \
    tmux \
    cron \
    mailutils \
    unzip

# Install Docker (kalau belum ada)
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "Docker sudah terinstall: $(docker --version)"
fi

# Install Docker Compose plugin (kalau belum)
if ! docker compose version &> /dev/null; then
    apt-get install -y docker-compose-plugin
fi

# Install rclone (untuk archive)
if ! command -v rclone &> /dev/null; then
    echo "Installing rclone..."
    curl https://rclone.org/install.sh | bash
else
    echo "rclone sudah terinstall: $(rclone --version | head -1)"
fi

# Buat folder kerja
mkdir -p ~/nas/contabo/scripts
mkdir -p ~/nas/logs

echo ""
echo "=== Install prerequisites SELESAI ==="
echo "Docker:        $(docker --version)"
echo "Docker Compose: $(docker compose version)"
echo "rclone:        $(rclone version | head -1)"
echo ""
echo "Next: jalankan 'make contabo-up' dari laptop untuk start Nextcloud"
