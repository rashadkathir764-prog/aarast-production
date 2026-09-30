import { Injectable, Logger } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { PrismaService } from '../../../../platform/database/prisma.service';
import { LoginThrottleService } from './login-throttle.service';
import { removeExpiredLoginThrottleWindows } from '../../infrastructure/auth-cleanup.repository';

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;

@Injectable()
export class LoginThrottleCleanupScheduler {
  private readonly logger = new Logger(LoginThrottleCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeExpiredWindows(): Promise<number | null> {
    const deleted = await removeExpiredLoginThrottleWindows(
      this.prisma,
      LoginThrottleService.windowMs,
    );

    if (deleted && deleted > 0) {
      this.logger.log(`Removed ${deleted} expired login throttle row(s)`);
    }
    return deleted;
  }
}
