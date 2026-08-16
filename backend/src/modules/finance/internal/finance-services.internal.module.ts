import { Module } from "@nestjs/common";
import { BudgetCategoriesService } from "../../../budget-categories/budget-categories.service";
import { MoneyBudgetService } from "../../../money/money-budget.service";
import { MoneySummaryService } from "../../../money/money-summary.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { WeddingCostsService } from "../../../wedding-costs/wedding-costs.service";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";
import { PlanningBudgetWritePublicModule } from "../../planning/public/planning-budget-write-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
    PlanningBudgetWritePublicModule,
  ],
  providers: [
    MoneySummaryService,
    MoneyBudgetService,
    BudgetCategoriesService,
    WeddingCostsService,
  ],
  exports: [
    MoneySummaryService,
    MoneyBudgetService,
    BudgetCategoriesService,
    WeddingCostsService,
  ],
})
export class FinanceServicesInternalModule {}
