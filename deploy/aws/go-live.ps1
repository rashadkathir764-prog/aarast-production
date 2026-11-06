# Stage 3 in one run, by the operator from a signed-in machine:
#   1. restarts OpenWA on its host, so WhatsApp codes work again
#   2. takes a database backup and copies it off the host
#   3. ships the committed HEAD (migrations included), through release.ps1
#   4. proves the newest backup restores (host/restore-drill.sh)
#   5. creates the outside uptime alarm (uptime.yaml)
# It stops at the first failure. Safe to run again. No secret is printed.
# Requires `aws login` and the `rk-server` SSH alias.
param(
  [string]$Region = 'eu-central-1',
  [string]$Stack = 'aarast-host',
  [string]$ApiUrl = 'https://api.3-121-198-183.sslip.io'
)
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

Step '1 من 5: إعادة تشغيل OpenWA'
ssh -o BatchMode=yes -o ConnectTimeout=15 rk-server 'sudo -n systemctl restart aarast-openwa.service'
if ($LASTEXITCODE -ne 0) { throw 'ما قدرنا نعيد تشغيل OpenWA على rk-server' }
Start-Sleep -Seconds 45

Step '2 من 5: نسخة احتياطية قبل النشر'
Invoke-OnHost $instance @"
set -eu
c=`$(docker ps -qf name=postgres-backup)
docker exec "`$c" /backup.sh >/dev/null
aws s3 sync /var/lib/docker/volumes/aarast_postgres_backups/_data s3://$opsBucket/backups/ --only-show-errors
echo backup done
"@

Step '3 من 5: نشر آخر نسخة من main'
& (Join-Path $PSScriptRoot 'release.ps1')
if ($LASTEXITCODE -ne 0) { throw 'فشل النشر: النسخة السابقة ما زالت على الخادم إن لم يكتمل التشغيل' }

Step '4 من 5: تجربة استرجاع النسخة في قاعدة مؤقتة'
Invoke-OnHost $instance 'bash /opt/aarast/current/deploy/aws/host/restore-drill.sh'

Step '5 من 5: تنبيهات توقف الخادم أو الرموز'
$alertEmail = & $aws cloudformation describe-stacks --region us-east-1 --stack-name aarast-spend-alerts `
  --query "Stacks[0].Parameters[?ParameterKey=='AlertEmail'].ParameterValue" --output text
& $aws cloudformation deploy --region $Region --stack-name aarast-uptime `
  --template-file (Join-Path $PSScriptRoot 'uptime.yaml') --capabilities CAPABILITY_NAMED_IAM `
  --no-fail-on-empty-changeset --parameter-overrides "AlertEmail=$alertEmail"
if ($LASTEXITCODE -ne 0) { throw 'ما انخلقت التنبيهات' }
Write-Host 'افتح البريد واضغط تأكيد الاشتراك في AWS Notifications، وإلا لن تصلك التنبيهات.'

Step 'النتيجة'
foreach ($path in '/live', '/ready/core', '/ready') {
  $response = Invoke-WebRequest -Uri "$ApiUrl$path" -SkipHttpErrorCheck -TimeoutSec 15
  "$path -> $($response.StatusCode) $($response.Content)"
}
Write-Host "`nإذا كان /ready يقول openwa down بعد دقيقتين، فجلسة واتساب تحتاج مسح QR: deploy/staging/OPENWA_HOST_RECOVERY.md"
