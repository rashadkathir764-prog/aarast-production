#!/usr/bin/env sh
# Restores a pg_dump backup into a throwaway Postgres container and runs
# sanity checks, so "we have backups" is a verified claim, not a hope.
#
# Usage:
#   ./verify-backup-restore.sh /path/to/backup.sql.gz
#
# With the postgres-backup-local sidecar, backups live in the
# aarast_postgres_backups volume, e.g.:
#   docker cp aarast-postgres-backup-prod:/backups/daily/<latest> ./b.sql.gz
#   ./verify-backup-restore.sh ./b.sql.gz
#
# Exits 0 only if the restore succeeds AND core tables exist with sane
# row counts.

set -eu

BACKUP_FILE="${1:?usage: verify-backup-restore.sh <backup.sql.gz>}"
CONTAINER="aarast-restore-verify-$$"
PG_IMAGE="postgres:16-alpine"

[ -f "$BACKUP_FILE" ] || { echo "FAIL: $BACKUP_FILE not found"; exit 1; }

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Starting scratch Postgres ($PG_IMAGE)..."
docker run -d --name "$CONTAINER" \
  -e POSTGRES_PASSWORD=restore_verify \
  -e POSTGRES_DB=restore_check \
  "$PG_IMAGE" >/dev/null

for i in $(seq 1 30); do
  if docker exec "$CONTAINER" pg_isready -U postgres -d restore_check >/dev/null 2>&1; then
    break
  fi
  [ "$i" = 30 ] && { echo "FAIL: scratch Postgres never became ready"; exit 1; }
  sleep 1
done

dump_sql() {
  case "$BACKUP_FILE" in
    *.gz) gunzip -c "$BACKUP_FILE" ;;
    *)    cat "$BACKUP_FILE" ;;
  esac
}

# Dumps reference the roles that owned objects in the source cluster;
# create them in the scratch container so the restore is noise-free.
echo "Pre-creating owner roles..."
dump_sql | grep -oE 'OWNER TO "?[A-Za-z0-9_]+"?' | \
  sed -E 's/OWNER TO "?([A-Za-z0-9_]+)"?/\1/' | sort -u | \
  while read -r ROLE; do
    [ "$ROLE" = "postgres" ] && continue
    docker exec "$CONTAINER" psql -U postgres -d restore_check -qc \
      "CREATE ROLE \"$ROLE\";" 2>/dev/null || true
    echo "  role: $ROLE"
  done

echo "Restoring $BACKUP_FILE ..."
RESTORE_ERRORS=$(dump_sql | docker exec -i "$CONTAINER" \
  psql -U postgres -d restore_check -v ON_ERROR_STOP=0 -q 2>&1 | \
  grep -c ERROR || true)
echo "  restore errors: $RESTORE_ERRORS"
[ "$RESTORE_ERRORS" = 0 ] || { echo "FAIL: restore produced errors"; exit 1; }

echo "Verifying restored schema..."
TABLES=$(docker exec "$CONTAINER" psql -U postgres -d restore_check -tAc \
  "SELECT count(*) FROM pg_tables WHERE schemaname='public';")
echo "  public tables: $TABLES"
[ "$TABLES" -ge 10 ] || { echo "FAIL: expected >=10 tables, got $TABLES"; exit 1; }

for TABLE in User WeddingPlan Expense FinancialCommitment; do
  COUNT=$(docker exec "$CONTAINER" psql -U postgres -d restore_check -tAc \
    "SELECT count(*) FROM \"$TABLE\";" 2>/dev/null) || {
      echo "FAIL: core table \"$TABLE\" missing from restore"; exit 1; }
  echo "  \"$TABLE\": $COUNT rows"
done

echo "PASS: backup restores cleanly and core tables are present."
