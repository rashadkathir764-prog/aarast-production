-- A revised offer's conversation event carries only its version number:
-- every plan reader opens the timeline, and a member without money access
-- must not read the old and new amounts there. «ايش تغيّر» is read from the
-- offer through its money-aware view. Earlier events lose their changes and
-- any amount they carried.
UPDATE "ConversationEvent"
SET "data" = jsonb_build_object('versionNo', "data"->'versionNo')
WHERE "type" = 'QUOTE_OFFER_REVISED'
  AND "data" IS NOT NULL
  AND "data" ? 'changes';

UPDATE "ConversationEvent"
SET "data" = "data" - 'amount'
WHERE "data" IS NOT NULL
  AND jsonb_typeof("data") = 'object'
  AND "data" ? 'amount';

-- When the customer was last told of a revision: a revision less than ten
-- minutes after it is not told again. Existing offers start unset, so their
-- next revision is told.
ALTER TABLE "QuoteOffer" ADD COLUMN "revisionNoticeAt" TIMESTAMP(3);
