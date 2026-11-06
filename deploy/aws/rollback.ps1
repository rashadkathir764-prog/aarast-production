# Puts the previous release back on the Aarast AWS host (RA-OP-05): runs
# deploy/aws/host/rollback.sh there through SSM. Without -Release it returns
# to the release that was live before the last deploy; deploy.sh keeps its
# tree and images, and dumps the database before each deploy and rollback.
# Requires `aws login` on this machine. No secrets pass through here.
param(
  [string]$Region = 'eu-central-1',
  [string]$Stack = 'aarast-host',
  [string]$Release = ''
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
if ($Release -and $Release -notmatch '^[0-9a-f]{40}$') { throw 'Release must be a full 40-character commit sha.' }

$outputs = & $aws cloudformation describe-stacks --region $Region --stack-name $Stack `
  --query 'Stacks[0].Outputs' --output json | ConvertFrom-Json
$value = { param($key) ($outputs | Where-Object OutputKey -eq $key).OutputValue }
$instance = & $value 'InstanceId'
$opsBucket = & $value 'OpsBucketName'

# SSM runs this with sh; the host script itself runs under bash. The live
# tree's rollback.sh is used, so a release older than the script can still be
# returned to.
$script = @"
set -eu
bash /opt/aarast/current/deploy/aws/host/rollback.sh $opsBucket $Release
"@
$params = @{ commands = @($script -replace "`r", ''); executionTimeout = @('3600') } | ConvertTo-Json -Compress
$paramFile = New-TemporaryFile
Set-Content -LiteralPath $paramFile -Value $params -Encoding utf8NoBOM
$id = & $aws ssm send-command --region $Region --instance-ids $instance --document-name AWS-RunShellScript `
  --parameters "file://$paramFile" --query Command.CommandId --output text
Remove-Item $paramFile
Write-Host "rollback on $instance (command $id)..."

do {
  Start-Sleep -Seconds 15
  $status = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --query Status --output text 2>$null
} while ($status -in @('Pending', 'InProgress', 'Delayed', $null, ''))

$result = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --output json | ConvertFrom-Json
"STATUS: $($result.Status)"
$result.StandardOutputContent
if ($result.StandardErrorContent) { '--- stderr ---'; $result.StandardErrorContent }
if ($result.Status -ne 'Success') { exit 1 }
