import { Module } from "@nestjs/common";
import {
  BudgetCategoriesController,
  WeddingPlanBudgetCategoriesController,
} from "../../budget-categories/budget-categories.controller";
import { MoneySummaryController } from "../../money/money-summary.controller";
import {
  CostPaymentsController,
  CostsController,
  PaymentSchedulesController,
  WeddingPlanCostPaymentsController,
  WeddingPlanCostsController,
  WeddingPlanPaymentSchedulesController,
} from "../../wedding-costs/wedding-costs.controller";
import { FinanceServicesInternalModule } from "./internal/finance-services.internal.module";
import { FinancePublicModule } from "./public/finance-public.module";

@Module({
  imports: [FinancePublicModule, FinanceServicesInternalModule],
  controllers: [
    MoneySummaryController,
    WeddingPlanBudgetCategoriesController,
    BudgetCategoriesController,
    WeddingPlanCostsController,
    CostsController,
    WeddingPlanCostPaymentsController,
    CostPaymentsController,
    WeddingPlanPaymentSchedulesController,
    PaymentSchedulesController,
  ],
})
export class FinanceModule {}
