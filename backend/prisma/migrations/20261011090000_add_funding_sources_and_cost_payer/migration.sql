-- CreateEnum
CREATE TYPE "FundingSourceKind" AS ENUM ('SAVINGS', 'FAMILY_SUPPORT', 'GIFT', 'LOAN', 'OTHER');

-- CreateEnum
CREATE TYPE "FundingSourceStatus" AS ENUM ('PLEDGED', 'RECEIVED');

-- CreateEnum
CREATE TYPE "LoanRepaymentStatus" AS ENUM ('PLANNED', 'PAID', 'CANCELLED');

-- CreateEnum
CREATE TYPE "CostPayer" AS ENUM ('GROOM', 'BRIDE', 'FAMILY', 'SHARED', 'OTHER');

-- AlterTable
ALTER TABLE "WeddingCost" ADD COLUMN     "payer" "CostPayer",
ADD COLUMN     "payerName" TEXT;

-- CreateTable
CREATE TABLE "FundingSource" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "kind" "FundingSourceKind" NOT NULL,
    "sourceName" TEXT NOT NULL,
    "sourcePhone" TEXT,
    "amount" DECIMAL(14,2) NOT NULL,
    "status" "FundingSourceStatus" NOT NULL DEFAULT 'RECEIVED',
    "receivedAt" TIMESTAMP(3),
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FundingSource_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "LoanRepayment" (
    "id" TEXT NOT NULL,
    "fundingSourceId" TEXT NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "dueDate" TIMESTAMP(3),
    "paidAt" TIMESTAMP(3),
    "status" "LoanRepaymentStatus" NOT NULL DEFAULT 'PLANNED',
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "LoanRepayment_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "FundingSource_weddingPlanId_kind_idx" ON "FundingSource"("weddingPlanId", "kind");

-- CreateIndex
CREATE UNIQUE INDEX "FundingSource_id_weddingPlanId_key" ON "FundingSource"("id", "weddingPlanId");

-- CreateIndex
CREATE INDEX "LoanRepayment_fundingSourceId_status_dueDate_idx" ON "LoanRepayment"("fundingSourceId", "status", "dueDate");

-- CreateIndex
CREATE INDEX "LoanRepayment_status_dueDate_idx" ON "LoanRepayment"("status", "dueDate");

-- AddForeignKey
ALTER TABLE "FundingSource" ADD CONSTRAINT "FundingSource_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "LoanRepayment" ADD CONSTRAINT "LoanRepayment_fundingSourceId_fkey" FOREIGN KEY ("fundingSourceId") REFERENCES "FundingSource"("id") ON DELETE CASCADE ON UPDATE CASCADE;

