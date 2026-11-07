# Builds the Google Play bundle (AAB) of Aarast, checked before and after.
#
#   cd D:\projects\aarast
#   powershell -ExecutionPolicy Bypass -File scripts\build-android-release.ps1
#
# The values come from mobile\android\.env.release (git-ignored, one
# KEY=VALUE per line), so nothing secret is typed on the command line or
# committed. The upload key is read from mobile\android\key.properties, as
# build.gradle.kts reads it. Every value below is required; a missing one
# stops the script before Gradle starts, with its name.
#
#   AARAST_API_BASE_URL                 https://aarast-api.shadowgardn.com
#   AARAST_INVITE_HOST                  aarast.shadowgardn.com
#   AARAST_FIREBASE_API_KEY             from the Firebase Android app
#   AARAST_FIREBASE_APP_ID
#   AARAST_FIREBASE_MESSAGING_SENDER_ID
#   AARAST_FIREBASE_PROJECT_ID
#   AARAST_SENTRY_DSN                   the mobile Sentry project's DSN
#   SENTRY_AUTH_TOKEN                   to upload the symbols (sentry_dart_plugin)
#   SENTRY_ORG
#   SENTRY_PROJECT
#
# Then it checks the bundle it built: who signed it (the SHA-256 that must
# match assetlinks.json, or the Play App Signing one added beside it), and
# prints the path to upload.

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mobile = Join-Path $root 'mobile'
$valuesFile = Join-Path $mobile 'android\.env.release'
$keyProperties = Join-Path $mobile 'android\key.properties'

if (-not (Test-Path $valuesFile)) {
  throw "Missing $valuesFile (KEY=VALUE per line). See the top of this script."
}
foreach ($line in Get-Content $valuesFile) {
  $trimmed = $line.Trim()
  if ($trimmed -eq '' -or $trimmed.StartsWith('#')) { continue }
  $at = $trimmed.IndexOf('=')
  if ($at -lt 1) { throw "Not KEY=VALUE in .env.release: $trimmed" }
  Set-Item -Path ("env:" + $trimmed.Substring(0, $at).Trim()) -Value $trimmed.Substring($at + 1).Trim()
}

$required = @(
  'AARAST_API_BASE_URL', 'AARAST_INVITE_HOST',
  'AARAST_FIREBASE_API_KEY', 'AARAST_FIREBASE_APP_ID',
  'AARAST_FIREBASE_MESSAGING_SENDER_ID', 'AARAST_FIREBASE_PROJECT_ID',
  'AARAST_SENTRY_DSN', 'SENTRY_AUTH_TOKEN', 'SENTRY_ORG', 'SENTRY_PROJECT'
)
$missing = @($required | Where-Object { -not (Get-Item -Path "env:$_" -ErrorAction SilentlyContinue).Value })
if ($missing.Count -gt 0) { throw ("Missing in .env.release: " + ($missing -join ', ')) }
if (-not $env:AARAST_API_BASE_URL.StartsWith('https://')) { throw 'AARAST_API_BASE_URL must start with https://' }
if (-not (Test-Path $keyProperties)) { throw "Missing $keyProperties (the upload key; see key.properties.example)." }

Push-Location $mobile
try {
  $releaseSha = (git rev-parse --short HEAD).Trim()
  if ((git status --porcelain).Length -gt 0) { throw 'Uncommitted changes: build a release from a clean main only.' }
  $versionMatch = [regex]::Match((Get-Content pubspec.yaml -Raw), '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$')
  if (-not $versionMatch.Success) { throw 'Invalid pubspec version.' }
  $buildName = $versionMatch.Groups[1].Value
  $buildNumber = $versionMatch.Groups[2].Value
  $releaseId = "aarast-mobile@$buildName+$buildNumber-$releaseSha"
  $env:SENTRY_RELEASE = $releaseId
  Write-Host "Building $releaseId for $($env:AARAST_API_BASE_URL)"

  flutter build appbundle --release `
    --build-name=$buildName `
    --build-number=$buildNumber `
    "--dart-define=AARAST_API_BASE_URL=$($env:AARAST_API_BASE_URL)" `
    "--dart-define=AARAST_INVITE_HOST=$($env:AARAST_INVITE_HOST)" `
    "--dart-define=AARAST_FIREBASE_API_KEY=$($env:AARAST_FIREBASE_API_KEY)" `
    "--dart-define=AARAST_FIREBASE_APP_ID=$($env:AARAST_FIREBASE_APP_ID)" `
    "--dart-define=AARAST_FIREBASE_MESSAGING_SENDER_ID=$($env:AARAST_FIREBASE_MESSAGING_SENDER_ID)" `
    "--dart-define=AARAST_FIREBASE_PROJECT_ID=$($env:AARAST_FIREBASE_PROJECT_ID)" `
    "--dart-define=AARAST_SENTRY_DSN=$($env:AARAST_SENTRY_DSN)" `
    '--dart-define=AARAST_ENVIRONMENT=production' `
    '--dart-define=AARAST_SENTRY_TRACES_SAMPLE_RATE=0.1' `
    "--dart-define=SENTRY_RELEASE=$releaseId" `
    "--dart-define=AARAST_BUILD_COMMIT=$releaseSha"
  if ($LASTEXITCODE -ne 0) { throw "flutter build appbundle failed ($LASTEXITCODE)." }

  $bundle = Join-Path $mobile 'build\app\outputs\bundle\release\app-release.aab'
  if (-not (Test-Path $bundle)) { throw "No bundle at $bundle" }
  Write-Host ''
  Write-Host 'Signed by (its SHA-256 must be in deploy\public-site\.well-known\assetlinks.json):'
  keytool -printcert -jarfile $bundle | Select-String 'SHA256'
  Write-Host ''
  Write-Host "Upload to Play Console (Closed testing): $bundle"
  Write-Host "Version $buildName ($buildNumber), commit $releaseSha"
} finally {
  Pop-Location
}
