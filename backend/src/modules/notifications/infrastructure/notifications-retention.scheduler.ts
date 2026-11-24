import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';

/** RA-BE-179 (Q-45): a notification is kept 180 days after it was read. */
export const READ_NOTIFICATION_RETENTION_DAYS = 180;
const DAY_MS = 24 * 60 * 60 * 1000;

/** RA-BE-179: the notifications read more than 180 days ago go; an unread one stays. */
export async function removeOldReadNotifications(
  client: Prisma.TransactionClient,
  now: Date,
): Promise<number> {
  const before = new Date(now.getTime() - READ_NOTIFICATION_RETENTION_DAYS * DAY_MS);
  const result = await client.notification.deleteMany({
    where: { readAt: { lt: before } },
  });
  return result.count;
}

/** Daily retention of the notifications (privacy page, «كم نحتفظ ببياناتك»). */
@Injectable()
export class NotificationsRetentionScheduler {
  private readonly logger = new Logger(NotificationsRetentionScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  @Cron('25 3 * * *')
  async removeOldRead(): Promise<number> {
    const removed = await removeOldReadNotifications(this.prisma, new Date());
    if (removed > 0) this.logger.log(`Removed ${removed} notification(s) read over 180 days ago`);
    return removed;
  }
}
