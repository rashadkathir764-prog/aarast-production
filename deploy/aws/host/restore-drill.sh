#!/bin/bash
# Proves the newest daily backup restores whole. It is loaded into a scratch
# database next to the live one, then checked against it: every table, the
# applied migrations, the constraints and indexes, and the row counts. The
# scratch database is dropped at the end; the live one is only read, and the
# backend keeps running. A restore re-checks every foreign key and unique rule
# on the data, so any restore error fails the drill: a damaged or partial
# backup cannot pass. No secret is printed.
# Usage on the host: bash restore-drill.sh
# (DRILL_CONTAINER and DRILL_BACKUPS point it elsewhere for a local proof.)
set -u
container=${DRILL_CONTAINER:-aarast-postgres-1}
backups=${DRILL_BACKUPS:-/var/lib/docker/volumes/aarast_postgres_backups/_data/last}
drill=aarast_restore_drill

# The newest real file: the backup image also keeps an aarast-latest link.
file=$(ls -1t "$backups"/*.sql.gz 2>/dev/null | grep -v -- '-latest\.sql\.gz$' | head -1)
[ -n "$file" ] || { echo "FAIL: no backup in $backups" >&2; exit 1; }
echo "backup: $(basename "$file"), $(stat -c %s "$file") bytes, $(stat -c %y "$file" | cut -c1-16)"
gzip -t "$file" || { echo "FAIL: the backup is damaged" >&2; exit 1; }

live=$(docker exec "$container" sh -c 'printf %s "$POSTGRES_DB"')
sql() { docker exec -i "$container" sh -c 'psql -q -tA -U "$POSTGRES_USER" -d "$1" -c "$2"' sh "$1" "$2"; }
cleanup() { sql postgres "DROP DATABASE IF EXISTS $drill" >/dev/null 2>&1; }
trap cleanup EXIT
status=0
fail() { echo "FAIL: $*"; status=1; }
# comm needs one byte order on both sides, whatever the database collation.
sorted() { printf '%s\n' "$1" | LC_ALL=C sort; }

cleanup
sql postgres "CREATE DATABASE $drill" || exit 1
log=$(mktemp)
started=$(date +%s)
gunzip -c "$file" \
  | docker exec -i "$container" sh -c 'psql -q -U "$POSTGRES_USER" -d "$1"' sh "$drill" >/dev/null 2>"$log"
seconds=$(($(date +%s) - started))
errors=$(grep -c ERROR "$log" || true)
grep ERROR "$log" | cut -c1-120 | sort | uniq -c | sort -rn | head -5
rm -f "$log"
[ "$errors" = 0 ] || fail "$errors restore errors"

# Migrations: the backup's history must be the live history or an older part
# of it (a deploy after the backup adds migrations; nothing removes one).
migrations="SELECT migration_name FROM _prisma_migrations WHERE finished_at IS NOT NULL AND rolled_back_at IS NULL"
backup_migrations=$(sql "$drill" "$migrations" 2>/dev/null) || backup_migrations=
live_migrations=$(sql "$live" "$migrations")
[ -n "$backup_migrations" ] || fail "the backup has no migration history"
unknown=$(comm -23 <(sorted "$backup_migrations") <(sorted "$live_migrations") | grep -c . || true)
[ "$unknown" = 0 ] || fail "$unknown migrations in the backup are not in the live database"
newer=$(comm -13 <(sorted "$backup_migrations") <(sorted "$live_migrations") | grep -c . || true)
echo "migrations: $(printf '%s\n' "$backup_migrations" | grep -c .) in the backup, $newer applied since"

# Structure: with no migration since the backup, it must match the live one
# exactly; after one, every table of the backup must still exist.
tables="SELECT tablename FROM pg_tables WHERE schemaname = 'public'"
constraints="SELECT count(*) FROM pg_constraint c JOIN pg_namespace n ON n.oid = c.connamespace WHERE n.nspname = 'public'"
indexes="SELECT count(*) FROM pg_indexes WHERE schemaname = 'public'"
backup_tables=$(sorted "$(sql "$drill" "$tables")")
live_tables=$(sorted "$(sql "$live" "$tables")")
gone=$(comm -23 <(printf '%s\n' "$backup_tables") <(printf '%s\n' "$live_tables") | grep -c . || true)
[ "$gone" = 0 ] || fail "$gone tables of the backup are not in the live database"
if [ "$newer" = 0 ]; then
  [ "$backup_tables" = "$live_tables" ] || fail "the backup's tables differ from the live ones"
  for check in constraints indexes; do
    restored=$(sql "$drill" "${!check}"); current=$(sql "$live" "${!check}")
    [ "$restored" = "$current" ] || fail "$check: backup=$restored live=$current"
  done
fi
echo "structure: $(printf '%s\n' "$backup_tables" | grep -c .) tables, $(sql "$drill" "$constraints") constraints, $(sql "$drill" "$indexes") indexes"

# Rows: every table is read back. The live database moves on after the
# backup, so counts are reported, not required to match.
backup_rows=0; live_rows=0; moved=0
for table in $backup_tables; do
  restored=$(sql "$drill" "SELECT count(*) FROM \"$table\"") || { fail "$table does not read back"; continue; }
  current=$(sql "$live" "SELECT count(*) FROM \"$table\"" 2>/dev/null) || current=0
  backup_rows=$((backup_rows + restored)); live_rows=$((live_rows + current))
  [ "$restored" = "$current" ] || moved=$((moved + 1))
done
echo "rows: backup=$backup_rows live=$live_rows ($moved tables changed since the backup)"
echo "restored in $seconds seconds"
[ "$status" = 0 ] && echo "PASS: the backup restores whole"
exit "$status"
