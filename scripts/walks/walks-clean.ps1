# Reseeds the isolated walk database and starts its API on port 3116.
# Called by walks.ps1; safe to run alone. Needs Docker Desktop (container
# aarast-db) and scripts/walks/walk-pass.txt (the demo password, git-ignored).
$S = $PSScriptRoot
$dbName = 'aarast_walks_20261101'
$port = 3116
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..\backend')

# Docker holds the database; say so instead of failing three steps later.
docker info 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop مطفأ: شغّله وانتظر حتى يصير aarast-db صحيًا، ثم أعد التشغيل' }

# A port of its own: nothing else in this machine answers for this API.
$taken = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue
if ($taken) { throw "port $port is taken" }

# A database of its own: the owner's local demo data stays as it is. The
# drop is forced because the last API may still hold a connection.
$line = (Get-Content .env | Select-String '^DATABASE_URL=').Line
$url = ($line -replace '^DATABASE_URL=', '').Trim('"')
$uri = [Uri]$url
$user = $uri.UserInfo.Split(':')[0]
docker exec aarast-db psql -U $user -d postgres -c "DROP DATABASE IF EXISTS $dbName WITH (FORCE)" 2>&1 | Out-Null
docker exec aarast-db psql -U $user -d postgres -c "CREATE DATABASE $dbName" 2>&1 | Select-Object -Last 1
$env:DATABASE_URL = $url.Replace($uri.AbsolutePath, "/$dbName")

$env:DEMO_SEED_TODAY = (Get-Date).ToString('yyyy-MM-dd')
$env:DEMO_PASSWORD = (Get-Content (Join-Path $S 'walk-pass.txt') -Raw).Trim()
npx prisma migrate deploy 2>&1 | Select-Object -Last 1
npx ts-node prisma/demo-seed.ts 2>&1 | Select-Object -Last 1
$ids = (node (Join-Path $S 'sweep-ids.cjs') 2>&1 | Select-Object -Last 1).ToString()
[IO.File]::WriteAllText((Join-Path $S 'sweep-ids.txt'), $ids)
"ids keys: " + (($ids -split ',' | ForEach-Object { ($_ -split '=')[0] }) -join ' ')

$env:PORT = "$port"
$env:AUTH_OTP_MODE = 'dev'
$env:AUTH_DEV_OTP_CODE = '123456'
$env:NODE_ENV = 'development'
$api = Start-Process -PassThru -WindowStyle Hidden -FilePath node -ArgumentList '--env-file=.env', '-r', 'ts-node/register', '-r', 'tsconfig-paths/register', 'src/main.ts' -RedirectStandardOutput (Join-Path $S 'api.log') -RedirectStandardError (Join-Path $S 'api.err')
"api pid: $($api.Id)"
for ($i = 0; $i -lt 60; $i++) {
  if ($api.HasExited) { throw "api exited: $(Get-Content (Join-Path $S 'api.err') -Tail 4)" }
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 "http://127.0.0.1:$port/live" | Out-Null; 'api up'; break } catch { Start-Sleep -Seconds 3 }
}

# Proof, not hope: the process on this port is the one just started, and it holds the isolated database.
$owner = (Get-NetTCPConnection -State Listen -LocalPort $port).OwningProcess | Select-Object -First 1
"port owner: $owner (expected $($api.Id))"
Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "http://127.0.0.1:$port/ready" -ErrorAction SilentlyContinue | Out-Null
docker exec aarast-db psql -U $user -d postgres -tAc "SELECT datname, count(*) FROM pg_stat_activity WHERE datname IN ('$dbName','aarast_dev') GROUP BY 1"
