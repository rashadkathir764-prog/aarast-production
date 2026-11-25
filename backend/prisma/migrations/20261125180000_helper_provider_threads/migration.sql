-- RA-BE-139 (Q-33 (أ), D124): a plan's conversations with a provider are one
-- per plan, provider and requester side. The plan's owner and its partners
-- (the groom and the bride members) share one thread; each helper who asks
-- the provider gets his own. The owner and the partners read every thread
-- of the plan; a helper reads the threads of his own requests.
--
-- `helperThread` marks a helper's own thread and `helperUserId` names him.
-- Erasing his account empties the name (his requests there pass to the
-- plan's owner, D112) and the thread stays a helper's, so it never collides
-- with the owner's.

BEGIN;

ALTER TABLE "Conversation"
  ADD COLUMN "helperThread" BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "helperUserId" TEXT;

ALTER TABLE "Conversation"
  ADD CONSTRAINT "Conversation_helperUserId_fkey"
    FOREIGN KEY ("helperUserId") REFERENCES "User"("id")
    ON DELETE SET NULL ON UPDATE CASCADE,
  -- Only a plan's thread is a helper's, and only a helper's names one.
  ADD CONSTRAINT "Conversation_helper_thread_check" CHECK (
    ("helperThread" AND "scope" = 'PLAN')
    OR (NOT "helperThread" AND "helperUserId" IS NULL)
  );

CREATE INDEX "Conversation_helperUserId_idx" ON "Conversation"("helperUserId");

-- The old key (one PLAN thread per plan and provider) goes before the data
-- step, which writes helpers' threads beside the owner's.
DROP INDEX "Conversation_plan_provider_key";

-- Existing threads stay the owner's and partners' thread. A helper's
-- requests leave one only where that takes nothing from anyone's chat:
--
--   (a) The thread has no message at all: each helper's requests, with their
--       conversation events, move to his own new thread (the same core
--       participants, block, close and notice state as the thread they
--       leave). When nobody on the owner's side asked in it either, the
--       first helper to ask keeps the thread itself as his own (the same
--       id, so notices and links keep pointing at it).
--   (b) Only one helper asked in it, nobody on the owner's side asked, and
--       every message in it is his or the provider's: it was his thread
--       from its start and becomes his own where it is, with its messages.
--
-- Everything else stays where it is, and the helper keeps reading it through
-- his requests in it:
--   * a thread with a message from the owner's side (the owner, a partner):
--     the helper already read that chat, and a chat is not divided by request;
--   * a thread with messages where the owner's side also asked, or several
--     helpers asked, or a message has no author left (an erased account):
--     no message can be told apart as one requester's.
--
-- The owner's side is read as it is now: the plan's owner and the members
-- in the groom's or the bride's role. A requester who is neither (a helper,
-- family, a member since removed) is a helper.

CREATE TEMP TABLE "_HelperRequest" ON COMMIT DROP AS
SELECT
  q."id" AS "quoteRequestId",
  q."conversationId",
  q."userId" AS "helperUserId",
  q."createdAt"
FROM "QuoteRequest" q
JOIN "Conversation" c ON c."id" = q."conversationId"
JOIN "WeddingPlan" p ON p."id" = c."weddingPlanId"
WHERE c."scope" = 'PLAN'
  AND q."userId" <> p."ownerUserId"
  AND NOT EXISTS (
    SELECT 1 FROM "SharedMember" m
    WHERE m."weddingPlanId" = c."weddingPlanId"
      AND m."userId" = q."userId"
      AND m."role" IN ('GROOM', 'BRIDE')
  );

CREATE TEMP TABLE "_HelperThreadSource" ON COMMIT DROP AS
SELECT
  c."id" AS "conversationId",
  c."weddingPlanId",
  c."providerId",
  EXISTS (
    SELECT 1 FROM "QuoteRequest" q
    WHERE q."conversationId" = c."id"
      AND q."id" NOT IN (SELECT "quoteRequestId" FROM "_HelperRequest")
  ) AS "ownerSideAsked",
  (SELECT count(DISTINCT h."helperUserId") FROM "_HelperRequest" h
    WHERE h."conversationId" = c."id") AS "helperCount",
  (SELECT h."helperUserId" FROM "_HelperRequest" h
    WHERE h."conversationId" = c."id"
    ORDER BY h."createdAt", h."quoteRequestId" LIMIT 1) AS "firstHelperUserId",
  EXISTS (SELECT 1 FROM "ChatMessage" cm WHERE cm."conversationId" = c."id")
    AS "hasMessages"
FROM "Conversation" c
WHERE c."id" IN (SELECT "conversationId" FROM "_HelperRequest");

-- Case (b) and the keeping helper of case (a): the thread becomes his own.
CREATE TEMP TABLE "_HelperThreadKept" ON COMMIT DROP AS
SELECT s."conversationId", s."firstHelperUserId" AS "helperUserId"
FROM "_HelperThreadSource" s
JOIN "Conversation" c ON c."id" = s."conversationId"
LEFT JOIN "Provider" pr ON pr."id" = c."providerId"
WHERE NOT s."ownerSideAsked"
  AND (
    NOT s."hasMessages"
    OR (
      s."helperCount" = 1
      AND NOT EXISTS (
        SELECT 1 FROM "ChatMessage" cm
        WHERE cm."conversationId" = s."conversationId"
          AND (
            cm."senderUserId" IS NULL
            OR (
              cm."senderUserId" <> s."firstHelperUserId"
              AND cm."senderUserId" IS DISTINCT FROM pr."userId"
            )
          )
      )
    )
  );

UPDATE "Conversation" c
SET "helperThread" = true,
    "helperUserId" = k."helperUserId"
FROM "_HelperThreadKept" k
WHERE c."id" = k."conversationId";

-- Case (a): every other helper of a thread with no message moves out.
CREATE TEMP TABLE "_HelperRequestMove" ON COMMIT DROP AS
SELECT
  h."quoteRequestId",
  h."conversationId" AS "fromConversationId",
  h."helperUserId",
  h."createdAt",
  'conv_helper_' || md5(s."weddingPlanId" || ':' || s."providerId" || ':' || h."helperUserId")
    AS "toConversationId"
FROM "_HelperRequest" h
JOIN "_HelperThreadSource" s ON s."conversationId" = h."conversationId"
LEFT JOIN "_HelperThreadKept" k ON k."conversationId" = h."conversationId"
WHERE NOT s."hasMessages"
  AND h."helperUserId" IS DISTINCT FROM k."helperUserId";

INSERT INTO "Conversation" (
  "id", "scope", "weddingPlanId", "providerId", "createdByUserId",
  "helperThread", "helperUserId", "lastActivityAt", "closedAt", "pushStopsAt",
  "customerSideBlockedAt", "customerSideBlockedById", "providerSideBlockedAt",
  "createdAt", "updatedAt"
)
SELECT
  m."toConversationId",
  'PLAN'::"ConversationScope",
  c."weddingPlanId",
  c."providerId",
  m."helperUserId",
  true,
  m."helperUserId",
  min(m."createdAt"),
  c."closedAt",
  c."pushStopsAt",
  c."customerSideBlockedAt",
  c."customerSideBlockedById",
  c."providerSideBlockedAt",
  min(m."createdAt"),
  min(m."createdAt")
FROM "_HelperRequestMove" m
JOIN "Conversation" c ON c."id" = m."fromConversationId"
GROUP BY
  m."toConversationId", m."helperUserId", c."weddingPlanId", c."providerId",
  c."closedAt", c."pushStopsAt", c."customerSideBlockedAt",
  c."customerSideBlockedById", c."providerSideBlockedAt";

UPDATE "QuoteRequest" q
SET "conversationId" = m."toConversationId"
FROM "_HelperRequestMove" m
WHERE q."id" = m."quoteRequestId";

UPDATE "ConversationEvent" e
SET "conversationId" = m."toConversationId"
FROM "_HelperRequestMove" m
WHERE e."conversationId" = m."fromConversationId"
  AND (
    e."quoteRequestId" = m."quoteRequestId"
    OR e."quoteOfferId" IN (
      SELECT o."id" FROM "QuoteOffer" o WHERE o."quoteRequestId" = m."quoteRequestId"
    )
  );

-- The core participants of a new thread, as a request makes them: the plan's
-- owner and the provider's account. Others join on their first read.
INSERT INTO "ConversationParticipant" (
  "id", "conversationId", "userId", "joinedAt", "createdAt", "updatedAt"
)
SELECT
  'cp_' || md5(c."id" || ':' || core."userId"),
  c."id",
  core."userId",
  c."createdAt",
  c."createdAt",
  c."createdAt"
FROM "Conversation" c
JOIN "WeddingPlan" p ON p."id" = c."weddingPlanId"
LEFT JOIN "Provider" pr ON pr."id" = c."providerId"
CROSS JOIN LATERAL (VALUES (p."ownerUserId"), (pr."userId")) AS core("userId")
WHERE c."id" IN (SELECT DISTINCT "toConversationId" FROM "_HelperRequestMove")
  AND core."userId" IS NOT NULL
ON CONFLICT ("conversationId", "userId") DO NOTHING;

-- Each thread's last activity is its own events' again.
UPDATE "Conversation" c
SET "lastActivityAt" = activity."lastActivityAt"
FROM (
  SELECT e."conversationId", max(e."occurredAt") AS "lastActivityAt"
  FROM "ConversationEvent" e
  WHERE e."conversationId" IN (
    SELECT "fromConversationId" FROM "_HelperRequestMove"
    UNION
    SELECT "toConversationId" FROM "_HelperRequestMove"
  )
  GROUP BY e."conversationId"
) activity
WHERE c."id" = activity."conversationId";

-- What stayed, said once in the migration's output.
DO $$
DECLARE
  kept BIGINT;
  moved BIGINT;
  stayed BIGINT;
BEGIN
  SELECT count(*) INTO kept FROM "_HelperThreadKept";
  SELECT count(*) INTO moved FROM "_HelperRequestMove";
  SELECT count(*) INTO stayed
  FROM "_HelperRequest" h
  WHERE NOT EXISTS (SELECT 1 FROM "_HelperThreadKept" k
                    WHERE k."conversationId" = h."conversationId"
                      AND k."helperUserId" = h."helperUserId")
    AND NOT EXISTS (SELECT 1 FROM "_HelperRequestMove" m
                    WHERE m."quoteRequestId" = h."quoteRequestId");
  RAISE NOTICE 'RA-BE-139: % thread(s) became a helper''s own, % request(s) moved to a helper''s new thread, % request(s) stayed in a shared thread', kept, moved, stayed;
END $$;

CREATE UNIQUE INDEX "Conversation_plan_provider_key"
  ON "Conversation"("weddingPlanId", "providerId")
  WHERE "scope" = 'PLAN' AND NOT "helperThread";

CREATE UNIQUE INDEX "Conversation_plan_provider_helper_key"
  ON "Conversation"("weddingPlanId", "providerId", "helperUserId")
  WHERE "scope" = 'PLAN' AND "helperThread";

COMMIT;
