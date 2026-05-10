# ==============================================================================
# archive-pull.ps1 (Windows PowerShell)
# Tarik file dari folder Archive-Ready/ di Contabo Nextcloud --> HDD lokal
# Pakai rclone via SFTP. Memanfaatkan DOWNLOAD bandwidth rumah (cepat).
#
# Dipanggil dari laptop via: make archive-pull
# ==============================================================================
$ErrorActionPreference = "Stop"

# Load .env (cari di parent folder dari script)
$envPath = Join-Path $PSScriptRoot "..\..\.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim().Trim('"'), 'Process')
        }
    }
} else {
    Write-Host "[ERROR] .env tidak ditemukan di $envPath" -ForegroundColor Red
    exit 1
}

# Config from .env (with defaults)
$ContaboHost    = $env:CONTABO_HOST
$ContaboUser    = $env:CONTABO_USER
$ContaboSshKey  = if ($env:CONTABO_SSH_KEY) { $env:CONTABO_SSH_KEY } else { "..\..\ssh-keys\contabo_nas" }
$HddMount       = if ($env:HDD_MOUNT) { $env:HDD_MOUNT } else { "E:\nas-archive" }
$ArchiveFolder  = if ($env:ARCHIVE_FOLDER) { $env:ARCHIVE_FOLDER } else { "Archive-Ready" }
$NcUser         = if ($env:NEXTCLOUD_ARCHIVE_USER) { $env:NEXTCLOUD_ARCHIVE_USER } else { "admin" }
$BwLimit        = if ($env:RCLONE_BWLIMIT) { $env:RCLONE_BWLIMIT } else { "0" }  # 0 = unlimited

Write-Host ""
Write-Host "=== Archive Pull (Contabo --> HDD Lokal) ===" -ForegroundColor Cyan
Write-Host "Source:  ${ContaboUser}@${ContaboHost}:Archive-Ready/"
Write-Host "Dest:    ${HddMount}\nextcloud-archive\$(Get-Date -Format 'yyyy-MM')\"
Write-Host "BW limit: $BwLimit"
Write-Host ""

# Step 1: Verify HDD mounted
if (-not (Test-Path $HddMount)) {
    Write-Host "[ERROR] HDD tidak ter-mount di $HddMount" -ForegroundColor Red
    Write-Host "        Cek apakah HDD external nyala dan dock station tercolok" -ForegroundColor Red
    exit 1
}
Write-Host "[OK] HDD ter-mount" -ForegroundColor Green

# Step 2: Verify rclone installed
$rclone = Get-Command rclone -ErrorAction SilentlyContinue
if (-not $rclone) {
    Write-Host "[ERROR] rclone tidak terinstall." -ForegroundColor Red
    Write-Host "        Install dari: https://rclone.org/downloads/" -ForegroundColor Red
    Write-Host "        Atau via: winget install Rclone.Rclone" -ForegroundColor Red
    exit 1
}

# Step 3: Setup destination folder
$BatchFolder = Get-Date -Format "yyyy-MM"
$DestPath = Join-Path $HddMount "nextcloud-archive\$BatchFolder"
New-Item -ItemType Directory -Force -Path $DestPath | Out-Null

# Step 4: Build rclone command
# Asumsi: rclone remote 'contabo-sftp' sudah di-config (lihat docs/05-archive-workflow.md)
# Atau gunakan inline SFTP config
$RemotePath = "/var/lib/docker/volumes/nas_nextcloud_data/_data/$NcUser/files/$ArchiveFolder"

Write-Host ""
Write-Host "[1/3] Pulling files via rclone (SFTP)..." -ForegroundColor Yellow

$rcloneArgs = @(
    "copy",
    "contabo-sftp:$RemotePath",
    "$DestPath",
    "--progress",
    "--transfers=4",
    "--checkers=8",
    "--log-file=$DestPath\rclone.log",
    "--log-level=INFO"
)

if ($BwLimit -ne "0") {
    $rcloneArgs += "--bwlimit=$BwLimit"
}

& rclone @rcloneArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] rclone copy gagal (exit $LASTEXITCODE)" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Step 5: Verify with checksum
Write-Host ""
Write-Host "[2/3] Verifying integrity (checksum)..." -ForegroundColor Yellow

& rclone check "contabo-sftp:$RemotePath" "$DestPath" --one-way --log-file="$DestPath\verify.log"

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Verify gagal! File tidak konsisten antara source & dest." -ForegroundColor Red
    Write-Host "        JANGAN run 'make archive-finalize' sampai ini fixed." -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Verify passed" -ForegroundColor Green

# Step 6: Summary
$FileCount = (Get-ChildItem -Recurse -File $DestPath | Where-Object { $_.Name -ne "rclone.log" -and $_.Name -ne "verify.log" }).Count
$TotalSize = (Get-ChildItem -Recurse -File $DestPath | Measure-Object -Property Length -Sum).Sum
$TotalSizeGB = [math]::Round($TotalSize / 1GB, 2)

Write-Host ""
Write-Host "[3/3] Summary" -ForegroundColor Yellow
Write-Host "  Files pulled: $FileCount"
Write-Host "  Total size:   $TotalSizeGB GB"
Write-Host "  Location:     $DestPath"
Write-Host ""
Write-Host "=== Archive Pull SELESAI ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next: jalankan 'make archive-finalize' untuk ganti file di Contabo dengan placeholder" -ForegroundColor Cyan
