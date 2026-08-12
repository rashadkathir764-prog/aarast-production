import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../platform/database/prisma.service';
import { OtpDispatchQuotaService } from './otp-dispatch-quota.service';

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;

@Injectable()
export class OtpDispatchQuotaCleanupScheduler {
  private readonly logger = new Logger(OtpDispatchQuotaCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeExpiredWindows(): Promise<number | null> {
    const deleted = await this.prisma.$transaction(async (tx) => {
      const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT pg_try_advisory_xact_lock(20260712, 7) AS locked
      `;
      if (!lock?.locked) return null;

      const inactiveBefore = new Date(
        Date.now() - OtpDispatchQuotaService.retentionMs,
      );
      return tx.$executeRaw`
        DELETE FROM "OtpDispatchQuota"
        WHERE "updatedAt" < ${inactiveBefore}
      `;
    });

    if (deleted && deleted > 0) {
      this.logger.log(`Removed ${deleted} expired OTP quota row(s)`);
    }
    return deleted;
  }
}
