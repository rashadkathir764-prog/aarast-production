#!/bin/bash
# Sends the WAL segments Postgres archived (compose.yml, RA-BE-147) to the ops
# bucket, and removes each from the host only after it was sent. Run every five
# minutes by the cron deploy.sh installs; a failure leaves the file for the next
# run and fails this one, so the cron mail and the disk alarm see it.
# Usage: wal-sync.sh <ops-bucket>
set -euo pipefail
ops_bucket=${1:?ops bucket}
dir=${WAL_ARCHIVE_DIR:-/var/lib/docker/volumes/aarast_postgres_wal/_data}
[ -d "$dir" ] || { echo "FAIL: no WAL archive at $dir" >&2; exit 1; }
sent=0
failed=0
for file in "$dir"/*; do
  [ -f "$file" ] || continue
  case "$file" in *.partial) continue ;; esac
  name=$(basename "$file")
  if aws s3 cp "$file" "s3://$ops_bucket/backups/wal/$name" --only-show-errors; then
    rm -f "$file"
    sent=$((sent + 1))
  else
    failed=$((failed + 1))
  fi
done
[ "$failed" = 0 ] || { echo "FAIL: $failed WAL segments were not sent; they stay on the host" >&2; exit 1; }
[ "$sent" = 0 ] || echo "sent $sent WAL segments"
