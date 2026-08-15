import { Module } from '@nestjs/common';
import { MarketplaceService } from '../../../marketplace/marketplace.service';
import { ProviderDashboardService } from '../../../provider-dashboard/provider-dashboard.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { CollaborationHistoryPublicModule } from '../../collaboration/public/collaboration-history-public.module';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { MediaStoragePublicModule } from '../../media/public/media-storage-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    NotificationsPublicModule,
    MediaStoragePublicModule,
  ],
  providers: [MarketplaceService, ProviderDashboardService],
  exports: [MarketplaceService, ProviderDashboardService],
})
export class MarketplaceServicesInternalModule {}
