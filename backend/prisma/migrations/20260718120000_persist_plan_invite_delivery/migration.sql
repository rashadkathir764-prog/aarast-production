CREATE TYPE "PlanInviteDeliveryStatus" AS ENUM (
  'UNKNOWN',
  'PENDING',
  'DELIVERED',
  'UNCERTAIN',
  'UNAVAILABLE'
);

ALTER TABLE "PlanInvite"
  ADD COLUMN "deliveryStatus" "PlanInviteDeliveryStatus" NOT NULL DEFAULT 'UNKNOWN',
  ADD COLUMN "deliveryAttemptedAt" TIMESTAMP(3);
