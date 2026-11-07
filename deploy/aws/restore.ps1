# Puts a backup back into the Aarast database on the AWS host (RA-OP-14): runs
# deploy/aws/host/restore.sh there through SSM. Without -Backup it only lists
# the backups on the host and changes nothing. With -Backup (a host path, as
# the list shows it) it restores that one; the database as it is now is dumped
# first and kept under another name, so the restore itself can be undone.
# For a bad release alone use rollback.ps1: it keeps the data.
# Requires `aws login` on this machine. No secrets pass through here.
param(
  [string]$Region = 'eu-central-1',
  [string]$Stack = 'aarast-host',
  [string]$Backup = ''
)
# Written for PowerShell 7 (pwsh). From Windows PowerShell 5.1 the script
# runs itself again under pwsh, as rollback.ps1 does.
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
if ($Backup -and $Backup -notmatch '^(/|s3://)[A-Za-z0-9._/-]+\.(sql\.gz|dump)$') {
  throw 'Backup must be a host path or an s3:// key ending in .sql.gz or .dump, as the list shows it.'
}

$outputs = & $aws cloudformation describe-stacks --region $Region --stack-name $Stack `
  --query 'Stacks[0].Outputs' --output json | ConvertFrom-Json
$value = { param($key) ($outputs | Where-Object OutputKey -eq $key).OutputValue }
$instance = & $value 'InstanceId'
$opsBucket = & $value 'OpsBucketName'

if ($Backup) {
  $script = @"
set -eu
bash /opt/aarast/current/deploy/aws/host/restore.sh $opsBucket $Backup
"@
} else {
  $script = @'
set -u
daily=/var/lib/docker/volumes/aarast_postgres_backups/_data
echo "daily backups, newest first (kept 7 days, 4 weeks, 3 months):"
ls -1t "$daily"/daily/*.sql.gz "$daily"/weekly/*.sql.gz "$daily"/monthly/*.sql.gz 2>/dev/null \
  | grep -v -- '-latest\.sql\.gz$' | head -20
echo "taken before each deploy, rollback and restore (the newest five):"
ls -1t /opt/aarast/backups/pre-deploy/*.dump 2>/dev/null
echo "in the ops bucket (30 days), the newest 15:"
aws s3 ls "s3://__OPS_BUCKET__/backups/" --recursive | grep -E '\.(sql\.gz|dump)$' | grep -v -- '-latest\.sql\.gz$' | sort | tail -n 15 \
  | awk '{ print "s3://__OPS_BUCKET__/" $4 }'
'@
  $script = $script.Replace('__OPS_BUCKET__', $opsBucket)
}
$params = @{ commands = @($script -replace "`r", ''); executionTimeout = @('3600') } | ConvertTo-Json -Compress
$paramFile = New-TemporaryFile
Set-Content -LiteralPath $paramFile -Value $params -Encoding utf8NoBOM
$id = & $aws ssm send-command --region $Region --instance-ids $instance --document-name AWS-RunShellScript `
  --parameters "file://$paramFile" --query Command.CommandId --output text
Remove-Item $paramFile
Write-Host $(if ($Backup) { "restore on $instance (command $id)..." } else { "listing backups on $instance..." })

do {
  Start-Sleep -Seconds 10
  $status = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --query Status --output text 2>$null
} while ($status -in @('Pending', 'InProgress', 'Delayed', $null, ''))

$result = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --output json | ConvertFrom-Json
"STATUS: $($result.Status)"
$result.StandardOutputContent
if ($result.StandardErrorContent) { '--- stderr ---'; $result.StandardErrorContent }
if ($result.Status -ne 'Success') { exit 1 }
