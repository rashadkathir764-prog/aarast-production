import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { QuoteRequestExpiryService } from './quote-request-expiry.service';

/** Hourly: end the requests nobody answered in seven days, and warn the day before (B-04). */
@Injectable()
export class QuoteRequestExpiryScheduler {
  private readonly logger = new Logger(QuoteRequestExpiryScheduler.name);

  constructor(private readonly expiry: QuoteRequestExpiryService) {}

  @Cron('40 * * * *')
  async expireOverdueRequests(): Promise<void> {
    const { expired, warned, skipped, failures } = await this.expiry.run();
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
