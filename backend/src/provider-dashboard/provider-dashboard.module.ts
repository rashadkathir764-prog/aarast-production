import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import {
  ProviderApplicationController,
  ProviderDashboardController,
} from './provider-dashboard.controller';
import { ProviderDashboardService } from './provider-dashboard.service';

@Module({
  imports: [PrismaModule],
  controllers: [ProviderApplicationController, ProviderDashboardController],
  providers: [ProviderDashboardService],
})
export class ProviderDashboardModule {}
