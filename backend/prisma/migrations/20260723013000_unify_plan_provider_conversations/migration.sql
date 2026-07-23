BEGIN;

-- The prelaunch chat rows are development/smoke data. Quote requests, offers,
-- plan/provider links and financial records are deliberately retained.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "QuoteRequest"
    WHERE "providerId" IS NULL
       OR ("weddingPlanId" IS NULL AND "userId" IS NULL)
  ) THEN
    RAISE EXCEPTION 'Conversation backfill found an unresolvable QuoteRequest';
  END IF;
END $$;

CREATE TEMP TABLE "_ConversationResetNotificationIds" ON COMMIT DROP AS
SELECT "id"
FROM "Notification"
WHERE "type" = 'CHAT_MESSAGE_RECEIVED'
   OR "entityType" = 'conversation';

DELETE FROM "OutboxEvent"
WHERE "type" = 'CONVERSATION_MESSAGE_AVAILABLE'
   OR "aggregateType" = 'conversation'
   OR (
     "aggregateType" = 'notification'
     AND "aggregateId" IN (SELECT "id" FROM "_ConversationResetNotificationIds")
   );

DELETE FROM "Notification"
WHERE "id" IN (SELECT "id" FROM "_ConversationResetNotificationIds");

DELETE FROM "ConversationReport";
DELETE FROM "ChatAttachment";
DELETE FROM "ChatMessage";
DELETE FROM "ConversationParticipant";
DELETE FROM "Conversation";

CREATE TYPE "ConversationScope" AS ENUM ('PLAN', 'ACCOUNT');
CREATE TYPE "ConversationEventType" AS ENUM (
  'QUOTE_REQUEST_CREATED',
  'QUOTE_REQUEST_CANCELLED',
  'QUOTE_REQUEST_REJECTED',
  'QUOTE_OFFER_RECEIVED',
  'QUOTE_OFFER_REJECTED',
  'QUOTE_OFFER_ACCEPTED'
);

DROP INDEX "Conversation_quoteRequestId_key";
DROP INDEX "Conversation_lastMessageAt_idx";
DROP INDEX "Conversation_lastMessageAt_createdAt_id_idx";
ALTER TABLE "Conversation" DROP CONSTRAINT "Conversation_quoteRequestId_fkey";

ALTER TABLE "Conversation"
  DROP COLUMN "quoteRequestId",
  DROP COLUMN "lastMessageAt",
  ADD COLUMN "scope" "ConversationScope" NOT NULL,
  ADD COLUMN "weddingPlanId" TEXT,
  ADD COLUMN "accountRequesterUserId" TEXT,
  ADD COLUMN "providerId" TEXT NOT NULL,
  ADD COLUMN "createdByUserId" TEXT,
  ADD COLUMN "lastActivityAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "customerSideBlockedAt" TIMESTAMP(3),
  ADD COLUMN "customerSideBlockedById" TEXT,
  ADD COLUMN "providerSideBlockedAt" TIMESTAMP(3);

ALTER TABLE "ConversationParticipant"
  DROP COLUMN "role",
  DROP COLUMN "blockedAt",
  ADD COLUMN "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "revokedAt" TIMESTAMP(3);

DROP TYPE "ConversationParticipantRole";

ALTER TABLE "QuoteRequest" ADD COLUMN "conversationId" TEXT;

INSERT INTO "Conversation" (
  "id",
  "scope",
  "weddingPlanId",
  "accountRequesterUserId",
  "providerId",
  "createdByUserId",
  "lastActivityAt",
  "createdAt",
  "updatedAt"
)
SELECT
  'conv_plan_' || md5(q."weddingPlanId" || ':' || q."providerId"),
  'PLAN'::"ConversationScope",
  q."weddingPlanId",
  NULL,
  q."providerId",
  (array_agg(q."userId" ORDER BY q."createdAt", q."id"))[1],
  GREATEST(
    max(q."updatedAt"),
    COALESCE(max(o."updatedAt"), max(q."updatedAt"))
  ),
  min(q."createdAt"),
  GREATEST(
    max(q."updatedAt"),
    COALESCE(max(o."updatedAt"), max(q."updatedAt"))
  )
FROM "QuoteRequest" q
LEFT JOIN "QuoteOffer" o ON o."quoteRequestId" = q."id"
WHERE q."weddingPlanId" IS NOT NULL
GROUP BY q."weddingPlanId", q."providerId";

INSERT INTO "Conversation" (
  "id",
  "scope",
  "weddingPlanId",
  "accountRequesterUserId",
  "providerId",
  "createdByUserId",
  "lastActivityAt",
  "createdAt",
  "updatedAt"
)
SELECT
  'conv_account_' || md5(q."userId" || ':' || q."providerId"),
  'ACCOUNT'::"ConversationScope",
  NULL,
  q."userId",
  q."providerId",
  q."userId",
  GREATEST(
    max(q."updatedAt"),
    COALESCE(max(o."updatedAt"), max(q."updatedAt"))
  ),
  min(q."createdAt"),
  GREATEST(
    max(q."updatedAt"),
    COALESCE(max(o."updatedAt"), max(q."updatedAt"))
  )
FROM "QuoteRequest" q
LEFT JOIN "QuoteOffer" o ON o."quoteRequestId" = q."id"
WHERE q."weddingPlanId" IS NULL
GROUP BY q."userId", q."providerId";

UPDATE "QuoteRequest" q
SET "conversationId" = c."id"
FROM "Conversation" c
WHERE (
    q."weddingPlanId" IS NOT NULL
    AND c."scope" = 'PLAN'
    AND c."weddingPlanId" = q."weddingPlanId"
    AND c."providerId" = q."providerId"
  ) OR (
    q."weddingPlanId" IS NULL
    AND c."scope" = 'ACCOUNT'
    AND c."accountRequesterUserId" = q."userId"
    AND c."providerId" = q."providerId"
  );

DO $$
DECLARE
  total_quotes BIGINT;
  linked_quotes BIGINT;
BEGIN
  SELECT count(*) INTO total_quotes FROM "QuoteRequest";
  SELECT count(*) INTO linked_quotes
  FROM "QuoteRequest"
  WHERE "conversationId" IS NOT NULL;
  IF linked_quotes <> total_quotes THEN
    RAISE EXCEPTION 'Conversation backfill linked % of % QuoteRequests', linked_quotes, total_quotes;
  END IF;
END $$;

ALTER TABLE "QuoteRequest" ALTER COLUMN "conversationId" SET NOT NULL;

CREATE TABLE "ConversationEvent" (
  "id" TEXT NOT NULL,
  "conversationId" TEXT NOT NULL,
  "quoteRequestId" TEXT,
  "quoteOfferId" TEXT,
  "actorUserId" TEXT,
  "type" "ConversationEventType" NOT NULL,
  "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "dedupeKey" TEXT NOT NULL,
  "data" JSONB,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ConversationEvent_pkey" PRIMARY KEY ("id")
);

-- Only the stable core participants are materialized during backfill. Shared
-- members are inserted lazily after a live canManageProviders check.
INSERT INTO "ConversationParticipant" (
  "id", "conversationId", "userId", "joinedAt", "createdAt", "updatedAt"
)
SELECT
  'cp_' || md5(c."id" || ':' || p."ownerUserId"),
  c."id",
  p."ownerUserId",
  c."createdAt",
  c."createdAt",
  c."updatedAt"
FROM "Conversation" c
JOIN "WeddingPlan" p ON p."id" = c."weddingPlanId"
WHERE c."scope" = 'PLAN'
ON CONFLICT ("conversationId", "userId") DO NOTHING;

INSERT INTO "ConversationParticipant" (
  "id", "conversationId", "userId", "joinedAt", "createdAt", "updatedAt"
)
SELECT
  'cp_' || md5(c."id" || ':' || c."accountRequesterUserId"),
  c."id",
  c."accountRequesterUserId",
  c."createdAt",
  c."createdAt",
  c."updatedAt"
FROM "Conversation" c
WHERE c."scope" = 'ACCOUNT'
ON CONFLICT ("conversationId", "userId") DO NOTHING;

INSERT INTO "ConversationParticipant" (
  "id", "conversationId", "userId", "joinedAt", "createdAt", "updatedAt"
)
SELECT
  'cp_' || md5(c."id" || ':' || p."userId"),
  c."id",
  p."userId",
  c."createdAt",
  c."createdAt",
  c."updatedAt"
FROM "Conversation" c
JOIN "Provider" p ON p."id" = c."providerId"
WHERE p."userId" IS NOT NULL
ON CONFLICT ("conversationId", "userId") DO NOTHING;

INSERT INTO "ConversationEvent" (
  "id", "conversationId", "quoteRequestId", "actorUserId", "type",
  "occurredAt", "dedupeKey", "data", "createdAt"
)
SELECT
  'ce_' || md5('quote-request:' || q."id" || ':created'),
  q."conversationId",
  q."id",
  q."userId",
  'QUOTE_REQUEST_CREATED'::"ConversationEventType",
  q."createdAt",
  'quote-request:' || q."id" || ':created',
  jsonb_build_object('status', 'SENT'),
  q."createdAt"
FROM "QuoteRequest" q;

INSERT INTO "ConversationEvent" (
  "id", "conversationId", "quoteRequestId", "actorUserId", "type",
  "occurredAt", "dedupeKey", "data", "createdAt"
)
SELECT
  'ce_' || md5('quote-request:' || q."id" || ':cancelled'),
  q."conversationId",
  q."id",
  q."userId",
  'QUOTE_REQUEST_CANCELLED'::"ConversationEventType",
  COALESCE(q."cancelledAt", q."updatedAt"),
  'quote-request:' || q."id" || ':cancelled',
  jsonb_build_object('status', 'CANCELLED'),
  COALESCE(q."cancelledAt", q."updatedAt")
FROM "QuoteRequest" q
WHERE q."status" = 'CANCELLED';

INSERT INTO "ConversationEvent" (
  "id", "conversationId", "quoteRequestId", "type", "occurredAt",
  "dedupeKey", "data", "createdAt"
)
SELECT
  'ce_' || md5('quote-request:' || q."id" || ':rejected'),
  q."conversationId",
  q."id",
  'QUOTE_REQUEST_REJECTED'::"ConversationEventType",
  COALESCE(q."rejectedAt", q."updatedAt"),
  'quote-request:' || q."id" || ':rejected',
  jsonb_build_object('status', 'REJECTED'),
  COALESCE(q."rejectedAt", q."updatedAt")
FROM "QuoteRequest" q
WHERE q."status" = 'REJECTED';

INSERT INTO "ConversationEvent" (
  "id", "conversationId", "quoteRequestId", "quoteOfferId", "type",
  "occurredAt", "dedupeKey", "data", "createdAt"
)
SELECT
  'ce_' || md5('quote-offer:' || o."id" || ':received'),
  q."conversationId",
  q."id",
  o."id",
  'QUOTE_OFFER_RECEIVED'::"ConversationEventType",
  o."createdAt",
  'quote-offer:' || o."id" || ':received',
  jsonb_build_object('status', 'PENDING'),
  o."createdAt"
FROM "QuoteOffer" o
JOIN "QuoteRequest" q ON q."id" = o."quoteRequestId";

INSERT INTO "ConversationEvent" (
  "id", "conversationId", "quoteRequestId", "quoteOfferId", "type",
  "occurredAt", "dedupeKey", "data", "createdAt"
)
SELECT
  'ce_' || md5('quote-offer:' || o."id" || ':rejected'),
  q."conversationId",
  q."id",
  o."id",
  'QUOTE_OFFER_REJECTED'::"ConversationEventType",
  o."updatedAt",
  'quote-offer:' || o."id" || ':rejected',
  jsonb_build_object('status', 'REJECTED'),
  o."updatedAt"
FROM "QuoteOffer" o
JOIN "QuoteRequest" q ON q."id" = o."quoteRequestId"
WHERE o."status" = 'REJECTED';

INSERT INTO "ConversationEvent" (
  "id", "conversationId", "quoteRequestId", "quoteOfferId", "actorUserId",
  "type", "occurredAt", "dedupeKey", "data", "createdAt"
)
SELECT
  'ce_' || md5('quote-offer:' || o."id" || ':accepted'),
  q."conversationId",
  q."id",
  o."id",
  q."userId",
  'QUOTE_OFFER_ACCEPTED'::"ConversationEventType",
  COALESCE(q."acceptedAt", o."updatedAt"),
  'quote-offer:' || o."id" || ':accepted',
  jsonb_build_object('status', 'ACCEPTED'),
  COALESCE(q."acceptedAt", o."updatedAt")
FROM "QuoteOffer" o
JOIN "QuoteRequest" q ON q."id" = o."quoteRequestId"
WHERE o."status" = 'ACCEPTED';

UPDATE "Conversation" c
SET "lastActivityAt" = activity."lastActivityAt",
    "updatedAt" = GREATEST(c."updatedAt", activity."lastActivityAt")
FROM (
  SELECT "conversationId", max("occurredAt") AS "lastActivityAt"
  FROM "ConversationEvent"
  GROUP BY "conversationId"
) activity
WHERE activity."conversationId" = c."id";

ALTER TABLE "Conversation"
  ADD CONSTRAINT "Conversation_scope_context_check" CHECK (
    (
      "scope" = 'PLAN'
      AND "weddingPlanId" IS NOT NULL
      AND "accountRequesterUserId" IS NULL
    ) OR (
      "scope" = 'ACCOUNT'
      AND "weddingPlanId" IS NULL
      AND "accountRequesterUserId" IS NOT NULL
    )
  ),
  ADD CONSTRAINT "Conversation_weddingPlanId_fkey"
    FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "Conversation_accountRequesterUserId_fkey"
    FOREIGN KEY ("accountRequesterUserId") REFERENCES "User"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "Conversation_providerId_fkey"
    FOREIGN KEY ("providerId") REFERENCES "Provider"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "Conversation_createdByUserId_fkey"
    FOREIGN KEY ("createdByUserId") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "Conversation_customerSideBlockedById_fkey"
    FOREIGN KEY ("customerSideBlockedById") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "QuoteRequest"
  ADD CONSTRAINT "QuoteRequest_conversationId_fkey"
    FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ConversationEvent"
  ADD CONSTRAINT "ConversationEvent_conversationId_fkey"
    FOREIGN KEY ("conversationId") REFERENCES "Conversation"("id")
    ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "ConversationEvent_quoteRequestId_fkey"
    FOREIGN KEY ("quoteRequestId") REFERENCES "QuoteRequest"("id")
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "ConversationEvent_quoteOfferId_fkey"
    FOREIGN KEY ("quoteOfferId") REFERENCES "QuoteOffer"("id")
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "ConversationEvent_actorUserId_fkey"
    FOREIGN KEY ("actorUserId") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

CREATE UNIQUE INDEX "Conversation_plan_provider_key"
  ON "Conversation"("weddingPlanId", "providerId")
  WHERE "scope" = 'PLAN';

CREATE UNIQUE INDEX "Conversation_account_provider_key"
  ON "Conversation"("accountRequesterUserId", "providerId")
  WHERE "scope" = 'ACCOUNT';

CREATE INDEX "Conversation_weddingPlanId_providerId_idx"
  ON "Conversation"("weddingPlanId", "providerId");
CREATE INDEX "Conversation_accountRequesterUserId_providerId_idx"
  ON "Conversation"("accountRequesterUserId", "providerId");
CREATE INDEX "Conversation_providerId_lastActivityAt_idx"
  ON "Conversation"("providerId", "lastActivityAt");
CREATE INDEX "Conversation_lastActivityAt_createdAt_id_idx"
  ON "Conversation"("lastActivityAt", "createdAt", "id");
CREATE INDEX "QuoteRequest_conversationId_createdAt_idx"
  ON "QuoteRequest"("conversationId", "createdAt");
CREATE UNIQUE INDEX "ConversationEvent_dedupeKey_key"
  ON "ConversationEvent"("dedupeKey");
CREATE INDEX "ConversationEvent_conversationId_occurredAt_id_idx"
  ON "ConversationEvent"("conversationId", "occurredAt", "id");
CREATE INDEX "ConversationEvent_quoteRequestId_occurredAt_idx"
  ON "ConversationEvent"("quoteRequestId", "occurredAt");
CREATE INDEX "ConversationEvent_quoteOfferId_occurredAt_idx"
  ON "ConversationEvent"("quoteOfferId", "occurredAt");

COMMIT;
