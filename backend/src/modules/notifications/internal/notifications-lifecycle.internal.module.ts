import { Module } from '@nestjs/common';
import { NotificationRemindersScheduler } from '../../../notifications/notification-reminders.scheduler';
import { NotificationsInternalModule } from './notifications-service.internal.module';

@Module({
  imports: [NotificationsInternalModule],
  providers: [NotificationRemindersScheduler],
})
export class NotificationsLifecycleInternalModule {}
