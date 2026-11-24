import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { isQuietHour } from '../shared-kernel/time/quiet-hours';
import { QuoteRequestExpiryService } from './quote-request-expiry.service';

/**
 * Hourly: end the requests nobody answered in seven days, and warn the day
 * before (B-04). RA-BE-185: the warning «طلب ينتهي بكرة» is made from 09:15
 * Aden to 21:00; the ending runs every hour.
 */
@Injectable()
export class QuoteRequestExpiryScheduler {
  private readonly logger = new Logger(QuoteRequestExpiryScheduler.name);

  constructor(private readonly expiry: QuoteRequestExpiryService) {}

  @Cron('15 * * * *')
  async expireOverdueRequests(now: Date = new Date()): Promise<void> {
    const { expired, warned, skipped, failures } = await this.expiry.run(now, {
      warn: !isQuietHour(now),
    });
    if (expired > 0 || warned > 0 || skipped > 0) {
      this.logger.log(
        `Quote requests expired=${expired} warned=${warned} skipped=${skipped}`,
      );
    }
    for (const failure of failures) {
      this.logger.error(
        `Quote request expiry failed for request ${failure.quoteRequestId}`,
        failure.error instanceof Error ? failure.error.stack : String(failure.error),
      );
    }
  }
}
