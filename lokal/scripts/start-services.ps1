# ==============================================================================
# start-services.ps1
# All-in-one startup script untuk laptop rumah:
# 1. Cek HDD external mounted
# 2. Start Tailscale
# 3. Start Docker services (FileBrowser, Syncthing, dll)
# 4. (Opsional) Trigger archive pull kalau Contabo storage > threshold
#
# Bisa di-set sebagai Startup item di Windows untuk auto-jalan saat login.
# ==============================================================================
$ErrorActionPreference = "Stop"

$ProjectRoot = Join-Path $PSScriptRoot "..\.."

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " NAS Local Services Startup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Verify HDD
Write-Host "[1/4] Verify HDD external..." -ForegroundColor Yellow
& (Join-Path $PSScriptRoot "verify-mount.ps1")
if ($LASTEXITCODE -ne 0) {
    Write-Host "HDD tidak siap. Cek dock station & HDD power." -ForegroundColor Red
    exit 1
}

# Step 2: Start Tailscale
Write-Host ""
Write-Host "[2/4] Start Tailscale..." -ForegroundColor Yellow
$tailscaleExe = "C:\Program Files\Tailscale\tailscale.exe"
if (Test-Path $tailscaleExe) {
    & $tailscaleExe up --hostname=laptop-nas 2>&1 | Out-Null
    $tsStatus = & $tailscaleExe status
    Write-Host $tsStatus
} else {
    Write-Host "[WARN] Tailscale tidak terinstall, skip" -ForegroundColor Yellow
}

# Step 3: Start Docker services
Write-Host ""
Write-Host "[3/4] Start Docker services..." -ForegroundColor Yellow
Push-Location (Join-Path $ProjectRoot "lokal")
try {
    docker compose --env-file ../.env up -d
} finally {
    Pop-Location
}

# Step 4: Auto archive (opsional, kalau .env ada AUTO_ARCHIVE_ON_START=true)
$envPath = Join-Path $ProjectRoot ".env"
if (Test-Path $envPath) {
    $autoArchive = (Get-Content $envPath | Where-Object { $_ -match '^AUTO_ARCHIVE_ON_START=' }) -replace '.*=', ''
    if ($autoArchive -eq 'true') {
        Write-Host ""
        Write-Host "[4/4] Auto-archive enabled, checking Contabo storage..." -ForegroundColor Yellow
        Push-Location $ProjectRoot
        try {
            make storage-alert
            if ($LASTEXITCODE -ne 0) {
                Write-Host "Storage alert triggered, running archive-now..." -ForegroundColor Yellow
                make archive-now
            } else {
                Write-Host "[OK] Storage masih sehat, skip archive" -ForegroundColor Green
            }
        } finally {
            Pop-Location
        }
    } else {
        Write-Host ""
        Write-Host "[4/4] Auto-archive disabled (set AUTO_ARCHIVE_ON_START=true di .env untuk aktifkan)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Services UP" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "FileBrowser : http://localhost:8080"
Write-Host "Syncthing   : http://localhost:8384"
Write-Host ""
Write-Host "Cek status: make status"
