import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  DebtInstallmentsController,
  InstallmentsController,
  WeddingPlanInstallmentsController,
} from './installments.controller';
import { InstallmentsService } from './installments.service';

@Module({
  imports: [AuthModule, PrismaModule, SharingModule],
  controllers: [
    DebtInstallmentsController,
    WeddingPlanInstallmentsController,
    InstallmentsController,
  ],
  providers: [InstallmentsService],
})
export class InstallmentsModule {}
