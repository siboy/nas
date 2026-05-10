# Setup Laptop Rumah (Local)

Step-by-step setup laptop sebagai cold storage NAS.

## 1. Pasang HDD External

1. Colok HDD external via dock station ke USB laptop
2. Pastikan dock station ada power adaptor sendiri (kalau HDD 3.5")
3. Buka File Explorer, pastikan drive baru muncul (misal E:)
4. **Format HDD kalau baru**:
   - Windows: Right-click → Format → NTFS (bukan exFAT!)
   - Volume label: `NAS-ARCHIVE`
5. Buat folder utama: `E:\nas-archive`

## 2. Konfigurasi Windows Power Settings

**WAJIB** supaya HDD ga sleep saat idle:

1. **Settings → System → Power & battery**
   - "Screen and sleep" → set "Never" untuk "When plugged in"
2. **Control Panel → Power Options → Change plan settings → Change advanced power settings**
   - **Hard disk → Turn off after**: 0 (Never)
   - **USB settings → USB selective suspend**: Disabled (both AC & battery)

## 3. Install Docker Desktop

1. Download dari https://www.docker.com/products/docker-desktop
2. Install, restart jika diminta
3. Run Docker Desktop, pastikan running (icon di system tray)
4. **Penting**: Settings → Resources → File Sharing → tambahkan `E:\` (drive HDD)

Test:
```powershell
docker --version
docker compose version
```

## 4. Install Tools Lain

```powershell
# Via winget (Windows 11)
winget install Git.Git
winget install Rclone.Rclone
winget install GnuWin32.Make

# Tailscale
# Download manual dari https://tailscale.com/download
```

Atau via Chocolatey:
```powershell
choco install git rclone make tailscale
```

## 5. Clone / Buat Project Folder

Sudah ada di `C:\nas`. Verify:
```powershell
cd C:\nas
ls
# Harus ada: CLAUDE.md, Makefile, lokal\, contabo\, docs\, dll
```

## 6. Setup .env

```powershell
cp .env.example .env
notepad .env
```

Isi minimal:
- `CONTABO_HOST` = IP atau hostname Contabo VPS
- `CONTABO_USER` = root atau user dengan sudo
- `HDD_MOUNT` = `E:/nas-archive` (sesuaikan drive letter)
- `DOMAIN` = `nextcloud.yourdomain.com`

## 7. Generate SSH Key untuk Contabo

```powershell
make setup-lokal
```

Atau manual:
```powershell
ssh-keygen -t ed25519 -f .\ssh-keys\contabo_nas -N '""' -C 'nas-archive'

# Copy public key ke Contabo
type .\ssh-keys\contabo_nas.pub | ssh root@your-vps "cat >> ~/.ssh/authorized_keys"

# Test
ssh -i .\ssh-keys\contabo_nas root@your-vps 'hostname'
```

## 8. Setup Tailscale

```powershell
# Login Tailscale (akan buka browser)
& 'C:\Program Files\Tailscale\tailscale.exe' up --hostname=laptop-nas

# Cek status
& 'C:\Program Files\Tailscale\tailscale.exe' status

# Catat Tailscale IP laptop
& 'C:\Program Files\Tailscale\tailscale.exe' ip -4
```

## 9. Setup rclone Remote

Untuk akses Contabo via SFTP:

```powershell
rclone config
```

Pilih:
- `n` (new remote)
- name: `contabo-sftp`
- type: `sftp`
- host: `<CONTABO_HOST>` (atau Tailscale IP Contabo)
- user: `root`
- port: `22`
- key_file: `C:\nas\ssh-keys\contabo_nas`
- (semua advanced ke default)

Test:
```powershell
rclone ls contabo-sftp:/var/lib/docker/volumes/nas_nextcloud_data/_data/admin/files/
```

## 10. Verify Mount

```powershell
make verify-mount
```

Harus output: `[OK] HDD mounted at E:\nas-archive`

## 11. Start Local Services

```powershell
make local-up
```

Akses:
- FileBrowser: http://localhost:8080 (default user: admin / admin — segera ganti!)
- Syncthing: http://localhost:8384

Setup admin FileBrowser pertama:
```powershell
docker exec nas-filebrowser /filebrowser users add admin <password> --perm.admin=true
```

## 12. (Opsional) Auto-start saat Windows Boot

Buat shortcut `start-services.ps1` di Startup folder:

```powershell
# Cek path startup folder
shell:startup
```

Buat file `start-nas.bat` di sana:
```bat
@echo off
powershell -ExecutionPolicy Bypass -File "C:\nas\lokal\scripts\start-services.ps1"
```

Atau register sebagai Task Scheduler:
- Trigger: At log on
- Action: `powershell.exe -ExecutionPolicy Bypass -File C:\nas\lokal\scripts\start-services.ps1`
- Run with highest privileges (untuk Tailscale)

## Verifikasi Setup Lokal

```powershell
make status
make verify-all
```

Lanjut ke: [03-setup-contabo.md](03-setup-contabo.md)

## Troubleshooting

| Problem | Solusi |
|---|---|
| `docker: command not found` | Docker Desktop belum running, cek system tray |
| HDD tiba-tiba ga ke-mount | Disable USB Selective Suspend, cek dock station power |
| FileBrowser bisa diakses tapi folder kosong | Cek Docker File Sharing, restart Docker Desktop |
| Tailscale connect tapi ga bisa ping Contabo | Cek `tailscale status`, pastikan Contabo juga ada di tailnet |
| SSH key permission denied | Set permission: `icacls .\ssh-keys\contabo_nas /inheritance:r /grant:r "$($env:USERNAME):F"` |
