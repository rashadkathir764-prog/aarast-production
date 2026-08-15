import { Module } from '@nestjs/common';
import { DashboardService } from '../../../dashboard/dashboard.service';
import { TimelineService } from '../../../timeline/timeline.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { CollaborationHistoryPublicModule } from '../../collaboration/public/collaboration-history-public.module';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { CollaborationScopePublicModule } from '../../collaboration/public/collaboration-scope-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';
import { IdentityAuthPublicModule } from '../../identity/public/identity-auth-public.module';

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationHistoryPublicModule,
    CollaborationScopePublicModule,
    NotificationsPublicModule,
    IdentityAuthPublicModule,
  ],
  providers: [DashboardService, TimelineService],
  exports: [DashboardService, TimelineService],
})
export class InsightsServicesInternalModule {}
