import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { PrismaModule } from "../prisma/prisma.module";
import { SharingModule } from "../sharing/sharing.module";
import {
  ApiV1FinancialCommitmentsController,
  ApiV1FinancialInstallmentsController,
  ApiV1FinancialPaymentRecordsController,
  ApiV1WeddingPlanFinancialCommitmentsController,
  ApiV1WeddingPlanFinancialInstallmentsController,
  ApiV1WeddingPlanFinancialPaymentRecordsController,
  FinancialCommitmentsController,
  FinancialInstallmentsController,
  FinancialPaymentRecordsController,
  WeddingPlanFinancialCommitmentsController,
  WeddingPlanFinancialInstallmentsController,
  WeddingPlanFinancialPaymentRecordsController,
} from "./financial-commitments.controller";
import { FinancialCommitmentsService } from "./financial-commitments.service";

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    WeddingPlanFinancialCommitmentsController,
    FinancialCommitmentsController,
    WeddingPlanFinancialPaymentRecordsController,
    FinancialPaymentRecordsController,
    WeddingPlanFinancialInstallmentsController,
    FinancialInstallmentsController,
    ApiV1WeddingPlanFinancialCommitmentsController,
    ApiV1FinancialCommitmentsController,
    ApiV1WeddingPlanFinancialPaymentRecordsController,
    ApiV1FinancialPaymentRecordsController,
    ApiV1WeddingPlanFinancialInstallmentsController,
    ApiV1FinancialInstallmentsController,
  ],
  providers: [FinancialCommitmentsService],
  exports: [FinancialCommitmentsService],
})
export class FinancialCommitmentsModule {}
