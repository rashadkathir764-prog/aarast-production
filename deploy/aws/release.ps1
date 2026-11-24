# Ships one CI-built release to the Aarast AWS host (RA-OP-25). The images are
# not built here or on the host: the "Release images" workflow built the four
# of them once from a commit CI passed, scanned them, and recorded each one's
# content digest. This takes that run's artifact to the ops bucket together
# with deploy/ (LF line endings) of the same commit, and runs
# deploy/aws/host/deploy.sh on the host through SSM, which loads each image and
# keeps it only if it is exactly the one the run recorded.
#   pwsh -File deploy/aws/release.ps1 -Run <id of the Release images run>
# Requires `aws login` and `gh auth login` on this machine. No secrets pass through here.
param(
  [Parameter(Mandatory)][string]$Run,
  [string]$Region = 'eu-central-1',
  [string]$Stack = 'aarast-host',
  [string]$BaseHost = '3-121-198-183.sslip.io',
  [string]$OpenWaLinkTarget = 'rk@81.17.102.27'
)
# Written for PowerShell 7 (pwsh). From Windows PowerShell 5.1 the script
# runs itself again under pwsh, so an Arabic string or a 7-only option never
# breaks it (go-live from Rashad's window, 2026-11-06).
if ($PSVersionTable.PSVersion.Major -lt 7) {
  $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
  if (-not $pwsh) { throw 'هذا السكربت يحتاج PowerShell 7: ثبّته ثم شغّله بالأمر pwsh' }
  $forward = @()
  foreach ($name in $PSBoundParameters.Keys) { $forward += "-$name"; $forward += $PSBoundParameters[$name] }
  & $pwsh.Source -NoProfile -File $PSCommandPath @forward
  exit $LASTEXITCODE
}

$ErrorActionPreference = 'Stop'
$aws = 'C:\Program Files\Amazon\AWSCLIV2\aws.exe'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$outputs = & $aws cloudformation describe-stacks --region $Region --stack-name $Stack `
  --query 'Stacks[0].Outputs' --output json | ConvertFrom-Json
$value = { param($key) ($outputs | Where-Object OutputKey -eq $key).OutputValue }
$instance = & $value 'InstanceId'
$opsBucket = & $value 'OpsBucketName'
$mediaBucket = & $value 'MediaBucketName'
$publicIp = & $value 'PublicIp'

# The run says which commit the images are of; nothing else decides it.
$gh = Get-Command gh -ErrorAction SilentlyContinue
if (-not $gh) { throw 'This script needs the GitHub CLI (gh) to take the CI-built images.' }
$info = & gh run view $Run --json workflowName,conclusion,headSha,headBranch | ConvertFrom-Json
if ($info.workflowName -ne 'Release images') { throw "Run $Run is '$($info.workflowName)', not a Release images run." }
if ($info.conclusion -ne 'success') { throw "Run $Run did not succeed ($($info.conclusion))." }
if ($info.headBranch -ne 'main') { throw "Run $Run is of branch $($info.headBranch); only main is released." }
$sha = $info.headSha
if ($sha -notmatch '^[0-9a-f]{40}$') { throw "Run $Run names no commit." }
git -C $repo cat-file -e "$sha^{commit}" 2>$null
if ($LASTEXITCODE -ne 0) { throw "Commit $sha is not in this clone: git fetch first." }

$download = Join-Path $env:TEMP "aarast-images-$sha"
if (Test-Path $download) { Remove-Item -Recurse -Force $download }
& gh run download $Run --name "release-images-$sha" --dir $download
if ($LASTEXITCODE -ne 0) { throw "Could not download the images of run $Run." }
$manifest = Get-Content -Raw (Join-Path $download 'release-images.json') | ConvertFrom-Json
if ($manifest.release -ne $sha) { throw "The manifest is for $($manifest.release), not $sha." }
if ($manifest.adminApiBaseUrl -ne "https://api.$BaseHost") {
  throw "The admin web was built for $($manifest.adminApiBaseUrl), this host is https://api.$BaseHost."
}
$manifest.images | ForEach-Object { Write-Host "image $($_.name) $($_.id)" }

# Only deploy/ goes to the host (compose, scripts); it builds nothing from source.
$archive = Join-Path $env:TEMP "aarast-$sha.tar.gz"
git -C $repo -c core.autocrlf=false -c core.eol=lf archive --format=tar.gz -o $archive $sha deploy
& $aws s3 cp $archive "s3://$opsBucket/releases/$sha/source.tar.gz" --region $Region --only-show-errors
Remove-Item $archive
& $aws s3 sync $download "s3://$opsBucket/releases/$sha/images" --region $Region --only-show-errors --delete
Remove-Item -Recurse -Force $download

# SSM runs this with sh; the host scripts themselves run under bash.
$script = @"
set -eu
tree=/opt/aarast/releases/$sha
mkdir -p "`$tree"
aws s3 cp s3://$opsBucket/releases/$sha/source.tar.gz /tmp/aarast-$sha.tar.gz --only-show-errors
tar -xzf /tmp/aarast-$sha.tar.gz -C "`$tree"
rm -f /tmp/aarast-$sha.tar.gz
bash "`$tree/deploy/aws/host/prepare-env.sh" $BaseHost $mediaBucket $Region $OpenWaLinkTarget $publicIp
bash "`$tree/deploy/aws/host/deploy.sh" $sha $opsBucket
"@
$params = @{ commands = @($script -replace "`r", ''); executionTimeout = @('3600') } | ConvertTo-Json -Compress
$paramFile = New-TemporaryFile
Set-Content -LiteralPath $paramFile -Value $params -Encoding utf8NoBOM
$id = & $aws ssm send-command --region $Region --instance-ids $instance --document-name AWS-RunShellScript `
  --parameters "file://$paramFile" --query Command.CommandId --output text
Remove-Item $paramFile
Write-Host "release $sha -> $instance (command $id); loading the CI-built images on the host..."

do {
  Start-Sleep -Seconds 15
  $status = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --query Status --output text 2>$null
} while ($status -in @('Pending', 'InProgress', 'Delayed', $null, ''))

$result = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --output json | ConvertFrom-Json
"STATUS: $($result.Status)"
$result.StandardOutputContent
if ($result.StandardErrorContent) { '--- stderr ---'; $result.StandardErrorContent }
if ($result.Status -ne 'Success') { exit 1 }
