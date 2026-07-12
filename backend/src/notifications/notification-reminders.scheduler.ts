import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { NotificationsService } from './notifications.service';

@Injectable()
export class NotificationRemindersScheduler {
  private readonly logger = new Logger(NotificationRemindersScheduler.name);

  constructor(private readonly notifications: NotificationsService) {}

  @Cron('15 * * * *')
  async generateDueReminders(): Promise<void> {
    const createdCount = await this.notifications.generateDueNotifications();
    if (createdCount == null) {
      this.logger.debug('Skipped reminder scan; another replica owns the lock');
    } else if (createdCount > 0) {
      this.logger.log(`Created ${createdCount} due reminder notification(s)`);
    }
  }
}
