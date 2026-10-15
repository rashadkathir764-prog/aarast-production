-- CreateTable
CREATE TABLE "CostReceipt" (
    "id" TEXT NOT NULL,
    "weddingCostId" TEXT NOT NULL,
    "costPaymentId" TEXT,
    "storageKey" TEXT NOT NULL,
    "contentType" TEXT NOT NULL,
    "byteSize" INTEGER NOT NULL,
    "uploadedByUserId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "CostReceipt_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "CostReceipt_storageKey_key" ON "CostReceipt"("storageKey");

-- CreateIndex
CREATE INDEX "CostReceipt_weddingCostId_createdAt_idx" ON "CostReceipt"("weddingCostId", "createdAt");

-- CreateIndex
CREATE INDEX "CostReceipt_costPaymentId_idx" ON "CostReceipt"("costPaymentId");

-- CreateIndex
CREATE INDEX "CostReceipt_uploadedByUserId_idx" ON "CostReceipt"("uploadedByUserId");

-- AddForeignKey
ALTER TABLE "CostReceipt" ADD CONSTRAINT "CostReceipt_weddingCostId_fkey" FOREIGN KEY ("weddingCostId") REFERENCES "WeddingCost"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "CostReceipt" ADD CONSTRAINT "CostReceipt_payment_same_cost_fkey" FOREIGN KEY ("costPaymentId", "weddingCostId") REFERENCES "CostPayment"("id", "weddingCostId") ON DELETE RESTRICT ON UPDATE CASCADE;
