#!/bin/bash
# A physical base backup of the live database (RA-BE-147): the starting point
# pitr-restore.sh replays the archived WAL on. The WAL itself is not in it
# (-X none): it comes from the archive wal-sync.sh keeps in the ops bucket.
# Run weekly by the cron deploy.sh installs. Kept two on the host, and in the
# ops bucket under backups/base/ (the bucket's 30-day rule is the window a
# point in time can be reached in). The name is the time the backup finished,
# so a time at or after it is always recoverable from it.
# Usage: base-backup.sh <ops-bucket>
set -euo pipefail
ops_bucket=${1:?ops bucket}
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=release-lib.sh
. "$here/release-lib.sh"
current=$(release_current)
[ -n "$current" ] || { echo "FAIL: no live release" >&2; exit 1; }
owner=$(sed -n 's/^POSTGRES_OWNER_USER=//p' "$env_file")
cd "/opt/aarast/releases/$current/deploy/aws"
export AARAST_RELEASE=$current
dir=/opt/aarast/backups/base
install -d -m 0700 "$dir"
tmp=$dir/in-progress.tar.gz
dc exec -T postgres pg_basebackup -U "$owner" -D - -Ft -z -X none --checkpoint=fast >"$tmp"
gzip -t "$tmp" || { rm -f "$tmp"; echo "FAIL: the base backup is damaged" >&2; exit 1; }
[ -s "$tmp" ] || { rm -f "$tmp"; echo "FAIL: the base backup is empty" >&2; exit 1; }
stamp=$(date -u +%Y%m%dT%H%M%SZ)
mv -f "$tmp" "$dir/$stamp.tar.gz"
aws s3 cp "$dir/$stamp.tar.gz" "s3://$ops_bucket/backups/base/$stamp.tar.gz" --only-show-errors
echo "base backup $stamp ($(stat -c %s "$dir/$stamp.tar.gz") bytes, copied to the ops bucket)"
ls -1t "$dir"/*.tar.gz 2>/dev/null | tail -n +3 | xargs -r rm -f
