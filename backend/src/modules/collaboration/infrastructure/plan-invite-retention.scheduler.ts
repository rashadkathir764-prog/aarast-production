import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';

/** RA-BE-179 (Q-45): an invitation never accepted is kept 90 days past its expiry. */
export const EXPIRED_INVITE_RETENTION_DAYS = 90;
const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * RA-BE-179: the invitations that expired unaccepted more than 90 days ago,
 * with the name and number they carry, go (their invite OTP codes cascade).
 */
export async function removeExpiredPlanInvites(
  client: Prisma.TransactionClient,
  now: Date,
): Promise<number> {
  const before = new Date(now.getTime() - EXPIRED_INVITE_RETENTION_DAYS * DAY_MS);
  const result = await client.planInvite.deleteMany({
    where: { acceptedAt: null, expiresAt: { lt: before } },
  });
  return result.count;
}

/** Daily retention of the plans' invitations (privacy page, «كم نحتفظ ببياناتك»). */
@Injectable()
export class PlanInviteRetentionScheduler {
  private readonly logger = new Logger(PlanInviteRetentionScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron('20 3 * * *')
  async removeExpired(): Promise<number> {
    const removed = await removeExpiredPlanInvites(this.prisma, new Date());
    if (removed > 0) this.logger.log(`Removed ${removed} invitation(s) expired over 90 days ago`);
    return removed;
  }
}
