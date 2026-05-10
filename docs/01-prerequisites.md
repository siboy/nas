# Prerequisites — Yang Perlu Disiapkan Sebelum Setup

## Hardware

### HDD External (BELUM DIBELI)
- **Kapasitas**: 2 TB minimum, 4 TB rekomendasi
- **Tipe**: 
  - **WD Red Plus / Seagate IronWolf** (NAS-grade) — kalau mau nyala lama
  - **WD Elements / Seagate Expansion** (consumer) — kalau on/off pattern (lebih murah, awet untuk on-demand)
- **Estimasi harga (2026, Indonesia)**:
  - 2 TB external: Rp 700.000 - 900.000
  - 4 TB external: Rp 1.300.000 - 1.700.000

### Dock Station / USB Hub Powered
- **Wajib**: powered (ada adaptor power sendiri), bukan bus-powered
- **Pilihan**:
  - **USB Docking Station single-bay** (~Rp 200-400rb) — slot 1 HDD bare
  - **USB Hub powered 4-port** (~Rp 100-300rb) — kalau pakai HDD external biasa
  - **DAS (Direct Attached Storage) 2-bay** (~Rp 800rb-1.5jt) — kalau mau RAID 1

### Laptop
- Sudah ada (HOME personal). Spec apapun cukup, tapi:
  - RAM 4GB minimum (8GB ideal)
  - Free disk 20GB di SSD internal untuk Docker images & cache
  - 2 port USB (sudah confirmed user)

## Software

### Di Laptop
- [ ] **Docker Desktop** (Windows/macOS) atau Docker Engine (Linux)
  - Download: https://www.docker.com/products/docker-desktop
  - **Penting Windows**: Settings → Resources → File Sharing → tambahkan drive HDD external
- [ ] **Git** (untuk clone project & SSH keys)
  - Download: https://git-scm.com/download/win
- [ ] **rclone** (untuk archive transfer)
  - Windows: `winget install Rclone.Rclone`
  - Linux: `curl https://rclone.org/install.sh | bash`
- [ ] **Tailscale** (untuk VPN private)
  - Download: https://tailscale.com/download
- [ ] **Make** (Windows: GnuWin32 atau via Chocolatey: `choco install make`)
- [ ] **PowerShell 7+** (Windows; Windows PowerShell 5.1 juga ok)

### Di Contabo VPS
- Auto-installed via `make setup-contabo`:
  - Docker + Docker Compose plugin
  - rclone
  - jq, mailutils (untuk monitoring)
  - cron

## Akun & Service Online

### Cloudflare (untuk Tunnel)
- [ ] Akun Cloudflare gratis: https://dash.cloudflare.com/sign-up
- [ ] **Domain sendiri** — wajib (bisa beli murah di Cloudflare Registrar atau Namecheap, ~$10/tahun untuk .com, atau beli .id ~Rp 250rb/tahun)
- [ ] DNS domain di-pointing ke Cloudflare (via NS records di registrar)
- [ ] Setup tunnel di Cloudflare dashboard → dapatkan TUNNEL_TOKEN

### Tailscale
- [ ] Akun Tailscale gratis (sampai 100 device): https://login.tailscale.com/start
- [ ] Login dengan Google/Microsoft/GitHub
- [ ] Install di laptop & Contabo (via `make setup-*`)

### Contabo VPS (sudah ada)
- [ ] Verifikasi spec via control panel: RAM, storage, bandwidth limit
- [ ] Catat IP publik VPS
- [ ] Pastikan SSH access bekerja dengan key (bukan password)
- [ ] Sudah ada MySQL container `mysql-8` jalan (di project lain) — tidak akan diganggu

## Credentials yang Perlu Disiapkan

Buat file `.env` dari `.env.example`. Field yang perlu diisi:

```bash
# Contabo connection
CONTABO_HOST=your.vps.ip.or.hostname
CONTABO_USER=root  # atau user yang punya sudo
CONTABO_SSH_KEY=./ssh-keys/contabo_nas

# Local HDD
HDD_MOUNT=E:/nas-archive  # Windows: drive letter, Linux: /mnt/nas

# Nextcloud
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=GeneratePasswordKuat
NEXTCLOUD_TRUSTED_DOMAINS=localhost,nextcloud.yourdomain.com

# Database (auto-generated nanti, tapi siapkan password kuat)
POSTGRES_PASSWORD=AnotherStrongPassword
REDIS_PASSWORD=YetAnotherStrongPassword

# Cloudflare Tunnel
CLOUDFLARE_TUNNEL_TOKEN=eyJh...  # dari Cloudflare dashboard

# Domain
DOMAIN=nextcloud.yourdomain.com

# Email alert (opsional)
ALERT_EMAIL=your@email.com
```

## Tips Generate Password Kuat

```powershell
# Windows PowerShell
[System.Web.Security.Membership]::GeneratePassword(32, 4)

# atau
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
```

```bash
# Linux/macOS
openssl rand -base64 32
```

## Checklist Pre-Setup

Sebelum jalan `make setup-*`, pastikan:

- [ ] HDD external sudah dibeli & dicolok ke laptop
- [ ] HDD ter-format (NTFS Windows, atau ext4 Linux) — pastikan **bukan exFAT**
- [ ] Docker Desktop running
- [ ] HDD drive (E: atau dimanapun) sudah ditambahkan ke Docker File Sharing
- [ ] Akun Cloudflare ready, domain sudah ada
- [ ] Contabo VPS bisa di-SSH dengan key
- [ ] `.env` sudah diisi semua field (jangan commit!)
- [ ] Folder `ssh-keys/` writable

Lanjut ke: [02-setup-local.md](02-setup-local.md)
