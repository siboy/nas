# Setup Contabo VPS

Step-by-step setup Nextcloud + Postgres + Redis di VPS Contabo.

## Prerequisites

- VPS Contabo aktif, bisa di-SSH dengan key
- `.env` di laptop sudah diisi (`CONTABO_HOST`, `CONTABO_USER`, dll)
- SSH key sudah di-generate (`make setup-lokal` di laptop)
- SSH public key sudah di-copy ke `~/.ssh/authorized_keys` di Contabo

## 1. Test SSH Connection

Dari laptop:
```powershell
make verify-ssh
```

Harus output: `[OK] SSH connected: <hostname-contabo>`

Kalau gagal:
```powershell
ssh -i .\ssh-keys\contabo_nas -v root@your-vps  # verbose mode untuk debug
```

## 2. Install Prerequisites di Contabo

```powershell
make setup-contabo
```

Ini akan:
1. SSH ke Contabo, jalankan `install-prereqs.sh`:
   - Update apt packages
   - Install Docker, Docker Compose, rclone, jq, mailutils
2. Copy folder `contabo/` & `.env` ke `~/nas/` di Contabo
3. Start service Docker (Nextcloud + Postgres + Redis + Cloudflared)

**Cek manual kalau perlu:**
```powershell
make contabo-bash
# Sekarang di Contabo
cd ~/nas
ls -la
docker ps
```

## 3. Verify MySQL Eksisting Tidak Terganggu

Penting karena Contabo sudah punya MySQL container `mysql-8` di network lain:

```powershell
make contabo-bash
docker ps --filter name=mysql
# mysql-8 harus tetap jalan, network terpisah
```

NAS network: `nas-net` (terisolasi dari `${NETWORK}` MySQL bisnis).

## 4. Initial Setup Nextcloud (Web UI)

Tunggu ~30 detik supaya container ready, lalu:

```
http://<CONTABO_HOST>:8080
```

Login dengan:
- Username: `${NEXTCLOUD_ADMIN_USER}` (dari .env)
- Password: `${NEXTCLOUD_ADMIN_PASSWORD}`

Wizard akan auto-detect database (PostgreSQL connected via env vars).

Klik "Install".

## 5. Tuning Nextcloud Post-Install

Via Makefile:

```powershell
# Set default phone region
make nc-occ CMD='config:system:set default_phone_region --value="ID"'

# Disable some apps yang ga perlu (untuk hemat resource)
make nc-occ CMD='app:disable dashboard'
make nc-occ CMD='app:disable firstrunwizard'

# Install apps yang berguna
make nc-occ CMD='app:install memories'        # Photo timeline (mirip Google Photos)
make nc-occ CMD='app:install previewgenerator' # Pre-generate thumbnails

# Run cron manual sekali
make nc-occ CMD='maintenance:repair'
```

## 6. Buat User untuk Kolaborasi

Lewat Web UI:
- Login admin → Settings → Users → New user

Atau via CLI:
```powershell
make nc-occ CMD='user:add --display-name="Andi" andi'
# Akan prompt password (atau pakai --password-from-env=PASS)
```

## 7. Setup Cloudflare Tunnel

### A. Buat Tunnel di Cloudflare Dashboard

1. Login https://one.dash.cloudflare.com
2. Networks → Tunnels → Create a tunnel
3. Pilih "Cloudflared", beri nama: `nas-contabo`
4. Save tunnel → copy **token** yang muncul
5. Public hostname:
   - Subdomain: `nextcloud`
   - Domain: `yourdomain.com`
   - Service: `HTTP` `nas-nextcloud:80`
6. Save

### B. Update .env dengan Token

```powershell
notepad .env
```

Tambah:
```
CLOUDFLARE_TUNNEL_TOKEN=eyJhbGciOiJIUzI1NiIs...
DOMAIN=nextcloud.yourdomain.com
```

### C. Restart Contabo Services

```powershell
make contabo-restart
```

### D. Update Trusted Domains di Nextcloud

```powershell
make nc-occ CMD='config:system:set trusted_domains 0 --value="nextcloud.yourdomain.com"'
make nc-occ CMD='config:system:set trusted_domains 1 --value="<CONTABO_IP>"'
make nc-occ CMD='config:system:set overwrite.cli.url --value="https://nextcloud.yourdomain.com"'
make nc-occ CMD='config:system:set overwriteprotocol --value="https"'
```

### E. Test Akses

Buka https://nextcloud.yourdomain.com — harus redirect ke login Nextcloud dengan HTTPS valid.

## 8. Setup Tailscale di Contabo (untuk SSH internal & archive)

```powershell
make contabo-bash
# Di Contabo
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=contabo-nas

# Catat Tailscale IP
tailscale ip -4
```

Sekarang bisa akses Contabo dari laptop via Tailscale IP (lebih aman dari publik).

## 9. Setup Cron untuk Monitoring (Opsional)

Di Contabo:
```bash
crontab -e
```

Tambah:
```
# Cek storage tiap pagi jam 8
0 8 * * * /root/nas/contabo/scripts/monitor-storage.sh >> /root/nas/logs/storage.log 2>&1

# Backup Nextcloud DB tiap minggu (Sabtu 2 pagi)
0 2 * * 6 /root/nas/contabo/scripts/nextcloud-backup.sh >> /root/nas/logs/backup.log 2>&1
```

## 10. Verifikasi Setup Contabo

```powershell
make status
```

Output yang diharapkan:
- `nas-nextcloud`: Up
- `nas-postgres`: Up (healthy)
- `nas-redis`: Up (healthy)
- `nas-cloudflared`: Up
- `nas-nextcloud-cron`: Up

## 11. Test Upload File

1. Login ke `https://nextcloud.yourdomain.com`
2. Upload file kecil (test.txt)
3. Verify di Contabo:
   ```powershell
   make contabo-bash
   ls /var/lib/docker/volumes/nas_nextcloud_data/_data/admin/files/
   ```

## Memori & Performance Tuning

VPS dengan 6GB RAM jalankan: Nextcloud (~500MB) + Postgres (~200MB) + Redis (~50MB) + cron (~200MB) + cloudflared (~50MB) = ~1GB. Sisa 5GB untuk OS & buffer.

Untuk performa lebih baik, edit `contabo/nextcloud-config/custom.config.php`:
```php
'redis' => [
    'host' => 'redis',
    'port' => 6379,
    'password' => 'your-redis-password',
],
'cache_path' => '/var/www/html/data/cache',
```

Restart:
```powershell
make contabo-restart
```

Lanjut ke: [04-setup-tunnel.md](04-setup-tunnel.md)

## Troubleshooting

| Problem | Solusi |
|---|---|
| Nextcloud "Internal Server Error" | `make nc-logs`, biasanya permission issue di volume |
| Database connection failed | Cek `nas-postgres` healthy: `docker exec nas-postgres pg_isready` |
| "Untrusted domain" error | Update `trusted_domains` (lihat step 7D) |
| Cloudflare tunnel ga konek | Cek token benar, cek `make tunnel-status` |
| Disk penuh tiba-tiba | `make storage-check`, biasanya log Nextcloud, rotate atau truncate |
