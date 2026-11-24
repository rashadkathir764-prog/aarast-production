import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { isQuietHour } from '../shared-kernel/time/quiet-hours';
import { BookingsService } from './bookings.service';

/**
 * Hourly: remind both sides of a confirmed booking a week and a day before
 * (V1 checklist 4.17). RA-BE-185: the reminders are made from 09:10 Aden to
 * 21:00, not right after midnight; completing past bookings runs every hour.
 */
@Injectable()
export class BookingRemindersScheduler {
  private readonly logger = new Logger(BookingRemindersScheduler.name);

  constructor(private readonly bookings: BookingsService) {}

  @Cron('10 * * * *')
  async sendDueReminders(now: Date = new Date()): Promise<void> {
    // B-22: bookings past the outcome window with no word complete first.
    const done = await this.bookings.completeOverdueBookings();
    if (done.completed > 0) this.logger.log(`Completed ${done.completed} past booking(s)`);
    for (const failure of done.failures) {
      this.logger.error(
        `Booking auto-completion failed for booking ${failure.bookingId}`,
        failure.error instanceof Error ? failure.error.stack : String(failure.error),
      );
    }
    if (isQuietHour(now)) return;
    const { sent, failures } = await this.bookings.sendDueReminders();
    if (sent > 0) this.logger.log(`Sent ${sent} booking reminder(s)`);
    for (const failure of failures) {
      this.logger.error(
        `Booking reminder failed for booking ${failure.bookingId}`,
        failure.error instanceof Error ? failure.error.stack : String(failure.error),
      );
    }
  }
}
