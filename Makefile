# ==============================================================================
# NAS Project — Self-hosted hybrid NAS (Contabo VPS + Laptop rumah + HDD external)
# ==============================================================================
# Pattern Makefile mengikuti C:\mtk\Makefile (multi-platform Windows + Linux)
# Maintained by: agusdd
# ==============================================================================

# Detect OS
ifeq ($(OS),Windows_NT)
    DETECTED_OS := Windows
    SHELL := powershell.exe
    .SHELLFLAGS := -NoProfile -Command
    RM := Remove-Item -Recurse -Force
    MKDIR := New-Item -ItemType Directory -Force -Path
else
    DETECTED_OS := $(shell uname -s)
    SHELL := /bin/bash
    RM := rm -rf
    MKDIR := mkdir -p
endif

# Load .env kalau ada
ifneq (,$(wildcard ./.env))
    include .env
    export
endif

# Default values (override via .env)
CONTABO_HOST ?= your-vps.contabo.com
CONTABO_USER ?= root
CONTABO_SSH_KEY ?= ./ssh-keys/contabo_nas
HDD_MOUNT ?= E:/nas-archive
NEXTCLOUD_DATA_PATH ?= /var/lib/docker/volumes/nas_nextcloud_data/_data
ARCHIVE_FOLDER ?= Archive-Ready
DOMAIN ?= nextcloud.yourdomain.com
TAILSCALE_HOSTNAME ?= laptop-nas

# Colors (untuk terminal yang support ANSI)
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m

# ==============================================================================
.PHONY: help
help:
	@echo ""
	@echo "NAS Project — Hybrid NAS (Contabo + Laptop)"
	@echo "============================================"
	@echo ""
	@echo "SETUP (jalankan sekali di awal):"
	@echo "  make setup-lokal        - Setup laptop rumah (Docker, Tailscale, FileBrowser)"
	@echo "  make setup-contabo      - Setup VPS Contabo (Nextcloud + Postgres + Redis)"
	@echo "  make setup-tunnel       - Setup Cloudflare Tunnel + Tailscale"
	@echo ""
	@echo "DAILY OPERATIONS:"
	@echo "  make local-up           - Nyalakan semua service di laptop (Docker, dll)"
	@echo "  make local-down         - Matikan service di laptop"
	@echo "  make contabo-up         - Nyalakan service di Contabo (via SSH)"
	@echo "  make contabo-down       - Matikan service di Contabo (via SSH)"
	@echo "  make status             - Cek status semua service (lokal + Contabo)"
	@echo ""
	@echo "ARCHIVE & STORAGE MANAGEMENT:"
	@echo "  make archive-now        - Trigger manual archive (Contabo --> HDD lokal)"
	@echo "  make archive-prepare    - SSH ke Contabo: pindah file >3 bulan ke folder Archive-Ready"
	@echo "  make archive-pull       - Tarik file dari folder Archive-Ready Contabo ke HDD lokal"
	@echo "  make archive-finalize   - Ganti file di Contabo dengan placeholder .archived.json"
	@echo "  make storage-check      - Cek pemakaian storage Contabo"
	@echo "  make storage-alert      - Trigger script alert kalau storage > 80%"
	@echo ""
	@echo "NEXTCLOUD MAINTENANCE (di Contabo via SSH):"
	@echo "  make nc-scan            - Trigger Nextcloud rescan files (after archive)"
	@echo "  make nc-occ CMD='...'   - Jalanin Nextcloud occ command (e.g. CMD='user:list')"
	@echo "  make nc-bash            - Bash shell ke container Nextcloud"
	@echo "  make nc-logs            - Tail log Nextcloud"
	@echo "  make nc-backup          - Backup database Nextcloud (postgres dump)"
	@echo ""
	@echo "TAILSCALE & TUNNEL:"
	@echo "  make tailscale-status   - Cek status Tailscale"
	@echo "  make tailscale-up       - Nyalakan Tailscale (laptop)"
	@echo "  make tunnel-status      - Cek status Cloudflare Tunnel"
	@echo ""
	@echo "FILEBROWSER (akses arsip dari luar):"
	@echo "  make fb-up              - Nyalakan FileBrowser"
	@echo "  make fb-down            - Matikan FileBrowser"
	@echo "  make fb-add-user U=name P=pass - Tambah user FileBrowser"
	@echo ""
	@echo "TROUBLESHOOTING:"
	@echo "  make verify-mount       - Cek apakah HDD external ter-mount benar"
	@echo "  make verify-tunnel      - Test koneksi Tailscale laptop <-> Contabo"
	@echo "  make logs-local         - Tail log Docker lokal"
	@echo "  make logs-contabo       - Tail log Docker Contabo"
	@echo ""
	@echo "GIT WORKFLOW:"
	@echo "  make ss                 - git status + log 10 commit terakhir"
	@echo "  make pull               - git pull + tampilkan 6 commit terakhir"
	@echo "  make push               - git push (pakai kredensial yang sudah di-config)"
	@echo "  make cmd m='msg'        - commit -am + push + tampilkan log"
	@echo "  make cal m='msg'        - git add . + commit -am + push (untuk file baru juga)"
	@echo "  make ff                 - git pull --no-ff"
	@echo ""
	@echo "Lihat README.md untuk panduan step-by-step setup awal."

# ==============================================================================
# SETUP
# ==============================================================================
.PHONY: setup-lokal setup-contabo setup-tunnel

setup-lokal:
	@echo "=== Setup Laptop Rumah ==="
	@echo "1. Cek prerequisites (Docker Desktop, PowerShell, Git)..."
	@docker --version
	@echo "2. Verifikasi HDD external ter-mount di $(HDD_MOUNT)..."
	@$(MAKE) verify-mount
	@echo "3. Copy .env.example ke .env kalau belum ada..."
ifeq ($(DETECTED_OS),Windows)
	@if (-not (Test-Path .env)) { Copy-Item .env.example .env; Write-Host 'Created .env - edit dulu!' -ForegroundColor Yellow; exit 1 }
else
	@[ -f .env ] || { cp .env.example .env; echo 'Created .env - edit dulu!'; exit 1; }
endif
	@echo "4. Generate SSH key untuk akses Contabo (kalau belum ada)..."
ifeq ($(DETECTED_OS),Windows)
	@if (-not (Test-Path $(CONTABO_SSH_KEY))) { ssh-keygen -t ed25519 -f $(CONTABO_SSH_KEY) -N '""' -C 'nas-archive' }
else
	@[ -f $(CONTABO_SSH_KEY) ] || ssh-keygen -t ed25519 -f $(CONTABO_SSH_KEY) -N '' -C 'nas-archive'
endif
	@echo "5. Pull Docker images..."
	@cd lokal && docker compose pull
	@echo ""
	@echo "Setup lokal SELESAI. Next steps:"
	@echo "  1. Copy SSH public key ke Contabo: ssh-copy-id -i $(CONTABO_SSH_KEY).pub $(CONTABO_USER)@$(CONTABO_HOST)"
	@echo "  2. Install Tailscale dari https://tailscale.com/download"
	@echo "  3. Run: make local-up"

setup-contabo:
	@echo "=== Setup VPS Contabo ==="
	@echo "Menjalankan installer di Contabo via SSH..."
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) 'bash -s' < contabo/scripts/install-prereqs.sh
	@echo ""
	@echo "Copy compose & scripts ke Contabo..."
	@scp -i $(CONTABO_SSH_KEY) -r contabo/ $(CONTABO_USER)@$(CONTABO_HOST):~/nas/
	@scp -i $(CONTABO_SSH_KEY) .env $(CONTABO_USER)@$(CONTABO_HOST):~/nas/.env
	@echo ""
	@echo "Start Nextcloud + Postgres + Redis..."
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) 'cd ~/nas && docker compose -f contabo/docker-compose.yml --env-file .env up -d'
	@echo ""
	@echo "Setup Contabo SELESAI. Akses Nextcloud di: http://$(CONTABO_HOST):8080"
	@echo "Lanjut: make setup-tunnel untuk expose ke domain HTTPS"

setup-tunnel:
	@echo "=== Setup Cloudflare Tunnel ==="
	@echo "Lihat docs/04-setup-tunnel.md untuk step-by-step."
	@echo ""
	@echo "Ringkasnya:"
	@echo "  1. Login Cloudflare, buat tunnel di dashboard"
	@echo "  2. Dapatkan tunnel token, simpan di .env sebagai CLOUDFLARE_TUNNEL_TOKEN"
	@echo "  3. Run: make contabo-up untuk start cloudflared di Contabo"

# ==============================================================================
# DAILY OPERATIONS — LOCAL (laptop)
# ==============================================================================
.PHONY: local-up local-down local-restart local-logs

local-up:
	@echo "=== Starting local services ==="
	@$(MAKE) verify-mount
	@cd lokal && docker compose --env-file ../.env up -d
	@echo ""
	@echo "Services started. Check status: make status"
	@echo "FileBrowser: http://localhost:8080"
	@echo "Syncthing UI: http://localhost:8384"

local-down:
	@cd lokal && docker compose --env-file ../.env down

local-restart: local-down local-up

local-logs:
	@cd lokal && docker compose --env-file ../.env logs -f --tail=100

# ==============================================================================
# DAILY OPERATIONS — CONTABO (via SSH)
# ==============================================================================
.PHONY: contabo-up contabo-down contabo-restart contabo-logs contabo-bash

contabo-up:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'cd ~/nas && docker compose -f contabo/docker-compose.yml --env-file .env up -d'

contabo-down:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'cd ~/nas && docker compose -f contabo/docker-compose.yml --env-file .env down'

contabo-restart: contabo-down contabo-up

contabo-logs:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'cd ~/nas && docker compose -f contabo/docker-compose.yml logs -f --tail=100'

contabo-bash:
	@ssh -t -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST)

# ==============================================================================
# STATUS & MONITORING
# ==============================================================================
.PHONY: status storage-check storage-alert

status:
	@echo "=== LOCAL Docker Status ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>$(if $(filter Windows,$(DETECTED_OS)),NUL,/dev/null) || echo "Docker tidak jalan / tidak ada container"
	@echo ""
	@echo "=== HDD Mount Check ==="
	@$(MAKE) verify-mount
	@echo ""
	@echo "=== CONTABO Docker Status ==="
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"' 2>$(if $(filter Windows,$(DETECTED_OS)),NUL,/dev/null) || echo "Tidak bisa SSH ke Contabo"
	@echo ""
	@echo "=== Storage Check ==="
	@$(MAKE) storage-check

storage-check:
	@echo "--- Disk usage Contabo ---"
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) 'df -h /'
	@echo ""
	@echo "--- Nextcloud data folder size ---"
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) 'du -sh $(NEXTCLOUD_DATA_PATH) 2>/dev/null || echo "Folder belum ada"'
ifeq ($(DETECTED_OS),Windows)
	@echo ""
	@echo "--- HDD external usage (lokal) ---"
	@if (Test-Path "$(HDD_MOUNT)") { Get-PSDrive -Name $(HDD_MOUNT)[0] | Format-Table Name, @{Name='Used(GB)';Expression={[math]::Round($$_.Used/1GB,2)}}, @{Name='Free(GB)';Expression={[math]::Round($$_.Free/1GB,2)}} }
endif

storage-alert:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) 'bash ~/nas/contabo/scripts/monitor-storage.sh'

# ==============================================================================
# ARCHIVE WORKFLOW (Skenario 2 + 3)
# ==============================================================================
.PHONY: archive-now archive-prepare archive-pull archive-finalize archive-dry-run

# Full archive workflow: prepare -> pull -> finalize
archive-now:
	@echo "=== ARCHIVE WORKFLOW START ==="
	@$(MAKE) verify-mount
	@$(MAKE) archive-prepare
	@$(MAKE) archive-pull
	@$(MAKE) archive-finalize
	@$(MAKE) nc-scan
	@echo "=== ARCHIVE WORKFLOW SELESAI ==="

# Step 1: Pindah file lama (>3 bulan atau yang user mark) ke folder Archive-Ready di Contabo
archive-prepare:
	@echo "--- Step 1: Prepare archive folder di Contabo ---"
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'bash ~/nas/contabo/scripts/archive-prepare.sh $(ARCHIVE_FOLDER)'

# Step 2: Tarik file dari Contabo ke HDD lokal via rclone (download bandwidth, fast)
archive-pull:
	@echo "--- Step 2: Pull files Contabo --> HDD lokal ---"
ifeq ($(DETECTED_OS),Windows)
	@powershell -ExecutionPolicy Bypass -File lokal/scripts/archive-pull.ps1
else
	@bash lokal/scripts/archive-pull.sh
endif

# Step 3: Setelah verified di lokal, ganti file di Contabo dengan placeholder .archived.json
archive-finalize:
	@echo "--- Step 3: Replace files Contabo dengan placeholder ---"
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'bash ~/nas/contabo/scripts/create-shortcuts.sh $(ARCHIVE_FOLDER)'

# Dry run — lihat apa yang AKAN dipindah tanpa benar-benar memindahkan
archive-dry-run:
	@echo "=== DRY RUN — tidak ada file yang di-archive ==="
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'bash ~/nas/contabo/scripts/archive-prepare.sh $(ARCHIVE_FOLDER) --dry-run'

# ==============================================================================
# NEXTCLOUD MAINTENANCE (Contabo)
# ==============================================================================
.PHONY: nc-scan nc-occ nc-bash nc-logs nc-backup nc-upgrade

# Rescan files setelah archive (biar Nextcloud DB sync sama filesystem)
nc-scan:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'docker exec --user www-data nas-nextcloud php occ files:scan --all'

# Run arbitrary occ command. Usage: make nc-occ CMD='user:list'
nc-occ:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		"docker exec --user www-data nas-nextcloud php occ $(CMD)"

nc-bash:
	@ssh -t -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'docker exec -it --user www-data nas-nextcloud bash'

nc-logs:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'docker logs -f --tail=200 nas-nextcloud'

# Backup database Postgres + config Nextcloud
nc-backup:
	@echo "Backup database & config Nextcloud..."
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'bash ~/nas/contabo/scripts/nextcloud-backup.sh'

nc-upgrade:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'cd ~/nas && docker compose -f contabo/docker-compose.yml pull nextcloud && docker compose -f contabo/docker-compose.yml up -d nextcloud'

# ==============================================================================
# FILEBROWSER (akses HDD lokal dari publik/Tailscale)
# ==============================================================================
.PHONY: fb-up fb-down fb-add-user fb-list-users

fb-up:
	@cd lokal && docker compose --env-file ../.env up -d filebrowser

fb-down:
	@cd lokal && docker compose --env-file ../.env stop filebrowser

fb-add-user:
	@docker exec nas-filebrowser /filebrowser users add $(U) $(P) --perm.admin=false

fb-list-users:
	@docker exec nas-filebrowser /filebrowser users ls

# ==============================================================================
# TAILSCALE
# ==============================================================================
.PHONY: tailscale-status tailscale-up tailscale-down tailscale-ip

tailscale-status:
ifeq ($(DETECTED_OS),Windows)
	@& 'C:/Program Files/Tailscale/tailscale.exe' status
else
	@tailscale status
endif

tailscale-up:
ifeq ($(DETECTED_OS),Windows)
	@& 'C:/Program Files/Tailscale/tailscale.exe' up --hostname=$(TAILSCALE_HOSTNAME)
else
	@sudo tailscale up --hostname=$(TAILSCALE_HOSTNAME)
endif

tailscale-down:
ifeq ($(DETECTED_OS),Windows)
	@& 'C:/Program Files/Tailscale/tailscale.exe' down
else
	@sudo tailscale down
endif

tailscale-ip:
ifeq ($(DETECTED_OS),Windows)
	@& 'C:/Program Files/Tailscale/tailscale.exe' ip -4
else
	@tailscale ip -4
endif

# ==============================================================================
# CLOUDFLARE TUNNEL
# ==============================================================================
.PHONY: tunnel-status tunnel-restart

tunnel-status:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'docker ps --filter name=cloudflared --format "{{.Names}}\t{{.Status}}"'

tunnel-restart:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'docker restart nas-cloudflared'

# ==============================================================================
# VERIFICATION & TROUBLESHOOTING
# ==============================================================================
.PHONY: verify-mount verify-tunnel verify-ssh verify-all logs-local logs-contabo

hdd: verify-mount

verify-mount:
ifeq ($(DETECTED_OS),Windows)
	@if (Test-Path "$(HDD_MOUNT)") { Write-Host "[OK] HDD mounted at $(HDD_MOUNT)" -ForegroundColor Green } else { Write-Host "[ERROR] HDD NOT mounted at $(HDD_MOUNT)" -ForegroundColor Red; exit 1 }
else
	@if mountpoint -q $(HDD_MOUNT) 2>/dev/null || [ -d "$(HDD_MOUNT)" ]; then echo "[OK] HDD mounted at $(HDD_MOUNT)"; else echo "[ERROR] HDD NOT mounted at $(HDD_MOUNT)"; exit 1; fi
endif

verify-ssh:
	@echo "Test SSH connection ke Contabo..."
	@ssh -i $(CONTABO_SSH_KEY) -o ConnectTimeout=5 $(CONTABO_USER)@$(CONTABO_HOST) 'echo "[OK] SSH connected: $$(hostname)"'

verify-tunnel:
	@echo "Test Tailscale ping ke Contabo..."
ifeq ($(DETECTED_OS),Windows)
	@& 'C:/Program Files/Tailscale/tailscale.exe' ping $(CONTABO_HOST)
else
	@tailscale ping $(CONTABO_HOST)
endif

verify-all: verify-mount verify-ssh verify-tunnel
	@echo "=== Semua verifikasi PASSED ==="

logs-local:
	@cd lokal && docker compose --env-file ../.env logs -f --tail=100

logs-contabo:
	@ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) \
		'cd ~/nas && docker compose -f contabo/docker-compose.yml logs -f --tail=100'

# ==============================================================================
# CLEANUP
# ==============================================================================
.PHONY: clean clean-local clean-contabo

clean-local:
	@echo "WARNING: Akan stop & remove semua container lokal (data volume tetap aman)"
ifeq ($(DETECTED_OS),Windows)
	@$$confirm = Read-Host "Type YES to confirm"; if ($$confirm -eq "YES") { cd lokal; docker compose --env-file ../.env down -v }
else
	@read -p "Type YES to confirm: " c && [ "$$c" = "YES" ] && cd lokal && docker compose --env-file ../.env down -v
endif

clean-contabo:
	@echo "WARNING: Akan stop & remove semua container Contabo (data volume tetap aman)"
ifeq ($(DETECTED_OS),Windows)
	@$$confirm = Read-Host "Type YES to confirm"; if ($$confirm -eq "YES") { ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) 'cd ~/nas && docker compose -f contabo/docker-compose.yml down -v' }
else
	@read -p "Type YES to confirm: " c && [ "$$c" = "YES" ] && ssh -i $(CONTABO_SSH_KEY) $(CONTABO_USER)@$(CONTABO_HOST) 'cd ~/nas && docker compose -f contabo/docker-compose.yml down -v'
endif

# ==============================================================================
# GIT WORKFLOW (mirror pattern dari C:/flask/Makefile)
# ==============================================================================
.PHONY: ss push pull cmd cal ff

ss:
	@git status
	@echo ""
	@echo "========== 10 COMMIT TERAKHIR =========="
ifeq ($(DETECTED_OS),Windows)
	@git log -10 --pretty=format:"%%h | %%ad | %%an <%%ae> | %%s" --date=format:"%%Y-%%m-%%d %%H:%%M"
else
	@git log -10 --pretty=format:"%h | %ad | %an <%ae> | %s" --date=format:"%Y-%m-%d %H:%M"
endif
	@echo ""
	@echo "========================================="

push:
	git push $(gittoken)

pull:
	git pull $(gittoken)
	@echo ""
	@echo "========== 6 COMMIT TERAKHIR =========="
ifeq ($(DETECTED_OS),Windows)
	@git log -6 --pretty=format:"%%h | %%ad | %%an <%%ae> | %%s" --date=format:"%%Y-%%m-%%d %%H:%%M"
else
	@git log -6 --pretty=format:"%h | %ad | %an <%ae> | %s" --date=format:"%Y-%m-%d %H:%M"
endif
	@echo ""
	@echo "========================================="

# Usage: make cmd m="commit message"
cmd:
	git commit -am "$m" --author="$(gituser) <$(gitemail)>"
	git push $(gittoken)
	@echo ""
	@echo "========== 10 COMMIT TERAKHIR =========="
ifeq ($(DETECTED_OS),Windows)
	@git log -10 --pretty=format:"%%h | %%ad | %%an <%%ae> | %%s" --date=format:"%%Y-%%m-%%d %%H:%%M"
else
	@git log -10 --pretty=format:"%h | %ad | %an <%ae> | %s" --date=format:"%Y-%m-%d %H:%M"
endif
	@echo ""
	@echo "========================================="

# Usage: make cal m="commit message" — staging file baru juga (git add .)
cal:
	git add .
	git commit -am "$m" --author="$(gituser) <$(gitemail)>"
	git push $(gittoken)

ff:
	git pull --no-ff $(gittoken)
