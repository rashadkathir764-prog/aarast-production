import { Injectable, Logger } from "@nestjs/common";
import { Cron } from "@nestjs/schedule";
import { PrismaService } from "../../../../platform/database/prisma.service";
import { removeReviewedAssistantReports } from "../../infrastructure/assistant-report.service";
import { removeOldErasedAccounts } from "../../infrastructure/account-erasure.repository";
import { AccountDeletionService } from "./account-deletion.service";
import { DataExportService } from "./data-export.service";

/**
 * D63, hourly: erase the accounts whose 30 days are over (through the one
 * erasure saga), then drop the download rows older than a week, the
 * assistant reports reviewed more than 90 days ago (RA-BE-166) and the
 * re-deletion list's ids older than 120 days (RA-OP-32). Every
 * failure is logged with its account and error; none is swallowed.
 */
@Injectable()
export class AccountDeletionPurgeScheduler {
  private readonly logger = new Logger(AccountDeletionPurgeScheduler.name);

  constructor(
    private readonly accountDeletion: AccountDeletionService,
    private readonly dataExports: DataExportService,
    private readonly prisma: PrismaService,
  ) {}

  @Cron("35 * * * *")
  async purgeDueAccounts(): Promise<void> {
    const now = new Date();
    const { erased, failures } = await this.accountDeletion.purgeDueAccounts(now);
    if (erased > 0) this.logger.log(`Erased ${erased} account(s) after their 30 days`);
    for (const failure of failures) {
      this.logger.error(
        `Account erasure failed for account ${failure.userId} (${failure.code})`,
        failure.error instanceof Error ? failure.error.stack : String(failure.error),
      );
    }
    const removed = await this.dataExports.removeOldExports(now);
    if (removed > 0) this.logger.log(`Removed ${removed} old data download row(s)`);
    const reports = await removeReviewedAssistantReports(this.prisma, now);
    if (reports > 0) this.logger.log(`Removed ${reports} assistant report(s) reviewed over 90 days ago`);
    // RA-OP-32: the re-deletion list keeps an id 120 days, past every backup.
    const listed = await removeOldErasedAccounts(this.prisma, now);
    if (listed > 0) this.logger.log(`Removed ${listed} id(s) from the re-deletion list`);
  }
}
