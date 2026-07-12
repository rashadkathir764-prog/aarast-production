import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { MediaModule } from '../media/media.module';
import { PrismaModule } from '../prisma/prisma.module';
import {
  ProviderApplicationController,
  ProviderDashboardController,
} from './provider-dashboard.controller';
import { ProviderDashboardService } from './provider-dashboard.service';

@Module({
  imports: [PrismaModule, NotificationsModule, MediaModule],
  controllers: [
    ProviderApplicationController,
    ProviderDashboardController,
  ],
  providers: [ProviderDashboardService],
})
export class ProviderDashboardModule {}
