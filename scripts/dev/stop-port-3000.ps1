# ============================================================
# Aarast - Stop Port 3000
# ============================================================
#
# Usage:
#   cd D:\projects\aarast
#   .\scripts\dev\stop-port-3000.ps1
#
# Finds the process listening on port 3000 and stops it.
# Only kills the exact PID on port 3000. No other processes touched.
# ============================================================

$ErrorActionPreference = "Stop"
$targetPort = 3000

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " Aarast - Stop Port $targetPort"          -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Find connections on port 3000
$connections = netstat -ano | Select-String ":$targetPort\s" | Select-String "LISTENING"

if (-not $connections) {
    Write-Host "No process found listening on port $targetPort. Nothing to stop." -ForegroundColor Green
    exit 0
}

# Extract unique PIDs
$pids = $connections | ForEach-Object {
    ($_ -split '\s+')[-1]
} | Select-Object -Unique

foreach ($pid in $pids) {
    if ($pid -match '^\d+$' -and [int]$pid -gt 0) {
        try {
            $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($proc) {
                Write-Host "Stopping PID $pid ($($proc.ProcessName)) on port $targetPort..." -ForegroundColor Yellow
                Stop-Process -Id $pid -Force
                Write-Host "PID $pid stopped successfully." -ForegroundColor Green
            } else {
                Write-Host "PID $pid not found (may have already stopped)." -ForegroundColor Gray
            }
        } catch {
            Write-Host "WARNING: Could not stop PID $pid - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "Port $targetPort is now free." -ForegroundColor Green
Write-Host ""
