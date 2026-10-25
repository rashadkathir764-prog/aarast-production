import { Injectable } from '@nestjs/common';
import { NotificationPriority, Prisma } from '@prisma/client';
import type {
  AdminNotificationReport,
  NotificationsAdminPort,
} from '../public/notifications-admin.port';

@Injectable()
export class NotificationsAdminService implements NotificationsAdminPort {
  async getReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminNotificationReport> {
    const [total, unread, archived, high, urgent] = await Promise.all([
      client.notification.count({ where: { createdAt } }),
      client.notification.count({
        where: { createdAt, readAt: null, archivedAt: null },
      }),
      client.notification.count({
        where: { createdAt, archivedAt: { not: null } },
      }),
      client.notification.count({
        where: { createdAt, priority: NotificationPriority.HIGH },
      }),
      client.notification.count({
        where: { createdAt, priority: NotificationPriority.URGENT },
      }),
    ]);
    return { total, unread, archived, high, urgent };
  }
}
