import { Injectable, Logger } from "@nestjs/common";
import { Interval } from "@nestjs/schedule";
import { PrismaService } from "../../../../platform/database/prisma.service";
import { removeExpiredAuthChallenges } from '../../infrastructure/auth-cleanup.repository';

const CLEANUP_INTERVAL_MS = 60 * 60 * 1_000;

@Injectable()
export class AuthChallengeCleanupScheduler {
  private readonly logger = new Logger(AuthChallengeCleanupScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Interval(CLEANUP_INTERVAL_MS)
  async removeExpiredSecurityState(): Promise<number | null> {
    const removed = await removeExpiredAuthChallenges(this.prisma);

    if (removed && removed > 0) {
      this.logger.log(
        `Removed ${removed} expired or revoked authentication row(s)`,
      );
    }
    return removed;
  }
}
