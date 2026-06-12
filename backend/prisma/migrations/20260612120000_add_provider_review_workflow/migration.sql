-- AlterEnum
ALTER TYPE "ProviderStatus" ADD VALUE 'NEEDS_CHANGES';

-- AlterTable
ALTER TABLE "Provider" ADD COLUMN     "primaryCategoryId" TEXT,
ADD COLUMN     "reviewNote" TEXT,
ADD COLUMN     "reviewedAt" TIMESTAMP(3),
ADD COLUMN     "reviewedById" TEXT;

-- CreateIndex
CREATE INDEX "Provider_primaryCategoryId_status_idx" ON "Provider"("primaryCategoryId", "status");

-- AddForeignKey
ALTER TABLE "Provider" ADD CONSTRAINT "Provider_primaryCategoryId_fkey" FOREIGN KEY ("primaryCategoryId") REFERENCES "ProviderCategory"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Provider" ADD CONSTRAINT "Provider_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
