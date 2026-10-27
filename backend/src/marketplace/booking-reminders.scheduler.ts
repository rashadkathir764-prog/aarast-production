import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { BookingsService } from './bookings.service';

/** Hourly: remind both sides of a confirmed booking a week and a day before (V1 checklist 4.17). */
@Injectable()
export class BookingRemindersScheduler {
  private readonly logger = new Logger(BookingRemindersScheduler.name);

  constructor(private readonly bookings: BookingsService) {}

  @Cron('25 * * * *')
  async sendDueReminders(): Promise<void> {
    // B-22: bookings past the outcome window with no word complete first.
    const done = await this.bookings.completeOverdueBookings();
    if (done.completed > 0) this.logger.log(`Completed ${done.completed} past booking(s)`);
    for (const failure of done.failures) {
      this.logger.error(
        `Booking auto-completion failed for booking ${failure.bookingId}`,
        failure.error instanceof Error ? failure.error.stack : String(failure.error),
      );
    }
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
