# Ships the committed HEAD of this repository to the Aarast AWS host:
# packs backend, admin-web and deploy (LF line endings), uploads the archive to
# the ops bucket, and runs deploy/aws/host/deploy.sh on the host through SSM.
# Requires `aws login` on this machine. No secrets pass through here.
param(
  [string]$Region = 'eu-central-1',
  [string]$Stack = 'aarast-host',
  [string]$BaseHost = '3-121-198-183.sslip.io',
  [string]$OpenWaLinkTarget = 'rk@81.17.102.27'
)
$ErrorActionPreference = 'Stop'
$aws = 'C:\Program Files\Amazon\AWSCLIV2\aws.exe'
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$outputs = & $aws cloudformation describe-stacks --region $Region --stack-name $Stack `
  --query 'Stacks[0].Outputs' --output json | ConvertFrom-Json
$value = { param($key) ($outputs | Where-Object OutputKey -eq $key).OutputValue }
$instance = & $value 'InstanceId'
$opsBucket = & $value 'OpsBucketName'
$mediaBucket = & $value 'MediaBucketName'

$sha = (git -C $repo rev-parse HEAD).Trim()
$dirty = git -C $repo status --porcelain -- backend admin-web deploy
if ($dirty) { Write-Warning 'Uncommitted changes are NOT shipped; only HEAD is.' }

$archive = Join-Path $env:TEMP "aarast-$sha.tar.gz"
git -C $repo -c core.autocrlf=false -c core.eol=lf archive --format=tar.gz -o $archive HEAD backend admin-web deploy
& $aws s3 cp $archive "s3://$opsBucket/releases/$sha/source.tar.gz" --region $Region --only-show-errors
Remove-Item $archive

# SSM runs this with sh; the host scripts themselves run under bash.
$script = @"
set -eu
tree=/opt/aarast/releases/$sha
mkdir -p "`$tree"
aws s3 cp s3://$opsBucket/releases/$sha/source.tar.gz /tmp/aarast-$sha.tar.gz --only-show-errors
tar -xzf /tmp/aarast-$sha.tar.gz -C "`$tree"
rm -f /tmp/aarast-$sha.tar.gz
bash "`$tree/deploy/aws/host/prepare-env.sh" $BaseHost $mediaBucket $Region $OpenWaLinkTarget
bash "`$tree/deploy/aws/host/deploy.sh" $sha $opsBucket
"@
$params = @{ commands = @($script -replace "`r", ''); executionTimeout = @('3600') } | ConvertTo-Json -Compress
$paramFile = New-TemporaryFile
Set-Content -LiteralPath $paramFile -Value $params -Encoding utf8NoBOM
$id = & $aws ssm send-command --region $Region --instance-ids $instance --document-name AWS-RunShellScript `
  --parameters "file://$paramFile" --query Command.CommandId --output text
Remove-Item $paramFile
Write-Host "release $sha -> $instance (command $id); building on the host..."

do {
  Start-Sleep -Seconds 15
  $status = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --query Status --output text 2>$null
} while ($status -in @('Pending', 'InProgress', 'Delayed', $null, ''))

$result = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --output json | ConvertFrom-Json
"STATUS: $($result.Status)"
$result.StandardOutputContent
if ($result.StandardErrorContent) { '--- stderr ---'; $result.StandardErrorContent }
if ($result.Status -ne 'Success') { exit 1 }
