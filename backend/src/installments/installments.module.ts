import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1DebtInstallmentsController,
  ApiV1InstallmentsController,
  DebtInstallmentsController,
  InstallmentsController,
  WeddingPlanInstallmentsController,
} from './installments.controller';
import { InstallmentsOverdueScheduler } from './installments-overdue.scheduler';
import { InstallmentsService } from './installments.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    DebtInstallmentsController,
    WeddingPlanInstallmentsController,
    InstallmentsController,
    ApiV1DebtInstallmentsController,
    ApiV1InstallmentsController,
  ],
  providers: [InstallmentsService, InstallmentsOverdueScheduler],
})
export class InstallmentsModule {}
