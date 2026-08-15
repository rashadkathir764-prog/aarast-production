import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CollaborationHistoryPublicModule } from "../modules/collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { CollaborationScopePublicModule } from "../modules/collaboration/public/collaboration-scope-public.module";
import { PrismaModule } from "../platform/database/prisma.module";
import {
  CostPaymentsController,
  CostsController,
  PaymentSchedulesController,
  WeddingPlanCostPaymentsController,
  WeddingPlanCostsController,
  WeddingPlanPaymentSchedulesController,
} from "./wedding-costs.controller";
import { WeddingCostsService } from "./wedding-costs.service";

@Module({
  imports: [
    AuthModule,
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [
    WeddingPlanCostsController,
    CostsController,
    WeddingPlanCostPaymentsController,
    CostPaymentsController,
    WeddingPlanPaymentSchedulesController,
    PaymentSchedulesController,
  ],
  providers: [WeddingCostsService],
  exports: [WeddingCostsService],
})
export class WeddingCostsModule {}
