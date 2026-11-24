import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';

const CLEANUP_INTERVAL_MS = 6 * 60 * 60 * 1_000;
const PROCESSED_RETENTION_MS = 7 * 24 * 60 * 60 * 1_000;
/** RA-BE-179 (Q-45): an event that failed for good is kept 30 days, for diagnosis. */
export const FAILED_RETENTION_DAYS = 30;
const FAILED_RETENTION_MS = FAILED_RETENTION_DAYS * 24 * 60 * 60 * 1_000;

@Injectable()
export class OutboxCleanupScheduler {
  private readonly logger = new Logger(OutboxCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeProcessedReceipts(): Promise<number | null> {
    const deleted = await this.prisma.$transaction(async (tx) => {
      const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT pg_try_advisory_xact_lock(20260711, 6) AS locked
      `;
      if (!lock?.locked) return null;

      const now = Date.now();
      const result = await tx.outboxEvent.deleteMany({
        where: {
          OR: [
            {
              status: 'PROCESSED',
              processedAt: { lt: new Date(now - PROCESSED_RETENTION_MS) },
            },
            // RA-BE-179: a failed event (its payload names people) goes
            // 30 days after its last attempt.
            {
              status: 'FAILED',
              updatedAt: { lt: new Date(now - FAILED_RETENTION_MS) },
            },
          ],
        },
      });
      return result.count;
    });

    if (deleted && deleted > 0) {
      this.logger.log(`Removed ${deleted} processed or failed outbox event(s)`);
    }
    return deleted;
  }
}
