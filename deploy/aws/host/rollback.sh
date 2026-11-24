#!/bin/bash
# Puts the previous release back on the host (RA-OP-05).
# Usage: rollback.sh <ops-bucket> [release-sha]
# Without a sha it returns to /opt/aarast/previous-release, which deploy.sh
# records before it switches. deploy.sh keeps that release's tree and images.
#
# Code only, and only when the database allows it (RA-BE-146): the database
# stays as the newer release left it, so before anything starts this reads which
# migrations the target release does not know and refuses the rollback when
# any of them drops, renames or tightens something the older code still uses,
# or adds an enum value it cannot read. Migrations are not only additions. A
# refused rollback is answered by a fix on top of the newer release, or by
# restore.sh with the pre-deploy dump deploy.sh took (the data written since is
# lost; docs/handover/OPERATIONS.md).
set -euo pipefail
ops_bucket=${1:?ops bucket}
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=release-lib.sh
. "$here/release-lib.sh"
[ -f "$env_file" ] || { echo "FAIL: no host env file" >&2; exit 1; }

target=${2:-$(cat /opt/aarast/previous-release 2>/dev/null || true)}
[ -n "$target" ] || { echo "FAIL: no previous release is recorded" >&2; exit 1; }
current=$(release_current)
[ "$target" != "$current" ] || { echo "FAIL: $target is already live" >&2; exit 1; }
tree=/opt/aarast/releases/$target
[ -d "$tree/deploy/aws" ] || { echo "FAIL: the tree of $target is gone" >&2; exit 1; }
for image in aarast-backend aarast-admin-web aarast-public-site aarast-openwa-link; do
  docker image inspect "$image:$target" >/dev/null 2>&1 \
    || { echo "FAIL: image $image:$target is gone" >&2; exit 1; }
done

echo "rolling back from ${current:-nothing} to $target"
[ -n "$current" ] || { echo "FAIL: no live release is recorded, so its migrations cannot be read; nothing was changed" >&2; exit 1; }
release_push_env
cd "$tree/deploy/aws"
# The migrations the database has applied, read from the live database itself.
export AARAST_RELEASE=$current
applied=$(dc exec -T postgres sh -c 'psql -q -tA -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT migration_name FROM _prisma_migrations WHERE finished_at IS NOT NULL AND rolled_back_at IS NULL"') \
  || { echo "FAIL: the applied migrations cannot be read from the database; nothing was changed" >&2; exit 1; }
[ -n "$applied" ] || { echo "FAIL: the database reports no applied migration; nothing was changed" >&2; exit 1; }
release_rollback_check "aarast-backend:$current" "aarast-backend:$target" "$applied"
export AARAST_RELEASE=$target
release_backup_before "before-rollback-to-$target" "$ops_bucket"
dc up -d --remove-orphans --quiet-pull
ln -sfn "$tree" /opt/aarast/current
if [ -n "$current" ]; then echo "$current" >/opt/aarast/previous-release; fi
release_wait_healthy || { echo "FAIL: $target is not healthy either" >&2; exit 1; }
echo "PASS: release $target is live again"
