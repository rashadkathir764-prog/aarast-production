import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../prisma/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import {
  FinancialCommitmentsController,
  FinancialInstallmentsController,
  FinancialPaymentRecordsController,
  WeddingPlanFinancialCommitmentsController,
  WeddingPlanFinancialInstallmentsController,
  WeddingPlanFinancialPaymentRecordsController,
} from "./financial-commitments.controller";
import { FinancialCommitmentsService } from "./financial-commitments.service";
import { FinancialInstallmentsOverdueScheduler } from "./financial-installments-overdue.scheduler";

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    WeddingPlanFinancialCommitmentsController,
    FinancialCommitmentsController,
    WeddingPlanFinancialPaymentRecordsController,
    FinancialPaymentRecordsController,
    WeddingPlanFinancialInstallmentsController,
    FinancialInstallmentsController,
  ],
  providers: [
    FinancialCommitmentsService,
    FinancialInstallmentsOverdueScheduler,
  ],
  exports: [FinancialCommitmentsService],
})
export class FinancialCommitmentsModule {}
