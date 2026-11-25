import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { isQuietHour } from '../shared-kernel/time/quiet-hours';
import { NotificationsService } from './notifications.service';

/**
 * The two scans' timings, as `REMINDER_SCHEDULE` states them
 * (`dayScan.everyHourAtMinute`, `tasks.ownReminderTime.checkEveryMinutes`);
 * a decorator takes only a constant, so `test/reminder-schedule.test.ts`
 * holds these two to the table.
 */
export const DUE_REMINDER_SCAN_CRON = '5 * * * *';
export const TASK_REMINDER_TIME_SCAN_CRON = '*/5 * * * *';

@Injectable()
export class NotificationRemindersScheduler {
  private readonly logger = new Logger(NotificationRemindersScheduler.name);

  constructor(private readonly notifications: NotificationsService) {}

  // RA-BE-185: hourly from :05, so the first scan of the day is 09:05 Aden.
  // A «ذكّرني» time still reminds at night (its push is held to 09:00); the
  // day reminders (a task, a payment, a loan, promised money, the wedding)
  // wait for the morning scan instead of firing right after midnight.
  @Cron(DUE_REMINDER_SCAN_CRON)
  async generateDueReminders(now: Date = new Date()): Promise<void> {
    const createdCount = await this.notifications.generateDueNotifications({
      dayReminders: !isQuietHour(now),
    });
    if (createdCount == null) {
      this.logger.debug('Skipped reminder scan; another replica owns the lock');
    } else if (createdCount > 0) {
      this.logger.log(`Created ${createdCount} due reminder notification(s)`);
    }
  }

  // A task's own «ذكّرني» time is told within five minutes of it, not up to
  // an hour late. Its own lock; the dedupe keys keep it and the hourly scan
  // from telling one reminder twice.
  @Cron(TASK_REMINDER_TIME_SCAN_CRON)
  async generateTaskReminderTimes(): Promise<void> {
    const createdCount = await this.notifications.generateDueNotifications({
      onlyTaskReminderTimes: true,
    });
    if (createdCount == null) {
      this.logger.debug('Skipped task reminder scan; another replica owns the lock');
    } else if (createdCount > 0) {
      this.logger.log(`Created ${createdCount} task reminder notification(s)`);
    }
  }
}
