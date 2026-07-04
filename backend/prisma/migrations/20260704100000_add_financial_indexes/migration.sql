-- CreateIndex
CREATE INDEX "Expense_weddingPlanId_idx" ON "Expense"("weddingPlanId");

-- CreateIndex
CREATE INDEX "Expense_budgetCategoryId_idx" ON "Expense"("budgetCategoryId");

-- CreateIndex
CREATE INDEX "BudgetCategory_weddingPlanId_idx" ON "BudgetCategory"("weddingPlanId");

-- CreateIndex
CREATE INDEX "Debt_weddingPlanId_idx" ON "Debt"("weddingPlanId");

-- CreateIndex
CREATE INDEX "Installment_debtId_idx" ON "Installment"("debtId");

-- CreateIndex
CREATE INDEX "Installment_status_dueDate_idx" ON "Installment"("status", "dueDate");
