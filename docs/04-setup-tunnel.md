# Setup Tunnel & Akses Dari Luar

Panduan setup Tailscale (private VPN) + Cloudflare Tunnel (public HTTPS) untuk akses NAS dari mana saja.

## Tailscale — Private VPN antara Laptop & Contabo

### Kenapa butuh?
- Laptop ↔ Contabo komunikasi aman (tanpa expose port di rumah)
- Bypass CGNAT (ISP rumah ga kasih IP publik)
- SSH lebih aman (Tailscale IP dibanding publik)
- Untuk `archive-pull` jalan dari laptop tarik ke Contabo

### Setup di Laptop
```powershell
# Install (jika belum)
winget install Tailscale.Tailscale

# Login
& 'C:\Program Files\Tailscale\tailscale.exe' up --hostname=laptop-nas

# Cek status
make tailscale-status
```

### Setup di Contabo
```powershell
make contabo-bash
# Di Contabo:
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --hostname=contabo-nas

# Catat IP
tailscale ip -4
# Contoh output: 100.64.10.5
```

### Update .env (Opsional, untuk pakai Tailscale IP)
```
CONTABO_HOST=100.64.10.5  # Tailscale IP, bukan publik
```

Keuntungan: SSH & rclone lewat private network, lebih cepat & aman.

### Test
```powershell
make verify-tunnel
```

## Cloudflare Tunnel — Public HTTPS Access

### Kenapa butuh?
- User awam bisa akses Nextcloud via browser (no VPN install)
- HTTPS otomatis
- No port forward di Contabo
- Anti-DDoS bonus dari Cloudflare

### Prerequisites
- Akun Cloudflare (gratis)
- Domain sendiri yang DNS-nya di-manage Cloudflare

### Step 1: Daftarkan Domain ke Cloudflare

Kalau belum:
1. https://dash.cloudflare.com → Add a Site → masukkan `yourdomain.com`
2. Pilih plan Free
3. Update nameservers di registrar domain ke yang Cloudflare kasih
4. Tunggu propagasi (5 menit - 24 jam)

### Step 2: Buat Tunnel

1. https://one.dash.cloudflare.com (Cloudflare Zero Trust)
2. **Networks → Tunnels → Create a tunnel**
3. Pilih **Cloudflared**
4. Tunnel name: `nas-contabo`
5. Save tunnel
6. **Copy token** yang muncul (long string mulai dengan `eyJ...`)

### Step 3: Setup Public Hostnames

Di tunnel yang baru dibuat:
- **Public hostnames → Add a public hostname**

Hostname 1 — Nextcloud:
- Subdomain: `nextcloud`
- Domain: `yourdomain.com`
- Service Type: `HTTP`
- URL: `nas-nextcloud:80`

Hostname 2 — FileBrowser (untuk akses HDD lokal dari publik):
- Subdomain: `files`
- Domain: `yourdomain.com`
- Service Type: `HTTP`
- URL: `<TAILSCALE_IP_LAPTOP>:8080`

> **Catatan**: FileBrowser di laptop ga selalu nyala. Bisa setup tunnel di laptop juga (lihat bawah) atau pakai service yang routeable saat laptop online.

### Step 4: Update .env & Restart

```
CLOUDFLARE_TUNNEL_TOKEN=eyJhbGciOi...
DOMAIN=nextcloud.yourdomain.com
```

```powershell
make contabo-restart
```

### Step 5: Test
- https://nextcloud.yourdomain.com → harus muncul Nextcloud login
- Cek tunnel status di Cloudflare dashboard → harus "HEALTHY"

## (Opsional) Cloudflare Tunnel di Laptop untuk FileBrowser

Kalau mau FileBrowser akses publik tanpa Tailscale:

### Buat Tunnel ke-2 di Cloudflare

Hostname:
- Subdomain: `files`
- Domain: `yourdomain.com`
- Service: `HTTP` `nas-filebrowser:80`

Copy token, simpan di `.env` sebagai `CLOUDFLARE_TUNNEL_TOKEN_LOCAL`.

### Aktifkan Cloudflared di Lokal

Edit `lokal/docker-compose.yml`, uncomment service `cloudflared`. Update token reference.

```powershell
make local-restart
```

Test: https://files.yourdomain.com (cuma jalan saat laptop nyala).

## Ringkasan Akses URL

| Service | URL Lokal (LAN) | URL Tailscale | URL Publik |
|---|---|---|---|
| Nextcloud (Contabo) | http://CONTABO_IP:8080 | http://100.x.x.x:8080 | https://nextcloud.yourdomain.com |
| FileBrowser (Lokal) | http://localhost:8080 | http://100.y.y.y:8080 | https://files.yourdomain.com (jika cloudflared lokal aktif) |
| Syncthing UI | http://localhost:8384 | http://100.y.y.y:8384 | (jangan expose publik!) |
| SSH Contabo | - | ssh root@100.x.x.x | ssh root@CONTABO_IP |

## Best Practice Security

### Trusted Domains Nextcloud
Pastikan list ini akurat di Nextcloud config:
```powershell
make nc-occ CMD='config:system:get trusted_domains'
```

### Cloudflare Access (Opsional, untuk extra layer)
Bisa proteksi domain dengan Cloudflare Access:
- **Zero Trust → Access → Applications → Add an application**
- Set policy: only specific email allowed
- User akses Nextcloud → harus auth Cloudflare dulu sebelum sampai login Nextcloud

### Rate Limiting di Cloudflare
- Dashboard → Security → WAF → Rate limiting rules
- Limit login attempt: 5 req/min per IP

## Troubleshooting

| Problem | Solusi |
|---|---|
| Tunnel "DEGRADED" di dashboard | Cek `make tunnel-status`, biasanya cloudflared restart fix it |
| `nextcloud.domain.com` 502 Bad Gateway | Nextcloud container down, `make contabo-restart` |
| Tailscale ga konek | `tailscale status`, kalau "Logged out" → `tailscale up` ulang |
| Slow access via tunnel | Cek pilih Cloudflare datacenter terdekat (auto), atau upgrade ke Argo Smart Routing ($5/bulan) |
| HTTPS cert error | Cloudflare auto-handle, tunggu 5 menit setelah setup tunnel |

Lanjut ke: [05-archive-workflow.md](05-archive-workflow.md)
