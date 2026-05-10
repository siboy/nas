# NAS Project — Konteks untuk Claude

Project ini adalah self-hosted NAS hybrid yang menggantikan Google Drive + Google Photos, dengan strategi **hot/cold storage tier** antara VPS Contabo (hot, online 24/7) dan laptop rumah + HDD external (cold, on-demand archive).

## Tujuan Utama

1. **Replace Google Drive**: file sync + sharing + kolaborasi via Nextcloud
2. **Replace Google Photos**: timeline foto + search + auto-backup HP via Nextcloud + Memories app (atau Immich nanti kalau butuh)
3. **Hemat biaya storage**: tidak perlu upgrade storage Contabo selamanya — file lama otomatis pindah ke HDD external di rumah
4. **Akses dari luar internet**: kolaborator/keluarga bisa upload/download tanpa install software (via Cloudflare Tunnel)

## Arsitektur

```
┌──────────────────────────┐                ┌──────────────────────────┐
│  VPS Contabo (HOT)       │                │  Laptop Rumah (COLD)     │
│  - Nextcloud aktif       │  ── tarik ──→  │  - Docker + Syncthing    │
│  - File <3 bulan         │   per 3 bulan  │  - FileBrowser           │
│  - 120GB working         │   atau saat    │  - HDD external (2TB+)   │
│  - 6GB RAM               │   penuh        │  - On-demand (on/off)    │
└──────────────────────────┘                └──────────────────────────┘
         ↑                                              ↑
         │ daily user access                            │ akses arsip
         │ (Cloudflare Tunnel)                          │ (Tailscale/CFTunnel)
         │                                              │
         └─────────── User: HP, Laptop, Web ────────────┘
```

**Komponen:**
- **Contabo VPS**: Nextcloud + PostgreSQL + Redis (di Docker), expose via Cloudflare Tunnel
- **Laptop rumah**: Docker dengan Syncthing (sync 2-arah) + FileBrowser (UI untuk akses arsip) + rclone (untuk archive pull)
- **Tailscale**: private network antara laptop dan VPS untuk koneksi aman
- **Cloudflare Tunnel**: expose service ke publik tanpa port forward

## Spesifikasi Resources

**Contabo VPS (existing):**
- RAM: 6 GB
- Storage: 120 GB
- Bandwidth: 32 TB/bulan (bukan masalah, jauh lebih dari cukup)
- OS: Linux (Ubuntu/Debian)
- **MySQL container sudah jalan** di `mysql-8` (lihat `C:\flask\containers\flask-mysql\docker-compose.dev.yml`)
  - Network: `${NETWORK}` (external, biasanya `my-network`)
  - **Tidak dipakai untuk Nextcloud** — Nextcloud lebih cocok pakai PostgreSQL

**Laptop rumah:**
- Spec personal HOME (belum spesifik)
- Pola pemakaian: **on/off, bukan 24/7** (nyala saat di rumah, mati saat dibawa)
- Storage: **HDD external belum dibeli** — rencana via dock station USB
- 2 port USB → kemungkinan pakai USB hub powered atau dock station

## 4 Skenario Utama

### Skenario 1 — Setup laptop dengan Docker + HDD mountable
- Laptop jalankan Docker dengan service: Syncthing, FileBrowser, optional SFTP
- HDD external mount ke OS (drive letter di Windows), lalu di-mount ke container Docker via volume
- Service di laptop expose lewat Tailscale supaya bisa diakses dari Contabo (VPS bisa "lihat" HDD lokal via SFTP/WebDAV)

### Skenario 2 — Contabo sebagai penampung sementara + shortcut/placeholder
- Nextcloud di Contabo simpan file aktif (yang sering diakses)
- File yang sudah di-archive ke HDD rumah → di Nextcloud diganti **placeholder file** (`.archived.json`) yang berisi metadata: nama file asli, ukuran, lokasi di HDD, tanggal archive
- User browse Nextcloud tetap lihat struktur folder lengkap, tapi file lama berupa shortcut (bukan file mentah)

### Skenario 3 — Auto-sync saat Docker lokal nyala
- Saat Docker di laptop nyala → trigger script `archive-pull`
- Script: SSH ke Contabo → pilih file lama (>3 bulan atau di folder `Archive-Ready`) → tarik via rclone ke HDD → ganti dengan placeholder di Contabo → update Nextcloud DB (`occ files:scan`)
- Bisa manual (`make archive-now`) atau otomatis saat penuh (alert dari `monitor-storage`)

### Skenario 4 — HDD lokal accessible dari luar untuk upload
- **FileBrowser** di laptop expose folder HDD via web UI dengan auth
- Akses via:
  - **Cloudflare Tunnel** (publik, browser-based, no install) → user awam
  - **Tailscale** (private VPN) → kolaborator teknis
- User bisa upload langsung ke HDD (bypass Contabo storage limit) — cocok untuk file besar
- Atau upload ke Contabo Nextcloud → otomatis sync ke HDD saat laptop nyala

## Struktur Folder Project

```
C:\nas\
├── CLAUDE.md                 # File ini
├── README.md                 # Panduan setup untuk user
├── Makefile                  # Entry point semua command
├── .env.example              # Template environment variables
├── .gitignore
├── lokal/                    # Setup untuk laptop rumah (Windows/Linux)
│   ├── docker-compose.yml    # Syncthing + FileBrowser + cloudflared
│   ├── filebrowser/
│   │   └── filebrowser.json  # Config FileBrowser
│   └── scripts/
│       ├── archive-pull.sh         # Tarik archive dari Contabo (Linux/WSL/Git Bash)
│       ├── archive-pull.ps1        # Versi PowerShell
│       ├── verify-mount.ps1        # Cek HDD mounted (Windows)
│       └── start-services.ps1      # Start Docker + Tailscale
├── contabo/                  # Setup untuk VPS Contabo (Linux)
│   ├── docker-compose.yml    # Nextcloud + Postgres + Redis + cloudflared
│   ├── nginx/
│   │   └── nextcloud.conf
│   └── scripts/
│       ├── install-prereqs.sh      # Install Docker, rclone, dll
│       ├── archive-prepare.sh      # Pindah file lama ke folder Archive-Ready
│       ├── create-shortcuts.sh     # Replace file dengan placeholder JSON
│       ├── monitor-storage.sh      # Alert kalau disk > 80%
│       └── nextcloud-occ.sh        # Wrapper untuk Nextcloud CLI
├── docs/
│   ├── 00-architecture.md
│   ├── 01-prerequisites.md
│   ├── 02-setup-local.md
│   ├── 03-setup-contabo.md
│   ├── 04-setup-tunnel.md
│   ├── 05-archive-workflow.md
│   ├── 06-troubleshooting.md
│   └── 07-credentials-template.md
└── ssh-keys/                 # Tempat SSH key (gitignored)
    └── .gitkeep
```

## Keputusan Teknis Penting (sudah didiskusikan)

| Topik | Keputusan | Alasan |
|---|---|---|
| Software NAS utama | **Nextcloud** | Mature, kolaborasi, share link, mobile app, foto support |
| Database Nextcloud | **PostgreSQL** (bukan MySQL eksisting) | Recommended Nextcloud, isolasi dari MySQL bisnis lain |
| File server lokal | **FileBrowser** | Lightweight, web UI bagus, permission per user |
| Sync laptop-VPS | **rclone** (scheduled) bukan live mount | Live mount lambat dan tidak reliable lintas benua |
| Tunnel laptop ↔ VPS | **Tailscale** | Bypass CGNAT, simple, gratis |
| Akses publik | **Cloudflare Tunnel** | No port forward, HTTPS otomatis, gratis |
| Archive trigger | **Folder `Archive-Ready`** (manual move) atau date-based | Predictable, user kontrol penuh |
| Shortcut file | **`.archived.json`** placeholder | Lightweight, mudah parse, kompatibel dengan Nextcloud |
| OS laptop | Windows (current) | Bisa upgrade ke WSL2/Linux nanti kalau perlu |

## Yang Sudah Dipertimbangkan & Ditolak

- ❌ **Live mount HDD lokal ke Nextcloud Contabo via SFTP**: terlalu lambat (latency Indonesia↔Eropa 200ms+), unreliable kalau internet rumah putus, browse folder bisa timeout. **Pakai sync, bukan mount.**
- ❌ **Immich di Contabo**: butuh RAM 6-8GB minimum + AI workload berat, tidak optimal di VPS 6GB yang juga jalankan Nextcloud. Bisa di-add nanti kalau Contabo upgrade RAM.
- ❌ **Nextcloud pakai MySQL eksisting**: walaupun bisa, lebih bersih pakai DB terpisah (PostgreSQL) supaya isolasi & compatibility maksimal.
- ❌ **Laptop nyala 24/7**: tidak realistis untuk laptop personal, boros listrik. Strategi cold storage sudah accommodate ini.
- ❌ **Buy mini PC dulu**: sudah punya VPS Contabo, leverage dulu yang ada. Mini PC bisa jadi upgrade path nanti kalau pola pemakaian berubah.

## Alur Kerja User Sehari-hari

**Saat laptop NYALA (di rumah, malam hari):**
1. Service Docker auto-start (Syncthing, FileBrowser, cloudflared)
2. Tailscale connect ke VPS Contabo
3. Trigger `make archive-pull` (manual atau scheduled) kalau Contabo storage > 70%
4. Foto/file baru di Nextcloud → otomatis sync ke HDD via Syncthing
5. User bisa akses arsip lama via FileBrowser (LAN: `http://192.168.x.x:8080`, atau publik via Cloudflare)

**Saat laptop MATI (di luar rumah):**
1. User tetap bisa upload/download via Nextcloud Contabo (URL: `https://nextcloud.domain.com`)
2. File arsip lama berupa placeholder `.archived.json` — kalau diklik, kasih info: "file ini ada di HDD rumah, akses tersedia saat laptop nyala jam 19:00-23:00"
3. Upload baru masuk ke Contabo, akan di-sync ke HDD saat laptop nyala lagi

## Status Progress (untuk Claude di sesi mendatang)

- ✅ **Project planning**: arsitektur, tools, scenarios — DONE
- ✅ **Folder skeleton & docs**: dibuat di `C:\nas\` — DONE
- ✅ **Setup laptop (Docker)**: FileBrowser + Syncthing JALAN per 2026-05-10
  - Docker Desktop 29.4.2 (Windows + WSL2 backend)
  - `nas-filebrowser` di :8080 — default user `admin`, password generated saat init (lihat `docker logs nas-filebrowser`), wajib diganti via UI
  - `nas-syncthing` di :8384 — belum diset password GUI
  - HDD path SEMENTARA: `C:/nas-archive-test` (folder dummy di SSD); ganti `HDD_MOUNT` di `.env` saat HDD beneran tersedia
  - `.env` sudah di-generate dengan password random aman (Postgres/Redis/Nextcloud admin) — hanya komponen lokal yg aktif
- ⏳ **HDD external & dock station**: BELUM DIBELI — pakai folder dummy untuk testing
- 🟡 **Setup Contabo (Nextcloud)**: PARTIAL per 2026-05-10
  - SSH access OK via key di laptop (lihat `CONTABO_SSH_KEY` di `.env`); user di server: `ubuntu`; alias VS Code SSH config: `vm-vps1`; alias var `vm-vps1root` ada juga untuk root tapi belum di-test
  - VPS = Ubuntu 22.04.5 LTS
  - Repo project sudah di-clone ke `/home/ubuntu/nas` via `git clone https://github.com/siboy/nas.git` (publik) — siap untuk `git pull` saat ada update
  - `.env` sudah di-scp ke `/home/ubuntu/nas/.env` (gitignored, harus selalu scp manual setiap berubah)
  - Tailscale 1.96.4 sudah terinstall di Contabo (hostname `contabo-nas`, IP & DNS name di `.env`)
  - **Belum dijalankan:** Docker install, postgres+redis+nextcloud start, Cloudflare tunnel
  - **Workflow update:** edit di laptop → commit → push → SSH ke Contabo → `cd ~/nas && git pull` (untuk file non-secret) + scp .env (kalau .env berubah)
- ✅ **Tailscale**: terinstall & terkonek per 2026-05-10 — laptop, HP, Contabo semua di tailnet yang sama
  - Version 1.96.x (Linux Contabo via install.sh, Windows laptop via GUI, Android HP via Play Store)
  - Tailnet name, account login, IP & hostname semua device → simpan di `.env` (lihat var `TAILSCALE_*`), JANGAN commit ke git
  - Hostname laptop di tailnet = default Windows machine name (flag `--hostname=laptop-nas` belum dipakai karena install via GUI, bukan `make tailscale-up`); Contabo dengan flag `--hostname=contabo-nas`
  - Catatan health (laptop): MagicDNS gagal set (Access denied) karena GUI tidak run elevated — pakai IP langsung untuk routing antar device
  - **Verified working:**
    - HP berhasil akses FileBrowser laptop via Tailscale IP port 8080 (P2P direct, bukan relay) bahkan saat data seluler di luar WiFi
    - Laptop SSH ke Contabo via Tailscale IP berhasil (latency ~27ms direct dari Indonesia ↔ Eropa, bukan via DERP)
- ⏳ **Cloudflare account & domain**: perlu konfirmasi user (apakah sudah punya domain?)

## Untuk Claude di Sesi Berikutnya

Saat user buka folder ini di sesi baru:
1. **Baca dulu** `docs/00-architecture.md` untuk visualisasi flow
2. **Cek status** progress di section atas — fase mana yang sudah done
3. **Tanya user**: "Sudah beli HDD external belum? Sudah punya akun Tailscale & Cloudflare?"
4. **Jangan langsung eksekusi** `make setup-*` sebelum konfirmasi user — beberapa command butuh credential yang harus diisi user dulu (`.env`)
5. **Reference setup MySQL eksisting**: `C:\flask\containers\flask-mysql\` — pattern Docker user, secrets file di `db/password.txt`, network external
6. **Style Makefile mengikuti** pattern di `C:\mtk\Makefile` (banyak target dengan prefix per service, autostart pakai tmux untuk yang persistent)

## Referensi & Link

- Nextcloud Docker: https://hub.docker.com/_/nextcloud
- FileBrowser: https://filebrowser.org/
- Syncthing: https://syncthing.net/
- Tailscale: https://tailscale.com/
- Cloudflare Tunnel: https://www.cloudflare.com/products/tunnel/
- rclone: https://rclone.org/
