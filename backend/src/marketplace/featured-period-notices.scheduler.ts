import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { FeaturedPeriodNoticesService } from './featured-period-notices.service';

/** Hourly: tell the provider his featured placement ends within a week, and that it ended (B-43). */
@Injectable()
export class FeaturedPeriodNoticesScheduler {
  private readonly logger = new Logger(FeaturedPeriodNoticesScheduler.name);

  constructor(private readonly notices: FeaturedPeriodNoticesService) {}

  @Cron('50 * * * *')
  async tellProviders(): Promise<void> {
    const { warned, ended, failures } = await this.notices.run();
    if (warned > 0 || ended > 0) {
      this.logger.log(`Featured placement notices warned=${warned} ended=${ended}`);
    }
    for (const failure of failures) {
      this.logger.error(
        `Featured placement notice failed for period ${failure.featuredPeriodId}`,
        failure.error instanceof Error ? failure.error.stack : String(failure.error),
      );
    }
  }
}
