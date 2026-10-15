import { Module } from "@nestjs/common";
import {
  BudgetCategoriesController,
  WeddingPlanBudgetCategoriesController,
} from "../../budget-categories/budget-categories.controller";
import {
  FundingSourcesController,
  LoanRepaymentsController,
  WeddingPlanFundingSourcesController,
} from "../../money/funding-sources.controller";
import { MoneySummaryController } from "../../money/money-summary.controller";
import {
  CostPaymentsController,
  CostsController,
  PaymentSchedulesController,
  WeddingPlanCostPaymentsController,
  WeddingPlanCostsController,
  WeddingPlanPaymentSchedulesController,
} from "../../wedding-costs/wedding-costs.controller";
import { CostReceiptsController } from "../../wedding-costs/cost-receipts.controller";
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
    CostReceiptsController,
    WeddingPlanCostPaymentsController,
    CostPaymentsController,
    WeddingPlanPaymentSchedulesController,
    PaymentSchedulesController,
    WeddingPlanFundingSourcesController,
    FundingSourcesController,
    LoanRepaymentsController,
  ],
})
export class FinanceModule {}
