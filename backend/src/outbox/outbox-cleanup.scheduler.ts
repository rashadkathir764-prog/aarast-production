import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../platform/database/prisma.service';

const CLEANUP_INTERVAL_MS = 6 * 60 * 60 * 1_000;
const PROCESSED_RETENTION_MS = 7 * 24 * 60 * 60 * 1_000;

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

      const result = await tx.outboxEvent.deleteMany({
        where: {
          status: 'PROCESSED',
          processedAt: {
            lt: new Date(Date.now() - PROCESSED_RETENTION_MS),
          },
        },
      });
      return result.count;
    });

    if (deleted && deleted > 0) {
      this.logger.log(`Removed ${deleted} processed outbox receipt(s)`);
    }
    return deleted;
  }
}
