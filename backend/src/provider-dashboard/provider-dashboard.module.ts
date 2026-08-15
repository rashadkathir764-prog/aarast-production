import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { MediaStoragePublicModule } from '../modules/media/public/media-storage-public.module';
import { PrismaModule } from '../platform/database/prisma.module';
import {
  ProviderApplicationController,
  ProviderDashboardController,
} from './provider-dashboard.controller';
import { ProviderDashboardService } from './provider-dashboard.service';

@Module({
  imports: [PrismaModule, NotificationsModule, MediaStoragePublicModule],
  controllers: [
    ProviderApplicationController,
    ProviderDashboardController,
  ],
  providers: [ProviderDashboardService],
})
export class ProviderDashboardModule {}
