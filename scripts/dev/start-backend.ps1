# ============================================================
# Aarast - Start Backend (Local Manual QA)
# Port: 3000
# Database: localhost:5433 (aarast-db Docker container)
# ============================================================
#
# Usage:
#   cd D:\projects\aarast
#   .\scripts\dev\start-backend.ps1
#
# Prerequisites:
#   - Docker container aarast-db must be running on port 5433.
#   - You must have a local backend/.env or this script sets env vars directly.
#   - Node.js must be installed.
#
# Note:
#   Smoke tests may use temporary safe ports (e.g. 3148, 3160).
#   Manual QA always uses port 3000.
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Aarast Backend - Local Dev (Port 3000)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Navigate to backend directory
$rootDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$backendDir = Join-Path $rootDir "backend"

if (-not (Test-Path $backendDir)) {
    Write-Host "ERROR: backend/ directory not found at: $backendDir" -ForegroundColor Red
    exit 1
}

Set-Location $backendDir
Write-Host "Working directory: $backendDir" -ForegroundColor Gray

# Set environment variables for this process
$env:PORT              = "3000"
$env:DATABASE_URL      = "postgresql://aarast_user:aarast_password@localhost:5433/aarast_dev?schema=public"
$env:JWT_SECRET        = "local-dev-secret"
$env:NODE_ENV          = "development"

Write-Host ""
Write-Host "Environment:" -ForegroundColor Yellow
Write-Host "  PORT         = $env:PORT"
Write-Host "  DATABASE_URL = postgresql://aarast_user:***@localhost:5433/aarast_dev"
Write-Host "  NODE_ENV     = $env:NODE_ENV"
Write-Host ""

# Build the backend
Write-Host "Building backend..." -ForegroundColor Yellow
npm run build
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: npm run build failed." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Build complete. Starting server on http://127.0.0.1:3000 ..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop." -ForegroundColor Gray
Write-Host ""

# Start the server
node dist/main.js
