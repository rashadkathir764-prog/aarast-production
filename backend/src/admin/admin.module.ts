import { Module } from '@nestjs/common';
import { PrismaModule } from '../platform/database/prisma.module';
import { AdminController } from './admin.controller';
import { AdminAuditController } from './admin-audit.controller';
import { AdminAuditService } from './admin-audit.service';
import { AdminGuard } from './admin.guard';
import { AdminPermissionGuard } from './admin-permission.guard';
import { AdminService } from './admin.service';
import { MessagingRealtimePublicModule } from '../modules/messaging/public/messaging-realtime-public.module';
import { NotificationsPublicModule } from '../modules/notifications/public/notifications-public.module';

@Module({
  imports: [
    PrismaModule,
    MessagingRealtimePublicModule,
    NotificationsPublicModule,
  ],
  controllers: [AdminController, AdminAuditController],
  providers: [
    AdminGuard,
    AdminPermissionGuard,
    AdminService,
    AdminAuditService,
  ],
})
export class AdminModule {}
