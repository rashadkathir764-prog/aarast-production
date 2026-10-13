#!/bin/bash
# Creates /opt/aarast/app/.env once, with random secrets generated on the host
# (they never leave it). Re-running keeps the existing file.
# Usage: prepare-env.sh <base-host> <media-bucket> <aws-region> <openwa-link-target>
#   base-host e.g. 3-121-198-183.sslip.io -> api.<base>, admin.<base>, <base>
set -euo pipefail
base_host=${1:?base host}
media_bucket=${2:?media bucket}
region=${3:?aws region}
openwa_target=${4:?openwa link target user@host}

env_file=/opt/aarast/app/.env
if [ -f "$env_file" ]; then
  echo "kept existing $env_file"
  exit 0
fi
install -d -m 0700 /opt/aarast/app
secret() { openssl rand -hex "$1"; }
owner_pw=$(secret 24)
migrator_pw=$(secret 24)
runtime_pw=$(secret 24)

umask 077
cat >"$env_file" <<EOF
AWS_REGION=$region
AARAST_API_HOST=api.$base_host
AARAST_ADMIN_HOST=admin.$base_host
AARAST_SITE_HOST=$base_host
AARAST_MEDIA_BUCKET=$media_bucket
OPENWA_LINK_TARGET=$openwa_target
POSTGRES_DB=aarast
POSTGRES_OWNER_USER=aarast_owner
POSTGRES_OWNER_PASSWORD=$owner_pw
AARAST_DB_MIGRATOR_USER=aarast_migrator
AARAST_DB_MIGRATOR_PASSWORD=$migrator_pw
AARAST_DB_RUNTIME_USER=aarast_runtime
AARAST_DB_RUNTIME_PASSWORD=$runtime_pw
AARAST_DB_MIGRATOR_DATABASE_URL=postgresql://aarast_migrator:$migrator_pw@postgres:5432/aarast?schema=public
AARAST_DB_RUNTIME_DATABASE_URL=postgresql://aarast_runtime:$runtime_pw@postgres:5432/aarast?schema=public
JWT_ACCESS_SECRET=$(secret 48)
AUTH_LOGIN_THROTTLE_PEPPER=$(secret 32)
METRICS_TOKEN=$(secret 24)
EOF
chmod 0600 "$env_file"
echo "created $env_file"
