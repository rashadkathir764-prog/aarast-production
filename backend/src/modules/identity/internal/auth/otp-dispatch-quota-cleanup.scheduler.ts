import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../../../../platform/database/prisma.service';
import { OtpDispatchQuotaService } from './otp-dispatch-quota.service';
import { removeExpiredOtpQuotaWindows } from '../../infrastructure/auth-cleanup.repository';

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;

@Injectable()
export class OtpDispatchQuotaCleanupScheduler {
  private readonly logger = new Logger(OtpDispatchQuotaCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeExpiredWindows(): Promise<number | null> {
    const deleted = await removeExpiredOtpQuotaWindows(
      this.prisma,
      OtpDispatchQuotaService.retentionMs,
    );

    if (deleted && deleted > 0) {
      this.logger.log(`Removed ${deleted} expired OTP quota row(s)`);
    }
    return deleted;
  }
}
