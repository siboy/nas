# ==============================================================================
# verify-mount.ps1
# Cek HDD external ter-mount dengan benar di Windows.
# Dipanggil dari Makefile via: make verify-mount
# ==============================================================================

# Load .env
$envPath = Join-Path $PSScriptRoot "..\..\.env"
if (Test-Path $envPath) {
    Get-Content $envPath | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim().Trim('"'), 'Process')
        }
    }
}

$HddMount = if ($env:HDD_MOUNT) { $env:HDD_MOUNT } else { "E:\nas-archive" }
$DriveLetter = $HddMount.Substring(0, 1)

Write-Host "Checking HDD mount at: $HddMount"

# Check 1: Drive letter exists
$drive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
if (-not $drive) {
    Write-Host "[ERROR] Drive ${DriveLetter}: tidak ada (HDD belum dicolok?)" -ForegroundColor Red
    exit 1
}

# Check 2: Folder exists (atau bisa dibuat)
if (-not (Test-Path $HddMount)) {
    try {
        New-Item -ItemType Directory -Force -Path $HddMount | Out-Null
        Write-Host "[OK] Folder $HddMount dibuat" -ForegroundColor Green
    } catch {
        Write-Host "[ERROR] Tidak bisa buat folder di $HddMount" -ForegroundColor Red
        exit 1
    }
}

# Check 3: Writable
$testFile = Join-Path $HddMount ".write-test"
try {
    "test" | Out-File -FilePath $testFile -Force
    Remove-Item $testFile -Force
} catch {
    Write-Host "[ERROR] HDD read-only atau permission issue di $HddMount" -ForegroundColor Red
    exit 1
}

# Check 4: Free space
$freeGB = [math]::Round($drive.Free / 1GB, 2)
$totalGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
$pctUsed = [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 1)

Write-Host "[OK] HDD mounted: $HddMount" -ForegroundColor Green
Write-Host "     Total: ${totalGB} GB"
Write-Host "     Free:  ${freeGB} GB"
Write-Host "     Used:  ${pctUsed}%"

if ($pctUsed -gt 90) {
    Write-Host "[!] WARNING: HDD usage > 90%, segera ganti HDD baru atau cleanup" -ForegroundColor Yellow
}

exit 0
