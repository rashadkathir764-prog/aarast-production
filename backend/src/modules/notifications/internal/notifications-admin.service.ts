import { Injectable } from '@nestjs/common';
import {
  type Notification,
  NotificationPriority,
  type NotificationType,
  Prisma,
} from '@prisma/client';
import type {
  AdminNotificationFilter,
  AdminNotificationReport,
  NotificationsAdminPort,
} from '../public/notifications-admin.port';

interface TextMatch {
  contains: string;
  mode: 'insensitive';
}

type NotificationAdminCondition =
  | { type: NotificationType }
  | { priority: NotificationPriority }
  | { readAt: null }
  | {
      OR: Array<
        | { title: TextMatch }
        | { entityType: TextMatch }
        | { userId: { in: string[] } }
      >;
    };

@Injectable()
export class NotificationsAdminService implements NotificationsAdminPort {
  async listNotifications(
    client: Prisma.TransactionClient,
    filter: AdminNotificationFilter,
    page: { skip: number; take: number },
  ): Promise<{ total: number; items: Notification[] }> {
    const and: NotificationAdminCondition[] = [];
    if (filter.type) and.push({ type: filter.type });
    if (filter.priority) and.push({ priority: filter.priority });
    if (filter.unreadOnly === true) and.push({ readAt: null });
    if (filter.search) {
      const text: TextMatch = {
        contains: filter.search.text,
        mode: 'insensitive',
      };
      and.push({
        OR: [
          { title: text },
          { entityType: text },
          { userId: { in: [...filter.search.userIds] } },
        ],
      });
    }
    const where = { AND: and };
    const total = await client.notification.count({ where });
    const items = await client.notification.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      skip: page.skip,
      take: page.take,
    });
    return { total, items };
  }

  async countUnreadNotifications(
    client: Prisma.TransactionClient,
  ): Promise<number> {
    return client.notification.count({
      where: { readAt: null, archivedAt: null },
    });
  }

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

  async markNotificationReadInTransaction(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<Notification | null> {
    if (!(await this.lockNotification(tx, notificationId))) return null;
    return tx.notification.update({
      where: { id: notificationId },
      data: { readAt: new Date() },
    });
  }

  async archiveNotificationInTransaction(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<Notification | null> {
    const existing = await this.lockNotification(tx, notificationId);
    if (!existing) return null;
    const now = new Date();
    return tx.notification.update({
      where: { id: notificationId },
      data: {
        archivedAt: now,
        readAt: existing.readAt ?? now,
      },
    });
  }

  async deleteNotificationInTransaction(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<boolean> {
    if (!(await this.lockNotification(tx, notificationId))) return false;
    await tx.notification.delete({ where: { id: notificationId } });
    return true;
  }

  private async lockNotification(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<{ id: string; readAt: Date | null } | null> {
    const rows = await tx.$queryRaw<Array<{ id: string; readAt: Date | null }>>(
      Prisma.sql`
        SELECT "id", "readAt"
        FROM "Notification"
        WHERE "id" = ${notificationId}
        FOR UPDATE
      `,
    );
    return rows[0] ?? null;
  }
}
