# NAS Project — Self-hosted Hybrid NAS

Self-hosted NAS yang menggabungkan **VPS Contabo (hot storage, online 24/7)** + **laptop rumah dengan HDD external (cold archive)**. Menggantikan Google Drive + Google Photos dengan biaya minimum dan kontrol penuh atas data.

## Arsitektur Singkat

```
User → Cloudflare Tunnel → Nextcloud @ Contabo (file aktif <3 bulan)
                                ↓
                        Quarterly archive
                                ↓
                    HDD External @ Laptop Rumah (file lama)
```

## Quickstart

### Prasyarat (lihat [docs/01-prerequisites.md](docs/01-prerequisites.md))
- HDD external + dock station USB
- Akun Cloudflare + domain
- Akun Tailscale (gratis)
- VPS Contabo (sudah ada)
- Laptop dengan Docker Desktop

### Setup Sekali Saja
```powershell
# 1. Copy & isi .env
cp .env.example .env
notepad .env

# 2. Setup laptop rumah
make setup-lokal

# 3. Setup VPS Contabo
make setup-contabo

# 4. Setup tunnel (Cloudflare)
make setup-tunnel
```

### Daily Operations
```powershell
make local-up        # Nyalakan service di laptop
make contabo-up      # Nyalakan service di Contabo
make status          # Cek status semua
```

### Archive (Per 3 Bulan atau Saat Penuh)
```powershell
make archive-now     # Workflow lengkap: prepare + pull + finalize
```

### Lihat Semua Command
```powershell
make help
```

## Struktur Project

```
C:\nas\
├── CLAUDE.md                 # Konteks untuk Claude (baca ini di sesi baru)
├── README.md                 # File ini
├── Makefile                  # Entry point semua command
├── .env.example              # Template environment variables
├── .gitignore
├── lokal/                    # Service yang jalan di laptop rumah
│   ├── docker-compose.yml    # FileBrowser + Syncthing
│   ├── filebrowser/          # Config FileBrowser
│   └── scripts/              # Archive scripts (PowerShell + Bash)
├── contabo/                  # Service yang jalan di VPS Contabo
│   ├── docker-compose.yml    # Nextcloud + Postgres + Redis + cloudflared
│   ├── nextcloud-config/     # Override Nextcloud config
│   └── scripts/              # Archive prepare, finalize, monitoring
├── docs/                     # Dokumentasi step-by-step
│   ├── 00-architecture.md
│   ├── 01-prerequisites.md
│   ├── 02-setup-local.md
│   ├── 03-setup-contabo.md
│   ├── 04-setup-tunnel.md
│   ├── 05-archive-workflow.md
│   ├── 06-troubleshooting.md
│   └── 07-credentials-template.md
└── ssh-keys/                 # SSH keys untuk Contabo (gitignored)
```

## Status Project

⚠️ **BELUM DIDEPLOY** — folder ini berisi planning + scripts ready-to-run.

Sebelum jalan, pastikan:
- [ ] HDD external sudah dibeli & dicolok
- [ ] `.env` sudah diisi dengan credential asli
- [ ] Domain Cloudflare sudah ready
- [ ] VPS Contabo bisa di-SSH

Lalu jalankan urutan:
1. `make setup-lokal`
2. `make setup-contabo`
3. `make setup-tunnel`
4. Test upload file via Nextcloud
5. Setelah 3 bulan: `make archive-now`

## Command Cheatsheet

| Command | Deskripsi |
|---|---|
| `make help` | Lihat semua command tersedia |
| `make setup-lokal` | Setup laptop (Docker, SSH, dll) |
| `make setup-contabo` | Setup VPS Contabo (Nextcloud) |
| `make local-up/down` | Start/stop service di laptop |
| `make contabo-up/down` | Start/stop service di Contabo |
| `make status` | Cek status semua service |
| `make archive-now` | Pindahkan file lama Contabo → HDD |
| `make storage-check` | Cek pemakaian disk Contabo |
| `make nc-occ CMD='...'` | Run Nextcloud CLI command |
| `make nc-backup` | Backup database Nextcloud |
| `make verify-all` | Test semua koneksi (HDD, SSH, Tailscale) |

## Kenapa Approach Ini?

Vs alternatif:
- ❌ **Google Drive berbayar**: Rp 30.000/bulan untuk 100GB → Rp 360k/tahun, ga ada batas atas (terus subscribe)
- ❌ **Sewa NAS storage cloud**: $10-20/bulan, lock-in vendor
- ❌ **Beli NAS appliance (Synology/QNAP)**: Rp 5jt+ upfront
- ❌ **Mini PC home server**: Rp 2-3jt + butuh listrik 24/7
- ✅ **Hybrid VPS + HDD lokal** (ini): leverage VPS yang sudah ada, HDD sekali bayar (~Rp 700rb-1.5jt), no recurring untuk storage tambahan

## Acknowledgements & References

- [Nextcloud Docker](https://hub.docker.com/_/nextcloud)
- [FileBrowser](https://filebrowser.org/)
- [rclone](https://rclone.org/)
- [Tailscale](https://tailscale.com/)
- [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)

## Documentation

Semua docs ada di folder `docs/`. Mulai dari [00-architecture.md](docs/00-architecture.md).

---

**Untuk Claude di sesi baru**: baca [CLAUDE.md](CLAUDE.md) terlebih dahulu untuk dapat konteks lengkap.
