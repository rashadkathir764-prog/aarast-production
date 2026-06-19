import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1WeddingPlanDashboardController,
  DashboardController,
  WeddingPlanDashboardController,
} from './dashboard.controller';
import { DashboardService } from './dashboard.service';

@Module({
  imports: [PrismaModule, SharingModule],
  controllers: [
    DashboardController,
    WeddingPlanDashboardController,
    ApiV1WeddingPlanDashboardController,
  ],
  providers: [DashboardService],
})
export class DashboardModule {}
