-- The application serializes target replacement with an advisory lock. This
-- partial unique index is the final database invariant: one live verified
-- upload may back a domain target at a time, while historical deletion jobs
-- and quota tombstones remain durable.
CREATE UNIQUE INDEX "MediaUploadTicket_live_consumed_target_key"
ON "MediaUploadTicket"("consumedByType", "consumedById")
WHERE "status" = 'VERIFIED'
  AND "consumedAt" IS NOT NULL
  AND "consumedByType" IS NOT NULL
  AND "consumedById" IS NOT NULL;
