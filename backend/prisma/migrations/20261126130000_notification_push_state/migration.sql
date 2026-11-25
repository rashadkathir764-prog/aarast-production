-- A push used to be recorded as sent whenever its outbox event finished,
-- even when the server had no Firebase credentials, the person had push off
-- or had no phone registered. Each notification that reaches a phone now
-- carries what became of its push; Firebase only accepts a message for a
-- device and never confirms the phone showed it, so no state claims that.
-- `openedAt` is the person opening the notice from the phone. Additive:
-- rows from before keep null (unknown).

-- CreateEnum
CREATE TYPE "PushDeliveryState" AS ENUM ('QUEUED', 'HELD', 'DISABLED', 'PREFERENCE_OFF', 'NO_DEVICE', 'SKIPPED_READ', 'SKIPPED_NO_ACCESS', 'SKIPPED_DIGEST', 'RETRYING', 'PARTIAL', 'ACCEPTED', 'FAILED');

-- AlterTable
ALTER TABLE "Notification" ADD COLUMN "openedAt" TIMESTAMP(3),
ADD COLUMN "pushState" "PushDeliveryState",
ADD COLUMN "pushStateAt" TIMESTAMP(3),
ADD COLUMN "pushHeldUntil" TIMESTAMP(3),
ADD COLUMN "pushAcceptedDevices" INTEGER,
ADD COLUMN "pushLastError" VARCHAR(120),
ADD COLUMN "pushRequestedAt" TIMESTAMP(3);
