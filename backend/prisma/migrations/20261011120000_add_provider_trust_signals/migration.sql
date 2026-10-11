-- AlterTable
ALTER TABLE "Provider" ADD COLUMN     "verifiedAt" TIMESTAMP(3),
ADD COLUMN     "verifiedById" TEXT;

-- AlterTable
ALTER TABLE "ProviderService" ADD COLUMN     "priceUpdatedAt" TIMESTAMP(3);

-- Existing priced services: the last edit is the best known price date.
UPDATE "ProviderService" SET "priceUpdatedAt" = "updatedAt" WHERE "basePrice" IS NOT NULL;

