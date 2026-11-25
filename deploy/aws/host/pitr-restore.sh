#!/bin/bash
# Brings the database back to a chosen second, in a scratch instance (RA-BE-147).
# The live database is not touched: a mistake at 14:00 is undone by recovering
# to 13:59, reading what was lost from the scratch instance, and putting that
# back (pg_dump of the tables, or of the whole database, then restore.sh).
# Usage: pitr-restore.sh <ops-bucket> '<YYYY-MM-DD HH:MM:SS>'   (UTC)
# It takes the newest base backup finished at or before that time, every
# archived WAL segment, and starts an isolated Postgres (no network) that
# replays the WAL up to the time and then opens for reading. What was written
# in the last five minutes before a crash may not be in the archive
# (archive_timeout); that is the most a point in time can miss.
set -euo pipefail
ops_bucket=${1:?ops bucket}
target=${2:?time, UTC, as 'YYYY-MM-DD HH:MM:SS'}
image='postgres:16-alpine@sha256:16bc17c64a573ef34162af9298258d1aec548232985b33ed7b1eac33ba35c229'
root=${PITR_ROOT:-/opt/aarast/pitr}

[[ "$target" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}$ ]] \
  || { echo "FAIL: the time must be UTC as 'YYYY-MM-DD HH:MM:SS'" >&2; exit 1; }
want=$(date -u -d "$target UTC" +%Y%m%dT%H%M%SZ 2>/dev/null) \
  || { echo "FAIL: '$target' is not a time (UTC as 'YYYY-MM-DD HH:MM:SS')" >&2; exit 1; }
[ "$(date -u -d "$target UTC" '+%Y-%m-%d %H:%M:%S')" = "$target" ] \
  || { echo "FAIL: '$target' is not a day that exists" >&2; exit 1; }

base=$(aws s3 ls "s3://$ops_bucket/backups/base/" | awk '{print $4}' \
  | grep -E '^[0-9]{8}T[0-9]{6}Z\.tar\.gz$' | sed 's/\.tar\.gz$//' \
  | awk -v want="$want" '$0 <= want' | sort | tail -1 || true)
[ -n "$base" ] || { echo "FAIL: no base backup at or before $target in s3://$ops_bucket/backups/base/" >&2; exit 1; }
echo "base backup: $base"

work=$root/$base
rm -rf "$work"
# Owner-only from creation (umask), as install -m would, and also where
# install cannot set a mode (the contract test on a Windows checkout).
(umask 077 && mkdir -p "$work/data" "$work/wal")
aws s3 cp "s3://$ops_bucket/backups/base/$base.tar.gz" "$work/base.tar.gz" --only-show-errors
gzip -t "$work/base.tar.gz" || { echo "FAIL: the base backup is damaged" >&2; exit 1; }
tar -xzf "$work/base.tar.gz" -C "$work/data"
aws s3 sync "s3://$ops_bucket/backups/wal/" "$work/wal" --only-show-errors
echo "WAL segments: $(ls -1 "$work/wal" | wc -l)"

cat >>"$work/data/postgresql.auto.conf" <<CONF
restore_command = 'cp /wal/%f %p'
recovery_target_time = '$target+00'
recovery_target_action = 'promote'
CONF
touch "$work/data/recovery.signal"
if [ -z "${PITR_NO_CHOWN:-}" ]; then
  chown -R 70:70 "$work/data" "$work/wal"
fi
chmod 0700 "$work/data"

name=aarast-pitr-$base
docker rm -f "$name" >/dev/null 2>&1 || true
docker run -d --name "$name" --network none \
  -v "$work/data:/var/lib/postgresql/data" -v "$work/wal:/wal:ro" "$image" >/dev/null
for _ in $(seq 1 60); do
  if docker exec "$name" sh -c 'pg_isready -q' >/dev/null 2>&1 \
     && [ "$(docker exec "$name" sh -c 'psql -q -tA -U postgres -d postgres -c "SELECT pg_is_in_recovery()"' 2>/dev/null)" = f ]; then
    echo "PASS: the database as of $target UTC is in the container $name (no network; the live database was not touched)"
    echo "Read it:  docker exec $name psql -U postgres -d <database>"
    echo "Dump it:  docker exec $name pg_dump -U <owner> -d <database> --format=custom > recovered.dump"
    echo "Put it back: restore.sh <ops-bucket> recovered.dump (a whole database), or copy only the rows that were lost."
    echo "Remove it when done: docker rm -f $name && rm -rf $work"
    exit 0
  fi
  sleep 5
done
echo "FAIL: the scratch instance did not finish recovering; docker logs $name" >&2
exit 1
