import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../modules/collaboration/public/collaboration-scope-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import { MoneySummaryController } from "./money-summary.controller";
import { MoneySummaryService } from "./money-summary.service";
import { MoneyBudgetService } from "./money-budget.service";

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [MoneySummaryController],
  providers: [MoneySummaryService, MoneyBudgetService],
  exports: [MoneySummaryService, MoneyBudgetService],
})
export class MoneyModule {}
