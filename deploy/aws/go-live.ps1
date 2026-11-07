# Stage 3 in one run, by the operator from a signed-in machine:
#   1. restarts OpenWA on its host, so WhatsApp codes work again
#   2. takes a database backup and copies it off the host
#   3. ships the committed HEAD (migrations included), through release.ps1
#   4. proves the newest backup restores (host/restore-drill.sh)
#   5. creates the outside uptime alarm (uptime.yaml)
#   6. protects the backups (RA-OP-04): versions in the ops and media
#      buckets, so an overwritten or deleted object is kept 30 days, and the
#      host disk's daily snapshots (backups.yaml). server.yaml is never
#      redeployed here (RA-OP-13).
# It stops at the first failure. Safe to run again. No secret is printed.
# Requires `aws login` and the `rk-server` SSH alias.
param(
  [string]$Region = 'eu-central-1',
  [string]$Stack = 'aarast-host',
  [string]$ApiUrl = 'https://api.3-121-198-183.sslip.io'
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

function Step([string]$text) { Write-Host "`n=== $text" -ForegroundColor Cyan }

function Invoke-OnHost([string]$instance, [string]$script) {
  $params = @{ commands = @($script -replace "`r", ''); executionTimeout = @('1800') } | ConvertTo-Json -Compress
  $paramFile = New-TemporaryFile
  Set-Content -LiteralPath $paramFile -Value $params -Encoding utf8NoBOM
  $id = & $aws ssm send-command --region $Region --instance-ids $instance --document-name AWS-RunShellScript `
    --parameters "file://$paramFile" --query Command.CommandId --output text
  Remove-Item $paramFile
  do {
    Start-Sleep -Seconds 5
    $status = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --query Status --output text 2>$null
  } while ($status -in @('Pending', 'InProgress', 'Delayed', $null, ''))
  $result = & $aws ssm get-command-invocation --region $Region --command-id $id --instance-id $instance --output json | ConvertFrom-Json
  $result.StandardOutputContent
  if ($result.Status -ne 'Success') {
    $result.StandardErrorContent
    throw "the host command ended as $($result.Status)"
  }
}

Step 'الدخول إلى AWS'
& $aws sts get-caller-identity --query Account --output text | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'انتهت جلسة AWS: شغّل aws login ثم أعد هذا السكربت' }
$outputs = & $aws cloudformation describe-stacks --region $Region --stack-name $Stack `
  --query 'Stacks[0].Outputs' --output json | ConvertFrom-Json
$instance = ($outputs | Where-Object OutputKey -eq 'InstanceId').OutputValue
$opsBucket = ($outputs | Where-Object OutputKey -eq 'OpsBucketName').OutputValue
$mediaBucket = ($outputs | Where-Object OutputKey -eq 'MediaBucketName').OutputValue

Step '1 من 6: إعادة تشغيل OpenWA'
ssh -o BatchMode=yes -o ConnectTimeout=15 rk-server 'sudo -n systemctl restart aarast-openwa.service'
if ($LASTEXITCODE -ne 0) { throw 'ما قدرنا نعيد تشغيل OpenWA على rk-server' }
Start-Sleep -Seconds 45

Step '2 من 6: نسخة احتياطية قبل النشر'
Invoke-OnHost $instance @"
set -eu
c=`$(docker ps -qf name=postgres-backup)
docker exec "`$c" /backup.sh >/dev/null
aws s3 sync /var/lib/docker/volumes/aarast_postgres_backups/_data s3://$opsBucket/backups/ --only-show-errors
echo backup done
"@

Step '3 من 6: نشر آخر نسخة من main'
& (Join-Path $PSScriptRoot 'release.ps1')
if ($LASTEXITCODE -ne 0) { throw 'فشل النشر: النسخة السابقة ما زالت على الخادم إن لم يكتمل التشغيل' }

Step '4 من 6: تجربة استرجاع النسخة في قاعدة مؤقتة'
Invoke-OnHost $instance 'bash /opt/aarast/current/deploy/aws/host/restore-drill.sh'

Step '5 من 6: تنبيهات توقف الخادم أو الرموز'
$alertEmail = & $aws cloudformation describe-stacks --region us-east-1 --stack-name aarast-spend-alerts `
  --query "Stacks[0].Parameters[?ParameterKey=='AlertEmail'].ParameterValue" --output text
& $aws cloudformation deploy --region $Region --stack-name aarast-uptime `
  --template-file (Join-Path $PSScriptRoot 'uptime.yaml') --capabilities CAPABILITY_NAMED_IAM `
  --no-fail-on-empty-changeset --parameter-overrides "AlertEmail=$alertEmail" "InstanceId=$instance"
if ($LASTEXITCODE -ne 0) { throw 'ما انخلقت التنبيهات' }
Write-Host 'افتح البريد واضغط تأكيد الاشتراك في AWS Notifications، وإلا لن تصلك التنبيهات.'

Step '6 من 6: حماية النسخ والصور'
# Versions keep an overwritten or deleted object for 30 days: the host may
# write backups/ and delete media, so neither a bad write nor a slip is final.
foreach ($bucket in $opsBucket, $mediaBucket) {
  & $aws s3api put-bucket-versioning --region $Region --bucket $bucket `
    --versioning-configuration Status=Enabled
  if ($LASTEXITCODE -ne 0) { throw "ما تفعّلت النسخ في $bucket" }
}
# The ops bucket's rules as server.yaml has them, plus the old versions'.
$opsRules = @{ Rules = @(
    @{ ID = 'ExpireOldBackups'; Status = 'Enabled'; Filter = @{ Prefix = 'backups/' }
       Expiration = @{ Days = 30 }; NoncurrentVersionExpiration = @{ NoncurrentDays = 30 } },
    @{ ID = 'ExpireOldReleases'; Status = 'Enabled'; Filter = @{ Prefix = 'releases/' }
       Expiration = @{ Days = 30 }; NoncurrentVersionExpiration = @{ NoncurrentDays = 7 } }
  ) }
$mediaRules = @{ Rules = @(
    @{ ID = 'KeepDeletedMedia30Days'; Status = 'Enabled'; Filter = @{ Prefix = '' }
       NoncurrentVersionExpiration = @{ NoncurrentDays = 30 }
       AbortIncompleteMultipartUpload = @{ DaysAfterInitiation = 2 } }
  ) }
foreach ($pair in @(@($opsBucket, $opsRules), @($mediaBucket, $mediaRules))) {
  $rulesFile = New-TemporaryFile
  Set-Content -LiteralPath $rulesFile -Value ($pair[1] | ConvertTo-Json -Depth 6 -Compress) -Encoding utf8NoBOM
  & $aws s3api put-bucket-lifecycle-configuration --region $Region --bucket $pair[0] `
    --lifecycle-configuration "file://$rulesFile"
  $code = $LASTEXITCODE
  Remove-Item $rulesFile
  if ($code -ne 0) { throw "ما انضبطت مدة الاحتفاظ في $($pair[0])" }
}
# A first creation that failed leaves the stack in ROLLBACK_COMPLETE, holding
# nothing, and CloudFormation updates no stack in that state: it is removed
# first, so a run after a failure goes through (go-live, 2026-11-07).
$backupsStatus = & $aws cloudformation describe-stacks --region $Region --stack-name aarast-backups `
  --query 'Stacks[0].StackStatus' --output text 2>$null
if ($backupsStatus -eq 'ROLLBACK_COMPLETE') {
  & $aws cloudformation delete-stack --region $Region --stack-name aarast-backups
  & $aws cloudformation wait stack-delete-complete --region $Region --stack-name aarast-backups
  if ($LASTEXITCODE -ne 0) { throw 'ما انحذفت محاولة لقطات القرص الفاشلة' }
}
& $aws cloudformation deploy --region $Region --stack-name aarast-backups `
  --template-file (Join-Path $PSScriptRoot 'backups.yaml') --capabilities CAPABILITY_IAM `
  --no-fail-on-empty-changeset
if ($LASTEXITCODE -ne 0) { throw 'ما انخلقت لقطات القرص اليومية' }

Step 'النتيجة'
foreach ($path in '/live', '/ready/core', '/ready') {
  $response = Invoke-WebRequest -Uri "$ApiUrl$path" -SkipHttpErrorCheck -TimeoutSec 15
  "$path -> $($response.StatusCode) $($response.Content)"
}
Write-Host "`nإذا كان /ready يقول openwa down بعد دقيقتين، فجلسة واتساب تحتاج مسح QR: deploy/staging/OPENWA_HOST_RECOVERY.md"
