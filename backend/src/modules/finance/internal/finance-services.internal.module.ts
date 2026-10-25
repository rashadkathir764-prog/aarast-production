import { Module } from "@nestjs/common";
import { BudgetCategoriesService } from "../../../budget-categories/budget-categories.service";
import { FundingSourcesService } from "../../../money/funding-sources.service";
import { MoneyBudgetService } from "../../../money/money-budget.service";
import { MoneySummaryService } from "../../../money/money-summary.service";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { CostReceiptsService } from "../../../wedding-costs/cost-receipts.service";
import { WeddingCostsService } from "../../../wedding-costs/wedding-costs.service";
import { CatalogReadPublicModule } from "../../catalog/public/catalog-read-public.module";
import { CollaborationHistoryPublicModule } from "../../collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../../collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../../collaboration/public/collaboration-scope-public.module";
import { ProviderReadPublicModule } from "../../marketplace/public/provider-read-public.module";
import { MediaStoragePublicModule } from "../../media/public/media-storage-public.module";
import { QuoteReadPublicModule } from "../../marketplace/public/quote-read-public.module";
import { PlanReadPublicModule } from "../../planning/public/plan-read-public.module";
import { PlanningBudgetWritePublicModule } from "../../planning/public/planning-budget-write-public.module";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
    PlanningBudgetWritePublicModule,
    PlanReadPublicModule,
    ProviderReadPublicModule,
    QuoteReadPublicModule,
    MediaStoragePublicModule,
    // G40: the directory categories each money item searches.
    CatalogReadPublicModule,
  ],
  providers: [
    MoneySummaryService,
    MoneyBudgetService,
    BudgetCategoriesService,
    WeddingCostsService,
    CostReceiptsService,
    FundingSourcesService,
  ],
  exports: [
    MoneySummaryService,
    MoneyBudgetService,
    BudgetCategoriesService,
    WeddingCostsService,
    CostReceiptsService,
    FundingSourcesService,
  ],
})
export class FinanceServicesInternalModule {}
