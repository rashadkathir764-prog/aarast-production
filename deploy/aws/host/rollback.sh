#!/bin/bash
# Puts the previous release back on the host (RA-OP-05).
# Usage: rollback.sh <ops-bucket> [release-sha]
# Without a sha it returns to /opt/aarast/previous-release, which deploy.sh
# records before it switches. deploy.sh keeps that release's tree and images.
#
# Code only: the database stays as the newer release left it. An older
# release's `prisma migrate deploy` accepts a database with newer migrations
# applied (verified 2026-11-06), and the migrations only add, so the older code
# runs on it. If a release ever needs its data put back too, restore the
# pre-deploy dump that deploy.sh took (see docs/handover/OPERATIONS.md).
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
release_push_env
cd "$tree/deploy/aws"
export AARAST_RELEASE=$target
release_backup_before "before-rollback-to-$target" "$ops_bucket"
dc up -d --remove-orphans --quiet-pull
ln -sfn "$tree" /opt/aarast/current
if [ -n "$current" ]; then echo "$current" >/opt/aarast/previous-release; fi
release_wait_healthy || { echo "FAIL: $target is not healthy either" >&2; exit 1; }
echo "PASS: release $target is live again"
