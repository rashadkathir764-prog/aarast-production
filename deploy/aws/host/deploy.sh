#!/bin/bash
# Builds and starts one release on the host. The release tree (git archive of
# backend, admin-web, deploy) is already extracted in /opt/aarast/releases/<sha>.
# Usage: deploy.sh <release-sha> <ops-bucket>
set -euo pipefail
release=${1:?release sha}
ops_bucket=${2:?ops bucket}
tree=/opt/aarast/releases/$release
# shellcheck source=release-lib.sh
. "$tree/deploy/aws/host/release-lib.sh"
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

release_push_env

cd "$tree/deploy/aws"
export AARAST_RELEASE=$release
# The migrations of the new release run inside `up` and only go forward, so
# the database is dumped first; and the release that was live is recorded so
# rollback.sh can put it back (RA-OP-05).
previous=$(release_current)
release_backup_before "before-$release" "$ops_bucket"
if [ -n "$previous" ] && [ "$previous" != "$release" ]; then
  echo "$previous" >/opt/aarast/previous-release
fi
dc up -d --remove-orphans --quiet-pull
ln -sfn "$tree" /opt/aarast/current

# Nightly copy of the database dumps to S3 (kept 30 days by the bucket rule).
cat >/etc/cron.d/aarast-backup-sync <<EOF
30 3 * * * root aws s3 sync /var/lib/docker/volumes/aarast_postgres_backups/_data s3://$ops_bucket/backups/ --only-show-errors
EOF
chmod 0644 /etc/cron.d/aarast-backup-sync

# Keep the two newest release trees and their images: the live one and the
# one rollback.sh can return to.
ls -1dt /opt/aarast/releases/*/ | tail -n +3 | while read -r old; do
  old_sha=$(basename "$old")
  rm -rf "$old"
  docker image rm "aarast-backend:$old_sha" "aarast-admin-web:$old_sha" \
    "aarast-public-site:$old_sha" "aarast-openwa-link:$old_sha" >/dev/null 2>&1 || true
done
docker builder prune -f --filter until=72h >/dev/null 2>&1 || true

if ! release_wait_healthy; then
  echo "FAIL: release $release is not healthy; rollback.sh puts back ${previous:-the previous release}" >&2
  exit 1
fi
echo "PASS: release $release is live"
