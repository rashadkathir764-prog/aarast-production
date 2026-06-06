# ============================================================
# Aarast - Start Flutter Web (Local Manual QA)
# API Base URL: http://127.0.0.1:3000
# ============================================================
#
# Usage:
#   cd D:\projects\aarast
#   .\scripts\dev\start-flutter-web.ps1
#
# Prerequisites:
#   - Flutter SDK must be installed and on PATH.
#   - Backend must be running on port 3000 (use start-backend.ps1).
#   - Chrome must be installed.
#
# Note:
#   The API base URL is injected via --dart-define so it overrides
#   the default in lib/core/config/api_config.dart.
#   The default in api_config.dart is already http://127.0.0.1:3000.
#
#   Smoke tests may use temporary safe ports.
#   Manual QA always uses port 3000.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Aarast Flutter Web - Local Dev"         -ForegroundColor Cyan
Write-Host " API -> http://127.0.0.1:3000"           -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to mobile directory
$rootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$mobileDir = Join-Path $rootDir "mobile"

if (-not (Test-Path $mobileDir)) {
    Write-Host "ERROR: mobile/ directory not found at: $mobileDir" -ForegroundColor Red
    exit 1
}

Set-Location $mobileDir
Write-Host "Working directory: $mobileDir" -ForegroundColor Gray
Write-Host ""

# Install dependencies
Write-Host "Running flutter pub get..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: flutter pub get failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Starting Flutter Web on Chrome..." -ForegroundColor Green
Write-Host "API base URL: http://127.0.0.1:3000" -ForegroundColor Gray
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""

# Run Flutter web with the fixed API URL
flutter run -d chrome --dart-define=AARAST_API_BASE_URL=http://127.0.0.1:3000
