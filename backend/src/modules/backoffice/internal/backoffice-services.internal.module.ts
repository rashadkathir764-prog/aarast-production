import { Module } from '@nestjs/common';
import { AdminAuditService } from '../../../admin/admin-audit.service';
import { AdminService } from '../../../admin/admin.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { MessagingRealtimePublicModule } from '../../messaging/public/messaging-realtime-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';

@Module({
  imports: [
    PrismaModule,
    MessagingRealtimePublicModule,
    NotificationsPublicModule,
  ],
  providers: [AdminService, AdminAuditService],
  exports: [AdminService, AdminAuditService],
})
export class BackofficeServicesInternalModule {}
