import { Module } from '@nestjs/common';
import { ConversationLifecyclePublicModule } from '../../messaging/public/conversation-lifecycle-public.module';
import { BookingRemindersScheduler } from '../../../marketplace/booking-reminders.scheduler';
import { BookingsService } from '../../../marketplace/bookings.service';
import { MarketplaceRelationsService } from '../../../marketplace/marketplace-relations';
import { MarketplaceService } from '../../../marketplace/marketplace.service';
import { ProviderDashboardService } from '../../../provider-dashboard/provider-dashboard.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { CatalogReadPublicModule } from '../../catalog/public/catalog-read-public.module';
import { CollaborationHistoryPublicModule } from '../../collaboration/public/collaboration-history-public.module';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { CollaborationScopePublicModule } from '../../collaboration/public/collaboration-scope-public.module';
import { FinancePublicModule } from '../../finance/public/finance-public.module';
import { ProviderAccountPublicModule } from '../../identity/public/provider-account-public.module';
import { UserReadPublicModule } from '../../identity/public/user-read-public.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';
import { MediaStoragePublicModule } from '../../media/public/media-storage-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';

@Module({
  imports: [
    PrismaModule,
    ConversationLifecyclePublicModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    NotificationsPublicModule,
    MediaStoragePublicModule,
    FinancePublicModule,
    CatalogReadPublicModule,
    CollaborationScopePublicModule,
    PlanReadPublicModule,
    UserReadPublicModule,
    ProviderAccountPublicModule,
  ],
  providers: [
    MarketplaceRelationsService,
    MarketplaceService,
    ProviderDashboardService,
    BookingsService,
    BookingRemindersScheduler,
  ],
  exports: [MarketplaceService, ProviderDashboardService, BookingsService],
})
export class MarketplaceServicesInternalModule {}
