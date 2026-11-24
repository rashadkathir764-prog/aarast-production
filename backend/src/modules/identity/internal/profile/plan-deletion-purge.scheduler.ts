import { Injectable, Logger } from "@nestjs/common";
import { Cron } from "@nestjs/schedule";
import { PlanDeletionPurgeService } from "./plan-deletion-purge.service";

/**
 * Q-45 (D124), hourly: erase the plans whose 30 days are over. Every
 * failure is logged with its plan and error; the plan stays due and is
 * tried again the next hour.
 */
@Injectable()
export class PlanDeletionPurgeScheduler {
  private readonly logger = new Logger(PlanDeletionPurgeScheduler.name);

  constructor(private readonly plans: PlanDeletionPurgeService) {}

  @Cron("45 * * * *")
  async purgeDuePlans(): Promise<void> {
    const { erased, failures } = await this.plans.purgeDuePlans(new Date());
    if (erased > 0) this.logger.log(`Erased ${erased} plan(s) after their 30 days`);
    for (const failure of failures) {
      this.logger.error(
        `Plan erasure failed for plan ${failure.weddingPlanId}`,
        failure.error instanceof Error ? failure.error.stack : String(failure.error),
      );
    }
  }
}
