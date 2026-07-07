-- CreateEnum
CREATE TYPE "FinancialCommitmentSourceType" AS ENUM ('PROVIDER_SERVICE', 'MANUAL_DEBT', 'MANUAL_COMMITMENT', 'OTHER');

-- CreateEnum
CREATE TYPE "FinancialCommitmentStatus" AS ENUM ('OPEN', 'PARTIALLY_PAID', 'PAID', 'CANCELLED');

-- CreateTable
CREATE TABLE "FinancialCommitment" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "budgetCategoryId" TEXT NOT NULL,
    "providerId" TEXT,
    "planProviderLinkId" TEXT,
    "quoteRequestId" TEXT,
    "quoteOfferId" TEXT,
    "sourceType" "FinancialCommitmentSourceType" NOT NULL DEFAULT 'MANUAL_COMMITMENT',
    "title" TEXT NOT NULL,
    "partyName" TEXT,
    "partyPhone" TEXT,
    "totalAmount" DECIMAL(14,2) NOT NULL,
    "paidAmount" DECIMAL(14,2) NOT NULL DEFAULT 0,
    "dueDate" TIMESTAMP(3),
    "agreementDate" TIMESTAMP(3),
    "status" "FinancialCommitmentStatus" NOT NULL DEFAULT 'OPEN',
    "note" TEXT,
    "legacyDebtId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FinancialCommitment_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FinancialPaymentRecord" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "financialCommitmentId" TEXT NOT NULL,
    "budgetCategoryId" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "paidAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "method" TEXT,
    "note" TEXT,
    "legacyExpenseId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FinancialPaymentRecord_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "FinancialInstallment" (
    "id" TEXT NOT NULL,
    "weddingPlanId" TEXT NOT NULL,
    "financialCommitmentId" TEXT NOT NULL,
    "budgetCategoryId" TEXT NOT NULL,
    "amount" DECIMAL(14,2) NOT NULL,
    "dueDate" TIMESTAMP(3),
    "paidAt" TIMESTAMP(3),
    "status" "InstallmentStatus" NOT NULL DEFAULT 'PENDING',
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "FinancialInstallment_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "FinancialCommitment_legacyDebtId_key" ON "FinancialCommitment"("legacyDebtId");

-- CreateIndex
CREATE INDEX "FinancialCommitment_weddingPlanId_status_idx" ON "FinancialCommitment"("weddingPlanId", "status");

-- CreateIndex
CREATE INDEX "FinancialCommitment_budgetCategoryId_idx" ON "FinancialCommitment"("budgetCategoryId");

-- CreateIndex
CREATE INDEX "FinancialCommitment_providerId_idx" ON "FinancialCommitment"("providerId");

-- CreateIndex
CREATE INDEX "FinancialCommitment_planProviderLinkId_idx" ON "FinancialCommitment"("planProviderLinkId");

-- CreateIndex
CREATE INDEX "FinancialCommitment_quoteRequestId_idx" ON "FinancialCommitment"("quoteRequestId");

-- CreateIndex
CREATE INDEX "FinancialCommitment_quoteOfferId_idx" ON "FinancialCommitment"("quoteOfferId");

-- CreateIndex
CREATE INDEX "FinancialCommitment_sourceType_idx" ON "FinancialCommitment"("sourceType");

-- CreateIndex
CREATE UNIQUE INDEX "FinancialPaymentRecord_legacyExpenseId_key" ON "FinancialPaymentRecord"("legacyExpenseId");

-- CreateIndex
CREATE INDEX "FinancialPaymentRecord_weddingPlanId_paidAt_idx" ON "FinancialPaymentRecord"("weddingPlanId", "paidAt");

-- CreateIndex
CREATE INDEX "FinancialPaymentRecord_financialCommitmentId_idx" ON "FinancialPaymentRecord"("financialCommitmentId");

-- CreateIndex
CREATE INDEX "FinancialPaymentRecord_budgetCategoryId_idx" ON "FinancialPaymentRecord"("budgetCategoryId");

-- CreateIndex
CREATE INDEX "FinancialInstallment_weddingPlanId_status_dueDate_idx" ON "FinancialInstallment"("weddingPlanId", "status", "dueDate");

-- CreateIndex
CREATE INDEX "FinancialInstallment_financialCommitmentId_idx" ON "FinancialInstallment"("financialCommitmentId");

-- CreateIndex
CREATE INDEX "FinancialInstallment_budgetCategoryId_idx" ON "FinancialInstallment"("budgetCategoryId");

-- AddForeignKey
ALTER TABLE "FinancialCommitment" ADD CONSTRAINT "FinancialCommitment_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialCommitment" ADD CONSTRAINT "FinancialCommitment_budgetCategoryId_fkey" FOREIGN KEY ("budgetCategoryId") REFERENCES "BudgetCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialCommitment" ADD CONSTRAINT "FinancialCommitment_providerId_fkey" FOREIGN KEY ("providerId") REFERENCES "Provider"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialCommitment" ADD CONSTRAINT "FinancialCommitment_planProviderLinkId_fkey" FOREIGN KEY ("planProviderLinkId") REFERENCES "PlanProviderLink"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialCommitment" ADD CONSTRAINT "FinancialCommitment_quoteRequestId_fkey" FOREIGN KEY ("quoteRequestId") REFERENCES "QuoteRequest"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialCommitment" ADD CONSTRAINT "FinancialCommitment_quoteOfferId_fkey" FOREIGN KEY ("quoteOfferId") REFERENCES "QuoteOffer"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialPaymentRecord" ADD CONSTRAINT "FinancialPaymentRecord_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialPaymentRecord" ADD CONSTRAINT "FinancialPaymentRecord_financialCommitmentId_fkey" FOREIGN KEY ("financialCommitmentId") REFERENCES "FinancialCommitment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialPaymentRecord" ADD CONSTRAINT "FinancialPaymentRecord_budgetCategoryId_fkey" FOREIGN KEY ("budgetCategoryId") REFERENCES "BudgetCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialInstallment" ADD CONSTRAINT "FinancialInstallment_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialInstallment" ADD CONSTRAINT "FinancialInstallment_financialCommitmentId_fkey" FOREIGN KEY ("financialCommitmentId") REFERENCES "FinancialCommitment"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "FinancialInstallment" ADD CONSTRAINT "FinancialInstallment_budgetCategoryId_fkey" FOREIGN KEY ("budgetCategoryId") REFERENCES "BudgetCategory"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
