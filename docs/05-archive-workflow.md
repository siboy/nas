# Archive Workflow — Quarterly Cold Storage Migration

Panduan workflow archive: pindahkan file lama dari Contabo ke HDD lokal, ganti dengan placeholder.

## Konsep

```
Setiap 3 bulan (atau saat Contabo > 80% penuh):

  ┌─────────────┐                        ┌──────────────────┐
  │   CONTABO   │                        │   LAPTOP RUMAH   │
  │             │                        │                  │
  │  /admin/    │                        │  E:\nas-archive\ │
  │   files/    │  ── archive-prepare ─→ │   nextcloud-     │
  │   (banyak)  │                        │   archive\       │
  │             │  ── archive-pull ────→ │   2026-05\       │
  │             │     (rclone SFTP)      │   ├── doc.pdf    │
  │             │                        │   ├── foto/      │
  │   /admin/   │  ← archive-finalize ─  │   └── video/     │
  │   files/    │     (replace dengan    │                  │
  │   (kosong + │      placeholder)      │                  │
  │   .archived │                        │                  │
  │   .json)    │                        │                  │
  └─────────────┘                        └──────────────────┘
```

## Trigger Workflow

### Manual (Recommended di awal)
```powershell
# Pastikan laptop nyala, HDD tercolok
make archive-now
```

### Auto saat Storage Penuh
Edit `.env`:
```
AUTO_ARCHIVE_ON_START=true
```

Saat laptop boot + Docker start → cek storage Contabo → kalau >80%, auto-trigger.

### Scheduled Quarterly
Windows Task Scheduler:
- Trigger: At startup OR Weekly Sunday 2am
- Action: `make -C C:\nas archive-now`
- Conditions: AC power, network connected

## Step-by-Step Workflow

### Step 0: Pre-flight Check

```powershell
make verify-all
```

Pastikan:
- HDD external mounted & writable
- SSH ke Contabo bisa
- Tailscale connected (kalau pakai)

### Step 1: Archive Prepare (di Contabo)

```powershell
make archive-prepare
```

Apa yang terjadi di Contabo:
1. Find semua file di `/admin/files/` yang `mtime > 90 hari` (default)
2. Skip file yang sudah di folder `Archive-Ready/` (sudah pernah diproses)
3. Skip file `.archived.json` (placeholder)
4. Move file ke `/admin/files/Archive-Ready/<original-path>/`
5. Trigger `occ files:scan` untuk update Nextcloud DB

**Dry-run dulu untuk safety:**
```powershell
make archive-dry-run
```
Akan list file yang AKAN dipindah, tanpa benar-benar memindahkan.

### Step 2: Archive Pull (di Laptop)

```powershell
make archive-pull
```

Apa yang terjadi:
1. Verify HDD mounted di `E:\nas-archive`
2. rclone copy dari `contabo-sftp:/var/lib/.../Archive-Ready/` ke `E:\nas-archive\nextcloud-archive\2026-05\`
3. Pakai DOWNLOAD bandwidth rumah (cepat, ~50-100 Mbps)
4. Verify dengan `rclone check --one-way` (checksum)
5. Log ke `E:\nas-archive\nextcloud-archive\2026-05\rclone.log`

**Estimasi waktu:**
- 60 GB di 50 Mbps download: ~2.5 jam
- Bisa overnight, jalankan sebelum tidur

**Bandwidth limit (jika perlu):**
```
RCLONE_BWLIMIT=10M  # 10 MB/s = 80 Mbps
```

### Step 3: Archive Finalize (di Contabo)

```powershell
make archive-finalize
```

Apa yang terjadi:
1. Untuk setiap file di `Archive-Ready/`:
   - Generate `.archived.json` dengan metadata (nama original, size, date, lokasi HDD)
   - Replace file mentah dengan placeholder JSON
   - File besar (1GB) → placeholder cuma ~500 bytes!
2. Trigger `occ files:scan` untuk update DB

**Hasil di Nextcloud UI:**
- User browse `/Archive-Ready/foto/2025/` → masih lihat file (tapi sebagai .json)
- Klik file → preview JSON → user tau "ini sudah di-archive ke HDD, akses via FileBrowser"

### Step 4: Verifikasi & Cleanup

```powershell
make storage-check
```

Pastikan storage Contabo turun signifikan.

Cek jumlah file di lokal:
```powershell
ls E:\nas-archive\nextcloud-archive\2026-05\ -Recurse | Measure-Object
```

## Anti-pattern: Apa yang TIDAK Boleh

❌ **Jangan** delete file di Contabo manual via Web UI sebelum verify lokal sukses
- Kalau verify gagal, kamu kehilangan data

❌ **Jangan** jalankan `archive-finalize` tanpa `archive-pull` sukses
- File di Contabo akan diganti placeholder, tapi belum ada backup

❌ **Jangan** restart Docker Contabo saat archive sedang jalan
- Bisa korup file/database

❌ **Jangan** cabut HDD saat archive-pull sedang jalan
- File yang setengah copy bisa korup

## Recovery: Restore File dari HDD ke Contabo

User butuh akses file yang sudah di-archive:

### Opsi A: Akses Langsung via FileBrowser (saat laptop nyala)
- Buka https://files.yourdomain.com
- Login user
- Browse `nextcloud-archive/2026-05/<path>/`
- Download

### Opsi B: Restore ke Nextcloud Contabo
Manual:
```powershell
# Dari laptop, push file ke Contabo
rclone copy "E:\nas-archive\nextcloud-archive\2026-05\foto.jpg" contabo-sftp:/var/lib/docker/volumes/nas_nextcloud_data/_data/admin/files/Restored/

# Hapus placeholder
make nc-occ CMD='files:delete admin/files/Archive-Ready/foto.jpg.archived.json'

# Rescan
make nc-scan
```

### Opsi C: Bulk Restore (untuk banyak file)
Buat script `restore-from-archive.sh`:
```bash
#!/bin/bash
BATCH="$1"  # e.g. "2026-05"
SOURCE="E:/nas-archive/nextcloud-archive/${BATCH}"
DEST="contabo-sftp:/var/lib/docker/volumes/nas_nextcloud_data/_data/admin/files/Restored/${BATCH}"

rclone copy "${SOURCE}" "${DEST}" --progress
ssh -i ssh-keys/contabo_nas root@CONTABO 'docker exec --user www-data nas-nextcloud php occ files:scan --all'
```

## Kustomisasi Archive Rule

### Ubah Threshold "Old Files"
Edit `.env`:
```
ARCHIVE_DAYS_OLD=180  # archive file >6 bulan, bukan 3 bulan
```

### Archive Folder Tertentu Saja
Modifikasi `contabo/scripts/archive-prepare.sh`:
```bash
# Cari di subfolder spesifik
find '${NEXTCLOUD_DATA_BASE}/Photos' -type f -mtime +${DAYS_OLD} ...
```

### Archive Berdasarkan Tag Nextcloud
Pakai tag system Nextcloud:
1. User tag file dengan "to-archive" via UI
2. Script query DB `oc_systemtag_object_mapping` → find tagged files
3. Move ke Archive-Ready

(Implementation: lihat docs/06-troubleshooting.md untuk advanced query)

## Schedule Recommendations

| Pemakaian | Schedule |
|---|---|
| Personal, sedikit foto | Quarterly (tiap 3 bulan) |
| Personal, banyak foto/video | Monthly |
| Keluarga (banyak HP backup) | Bi-weekly (tiap 2 minggu) |
| Kolaborasi tim | Weekly + auto saat storage > 70% |

## Monitoring & Logs

```powershell
# Cek log archive terakhir di lokal
cat E:\nas-archive\nextcloud-archive\2026-05\rclone.log

# Cek log di Contabo
make contabo-bash
tail -100 ~/nas/logs/storage.log
tail -100 ~/nas/logs/backup.log
```

Lanjut ke: [06-troubleshooting.md](06-troubleshooting.md)
