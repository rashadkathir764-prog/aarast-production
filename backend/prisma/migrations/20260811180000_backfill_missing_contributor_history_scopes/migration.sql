BEGIN;

SET LOCAL lock_timeout = '15s';

-- Prevent a WeddingPlan insert from racing past the backfill/postcondition.
LOCK TABLE "WeddingPlan", "SharedMember", "ContributorHistoryScope", "ContributorTenure"
  IN SHARE ROW EXCLUSIVE MODE;

-- Coverage begins at this repair, not at plan creation: no historical runtime
-- events are claimed for the period in which the scope was missing.
WITH backfill_clock AS (
  SELECT CURRENT_TIMESTAMP AS "backfilledAt"
)
INSERT INTO "ContributorHistoryScope" (
  "id",
  "weddingPlanId",
  "status",
  "historyCoverageStartsAt",
  "archivedAt",
  "createdAt",
  "updatedAt"
)
SELECT
  'scope_backfill_' || md5(plan."id"),
  plan."id",
  CASE
    WHEN plan."status" = 'ARCHIVED' THEN 'ARCHIVED'::"ContributionScopeStatus"
    ELSE 'ACTIVE'::"ContributionScopeStatus"
  END,
  clock."backfilledAt",
  CASE
    WHEN plan."status" = 'ARCHIVED' THEN plan."updatedAt"
    ELSE NULL
  END,
  clock."backfilledAt",
  clock."backfilledAt"
FROM "WeddingPlan" AS plan
CROSS JOIN backfill_clock AS clock
LEFT JOIN "ContributorHistoryScope" AS scope
  ON scope."weddingPlanId" = plan."id"
WHERE scope."id" IS NULL
ON CONFLICT ("weddingPlanId") DO NOTHING;

-- A scope-less plan could already have live contributors. Start their runtime
-- tracking at the repair boundary without claiming pre-repair contributions.
INSERT INTO "ContributorTenure" (
  "id",
  "historyScopeId",
  "actorUserId",
  "actorReference",
  "sharedMemberId",
  "joinedAt",
  "trackingStartedAt",
  "roleAtTrackingStart",
  "createdAt",
  "updatedAt"
)
SELECT
  'tenure_backfill_' || md5(member."id"),
  scope."id",
  member."userId",
  encode(digest(member."userId", 'sha256'), 'hex'),
  member."id",
  member."createdAt",
  CURRENT_TIMESTAMP,
  member."role",
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM "SharedMember" AS member
JOIN "ContributorHistoryScope" AS scope
  ON scope."weddingPlanId" = member."weddingPlanId"
LEFT JOIN "ContributorTenure" AS tenure
  ON tenure."historyScopeId" = scope."id"
  AND tenure."sharedMemberId" = member."id"
  AND tenure."endedAt" IS NULL
WHERE tenure."id" IS NULL
ON CONFLICT ("sharedMemberId") DO NOTHING;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "WeddingPlan" AS plan
    LEFT JOIN "ContributorHistoryScope" AS scope
      ON scope."weddingPlanId" = plan."id"
    WHERE scope."id" IS NULL
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'contributor_history_scope_backfill_incomplete';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "WeddingPlan" AS plan
    JOIN "ContributorHistoryScope" AS scope
      ON scope."weddingPlanId" = plan."id"
    WHERE
      (plan."status" = 'PLANNING' AND scope."status" <> 'ACTIVE')
      OR (plan."status" = 'ARCHIVED' AND scope."status" <> 'ARCHIVED')
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'contributor_history_scope_status_mismatch';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM "SharedMember" AS member
    JOIN "ContributorHistoryScope" AS scope
      ON scope."weddingPlanId" = member."weddingPlanId"
    LEFT JOIN "ContributorTenure" AS tenure
      ON tenure."historyScopeId" = scope."id"
      AND tenure."sharedMemberId" = member."id"
      AND tenure."actorUserId" = member."userId"
      AND tenure."actorReference" = encode(digest(member."userId", 'sha256'), 'hex')
      AND tenure."endedAt" IS NULL
    WHERE tenure."id" IS NULL
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'contributor_current_tenure_backfill_incomplete';
  END IF;
END $$;

COMMIT;
