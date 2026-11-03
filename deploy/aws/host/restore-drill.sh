#!/bin/bash
# Proves the newest backup restores: it is loaded into a scratch database,
# compared with the live one by row counts, and dropped. The live database is
# only read, and the backend keeps running. No secret is printed.
# Usage on the host: bash restore-drill.sh
set -u
container=aarast-postgres-1
drill=aarast_restore_drill
backups=/var/lib/docker/volumes/aarast_postgres_backups/_data/last

file=$(ls -1t "$backups"/*.sql.gz | head -1)
[ -n "$file" ] || { echo "FAIL: no backup in $backups" >&2; exit 1; }
echo "backup: $(basename "$file"), $(stat -c %s "$file") bytes, $(stat -c %y "$file" | cut -c1-16)"
gzip -t "$file" || { echo "FAIL: the backup is damaged" >&2; exit 1; }

live=$(docker exec "$container" sh -c 'printf %s "$POSTGRES_DB"')
sql() { docker exec -i "$container" sh -c 'psql -q -tA -U "$POSTGRES_USER" -d "$1" -c "$2"' sh "$1" "$2"; }
cleanup() { sql postgres "DROP DATABASE IF EXISTS $drill" >/dev/null; }
trap cleanup EXIT

cleanup
sql postgres "CREATE DATABASE $drill" || exit 1
log=$(mktemp)
started=$(date +%s)
gunzip -c "$file" \
  | docker exec -i "$container" sh -c 'psql -q -U "$POSTGRES_USER" -d "$1"' sh "$drill" >/dev/null 2>"$log"
echo "restored in $(($(date +%s) - started)) seconds"
errors=$(grep -c ERROR "$log" || true)
grep ERROR "$log" | cut -c1-120 | sort | uniq -c | sort -rn | head -5
rm -f "$log"

status=0
[ "$errors" = 0 ] || { echo "FAIL: $errors restore errors"; status=1; }
for table in '"User"' '"WeddingPlan"' '"WeddingTask"' '"WeddingCost"' '"Guest"' '"_prisma_migrations"'; do
  restored=$(sql "$drill" "SELECT count(*) FROM $table") || restored=missing
  current=$(sql "$live" "SELECT count(*) FROM $table")
  echo "$table backup=$restored live=$current"
  [ "$restored" != missing ] || status=1
done
[ "$status" = 0 ] && echo "PASS: the backup restores"
exit "$status"
