import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../platform/database/prisma.service';
import { LoginThrottleService } from './login-throttle.service';

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;

@Injectable()
export class LoginThrottleCleanupScheduler {
  private readonly logger = new Logger(LoginThrottleCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeExpiredWindows(): Promise<number | null> {
    const deleted = await this.prisma.$transaction(async (tx) => {
      const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT pg_try_advisory_xact_lock(20260711, 5) AS locked
      `;
      if (!lock?.locked) return null;

      const now = new Date();
      const inactiveBefore = new Date(
        now.getTime() - LoginThrottleService.windowMs,
      );
      const result = await tx.loginThrottle.deleteMany({
        where: {
          OR: [
            { lockedUntil: { lt: now } },
            { lockedUntil: null, updatedAt: { lt: inactiveBefore } },
          ],
        },
      });
      return result.count;
    });

    if (deleted && deleted > 0) {
      this.logger.log(`Removed ${deleted} expired login throttle row(s)`);
    }
    return deleted;
  }
}
