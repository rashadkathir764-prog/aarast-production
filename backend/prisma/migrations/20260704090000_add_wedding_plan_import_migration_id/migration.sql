-- AlterTable
ALTER TABLE "WeddingPlan" ADD COLUMN "importMigrationId" TEXT;

-- CreateIndex
CREATE UNIQUE INDEX "WeddingPlan_ownerUserId_importMigrationId_key" ON "WeddingPlan"("ownerUserId", "importMigrationId");
