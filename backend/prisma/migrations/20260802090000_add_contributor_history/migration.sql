BEGIN;

SET LOCAL lock_timeout = '15s';
LOCK TABLE "WeddingPlan", "SharedMember", "WeddingTask", "QuoteRequest", "PlanInvite" IN SHARE MODE;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TYPE "ContributionScopeStatus" AS ENUM ('ACTIVE', 'ARCHIVED', 'DELETED');
CREATE TYPE "ContributorTenureEndReason" AS ENUM ('MEMBER_REMOVED', 'MEMBER_LEFT', 'ACCOUNT_DELETED', 'PLAN_DELETED');
CREATE TYPE "ContributionSection" AS ENUM ('TASKS', 'GUESTS', 'MONEY', 'PROVIDERS', 'MEMBERS', 'PLAN');
CREATE TYPE "ContributionEntityType" AS ENUM (
  'TASK',
  'TASK_CHECKLIST_ITEM',
  'GUEST',
  'GUEST_GROUP',
  'MONEY_ITEM',
  'BUDGET_CATEGORY',
  'WEDDING_COST',
  'COST_PAYMENT',
  'PAYMENT_SCHEDULE',
  'PROVIDER_ITEM',
  'QUOTE_REQUEST',
  'PLAN_PROVIDER_LINK',
  'MEMBER_ITEM',
  'PLAN_INVITE',
  'PLAN',
  'SECTION'
);
CREATE TYPE "ContributionAction" AS ENUM (
  'CREATED',
  'UPDATED',
  'DELETED',
  'ASSIGNED',
  'UNASSIGNED',
  'COMPLETED',
  'REOPENED',
  'STATUS_CHANGED',
  'PAYMENT_RECORDED',
  'PAYMENT_REVERSED',
  'INVITED',
  'SECTION_REVOKED',
  'MEMBER_LEFT',
  'MEMBER_REMOVED',
  'LEGACY_CAPTURED'
);
CREATE TYPE "ContributionProvenance" AS ENUM ('RUNTIME', 'REVOCATION_SNAPSHOT', 'LEGACY_EXPLICIT');
CREATE TYPE "ContributionPermission" AS ENUM (
  'MANAGE_TASKS',
  'MANAGE_GUESTS',
  'VIEW_MONEY',
  'MANAGE_MONEY',
  'MANAGE_PROVIDERS',
  'MANAGE_MEMBERS',
  'MANAGE_PLAN'
);

ALTER TABLE "SharedMember"
  ADD COLUMN "authorityVersion" INTEGER NOT NULL DEFAULT 1;

CREATE TABLE "ContributorHistoryScope" (
  "id" TEXT NOT NULL,
  "weddingPlanId" TEXT,
  "status" "ContributionScopeStatus" NOT NULL DEFAULT 'ACTIVE',
  "historyCoverageStartsAt" TIMESTAMP(3) NOT NULL,
  "archivedAt" TIMESTAMP(3),
  "deletedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ContributorHistoryScope_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ContributorHistoryScope_lifecycle_check"
    CHECK (
      (
        "status" = 'ACTIVE'::"ContributionScopeStatus"
        AND "weddingPlanId" IS NOT NULL
        AND "archivedAt" IS NULL
        AND "deletedAt" IS NULL
      )
      OR (
        "status" = 'ARCHIVED'::"ContributionScopeStatus"
        AND "weddingPlanId" IS NOT NULL
        AND "archivedAt" IS NOT NULL
        AND "deletedAt" IS NULL
      )
      OR (
        "status" = 'DELETED'::"ContributionScopeStatus"
        AND "deletedAt" IS NOT NULL
      )
    )
);

CREATE TABLE "ContributorTenure" (
  "id" TEXT NOT NULL,
  "historyScopeId" TEXT NOT NULL,
  "actorUserId" TEXT,
  "actorReference" CHAR(64) NOT NULL,
  "sharedMemberId" TEXT,
  "joinedAt" TIMESTAMP(3) NOT NULL,
  "trackingStartedAt" TIMESTAMP(3) NOT NULL,
  "endedAt" TIMESTAMP(3),
  "endReason" "ContributorTenureEndReason",
  "roleAtTrackingStart" "SharedMemberRole" NOT NULL,
  "roleAtEnd" "SharedMemberRole",
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "ContributorTenure_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ContributorTenure_actor_reference_check"
    CHECK ("actorReference" ~ '^[0-9a-f]{64}$'),
  CONSTRAINT "ContributorTenure_lifecycle_check"
    CHECK (
      (
        "endedAt" IS NULL
        AND "endReason" IS NULL
        AND "sharedMemberId" IS NOT NULL
      )
      OR (
        "endedAt" IS NOT NULL
        AND "endReason" IS NOT NULL
        AND "sharedMemberId" IS NULL
      )
    )
);

CREATE TABLE "ContributionEvent" (
  "id" TEXT NOT NULL,
  "historyScopeId" TEXT NOT NULL,
  "contributorTenureId" TEXT NOT NULL,
  "section" "ContributionSection" NOT NULL,
  "entityType" "ContributionEntityType" NOT NULL,
  "entityId" TEXT,
  "action" "ContributionAction" NOT NULL,
  "snapshot" JSONB NOT NULL,
  "snapshotHash" CHAR(64) NOT NULL,
  "snapshotVersion" INTEGER NOT NULL DEFAULT 1,
  "dedupeKey" VARCHAR(200) NOT NULL,
  "eventFingerprint" CHAR(64) NOT NULL,
  "provenance" "ContributionProvenance" NOT NULL,
  "requiredPermission" "ContributionPermission",
  "permissionPolicyVersion" INTEGER NOT NULL DEFAULT 1,
  "authorityVersion" INTEGER NOT NULL DEFAULT 1,
  "occurredAt" TIMESTAMP(3),
  "capturedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ContributionEvent_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ContributionEvent_snapshot_object_check"
    CHECK (jsonb_typeof("snapshot") = 'object'),
  CONSTRAINT "ContributionEvent_snapshot_size_check"
    CHECK (pg_column_size("snapshot") <= 16384),
  CONSTRAINT "ContributionEvent_snapshot_hash_check"
    CHECK ("snapshotHash" ~ '^[0-9a-f]{64}$' AND "eventFingerprint" ~ '^[0-9a-f]{64}$'),
  CONSTRAINT "ContributionEvent_dedupe_key_check"
    CHECK (length(btrim("dedupeKey")) > 0),
  CONSTRAINT "ContributionEvent_snapshot_version_check"
    CHECK ("snapshotVersion" > 0 AND "permissionPolicyVersion" > 0 AND "authorityVersion" > 0),
  CONSTRAINT "ContributionEvent_section_entity_check"
    CHECK (
      "entityType" = 'SECTION'::"ContributionEntityType"
      OR ("section" = 'TASKS'::"ContributionSection" AND "entityType" IN ('TASK'::"ContributionEntityType", 'TASK_CHECKLIST_ITEM'::"ContributionEntityType"))
      OR ("section" = 'GUESTS'::"ContributionSection" AND "entityType" IN ('GUEST'::"ContributionEntityType", 'GUEST_GROUP'::"ContributionEntityType"))
      OR ("section" = 'MONEY'::"ContributionSection" AND "entityType" IN ('MONEY_ITEM'::"ContributionEntityType", 'BUDGET_CATEGORY'::"ContributionEntityType", 'WEDDING_COST'::"ContributionEntityType", 'COST_PAYMENT'::"ContributionEntityType", 'PAYMENT_SCHEDULE'::"ContributionEntityType"))
      OR ("section" = 'PROVIDERS'::"ContributionSection" AND "entityType" IN ('PROVIDER_ITEM'::"ContributionEntityType", 'QUOTE_REQUEST'::"ContributionEntityType", 'PLAN_PROVIDER_LINK'::"ContributionEntityType"))
      OR ("section" = 'MEMBERS'::"ContributionSection" AND "entityType" IN ('MEMBER_ITEM'::"ContributionEntityType", 'PLAN_INVITE'::"ContributionEntityType"))
      OR ("section" = 'PLAN'::"ContributionSection" AND "entityType" = 'PLAN'::"ContributionEntityType")
    ),
  CONSTRAINT "ContributionEvent_entity_identity_check"
    CHECK (
      ("entityType" = 'SECTION'::"ContributionEntityType" AND "entityId" IS NULL)
      OR ("entityType" <> 'SECTION'::"ContributionEntityType" AND "entityId" IS NOT NULL)
    ),
  CONSTRAINT "ContributionEvent_revocation_shape_check"
    CHECK (
      (
        "action" = 'SECTION_REVOKED'::"ContributionAction"
        AND "provenance" = 'REVOCATION_SNAPSHOT'::"ContributionProvenance"
        AND "requiredPermission" IS NOT NULL
      )
      OR (
        "action" <> 'SECTION_REVOKED'::"ContributionAction"
        AND "provenance" <> 'REVOCATION_SNAPSHOT'::"ContributionProvenance"
      )
    ),
  CONSTRAINT "ContributionEvent_action_provenance_entity_check"
    CHECK (
      (
        (
          "action" = 'SECTION_REVOKED'::"ContributionAction"
          AND "entityType" = 'SECTION'::"ContributionEntityType"
        )
        OR (
          "action" <> 'SECTION_REVOKED'::"ContributionAction"
          AND "entityType" <> 'SECTION'::"ContributionEntityType"
        )
      )
      AND (
        (
          "action" = 'LEGACY_CAPTURED'::"ContributionAction"
          AND "provenance" = 'LEGACY_EXPLICIT'::"ContributionProvenance"
        )
        OR (
          "action" <> 'LEGACY_CAPTURED'::"ContributionAction"
          AND "provenance" <> 'LEGACY_EXPLICIT'::"ContributionProvenance"
        )
      )
    ),
  CONSTRAINT "ContributionEvent_permission_section_check"
    CHECK (
      "requiredPermission" IS NULL
      OR ("requiredPermission" = 'MANAGE_TASKS'::"ContributionPermission" AND "section" = 'TASKS'::"ContributionSection")
      OR ("requiredPermission" = 'MANAGE_GUESTS'::"ContributionPermission" AND "section" = 'GUESTS'::"ContributionSection")
      OR ("requiredPermission" IN ('VIEW_MONEY'::"ContributionPermission", 'MANAGE_MONEY'::"ContributionPermission") AND "section" = 'MONEY'::"ContributionSection")
      OR ("requiredPermission" = 'MANAGE_PROVIDERS'::"ContributionPermission" AND "section" = 'PROVIDERS'::"ContributionSection")
      OR ("requiredPermission" = 'MANAGE_MEMBERS'::"ContributionPermission" AND "section" = 'MEMBERS'::"ContributionSection")
      OR ("requiredPermission" = 'MANAGE_PLAN'::"ContributionPermission" AND "section" = 'PLAN'::"ContributionSection")
    )
);

CREATE UNIQUE INDEX "ContributorHistoryScope_weddingPlanId_key"
  ON "ContributorHistoryScope"("weddingPlanId");
CREATE INDEX "ContributorHistoryScope_status_updatedAt_idx"
  ON "ContributorHistoryScope"("status", "updatedAt");

CREATE UNIQUE INDEX "ContributorTenure_sharedMemberId_key"
  ON "ContributorTenure"("sharedMemberId");
CREATE UNIQUE INDEX "ContributorTenure_id_historyScopeId_key"
  ON "ContributorTenure"("id", "historyScopeId");
CREATE INDEX "ContributorTenure_actorUserId_endedAt_joinedAt_idx"
  ON "ContributorTenure"("actorUserId", "endedAt", "joinedAt");
CREATE INDEX "ContributorTenure_actorReference_endedAt_joinedAt_idx"
  ON "ContributorTenure"("actorReference", "endedAt", "joinedAt");
CREATE INDEX "ContributorTenure_historyScopeId_endedAt_idx"
  ON "ContributorTenure"("historyScopeId", "endedAt");
CREATE UNIQUE INDEX "ContributorTenure_one_active_reference_per_scope"
  ON "ContributorTenure"("historyScopeId", "actorReference")
  WHERE "endedAt" IS NULL;

CREATE UNIQUE INDEX "ContributionEvent_contributorTenureId_dedupeKey_key"
  ON "ContributionEvent"("contributorTenureId", "dedupeKey");
CREATE INDEX "ContributionEvent_contributorTenureId_capturedAt_id_idx"
  ON "ContributionEvent"("contributorTenureId", "capturedAt" DESC, "id" DESC);
CREATE INDEX "ContributionEvent_contributorTenureId_section_entityType_action_entityId_idx"
  ON "ContributionEvent"("contributorTenureId", "section", "entityType", "action", "entityId");
CREATE INDEX "ContributionEvent_historyScopeId_section_capturedAt_idx"
  ON "ContributionEvent"("historyScopeId", "section", "capturedAt" DESC);
CREATE INDEX "ContributionEvent_historyScopeId_entityType_entityId_idx"
  ON "ContributionEvent"("historyScopeId", "entityType", "entityId");

ALTER TABLE "ContributorHistoryScope"
  ADD CONSTRAINT "ContributorHistoryScope_weddingPlanId_fkey"
  FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ContributorTenure"
  ADD CONSTRAINT "ContributorTenure_historyScopeId_fkey"
  FOREIGN KEY ("historyScopeId") REFERENCES "ContributorHistoryScope"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ContributorTenure"
  ADD CONSTRAINT "ContributorTenure_actorUserId_fkey"
  FOREIGN KEY ("actorUserId") REFERENCES "User"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ContributorTenure"
  ADD CONSTRAINT "ContributorTenure_sharedMemberId_fkey"
  FOREIGN KEY ("sharedMemberId") REFERENCES "SharedMember"("id")
  ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "ContributionEvent"
  ADD CONSTRAINT "ContributionEvent_historyScopeId_fkey"
  FOREIGN KEY ("historyScopeId") REFERENCES "ContributorHistoryScope"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ContributionEvent"
  ADD CONSTRAINT "ContributionEvent_contributorTenureId_historyScopeId_fkey"
  FOREIGN KEY ("contributorTenureId", "historyScopeId")
  REFERENCES "ContributorTenure"("id", "historyScopeId")
  ON DELETE RESTRICT ON UPDATE CASCADE;

-- Cutover coverage is explicit. No pre-cutover activity is claimed unless a
-- legacy source column proves the relationship directly.
INSERT INTO "ContributorHistoryScope" (
  "id", "weddingPlanId", "status", "historyCoverageStartsAt", "archivedAt", "createdAt", "updatedAt"
)
SELECT
  'scope_' || md5(plan."id"),
  plan."id",
  CASE
    WHEN plan."status" = 'ARCHIVED' THEN 'ARCHIVED'::"ContributionScopeStatus"
    ELSE 'ACTIVE'::"ContributionScopeStatus"
  END,
  CURRENT_TIMESTAMP,
  CASE
    WHEN plan."status" = 'ARCHIVED' THEN CURRENT_TIMESTAMP
    ELSE NULL
  END,
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM "WeddingPlan" AS plan;

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
  'tenure_' || md5(member."id"),
  scope."id",
  member."userId",
  encode(digest(member."userId", 'sha256'), 'hex'),
  member."id",
  member."createdAt",
  scope."historyCoverageStartsAt",
  member."role",
  CURRENT_TIMESTAMP,
  CURRENT_TIMESTAMP
FROM "SharedMember" AS member
JOIN "ContributorHistoryScope" AS scope
  ON scope."weddingPlanId" = member."weddingPlanId";

DO $$
BEGIN
  IF (SELECT count(*) FROM "ContributorHistoryScope") <>
     (SELECT count(*) FROM "WeddingPlan") THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'legacy_scope_count_mismatch';
  END IF;

  IF (SELECT count(*) FROM "ContributorTenure" WHERE "endedAt" IS NULL) <>
     (SELECT count(*) FROM "SharedMember") THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'legacy_current_tenure_count_mismatch';
  END IF;
END $$;

-- Use the same compact, recursively key-sorted JSON representation as the
-- runtime canonicalJson helper before hashing a frozen legacy snapshot.
CREATE FUNCTION "canonical_contribution_json"(input JSONB)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $$
DECLARE
  input_type TEXT := jsonb_typeof(input);
  output TEXT;
BEGIN
  IF input_type = 'object' THEN
    SELECT '{' || string_agg(
      to_json(entry.key)::text || ':' || "canonical_contribution_json"(entry.value),
      ',' ORDER BY entry.key
    ) || '}'
    INTO output
    FROM jsonb_each(input) AS entry;
    RETURN COALESCE(output, '{}');
  ELSIF input_type = 'array' THEN
    SELECT '[' || string_agg(
      "canonical_contribution_json"(item.value),
      ',' ORDER BY item.ordinality
    ) || ']'
    INTO output
    FROM jsonb_array_elements(input) WITH ORDINALITY AS item(value, ordinality);
    RETURN COALESCE(output, '[]');
  END IF;
  RETURN input::text;
END;
$$;

-- Legacy rows predate the runtime validator. Omit user-entered text rather
-- than importing a name/title that contains digits or credential/PII shapes.
CREATE FUNCTION "safe_legacy_contribution_text"(input TEXT)
RETURNS TEXT
LANGUAGE plpgsql
IMMUTABLE
STRICT
AS $$
DECLARE
  normalized TEXT := translate(input, '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹', '01234567890123456789');
BEGIN
  IF octet_length(input) > 2048
     OR normalized ~ '[0-9]'
     OR input ~* '[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}'
     OR input ~* '(bearer[[:space:]]+|token|secret|signature)' THEN
    RETURN NULL;
  END IF;
  RETURN input;
END;
$$;

WITH task_history AS (
  SELECT
    task."id" AS "entityId",
    task."weddingPlanId",
    task."assigneeUserId",
    "safe_legacy_contribution_text"(task."title") AS "title",
    task."status"::text AS "status",
    task."priority"::text AS "priority",
    task."dueDate",
    "safe_legacy_contribution_text"(task."taskCategory") AS "taskCategory",
    scope."id" AS "historyScopeId",
    tenure."id" AS "contributorTenureId",
    tenure."actorReference",
    member."authorityVersion",
    jsonb_strip_nulls(jsonb_build_object(
      'title', "safe_legacy_contribution_text"(task."title"),
      'status', task."status"::text,
      'priority', task."priority"::text,
      'dueDate', task."dueDate",
      'category', "safe_legacy_contribution_text"(task."taskCategory")
    )) AS "snapshot"
  FROM "WeddingTask" AS task
  JOIN "ContributorHistoryScope" AS scope
    ON scope."weddingPlanId" = task."weddingPlanId"
  JOIN "ContributorTenure" AS tenure
    ON tenure."historyScopeId" = scope."id"
   AND tenure."actorUserId" = task."assigneeUserId"
   AND tenure."endedAt" IS NULL
  JOIN "SharedMember" AS member
    ON member."id" = tenure."sharedMemberId"
  WHERE task."assigneeUserId" IS NOT NULL
)
INSERT INTO "ContributionEvent" (
  "id", "historyScopeId", "contributorTenureId", "section", "entityType",
  "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
  "eventFingerprint", "provenance", "requiredPermission",
  "permissionPolicyVersion", "authorityVersion", "occurredAt", "capturedAt"
)
SELECT
  'event_' || md5('task-assignment:' || history."entityId" || ':' || history."assigneeUserId"),
  history."historyScopeId",
  history."contributorTenureId",
  'TASKS'::"ContributionSection",
  'TASK'::"ContributionEntityType",
  history."entityId",
  'LEGACY_CAPTURED'::"ContributionAction",
  history."snapshot",
  encode(digest("canonical_contribution_json"(history."snapshot"), 'sha256'), 'hex'),
  'legacy:task-assignment:' || history."entityId" || ':' || history."assigneeUserId",
  encode(digest(
    history."contributorTenureId" || ':' || history."actorReference" ||
      ':LEGACY_CONFIRMED_ASSIGNMENT:' || history."entityId" || ':' ||
      "canonical_contribution_json"(history."snapshot"),
    'sha256'
  ), 'hex'),
  'LEGACY_EXPLICIT'::"ContributionProvenance",
  'MANAGE_TASKS'::"ContributionPermission",
  1,
  history."authorityVersion",
  NULL,
  CURRENT_TIMESTAMP
FROM task_history AS history;

WITH quote_history AS (
  SELECT
    request."id" AS "entityId",
    request."userId",
    request."status"::text AS "status",
    request."createdAt",
    scope."id" AS "historyScopeId",
    tenure."id" AS "contributorTenureId",
    tenure."actorReference",
    member."authorityVersion",
    jsonb_build_object(
      'requestStatus', request."status"::text,
      'status', request."status"::text
    ) AS "snapshot"
  FROM "QuoteRequest" AS request
  JOIN "ContributorHistoryScope" AS scope
    ON scope."weddingPlanId" = request."weddingPlanId"
  JOIN "ContributorTenure" AS tenure
    ON tenure."historyScopeId" = scope."id"
   AND tenure."actorUserId" = request."userId"
   AND tenure."endedAt" IS NULL
  JOIN "SharedMember" AS member
    ON member."id" = tenure."sharedMemberId"
  WHERE request."weddingPlanId" IS NOT NULL
)
INSERT INTO "ContributionEvent" (
  "id", "historyScopeId", "contributorTenureId", "section", "entityType",
  "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
  "eventFingerprint", "provenance", "requiredPermission",
  "permissionPolicyVersion", "authorityVersion", "occurredAt", "capturedAt"
)
SELECT
  'event_' || md5('quote-creation:' || history."entityId" || ':' || history."userId"),
  history."historyScopeId",
  history."contributorTenureId",
  'PROVIDERS'::"ContributionSection",
  'QUOTE_REQUEST'::"ContributionEntityType",
  history."entityId",
  'LEGACY_CAPTURED'::"ContributionAction",
  history."snapshot",
  encode(digest("canonical_contribution_json"(history."snapshot"), 'sha256'), 'hex'),
  'legacy:quote-creation:' || history."entityId" || ':' || history."userId",
  encode(digest(
    history."contributorTenureId" || ':' || history."actorReference" ||
      ':LEGACY_CONFIRMED_CREATION:' || history."entityId" || ':' ||
      "canonical_contribution_json"(history."snapshot"),
    'sha256'
  ), 'hex'),
  'LEGACY_EXPLICIT'::"ContributionProvenance",
  'MANAGE_PROVIDERS'::"ContributionPermission",
  1,
  history."authorityVersion",
  history."createdAt",
  CURRENT_TIMESTAMP
FROM quote_history AS history;

-- PlanInvite.inviterUserId is direct creator evidence. We only backfill when
-- that inviter still has a current membership tenure in the same plan; no
-- historical tenure is invented for a user who may have left earlier.
WITH invite_history AS (
  SELECT
    invite."id" AS "entityId",
    invite."inviterUserId",
    invite."createdAt",
    scope."id" AS "historyScopeId",
    tenure."id" AS "contributorTenureId",
    tenure."actorReference",
    member."authorityVersion",
    jsonb_strip_nulls(jsonb_build_object(
      'displayName', "safe_legacy_contribution_text"(invite."name"),
      'role', invite."role"::text,
      'permissionLabels', to_jsonb(array_remove(ARRAY[
        CASE WHEN invite."canViewMoney" THEN 'VIEW_MONEY' END,
        CASE WHEN invite."canEditPlan" THEN 'EDIT_PLAN' END,
        CASE WHEN invite."canManageTasks" THEN 'MANAGE_TASKS' END,
        CASE WHEN invite."canManageGuests" THEN 'MANAGE_GUESTS' END,
        CASE WHEN invite."canManageProviders" THEN 'MANAGE_PROVIDERS' END,
        CASE WHEN invite."canInviteMembers" THEN 'INVITE_MEMBERS' END,
        CASE WHEN invite."canManageMoney" THEN 'MANAGE_MONEY' END
      ], NULL)),
      'inviteState', CASE
        WHEN invite."acceptedAt" IS NOT NULL THEN 'ACCEPTED'
        WHEN invite."declinedAt" IS NOT NULL THEN 'DECLINED'
        WHEN invite."revokedAt" IS NOT NULL THEN 'REVOKED'
        ELSE 'PENDING'
      END
    )) AS "snapshot"
  FROM "PlanInvite" AS invite
  JOIN "ContributorHistoryScope" AS scope
    ON scope."weddingPlanId" = invite."weddingPlanId"
  JOIN "ContributorTenure" AS tenure
    ON tenure."historyScopeId" = scope."id"
   AND tenure."actorUserId" = invite."inviterUserId"
   AND tenure."endedAt" IS NULL
  JOIN "SharedMember" AS member
    ON member."id" = tenure."sharedMemberId"
)
INSERT INTO "ContributionEvent" (
  "id", "historyScopeId", "contributorTenureId", "section", "entityType",
  "entityId", "action", "snapshot", "snapshotHash", "dedupeKey",
  "eventFingerprint", "provenance", "requiredPermission",
  "permissionPolicyVersion", "authorityVersion", "occurredAt", "capturedAt"
)
SELECT
  'event_' || md5('plan-invite:' || history."entityId" || ':' || history."inviterUserId"),
  history."historyScopeId",
  history."contributorTenureId",
  'MEMBERS'::"ContributionSection",
  'PLAN_INVITE'::"ContributionEntityType",
  history."entityId",
  'LEGACY_CAPTURED'::"ContributionAction",
  history."snapshot",
  encode(digest("canonical_contribution_json"(history."snapshot"), 'sha256'), 'hex'),
  'legacy:plan-invite:' || history."entityId" || ':' || history."inviterUserId",
  encode(digest(
    history."contributorTenureId" || ':' || history."actorReference" ||
      ':LEGACY_CONFIRMED_INVITER:' || history."entityId" || ':' ||
      "canonical_contribution_json"(history."snapshot"),
    'sha256'
  ), 'hex'),
  'LEGACY_EXPLICIT'::"ContributionProvenance",
  'MANAGE_MEMBERS'::"ContributionPermission",
  1,
  history."authorityVersion",
  history."createdAt",
  CURRENT_TIMESTAMP
FROM invite_history AS history;

-- Accepted membership alone does not prove who created or managed that
-- member. It is deliberately left unattributed rather than guessed.

DROP FUNCTION "safe_legacy_contribution_text"(TEXT);
DROP FUNCTION "canonical_contribution_json"(JSONB);

CREATE FUNCTION "enforce_contributor_tenure_immutability"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION USING
      ERRCODE = '55000',
      MESSAGE = 'ContributorTenure is immutable and cannot be deleted';
  END IF;

  IF NEW."id" IS DISTINCT FROM OLD."id"
    OR NEW."historyScopeId" IS DISTINCT FROM OLD."historyScopeId"
    OR NEW."actorReference" IS DISTINCT FROM OLD."actorReference"
    OR NEW."joinedAt" IS DISTINCT FROM OLD."joinedAt"
    OR NEW."trackingStartedAt" IS DISTINCT FROM OLD."trackingStartedAt"
    OR NEW."roleAtTrackingStart" IS DISTINCT FROM OLD."roleAtTrackingStart"
    OR NEW."createdAt" IS DISTINCT FROM OLD."createdAt"
  THEN
    RAISE EXCEPTION USING
      ERRCODE = '55000',
      MESSAGE = 'ContributorTenure identity fields are immutable';
  END IF;

  -- User deletion may detach the live user relation only after the tenure has
  -- been closed. Reassignment and reattachment would falsify the actor.
  IF NEW."actorUserId" IS DISTINCT FROM OLD."actorUserId"
    AND NOT (
      OLD."actorUserId" IS NOT NULL
      AND NEW."actorUserId" IS NULL
      AND NEW."endedAt" IS NOT NULL
    )
  THEN
    RAISE EXCEPTION USING
      ERRCODE = '55000',
      MESSAGE = 'ContributorTenure identity fields are immutable';
  END IF;

  -- A membership link may only be detached by the one-way active-to-ended
  -- lifecycle transition. A closed tenure can never be attached again.
  IF NEW."sharedMemberId" IS DISTINCT FROM OLD."sharedMemberId"
    AND NOT (
      OLD."sharedMemberId" IS NOT NULL
      AND NEW."sharedMemberId" IS NULL
      AND OLD."endedAt" IS NULL
      AND NEW."endedAt" IS NOT NULL
    )
  THEN
    RAISE EXCEPTION USING
      ERRCODE = '55000',
      MESSAGE = 'ContributorTenure lifecycle transition is invalid';
  END IF;

  IF OLD."endedAt" IS NULL AND NEW."endedAt" IS NULL THEN
    IF NEW."endReason" IS DISTINCT FROM OLD."endReason"
      OR NEW."roleAtEnd" IS DISTINCT FROM OLD."roleAtEnd"
    THEN
      RAISE EXCEPTION USING
        ERRCODE = '55000',
        MESSAGE = 'ContributorTenure lifecycle transition is invalid';
    END IF;
  ELSIF OLD."endedAt" IS NULL AND NEW."endedAt" IS NOT NULL THEN
    IF NEW."endReason" IS NULL OR NEW."sharedMemberId" IS NOT NULL THEN
      RAISE EXCEPTION USING
        ERRCODE = '55000',
        MESSAGE = 'ContributorTenure lifecycle transition is invalid';
    END IF;
  ELSIF OLD."endedAt" IS NOT NULL THEN
    IF NEW."endedAt" IS DISTINCT FROM OLD."endedAt"
      OR NEW."endReason" IS DISTINCT FROM OLD."endReason"
      OR NEW."roleAtEnd" IS DISTINCT FROM OLD."roleAtEnd"
      OR NEW."sharedMemberId" IS DISTINCT FROM OLD."sharedMemberId"
    THEN
      RAISE EXCEPTION USING
        ERRCODE = '55000',
        MESSAGE = 'ContributorTenure lifecycle transition is invalid';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER "ContributorTenure_immutable_identity"
BEFORE UPDATE OR DELETE ON "ContributorTenure"
FOR EACH ROW EXECUTE FUNCTION "enforce_contributor_tenure_immutability"();

CREATE FUNCTION "reject_contribution_event_mutation"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION USING
    ERRCODE = '55000',
    MESSAGE = 'ContributionEvent is append-only';
END;
$$;

CREATE TRIGGER "ContributionEvent_append_only"
BEFORE UPDATE OR DELETE ON "ContributionEvent"
FOR EACH ROW EXECUTE FUNCTION "reject_contribution_event_mutation"();

COMMIT;
