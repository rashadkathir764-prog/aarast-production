import { Injectable, Logger } from "@nestjs/common";
import { Interval } from "@nestjs/schedule";
import { PrismaService } from "../prisma/prisma.service";

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;
const RETENTION_MS = 24 * 60 * 60 * 1_000;

@Injectable()
export class AuthChallengeCleanupScheduler {
  private readonly logger = new Logger(AuthChallengeCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeExpiredSecurityState(): Promise<number | null> {
    const removed = await this.prisma.$transaction(async (tx) => {
      const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT pg_try_advisory_xact_lock(20260717, 1) AS locked
      `;
      if (!lock?.locked) return null;

      const retainedAfter = new Date(Date.now() - RETENTION_MS);
      const [loginChallenges, resetChallenges] = await Promise.all([
        tx.adminLoginChallenge.deleteMany({
          where: { expiresAt: { lt: retainedAfter } },
        }),
        tx.adminPasswordResetChallenge.deleteMany({
          where: { expiresAt: { lt: retainedAfter } },
        }),
      ]);
      const otpCodes = await tx.otpCode.deleteMany({
        where: { expiresAt: { lt: retainedAfter } },
      });
      return loginChallenges.count + resetChallenges.count + otpCodes.count;
    });

    if (removed && removed > 0) {
      this.logger.log(`Removed ${removed} expired authentication row(s)`);
    }
    return removed;
  }
}
