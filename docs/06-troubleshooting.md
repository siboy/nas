# Troubleshooting

Kumpulan masalah umum dan solusinya.

## Docker

### Container restart loop
```powershell
make local-logs    # cek error
docker logs nas-nextcloud --tail 100
```

Common causes:
- Permission issue volume → cek `docker exec ... ls -la /var/www/html`
- Database connection → pastikan postgres healthy: `docker exec nas-postgres pg_isready`
- Out of memory → `docker stats`

### "Cannot connect to Docker daemon"
- Windows: Docker Desktop tidak running, cek system tray
- Linux: `sudo systemctl start docker`

### Volume tidak ter-mount di container (Windows)
- Docker Desktop → Settings → Resources → File Sharing → tambahkan drive (e.g. `E:\`)
- Restart Docker Desktop

## HDD External

### HDD tiba-tiba ga ke-mount
1. Cek dock station nyala (LED hidup)
2. Cek di Disk Management (Windows) atau `lsblk` (Linux) — apakah disk dideteksi?
3. Coba colok ulang USB
4. Disable USB Selective Suspend (lihat docs/02-setup-local.md step 2)

### HDD muncul tapi read-only
- Windows: Right-click drive → Properties → Security → grant Full Control ke user
- NTFS bisa read-only kalau di-eject dari OS lain tanpa proper unmount

### Drive letter berubah-ubah
Set drive letter permanen:
- Disk Management → Right-click partition → Change drive letter → assign permanen (E:)
- Update `.env` HDD_MOUNT kalau perlu

## SSH ke Contabo

### Permission denied (publickey)
```powershell
# Test verbose
ssh -i .\ssh-keys\contabo_nas -v root@your-vps
```

Check:
1. Public key sudah ada di `~/.ssh/authorized_keys` Contabo:
   ```bash
   ssh root@your-vps  # via password (kalau masih bisa)
   cat ~/.ssh/authorized_keys
   ```
2. Permission file di laptop:
   ```powershell
   icacls .\ssh-keys\contabo_nas /inheritance:r /grant:r "$($env:USERNAME):F"
   ```
3. Permission di Contabo:
   ```bash
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ```

### SSH connection timeout
- Cek firewall Contabo: `ufw status`
- Cek Cloudflare proxy off untuk SSH (jangan proxy port 22)
- Coba via Tailscale IP: `ssh -i key root@100.x.x.x`

## Nextcloud

### "Internal Server Error"
```powershell
make nc-logs
```

Common causes:
- Permission issue: 
  ```powershell
  make contabo-bash
  docker exec --user root nas-nextcloud chown -R www-data:www-data /var/www/html
  ```
- Out of memory: cek `docker stats nas-nextcloud`, naikkan limit di compose

### "Untrusted domain" error
```powershell
make nc-occ CMD='config:system:set trusted_domains 2 --value="new.domain.com"'
```

### File upload gagal/limit
Edit `contabo/nextcloud-config/custom.config.php`, atau via php.ini di container:
```powershell
make contabo-bash
docker exec nas-nextcloud bash -c "echo 'upload_max_filesize=10G' >> /usr/local/etc/php/conf.d/uploads.ini"
docker exec nas-nextcloud bash -c "echo 'post_max_size=10G' >> /usr/local/etc/php/conf.d/uploads.ini"
docker restart nas-nextcloud
```

### Database connection error
```powershell
# Cek postgres healthy
make contabo-bash
docker exec nas-postgres pg_isready -U nextcloud

# Re-init kalau corrupt
make contabo-bash
docker exec nas-postgres psql -U nextcloud -c "SELECT version();"
```

### Slow performance
1. Enable APCu + Redis (sudah ada di custom.config.php)
2. Run `occ db:add-missing-indices`:
   ```powershell
   make nc-occ CMD='db:add-missing-indices'
   make nc-occ CMD='db:add-missing-columns'
   make nc-occ CMD='db:add-missing-primary-keys'
   ```
3. Pre-generate previews:
   ```powershell
   make nc-occ CMD='preview:generate-all -vvv'
   ```

## Tailscale

### "Logged out" status
```powershell
& 'C:\Program Files\Tailscale\tailscale.exe' up --hostname=laptop-nas
```

### Bisa ping IP tapi ga bisa SSH/HTTP
- Cek MagicDNS: `tailscale status` harus tampilkan hostname
- Cek ACL di Tailscale dashboard (default: all allowed)

### IP berubah setelah re-login
- Set hostname permanen via flag `--hostname=`
- Atau register node sebagai non-ephemeral di admin panel

## Cloudflare Tunnel

### Tunnel "DEGRADED" / "DOWN"
```powershell
make tunnel-status
make contabo-bash
docker logs nas-cloudflared --tail 50
```

Common: token expired/invalid. Re-create tunnel di dashboard, update token di `.env`, restart:
```powershell
make contabo-restart
```

### 502 Bad Gateway
- Backend service (Nextcloud) down → `make contabo-up`
- URL salah di tunnel config — harus `nas-nextcloud:80` (nama container Docker), bukan localhost

### 1033 Argo Tunnel Error
- Tunnel ID tidak match → re-create tunnel

## Archive Workflow

### `archive-prepare` tidak menemukan file
Cek path data Nextcloud:
```powershell
make contabo-bash
docker exec nas-nextcloud find /var/www/html/data -type d -name "files" | head
```

Update di `.env` kalau path beda:
```
NEXTCLOUD_ARCHIVE_USER=admin  # atau username lain
```

### `archive-pull` rclone error "no such host"
- rclone remote `contabo-sftp` belum di-config: `rclone config`
- Atau host tidak resolve, ganti ke IP

### Verify checksum gagal
- File di-modify selama transfer (race condition) — re-run pull
- Atau ada file rusak di sumber, cek log Contabo

### Storage tidak turun setelah archive-finalize
- File mentah masih ada di Trash Nextcloud:
  ```powershell
  make nc-occ CMD='trashbin:cleanup --all-users'
  ```
- File version masih disimpan:
  ```powershell
  make nc-occ CMD='versions:cleanup'
  ```

## FileBrowser

### "Permission denied" saat upload
```powershell
docker exec nas-filebrowser ls -la /srv
# Cek owner, harus writable
```

Fix: chmod via Windows GUI, atau `chmod -R 755 E:\nas-archive`.

### Upload file besar gagal
Edit `lokal/filebrowser/filebrowser.json`:
```json
{
  "commands": {
    "after_upload": []
  },
  "settings": {
    "uploadLimit": "10737418240"
  }
}
```

## .env & Environment Variables

### Variable tidak ke-load
- File harus exact `.env` (bukan `.env.txt`)
- Format: `KEY=value` (no space sekitar `=`)
- Special chars di value harus di-quote: `KEY="value with space"`

### Makefile error "missing separator"
- Tab vs space issue: Makefile WAJIB pakai TAB untuk indent recipe
- Edit di VS Code: bottom right pilih "Tab Size: 4" + indentation TAB

## Performance & Resource

### VPS Contabo lag
```powershell
make contabo-bash
htop  # cek CPU
free -h  # cek RAM
df -h  # cek disk
```

Common: disk penuh → archive sekarang, atau cleanup logs:
```bash
docker system prune -a  # hapus image & container ga terpakai
journalctl --vacuum-size=500M  # truncate log systemd
```

### Bandwidth Contabo terlampaui
Cek `vnstat -m` untuk usage bulanan. Limit 32TB jarang tercapai untuk personal.

## Recovery & Backup

### Database Nextcloud korup
1. Restore dari backup: `nas-backup` script terbaru di `~/nas/backups/`
2. Stop Nextcloud, restore DB, start ulang
3. `occ maintenance:repair`

### Lost SSH access ke Contabo
- Login via Contabo Web Console (VNC)
- Re-add SSH key ke `~/.ssh/authorized_keys`

### Lost data HDD external
- Kalau ada backup HDD ke-2: restore
- Kalau ga ada: data hilang permanen
- **Lesson**: selalu siapkan HDD ke-2 sebagai mirror untuk file kritis!

## Diagnostics Commands

```powershell
# All-in-one health check
make verify-all

# Detail status
make status

# Logs realtime
make logs-local       # laptop
make logs-contabo     # VPS

# Disk usage
make storage-check

# Container resource usage
docker stats --no-stream
```

Lanjut ke: [07-credentials-template.md](07-credentials-template.md)
