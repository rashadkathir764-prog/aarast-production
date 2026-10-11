-- AlterEnum
-- Over-budget categories, loan repayment reminders and the wedding countdown
-- (V1 checklist 4.8 and 4.17). PostgreSQL 12+ accepts several ADD VALUE
-- statements in one migration.
ALTER TYPE "NotificationType" ADD VALUE 'BUDGET_CATEGORY_EXCEEDED';
ALTER TYPE "NotificationType" ADD VALUE 'LOAN_REPAYMENT_DUE_SOON';
ALTER TYPE "NotificationType" ADD VALUE 'LOAN_REPAYMENT_OVERDUE';
ALTER TYPE "NotificationType" ADD VALUE 'WEDDING_COUNTDOWN';
