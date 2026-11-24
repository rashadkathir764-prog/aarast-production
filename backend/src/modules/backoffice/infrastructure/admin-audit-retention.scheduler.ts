import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';

/** RA-BE-179 (Q-45): the back office's audit log is kept two years. */
export const ADMIN_AUDIT_RETENTION_YEARS = 2;

/**
 * RA-BE-179: the audit rows older than two years go. The log stays
 * append-only: its trigger refuses every UPDATE and every DELETE of a row
 * younger than two years (migration 20261125090000_retention_periods).
 */
export async function removeExpiredAdminAudit(
  client: Prisma.TransactionClient,
  now: Date,
): Promise<number> {
  const before = new Date(now);
  before.setUTCFullYear(before.getUTCFullYear() - ADMIN_AUDIT_RETENTION_YEARS);
  // A day's margin, so the database's own clock never sees a younger row.
  before.setUTCDate(before.getUTCDate() - 1);
  const result = await client.adminAuditLog.deleteMany({
    where: { createdAt: { lt: before } },
  });
  return result.count;
}

/** Daily retention of the audit log (privacy page, «كم نحتفظ ببياناتك»). */
@Injectable()
export class AdminAuditRetentionScheduler {
  private readonly logger = new Logger(AdminAuditRetentionScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron('30 3 * * *')
  async removeExpired(): Promise<number> {
    const removed = await removeExpiredAdminAudit(this.prisma, new Date());
    if (removed > 0) this.logger.log(`Removed ${removed} audit row(s) older than two years`);
    return removed;
  }
}
