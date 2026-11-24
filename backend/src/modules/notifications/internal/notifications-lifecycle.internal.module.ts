import { Module } from '@nestjs/common';
import { NotificationRemindersScheduler } from '../../../notifications/notification-reminders.scheduler';
import { NotificationsInternalModule } from './notifications-service.internal.module';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { NotificationsRetentionScheduler } from '../infrastructure/notifications-retention.scheduler';

@Module({
  imports: [NotificationsInternalModule, PrismaModule],
  // RA-BE-179: the read notifications go after 180 days.
  providers: [NotificationRemindersScheduler, NotificationsRetentionScheduler],
})
export class NotificationsLifecycleInternalModule {}
