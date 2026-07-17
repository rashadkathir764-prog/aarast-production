#!/usr/bin/env sh
# Restore a database backup into an isolated PostgreSQL container, run the
# candidate backend's migrations twice, and verify the canonical Aarast schema.
# Nothing in the source database or running application stack is touched.
#
# Usage:
#   AARAST_VERIFY_BACKEND_IMAGE=sha256:<candidate-image-id> \
#   AARAST_VERIFY_GIT_REVISION=<full-40-character-git-sha> \
#     ./verify-backup-restore.sh /path/to/backup.dump
#
# Supported inputs: pg_dump custom format, plain SQL, and gzip-compressed SQL.
# Optional: AARAST_VERIFY_BACKUP_SHA256=<expected lowercase sha256>.

set -eu

BACKUP_FILE="${1:?usage: verify-backup-restore.sh <backup-file>}"
CANDIDATE_IMAGE="${AARAST_VERIFY_BACKEND_IMAGE:?set immutable AARAST_VERIFY_BACKEND_IMAGE}"
EXPECTED_REVISION="${AARAST_VERIFY_GIT_REVISION:?set AARAST_VERIFY_GIT_REVISION to the candidate full Git SHA}"
EXPECTED_SHA256="${AARAST_VERIFY_BACKUP_SHA256:-}"
PG_IMAGE="${AARAST_VERIFY_POSTGRES_IMAGE:-postgres@sha256:16bc17c64a573ef34162af9298258d1aec548232985b33ed7b1eac33ba35c229}"
CONTAINER="aarast-restore-verify-$$"
NETWORK="aarast-restore-verify-$$"
DATABASE="restore_check"
PASSWORD="restore_verify_only"

[ -f "$BACKUP_FILE" ] || { echo "FAIL: backup file not found"; exit 1; }
case "$CANDIDATE_IMAGE" in
  sha256:*|*@sha256:*) ;;
  *) echo "FAIL: candidate backend image must be immutable"; exit 1 ;;
esac
[ "${#EXPECTED_REVISION}" -eq 40 ] || {
  echo "FAIL: expected Git revision must be a full 40-character lowercase SHA"
  exit 1
}
case "$EXPECTED_REVISION" in
  *[!0-9a-f]*)
    echo "FAIL: expected Git revision must be a full 40-character lowercase SHA"
    exit 1
    ;;
esac
case "$PG_IMAGE" in
  sha256:*|*@sha256:*) ;;
  *) echo "FAIL: PostgreSQL verification image must be pinned by digest"; exit 1 ;;
esac

ACTUAL_REVISION=$(docker image inspect -f \
  '{{ index .Config.Labels "org.opencontainers.image.revision" }}' \
  "$CANDIDATE_IMAGE")
[ "$ACTUAL_REVISION" = "$EXPECTED_REVISION" ] || {
  echo "FAIL: candidate image revision label does not match the expected Git SHA"
  exit 1
}

BACKUP_DIR=$(CDPATH= cd -- "$(dirname -- "$BACKUP_FILE")" && pwd)
BACKUP_NAME=$(basename -- "$BACKUP_FILE")
BACKUP_ABS="$BACKUP_DIR/$BACKUP_NAME"

cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

if [ -n "$EXPECTED_SHA256" ]; then
  ACTUAL_SHA256=$(sha256sum "$BACKUP_ABS" | awk '{print $1}')
  [ "$ACTUAL_SHA256" = "$EXPECTED_SHA256" ] || {
    echo "FAIL: backup checksum mismatch"
    exit 1
  }
  echo "PASS: backup checksum matches"
fi

docker network create --internal "$NETWORK" >/dev/null
docker run -d --name "$CONTAINER" \
  --network "$NETWORK" --network-alias db \
  -e POSTGRES_PASSWORD="$PASSWORD" \
  -e POSTGRES_DB="$DATABASE" \
  -v "$BACKUP_ABS:/backup/input:ro" \
  "$PG_IMAGE" >/dev/null

i=0
# The official PostgreSQL entrypoint briefly starts a socket-only server while
# it creates the requested database, then stops it before launching the final
# server. A socket probe can therefore win that initialization race and let
# pg_restore run during the restart. TCP becomes ready only for the final
# server, so it is the stable readiness contract for this disposable restore.
until docker exec "$CONTAINER" pg_isready -h 127.0.0.1 -U postgres -d "$DATABASE" >/dev/null 2>&1; do
  i=$((i + 1))
  [ "$i" -lt 30 ] || { echo "FAIL: scratch PostgreSQL never became ready"; exit 1; }
  sleep 1
done

dump_sql() {
  case "$BACKUP_NAME" in
    *.gz) gzip -dc "$BACKUP_ABS" ;;
    *) cat "$BACKUP_ABS" ;;
  esac
}

if docker exec "$CONTAINER" pg_restore --list /backup/input >/dev/null 2>&1; then
  echo "Restoring custom-format backup..."
  docker exec "$CONTAINER" pg_restore \
    --exit-on-error --no-owner --no-privileges \
    -U postgres -d "$DATABASE" /backup/input
else
  echo "Restoring plain SQL backup..."
  # Plain dumps may preserve object owners. Recreate only syntactically safe
  # owner roles inside this disposable cluster before restoring.
  dump_sql | grep -oE 'OWNER TO "?[A-Za-z0-9_]+"?' | \
    sed -E 's/OWNER TO "?([A-Za-z0-9_]+)"?/\1/' | sort -u | \
    while IFS= read -r role; do
      [ -n "$role" ] || continue
      [ "$role" = postgres ] && continue
      docker exec "$CONTAINER" psql -U postgres -d "$DATABASE" \
        -v ON_ERROR_STOP=1 -qc "CREATE ROLE \"$role\";" 2>/dev/null || true
    done
  dump_sql | docker exec -i "$CONTAINER" \
    psql -U postgres -d "$DATABASE" -v ON_ERROR_STOP=1 -q
fi

DATABASE_URL="postgresql://postgres:$PASSWORD@db:5432/$DATABASE?schema=public"

run_candidate_migrations() {
  docker run --rm --network "$NETWORK" \
    -e DATABASE_URL="$DATABASE_URL" \
    --entrypoint sh "$CANDIDATE_IMAGE" -ec \
    './node_modules/.bin/prisma migrate deploy && ./node_modules/.bin/prisma migrate status'
}

echo "Running candidate migrations..."
run_candidate_migrations
echo "Re-running migrations to prove a clean second pass..."
run_candidate_migrations

RESULT=$(docker exec "$CONTAINER" psql -U postgres -d "$DATABASE" -Atc '
SELECT
  to_regclass('"'"'"User"'"'"') IS NOT NULL,
  to_regclass('"'"'"WeddingPlan"'"'"') IS NOT NULL,
  to_regclass('"'"'"BudgetCategory"'"'"') IS NOT NULL,
  to_regclass('"'"'"WeddingCost"'"'"') IS NOT NULL,
  to_regclass('"'"'"CostPayment"'"'"') IS NOT NULL,
  to_regclass('"'"'"PaymentSchedule"'"'"') IS NOT NULL,
  to_regclass('"'"'"Expense"'"'"') IS NULL,
  to_regclass('"'"'"FinancialCommitment"'"'"') IS NULL,
  to_regclass('"'"'"FinancialPaymentRecord"'"'"') IS NULL,
  to_regclass('"'"'"FinancialInstallment"'"'"') IS NULL,
  NOT EXISTS (
    SELECT 1 FROM "BudgetCategory"
    WHERE trim("name") = '"'"''"'"' OR trim("normalizedName") = '"'"''"'"'
  ),
  NOT EXISTS (
    SELECT 1 FROM "SharedMember" WHERE "canManageMoney" AND NOT "canViewMoney"
  ),
  NOT EXISTS (
    SELECT 1 FROM "PlanInvite" WHERE "canManageMoney" AND NOT "canViewMoney"
  ),
  NOT EXISTS (
    SELECT 1 FROM "_prisma_migrations"
    WHERE finished_at IS NULL AND rolled_back_at IS NULL
  );')

[ "$RESULT" = "t|t|t|t|t|t|t|t|t|t|t|t|t|t" ] || {
  echo "FAIL: restored database failed canonical schema postconditions"
  exit 1
}

for table in User WeddingPlan BudgetCategory WeddingCost CostPayment PaymentSchedule; do
  count=$(docker exec "$CONTAINER" psql -U postgres -d "$DATABASE" -Atc \
    "SELECT count(*) FROM \"$table\";")
  echo "$table rows: $count"
done

echo "PASS: backup restore, candidate migration, second pass, and canonical schema checks succeeded"
