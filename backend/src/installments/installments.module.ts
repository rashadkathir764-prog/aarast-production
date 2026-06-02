import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import {
  DebtInstallmentsController,
  InstallmentsController,
  WeddingPlanInstallmentsController,
} from './installments.controller';
import { InstallmentsService } from './installments.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [
    DebtInstallmentsController,
    WeddingPlanInstallmentsController,
    InstallmentsController,
  ],
  providers: [InstallmentsService],
})
export class InstallmentsModule {}
