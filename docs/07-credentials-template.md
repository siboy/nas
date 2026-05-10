# Credentials Template

Template untuk catat credential — **JANGAN COMMIT FILE INI KE GIT**.

> Copy file ini ke `docs/credentials-private.md` (sudah ada di .gitignore), isi nilainya, simpan di password manager.

## Contabo VPS

| Field | Value |
|---|---|
| IP Publik | `XXX.XXX.XXX.XXX` |
| Hostname (jika ada) | |
| Tailscale IP | `100.X.X.X` |
| SSH user | `root` |
| SSH key path | `./ssh-keys/contabo_nas` |
| SSH key fingerprint | (run `ssh-keygen -lf ssh-keys/contabo_nas.pub`) |
| Web console URL | https://my.contabo.com |
| Plan | VPS S/M/L |
| RAM / Storage | 6 GB / 120 GB |

## Nextcloud

| Field | Value |
|---|---|
| Public URL | https://nextcloud.yourdomain.com |
| Internal URL | http://CONTABO_IP:8080 |
| Admin user | admin |
| Admin password | (di password manager) |
| Default region | ID |

## PostgreSQL

| Field | Value |
|---|---|
| Container | nas-postgres |
| Host (internal) | postgres |
| Port | 5432 (internal only) |
| Database | nextcloud |
| User | nextcloud |
| Password | (di password manager) |

## Redis

| Field | Value |
|---|---|
| Container | nas-redis |
| Host (internal) | redis |
| Port | 6379 |
| Password | (di password manager) |

## Cloudflare

| Field | Value |
|---|---|
| Account email | |
| Domain | yourdomain.com |
| Tunnel name | nas-contabo |
| Tunnel ID | |
| Tunnel token (Contabo) | (di .env) |
| Tunnel token (Lokal) | (di .env, jika dipakai) |

## Tailscale

| Field | Value |
|---|---|
| Login email | |
| Tailnet name | |
| Laptop hostname | laptop-nas |
| Contabo hostname | contabo-nas |

## Domain Registrar

| Field | Value |
|---|---|
| Registrar | (Cloudflare/Namecheap/dll) |
| Domain | yourdomain.com |
| Renewal date | |
| Cost | $X/tahun |

## HDD External

| Field | Value |
|---|---|
| Brand & model | (e.g. WD Elements 2TB) |
| Serial number | |
| Drive letter | E: |
| Mount path | E:\nas-archive |
| Capacity | 2 TB |
| Purchase date | |
| Warranty until | |

## Backup HDD (Mirror, jika ada)

| Field | Value |
|---|---|
| Brand & model | |
| Connected via | (slot dock #2 / USB hub port 3) |
| Sync schedule | Weekly (Sunday 3am) |

## User Accounts (Nextcloud)

| Username | Email | Role | Notes |
|---|---|---|---|
| admin | | Admin | |
| | | User | Read+write semua |
| | | User | Read-only foto |

## Recovery Info

| Item | Location |
|---|---|
| Last DB backup | `~/nas/backups/` di Contabo |
| HDD backup mirror | (drive letter / sync target) |
| .env backup | (encrypted USB / password manager note) |
| SSH keys backup | (encrypted USB) |

## Important URLs Quick Reference

- Nextcloud: https://nextcloud.yourdomain.com
- FileBrowser (lokal): http://localhost:8080
- FileBrowser (publik): https://files.yourdomain.com
- Syncthing UI: http://localhost:8384
- Cloudflare Dashboard: https://dash.cloudflare.com
- Contabo Panel: https://my.contabo.com
- Tailscale Admin: https://login.tailscale.com/admin

## Emergency Contact

Kalau ada masalah dengan service, cek urutan ini:
1. https://www.cloudflarestatus.com (Cloudflare down?)
2. https://contabo.com/en/status (Contabo down?)
3. Internet rumah OK?
4. Laptop nyala?
