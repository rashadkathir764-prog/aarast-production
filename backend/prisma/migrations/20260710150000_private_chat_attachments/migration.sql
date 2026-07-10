-- Chat images are private objects. Persist only their storage key; signed GET
-- URLs are minted after conversation authorization and are never stored.
ALTER TABLE "ChatAttachment" ADD COLUMN "storageKey" TEXT;

UPDATE "ChatAttachment"
SET "storageKey" = 'chat-image/' || split_part(
  split_part("url", '/chat-image/', 2),
  '?',
  1
)
WHERE "url" LIKE '%/chat-image/%';

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM "ChatAttachment"
    WHERE "storageKey" IS NULL
       OR "storageKey" !~ '^chat-image/[^/]+/[0-9a-fA-F-]+\.(jpg|png|webp)$'
  ) THEN
    RAISE EXCEPTION 'Cannot migrate an invalid public chat attachment URL';
  END IF;
END $$;

ALTER TABLE "ChatAttachment" ALTER COLUMN "storageKey" SET NOT NULL;
ALTER TABLE "ChatAttachment" DROP COLUMN "url";
