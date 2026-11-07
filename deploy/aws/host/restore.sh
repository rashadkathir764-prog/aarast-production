#!/bin/bash
# Puts a backup back into the live database (RA-OP-14): for lost or damaged
# data. A bad release alone needs rollback.sh, not this.
# Usage: restore.sh <ops-bucket> <backup-file>
#   <backup-file>  a daily .sql.gz (under /var/lib/docker/volumes/
#                  aarast_postgres_backups/_data), a pre-deploy .dump (under
#                  /opt/aarast/backups/pre-deploy), or an s3:// key in the ops
#                  bucket (older copies, or a new host), fetched first.
# Order: a dump of the database as it is now (so this restore can itself be
# undone), the backend stops, the backup loads into a new database, and only
# when it loads without a single error do the names swap. The database it
# replaces is kept under another name, never dropped here. Then postgres-roles
# re-applies the least-privilege grants to the restored database, migrate
# brings it up to the live release, and the backend starts. What was written
# after the backup is not in it: that is what a restore means.
# No secret is printed.
set -euo pipefail
ops_bucket=${1:?ops bucket}
file=${2:?backup file (.sql.gz or .dump)}
here=$(cd "$(dirname "$0")" && pwd)
# shellcheck source=release-lib.sh
. "$here/release-lib.sh"
[ -f "$env_file" ] || { echo "FAIL: no host env file" >&2; exit 1; }
case "$file" in
  s3://*)
    install -d -m 0700 /opt/aarast/backups/from-bucket
    fetched=/opt/aarast/backups/from-bucket/$(basename "$file")
    aws s3 cp "$file" "$fetched" --only-show-errors \
      || { echo "FAIL: could not fetch $file; nothing was changed" >&2; exit 1; }
    file=$fetched ;;
esac
[ -s "$file" ] || { echo "FAIL: no backup at $file" >&2; exit 1; }
case "$file" in
  *.sql.gz) gzip -t "$file" || { echo "FAIL: the backup is damaged" >&2; exit 1; } ;;
  *.dump) ;;
  *) echo "FAIL: a backup ends in .sql.gz or .dump" >&2; exit 1 ;;
esac
current=$(release_current)
[ -n "$current" ] || { echo "FAIL: no live release to restore under" >&2; exit 1; }
db=$(sed -n 's/^POSTGRES_DB=//p' "$env_file")
incoming=${db}_restore_incoming
kept=${db}_before_restore_$(date -u +%Y%m%dT%H%M%SZ)

release_push_env
cd "/opt/aarast/releases/$current/deploy/aws"
export AARAST_RELEASE=$current
admin() { dc exec -T postgres sh -c 'PGOPTIONS="-c client_min_messages=warning" psql -q -tA -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -c "$1"' sh "$1"; }
# The live database, untouched, back in service: the way out of every failure
# before the names swap.
back_as_it_was() {
  admin "DROP DATABASE IF EXISTS \"$incoming\"" >/dev/null || true
  dc up -d --quiet-pull backend
  release_wait_healthy || true
}

echo "restoring $(basename "$file") under release $current"
release_backup_before before-restore "$ops_bucket"
started=$(date +%s)
dc stop backend
admin "DROP DATABASE IF EXISTS \"$incoming\"" >/dev/null
admin "CREATE DATABASE \"$incoming\"" >/dev/null
log=$(mktemp)
loaded=yes
case "$file" in
  *.sql.gz)
    gunzip -c "$file" \
      | dc exec -T postgres sh -c 'psql -q -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$1"' sh "$incoming" >/dev/null 2>"$log" \
      || loaded=no ;;
  *.dump)
    dc exec -T postgres sh -c 'pg_restore --exit-on-error -U "$POSTGRES_USER" -d "$1"' sh "$incoming" <"$file" 2>"$log" \
      || loaded=no ;;
esac
if [ "$loaded" != yes ]; then
  echo "FAIL: the backup did not load; the live database was not touched:" >&2
  grep -i error "$log" | cut -c1-160 | head -5 >&2
  rm -f "$log"
  back_as_it_was
  exit 1
fi
rm -f "$log"
echo "loaded in $(($(date +%s) - started)) seconds"

# Both renames in one transaction: either the restored database is live, or
# nothing changed. Sessions on the live database are closed first (the backend
# is already stopped; this catches a backup or a console left open).
admin "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$db' AND pid <> pg_backend_pid()" >/dev/null
if ! admin "BEGIN; ALTER DATABASE \"$db\" RENAME TO \"$kept\"; ALTER DATABASE \"$incoming\" RENAME TO \"$db\"; COMMIT;" >/dev/null; then
  echo "FAIL: the names could not be swapped; the live database was not touched" >&2
  back_as_it_was
  exit 1
fi

# postgres-roles and migrate run again before the backend, as on every start.
dc up -d --quiet-pull backend
if ! release_wait_healthy; then
  echo "FAIL: the backend is not healthy on the restored database." >&2
  echo "The database it replaced is $kept: rename it back to $db to undo." >&2
  exit 1
fi
echo "the backend was down for $(($(date +%s) - started)) seconds"
echo "the database as it was is kept as $kept ($(admin "SELECT pg_size_pretty(pg_database_size('$kept'))"))"
echo "once the restore is confirmed, it can be dropped (production data: the owner's call)"
echo "PASS: $(basename "$file") is the live database"
