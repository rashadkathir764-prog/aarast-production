$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

Push-Location $root
try {
  node .\scripts\docs-sync.mjs --check
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }

  node .\scripts\docs-verify.mjs
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} finally {
  Pop-Location
}
