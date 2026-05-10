# Arsitektur NAS Hybrid

## Big Picture

```
                    ┌──────────────────────────┐
                    │   USER (HP, Laptop, Web) │
                    └─────────────┬────────────┘
                                  │
                  ┌───────────────┴───────────────┐
                  │                               │
                  ▼                               ▼
        Daily access (cepat)              Akses arsip lama
        https://nextcloud.dom             (saat laptop nyala)
                  │                               │
                  ▼                               ▼
        ┌──────────────────────┐      ┌──────────────────────┐
        │  Cloudflare Tunnel   │      │  Cloudflare Tunnel   │
        │    (publik HTTPS)    │      │  atau Tailscale VPN  │
        └──────────┬───────────┘      └──────────┬───────────┘
                   │                              │
                   ▼                              ▼
        ┌──────────────────────┐      ┌──────────────────────┐
        │  CONTABO VPS (HOT)   │      │  LAPTOP RUMAH (COLD) │
        │  ──────────────────  │      │  ──────────────────  │
        │  • Nextcloud         │      │  • FileBrowser       │
        │  • PostgreSQL        │      │  • Syncthing         │
        │  • Redis             │      │  • rclone (archive)  │
        │  • cloudflared       │      │  • cloudflared       │
        │                      │      │                      │
        │  Storage: 120 GB     │      │  Storage: HDD 2TB+   │
        │  Files: <3 bulan     │      │  Files: arsip lama   │
        │  Online: 24/7        │      │  Online: on-demand   │
        └──────────┬───────────┘      └──────────┬───────────┘
                   │                              │
                   │       Tailscale VPN          │
                   └──────────────┬───────────────┘
                                  │
                       Quarterly archive sync
                       (Contabo --> HDD lokal)
                       via rclone over SFTP
```

## Komponen Detail

### Contabo VPS (Hot Storage)
- **Nextcloud 29** (Docker): aplikasi utama, web UI, mobile API
- **PostgreSQL 16** (Docker): database Nextcloud (terisolasi dari MySQL bisnis)
- **Redis 7** (Docker): cache + file locking
- **Cloudflared** (Docker): tunnel ke Cloudflare untuk akses publik HTTPS
- **Network**: `nas-net` (terpisah dari network MySQL bisnis `${NETWORK}`)

### Laptop Rumah (Cold Storage)
- **FileBrowser** (Docker): web UI untuk browse/upload/download HDD external
- **Syncthing** (Docker): sync 2-arah opsional (untuk HP backup, dll)
- **rclone** (CLI atau Docker): tool transfer file Contabo ↔ HDD
- **HDD External**: mounted via dock station USB ke drive letter (Windows: E:, Linux: /mnt/nas)

### Konektivitas
- **Tailscale**: VPN mesh antara laptop ↔ Contabo, bypass CGNAT
- **Cloudflare Tunnel**: expose Nextcloud (Contabo) + FileBrowser (laptop) ke internet publik
- **SSH**: laptop ↔ Contabo untuk command remote (deployment, archive trigger)

## Flow Data: Upload File Baru

```
User HP --> Nextcloud Mobile App --> HTTPS via Cloudflare --> Contabo Nextcloud
                                                                     |
                                                                     v
                                                          Disimpan di volume Docker
                                                          /var/lib/docker/volumes/
                                                          nas_nextcloud_data/_data/
```

File langsung bisa diakses oleh semua user yang punya share permission.

## Flow Data: Archive File Lama (Quarterly)

```
1. Trigger (manual atau auto saat Contabo storage > 80%)
   make archive-now
   
2. archive-prepare.sh (di Contabo)
   - Find files >90 hari
   - Move ke folder /Archive-Ready/
   - Rescan Nextcloud DB
   
3. archive-pull.ps1 (di laptop)
   - rclone copy via SFTP: Contabo:Archive-Ready --> HDD:nextcloud-archive/2026-05/
   - rclone check (verify checksum)
   
4. create-shortcuts.sh (di Contabo)
   - Replace setiap file di Archive-Ready dengan placeholder.archived.json
   - File mentah dihapus, hanya placeholder JSON yang tersisa (~500 bytes)
   - Rescan Nextcloud DB
   
5. nc-scan
   - Final rescan untuk update UI
```

## Flow Data: Akses File Arsip

**User mau file lama yang sudah di-archive:**

Opsi A — saat laptop NYALA:
```
User --> FileBrowser (laptop, public via Cloudflare Tunnel)
           --> Browse HDD external --> Download
```

Opsi B — saat laptop MATI:
```
User --> Nextcloud (Contabo) --> Klik file --> Lihat .archived.json
       --> Info: "File ada di HDD, akses tersedia jam 19:00-23:00"
       --> Tunggu laptop nyala atau request restore manual
```

## Data Flow: Direct Upload ke HDD (Bypass Contabo)

Untuk file BESAR yang ga muat di Contabo 120GB (misal video 10GB):
```
User --> FileBrowser (laptop) via Cloudflare Tunnel
           --> Upload langsung ke HDD external
           --> File ada di HDD, TIDAK di-sync ke Nextcloud Contabo
           --> User butuh akses file --> ke FileBrowser saat laptop nyala
```

## Keputusan Arsitektur Penting

### Kenapa Sync, Bukan Live Mount?

**Alternatif yang ditolak**: Mount HDD lokal ke Contabo Nextcloud via SFTP External Storage.

Alasan ditolak:
- Latency Indonesia ↔ Eropa ~200-300ms per request
- Browse folder besar bisa timeout
- Upload/download dibatasi upload bandwidth rumah (~10-50 Mbps)
- Internet rumah putus = External Storage hilang dari Nextcloud
- Database & filesystem state bisa korup kalau disconnect tiba-tiba

**Solusi**: Sync periodik via rclone. File copy duluan ke local cache, baru disajikan ke user.

### Kenapa PostgreSQL, Bukan MySQL Eksisting?

User sudah punya MySQL container `mysql-8` jalan di Contabo. Tapi:
- Nextcloud direkomendasikan PostgreSQL untuk performa terbaik
- Isolasi: database NAS terpisah dari database bisnis (lebih aman, mudah backup terpisah)
- Maintenance: upgrade Nextcloud ga akan affect MySQL bisnis
- Resource: PostgreSQL untuk Nextcloud cuma butuh ~200MB RAM

### Kenapa Cloudflare Tunnel, Bukan Port Forward?

- ISP Indonesia banyak yang CGNAT (no public IP)
- Port forward butuh setup router & DNS dynamic
- Cloudflare Tunnel: gratis, HTTPS otomatis, no router config, anti-DDoS

### Kenapa FileBrowser, Bukan Nextcloud Lokal?

- Nextcloud = heavy (PHP + DB + Redis), butuh ~2GB RAM
- FileBrowser = single binary Go, ~30MB RAM
- Use case: lokal cuma untuk akses arsip HDD, ga perlu collaboration features
- Bisa upgrade ke Nextcloud lokal nanti kalau perlu fitur lebih

## Capacity Planning

| Komponen | Estimasi |
|---|---|
| Contabo storage | 120 GB (working space ~100 GB setelah dipotong OS+DB+overhead) |
| Bandwidth Contabo | 32 TB/bulan (jauh lebih dari cukup) |
| HDD external awal | Rekomendasi 2 TB (Rp 700-900rb) atau 4 TB (Rp 1.3-1.7jt) |
| RAM Contabo | 6 GB (cukup untuk Nextcloud + Postgres + Redis dengan headroom) |
| Archive interval | 3 bulan (atau saat Contabo > 80% penuh) |
| Estimated growth | Tergantung user — hitung GB/bulan rata-rata |

## Path Upgrade ke Depan

1. **Foto AI features**: Tambah Immich di Contabo (kalau RAM upgrade ke 12GB+)
2. **High availability**: Tambah HDD ke-2 di rumah sebagai mirror (RAID 1 via Storage Spaces / mdadm)
3. **Off-site backup**: Backup HDD lokal mingguan ke Backblaze B2 (~$6/TB/bulan)
4. **Multi-user kolaborasi**: Setup OnlyOffice/Collabora di Contabo untuk co-editing dokumen
5. **Mini PC dedicated**: Pindah workload lokal dari laptop ke mini PC N100 (Rp 2-3jt) untuk uptime lebih baik
