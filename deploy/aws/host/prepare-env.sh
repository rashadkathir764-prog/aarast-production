#!/bin/bash
# Creates /opt/aarast/app/.env once, with random secrets generated on the host
# (they never leave it). Re-running preserves secrets and adds the public IP once.
# Usage: prepare-env.sh <base-host> <media-bucket> <aws-region> <openwa-link-target> <public-ip>
#   base-host e.g. 3-121-198-183.sslip.io -> api.<base>, admin.<base>, <base>
set -euo pipefail
base_host=${1:?base host}
media_bucket=${2:?media bucket}
region=${3:?aws region}
openwa_target=${4:?openwa link target user@host}
direct_api_ip=${5:?public Elastic IP}

python3 - "$direct_api_ip" <<'PY'
import ipaddress, sys
try:
    address = ipaddress.ip_address(sys.argv[1])
except ValueError:
    raise SystemExit('FAIL: direct API address must be a public IPv4 address')
if address.version != 4 or not address.is_global:
    raise SystemExit('FAIL: direct API address must be a public IPv4 address')
PY

env_file=${AARAST_ENV_FILE:-/opt/aarast/app/.env}
if [ -f "$env_file" ]; then
  count=$(grep -c '^AARAST_DIRECT_API_IP=' "$env_file" || true)
  if [ "$count" = 0 ]; then
    printf '\nAARAST_DIRECT_API_IP=%s\n' "$direct_api_ip" >>"$env_file"
  elif [ "$count" != 1 ] || [ "$(sed -n 's/^AARAST_DIRECT_API_IP=//p' "$env_file")" != "$direct_api_ip" ]; then
    echo "FAIL: existing direct API IP differs; inspect before changing it" >&2
    exit 1
  fi
  echo "kept existing $env_file"
  exit 0
fi
install -d -m 0700 "$(dirname "$env_file")"
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
AARAST_DIRECT_API_IP=$direct_api_ip
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
