import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../prisma/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
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
  imports: [AuthModule, PrismaModule, SharingModule],
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
