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

## Transfer File ke NAS (dari Mac/Linux via SMB + Tailscale)

Mac/Linux yang sudah join tailnet bisa mount folder NAS dan transfer file pakai `rsync` (built-in di macOS, no install). Skenario: offload file dari Mac yg storage-nya penuh ke folder NAS di PC.

### Mount SMB share di Mac

Finder → **Cmd+K** → masukkan:

```
smb://<TAILSCALE_IP_PC>/nas-archive
```

Username = Windows username PC, password = Windows password. Folder akan mount di `/Volumes/nas-archive`.

### Verify mount + permission write

```bash
mount | grep nas-archive                                    # cek mount point
touch /Volumes/nas-archive/test.txt && rm /Volumes/nas-archive/test.txt  # test write
```

### Transfer 1 file (sanity check)

```bash
cp ~/Desktop/file.jpg /Volumes/nas-archive/Photos/
```

### Bulk transfer pakai rsync

```bash
# Pattern dasar: -a (archive mode) -v (verbose) -h (human size) --progress
rsync -avh --progress ~/Pictures/Foto2024/ /Volumes/nas-archive/Photos/2024/

# CATATAN: trailing slash penting!
#   ~/Pictures/Foto2024/   → copy ISI folder
#   ~/Pictures/Foto2024    → copy folder ITU SENDIRI (extra nesting)
```

Real example (transfer multi-folder sekaligus):

```bash
# Bikin struktur dulu di NAS
mkdir -p /Volumes/nas-archive/Foto/{2024,2025,2026}
mkdir -p /Volumes/nas-archive/Documents/{Kerja,Pribadi}
mkdir -p /Volumes/nas-archive/Video

# Transfer per kategori
rsync -avh --progress ~/Pictures/  /Volumes/nas-archive/Foto/
rsync -avh --progress ~/Documents/ /Volumes/nas-archive/Documents/
rsync -avh --progress ~/Movies/    /Volumes/nas-archive/Video/
```

### Verify sebelum hapus dari Mac (penting!)

```bash
# Bandingkan jumlah file & total size
echo "Source files:" && find ~/Pictures -type f | wc -l
echo "Dest files:"   && find /Volumes/nas-archive/Foto -type f | wc -l
echo "Source size:"  && du -sh ~/Pictures
echo "Dest size:"    && du -sh /Volumes/nas-archive/Foto
```

Kalau jumlah file & size **sama** → safe untuk hapus dari Mac.

### Hapus dari Mac setelah verified

```bash
# HATI-HATI: rm tidak ke Trash, irreversible
rm -rf ~/Pictures/Foto2024

# SAFER: pakai Finder (Cmd+Delete) yang move ke Trash, bisa di-recover
```

### Tips & gotchas

- **Tailscale stay ON** di PC & Mac selama transfer
- **Jangan tutup PC** mid-transfer — set Power Settings → "Never sleep"
- **Tailscale direct (P2P)** jauh lebih cepat dari DERP relay; cek dengan `tailscale ping <hostname>` (kalau ada `via direct` = bagus, `via DERP` = relay)
- **rsync resume otomatis** kalau diulang dengan flag yang sama (skip file yg sudah identik)
- Estimasi: 10GB ~3-5 menit (LAN direct), 50GB ~15-25 menit (LAN direct)

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
