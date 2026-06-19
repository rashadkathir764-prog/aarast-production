import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { PrismaModule } from '../prisma/prisma.module';
import {
  ApiV1ProviderController,
  ProviderApplicationController,
  ProviderDashboardController,
} from './provider-dashboard.controller';
import { ProviderDashboardService } from './provider-dashboard.service';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [
    ProviderApplicationController,
    ProviderDashboardController,
    ApiV1ProviderController,
  ],
  providers: [ProviderDashboardService],
})
export class ProviderDashboardModule {}
