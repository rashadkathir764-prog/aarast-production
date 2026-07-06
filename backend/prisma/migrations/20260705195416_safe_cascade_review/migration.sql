-- DropForeignKey
ALTER TABLE "BudgetCategory" DROP CONSTRAINT "BudgetCategory_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "Debt" DROP CONSTRAINT "Debt_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "Expense" DROP CONSTRAINT "Expense_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "Guest" DROP CONSTRAINT "Guest_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "GuestGroup" DROP CONSTRAINT "GuestGroup_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "Notification" DROP CONSTRAINT "Notification_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "PlanInvite" DROP CONSTRAINT "PlanInvite_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "PlanProviderLink" DROP CONSTRAINT "PlanProviderLink_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "SharedMember" DROP CONSTRAINT "SharedMember_weddingPlanId_fkey";

-- DropForeignKey
ALTER TABLE "WeddingTask" DROP CONSTRAINT "WeddingTask_weddingPlanId_fkey";

-- AddForeignKey
ALTER TABLE "BudgetCategory" ADD CONSTRAINT "BudgetCategory_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Expense" ADD CONSTRAINT "Expense_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Debt" ADD CONSTRAINT "Debt_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "WeddingTask" ADD CONSTRAINT "WeddingTask_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "SharedMember" ADD CONSTRAINT "SharedMember_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanInvite" ADD CONSTRAINT "PlanInvite_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Notification" ADD CONSTRAINT "Notification_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Guest" ADD CONSTRAINT "Guest_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "GuestGroup" ADD CONSTRAINT "GuestGroup_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "PlanProviderLink" ADD CONSTRAINT "PlanProviderLink_weddingPlanId_fkey" FOREIGN KEY ("weddingPlanId") REFERENCES "WeddingPlan"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
