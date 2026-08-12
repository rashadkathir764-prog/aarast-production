import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../database/prisma.service';
import { idempotencyAmbiguousTombstones } from '../observability/metrics';

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;

@Injectable()
export class IdempotencyCleanupScheduler {
  private readonly logger = new Logger(IdempotencyCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeExpiredKeys(): Promise<void> {
    const snapshot = await this.prisma.$transaction(async (tx) => {
      // Only one replica performs cleanup. The transaction-scoped lock is
      // released automatically on commit, rollback, or process failure.
      const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT pg_try_advisory_xact_lock(20260710, 2) AS locked
      `;
      if (!lock?.locked) return null;

      const now = new Date();
      const result = await tx.idempotencyKey.deleteMany({
        // Never delete an ambiguous in-flight reservation. Its handler may
        // have committed before the process crashed while storing the replay
        // response; retaining it prevents a duplicate mutation.
        where: {
          completedAt: { not: null },
          expiresAt: { lt: now },
        },
      });
      const ambiguousCount = await tx.idempotencyKey.count({
        where: {
          completedAt: null,
          expiresAt: { lt: now },
        },
      });
      return { deletedCount: result.count, ambiguousCount };
    });

    if (!snapshot) return;
    idempotencyAmbiguousTombstones.set(snapshot.ambiguousCount);
    if (snapshot.ambiguousCount > 0) {
      this.logger.warn(
        `Detected ${snapshot.ambiguousCount} ambiguous idempotency tombstone(s)`,
      );
    }
    if (snapshot.deletedCount > 0) {
      this.logger.log(
        `Removed ${snapshot.deletedCount} expired idempotency key(s)`,
      );
    }
  }
}
