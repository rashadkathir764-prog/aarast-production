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
# the generated plugin files for the run. A Flutter build can also regenerate
# the Linux plugin files. Only these files are snapshotted and put back at the
# end, byte for byte, so any other work in mobile/windows or mobile/linux stays.
$generated = @(
  'windows\flutter\generated_plugins.cmake',
  'windows\flutter\generated_plugin_registrant.cc',
  'windows\flutter\generated_plugin_registrant.h',
  'linux\flutter\generated_plugins.cmake',
  'linux\flutter\generated_plugin_registrant.cc',
  'linux\flutter\generated_plugin_registrant.h'
)
$snapshot = @{}
foreach ($f in $generated) {
  $path = Join-Path $mobile $f
  if (Test-Path $path) { $snapshot[$path] = [IO.File]::ReadAllBytes($path) }
}
foreach ($f in 'windows\flutter\generated_plugins.cmake', 'windows\flutter\generated_plugin_registrant.cc') {
  $path = Join-Path $mobile $f
  $kept = Get-Content $path | Where-Object { $_ -notmatch 'flutter_secure_storage_windows|FlutterSecureStorageWindows' }
  [IO.File]::WriteAllLines($path, $kept)
}

try {
  Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -match 'src/main.ts' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
  & (Join-Path $S 'walks-clean.ps1') 2>&1 | Where-Object { "$_" -match 'api pid|api up|successfully|keys|Docker' } | ForEach-Object { "$_".Substring(0, [Math]::Min(100, "$_".Length)) }
  $pass = (Get-Content (Join-Path $S 'walk-pass.txt') -Raw).Trim()
  $ids = [IO.File]::ReadAllText((Join-Path $S 'sweep-ids.txt'))
  $dir = Join-Path $S 'out'
  New-Item -ItemType Directory -Force $dir | Out-Null
  # The Windows walk build needs a JDK 17. Keep a JAVA_HOME already set;
  # otherwise use the one Gradle provisioned on this machine.
  if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    $gradleJdk = Get-ChildItem (Join-Path $HOME '.gradle\jdks') -Directory -Filter '*-17-*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $gradleJdk) { throw 'JAVA_HOME is not set and no Gradle JDK 17 was found.' }
    $env:JAVA_HOME = $gradleJdk.FullName
  }
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
} finally {
  foreach ($path in $snapshot.Keys) { [IO.File]::WriteAllBytes($path, $snapshot[$path]) }
}
