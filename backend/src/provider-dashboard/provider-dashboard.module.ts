import { Module } from '@nestjs/common';
import { NotificationsPublicModule } from '../modules/notifications/public/notifications-public.module';
import { MediaStoragePublicModule } from '../modules/media/public/media-storage-public.module';
import { PrismaModule } from '../platform/database/prisma.module';
import {
  ProviderApplicationController,
  ProviderDashboardController,
} from './provider-dashboard.controller';
import { ProviderDashboardService } from './provider-dashboard.service';

@Module({
  imports: [PrismaModule, NotificationsPublicModule, MediaStoragePublicModule],
  controllers: [
    ProviderApplicationController,
    ProviderDashboardController,
  ],
  providers: [ProviderDashboardService],
})
export class ProviderDashboardModule {}
