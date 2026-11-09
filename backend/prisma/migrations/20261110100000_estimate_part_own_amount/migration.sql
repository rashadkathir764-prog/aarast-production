-- RA-BE-120 (D105): a PART agreement with no part typed settles its own
-- amount, read at the time. It was written as the amount itself, so an
-- amount corrected later left the part at the old figure and the item's
-- expected cost drifted. A null part is now "its own amount".
ALTER TABLE "WeddingCost" DROP CONSTRAINT "WeddingCost_estimate_part_check";
ALTER TABLE "WeddingCost" ADD CONSTRAINT "WeddingCost_estimate_part_check" CHECK (
  ("estimateCover" = 'WHOLE' AND "estimatePart" IS NULL)
  OR ("estimateCover" = 'PART' AND ("estimatePart" IS NULL OR "estimatePart" > 0))
);

-- A part written as the agreement's own amount is that: it follows the amount.
UPDATE "WeddingCost"
SET "estimatePart" = NULL
WHERE "estimateCover" = 'PART' AND "estimatePart" = "totalAmount";
