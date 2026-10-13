#!/bin/bash
# Builds and starts one release on the host. The release tree (git archive of
# backend, admin-web, deploy) is already extracted in /opt/aarast/releases/<sha>.
# Usage: deploy.sh <release-sha> <ops-bucket>
set -euo pipefail
release=${1:?release sha}
ops_bucket=${2:?ops bucket}
tree=/opt/aarast/releases/$release
env_file=/opt/aarast/app/.env
[ -f "$env_file" ] || { echo "FAIL: run prepare-env.sh first" >&2; exit 1; }
api_host=$(sed -n 's/^AARAST_API_HOST=//p' "$env_file")

cd "$tree"
export DOCKER_BUILDKIT=1
docker build -q -t "aarast-backend:$release" --build-arg "AARAST_GIT_REVISION=$release" backend
docker build -q -t "aarast-admin-web:$release" --build-arg "AARAST_GIT_REVISION=$release" \
  --build-arg "VITE_API_BASE_URL=https://$api_host" admin-web
docker build -q -t "aarast-public-site:$release" --build-arg "AARAST_GIT_REVISION=$release" deploy/public-site
docker build -q -t "aarast-openwa-link:$release" deploy/aws/openwa-link
echo "images built for $release"

cd "$tree/deploy/aws"
AARAST_RELEASE=$release docker compose --env-file "$env_file" up -d --remove-orphans
ln -sfn "$tree" /opt/aarast/current

# Nightly copy of the database dumps to S3 (kept 30 days by the bucket rule).
cat >/etc/cron.d/aarast-backup-sync <<EOF
30 3 * * * root aws s3 sync /var/lib/docker/volumes/aarast_postgres_backups/_data s3://$ops_bucket/backups/ --only-show-errors
EOF
chmod 0644 /etc/cron.d/aarast-backup-sync

# Keep the two newest release trees and their images.
ls -1dt /opt/aarast/releases/*/ | tail -n +3 | while read -r old; do
  old_sha=$(basename "$old")
  rm -rf "$old"
  docker image rm "aarast-backend:$old_sha" "aarast-admin-web:$old_sha" \
    "aarast-public-site:$old_sha" "aarast-openwa-link:$old_sha" >/dev/null 2>&1 || true
done
docker builder prune -f --filter until=72h >/dev/null 2>&1 || true

echo "waiting for the backend to become healthy"
for _ in $(seq 1 40); do
  state=$(docker inspect --format '{{.State.Health.Status}}' "$(docker compose ps -q backend)" 2>/dev/null || echo starting)
  [ "$state" = healthy ] && break
  sleep 6
done
docker compose ps --format 'table {{.Service}}\t{{.Status}}'
[ "$state" = healthy ] || { docker compose logs --tail 60 backend; exit 1; }
echo "PASS: release $release is live"
