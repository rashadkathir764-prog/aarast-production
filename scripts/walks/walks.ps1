param([string[]]$walks)
# Runs real-app walks on the Windows build against the isolated API:
#   pwsh -File scripts/walks/walks.ps1 -walks groom,route_sweep
# or from PowerShell: & .\scripts\walks\walks.ps1 -walks @('groom','route_sweep')
# A walk whose name starts with "offline_groom" is launched against a closed
# port (the server out of reach) and keeps the local copy the previous walk
# left on this machine; run offline_prime (or groom) before it.
# Screens and logs land in scripts/walks/out/<walk>/ (git-ignored).
$ErrorActionPreference = 'Continue'
$S = $PSScriptRoot
$repo = Resolve-Path (Join-Path $S '..\..')
$mobile = Join-Path $repo 'mobile'

# The Windows build cannot link flutter_secure_storage_windows; drop it from
# the generated plugin files for the run and restore them at the end.
foreach ($f in 'windows\flutter\generated_plugins.cmake', 'windows\flutter\generated_plugin_registrant.cc') {
  $path = Join-Path $mobile $f
  $kept = Get-Content $path | Where-Object { $_ -notmatch 'flutter_secure_storage_windows|FlutterSecureStorageWindows' }
  [IO.File]::WriteAllLines($path, $kept)
}

Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'src/main.ts' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
& (Join-Path $S 'walks-clean.ps1') 2>&1 | Where-Object { "$_" -match 'api pid|api up|successfully|keys|Docker' } | ForEach-Object { "$_".Substring(0, [Math]::Min(100, "$_".Length)) }
$pass = (Get-Content (Join-Path $S 'walk-pass.txt') -Raw).Trim()
$ids = [IO.File]::ReadAllText((Join-Path $S 'sweep-ids.txt'))
$dir = Join-Path $S 'out'
New-Item -ItemType Directory -Force $dir | Out-Null
$env:JAVA_HOME = 'C:\Users\Rashad\.gradle\jdks\eclipse_adoptium-17-amd64-windows.2'
Set-Location $mobile
foreach ($walk in $walks) {
  "=== $walk $(Get-Date -Format HH:mm:ss)"
  $out = Join-Path $dir "$walk.log"
  $base = if ($walk -like 'offline_groom*') { 'http://127.0.0.1:9' } else { 'http://127.0.0.1:3116' }
  flutter test --no-pub "integration_test/journeys/${walk}_walk_test.dart" -d windows `
    "--dart-define=AARAST_API_BASE_URL=$base" `
    "--dart-define=DEMO_PASSWORD=$pass" `
    "--dart-define=AARAST_WALKS_DIR=$dir" `
    "--dart-define=AARAST_SWEEP_IDS=$ids" *> $out
  (Get-Content $out -Encoding utf8 | Select-String -Pattern 'All tests passed|Some tests failed|Build process failed|Error:' | Select-Object -Last 2 | ForEach-Object { $_.Line.Substring(0, [Math]::Min(120, $_.Line.Length)) })
}
"=== done $(Get-Date -Format HH:mm:ss)"
git -C $repo checkout -- mobile/windows mobile/linux
