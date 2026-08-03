import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { ContributionHistoryModule } from "../contribution-history/contribution-history.module";
import { PrismaModule } from "../prisma/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import {
  BudgetCategoriesController,
  WeddingPlanBudgetCategoriesController,
} from "./budget-categories.controller";
import { BudgetCategoriesService } from "./budget-categories.service";

@Module({
  imports: [AuthModule, PrismaModule, SharingModule, ContributionHistoryModule],
  controllers: [
    WeddingPlanBudgetCategoriesController,
    BudgetCategoriesController,
  ],
  providers: [BudgetCategoriesService],
})
export class BudgetCategoriesModule {}
