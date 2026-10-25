-- B4 (B-09, B-19): the provider's reply to a review, and a type of its own
-- for every notice the provider and the reviewer read.

-- B-19: each notice its own type (the rows are moved to them by the next
-- migration: a new enum value is usable only after this one commits).
ALTER TYPE "NotificationType" ADD VALUE 'BOOKING_REQUESTED';
ALTER TYPE "NotificationType" ADD VALUE 'REVIEW_RECEIVED';
ALTER TYPE "NotificationType" ADD VALUE 'REVIEW_REPLIED';
ALTER TYPE "NotificationType" ADD VALUE 'PROVIDER_APPROVED';
ALTER TYPE "NotificationType" ADD VALUE 'PROVIDER_NEEDS_CHANGES';
ALTER TYPE "NotificationType" ADD VALUE 'PROVIDER_REJECTED';
ALTER TYPE "NotificationType" ADD VALUE 'PROVIDER_SUSPENDED';
ALTER TYPE "NotificationType" ADD VALUE 'PROVIDER_IN_REVIEW';
ALTER TYPE "NotificationType" ADD VALUE 'PROVIDER_CLAIM_DECIDED';
ALTER TYPE "NotificationType" ADD VALUE 'LISTING_PLAN_CHANGED';

-- B-09: the provider replies once (p27); the moderation team may hide the
-- reply as it hides a review. The three columns are set together or not at
-- all, and a reply is published or hidden, never pending.
ALTER TABLE "ProviderReview"
  ADD COLUMN "replyBody" TEXT,
  ADD COLUMN "repliedAt" TIMESTAMP(3),
  ADD COLUMN "replyStatus" "ReviewStatus";

ALTER TABLE "ProviderReview"
  ADD CONSTRAINT "ProviderReview_reply_complete" CHECK (
    ("replyBody" IS NULL AND "repliedAt" IS NULL AND "replyStatus" IS NULL)
    OR (
      "replyBody" IS NOT NULL
      AND "repliedAt" IS NOT NULL
      AND "replyStatus" IN ('PUBLISHED', 'HIDDEN')
    )
  );
