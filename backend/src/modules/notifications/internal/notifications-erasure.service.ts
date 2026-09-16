import { Injectable } from '@nestjs/common';
import type { NotificationPreference, Prisma } from '@prisma/client';
import type {
  NotificationPreferenceUpdate,
  NotificationsErasurePort,
  OwnedNotificationScope,
} from '../public/notifications-erasure.port';

@Injectable()
export class NotificationsErasureService implements NotificationsErasurePort {
  async listOwnedNotificationIds(
    tx: Prisma.TransactionClient,
    scope: OwnedNotificationScope,
  ): Promise<string[]> {
    const notifications = await tx.notification.findMany({
      where: {
        OR: [
          { userId: scope.userId },
          ...(scope.weddingPlanIds.length > 0
            ? [{ weddingPlanId: { in: [...scope.weddingPlanIds] } }]
            : []),
          ...(scope.quoteRequestIds.length > 0
            ? [
                {
                  entityType: 'quote_request',
                  entityId: { in: [...scope.quoteRequestIds] },
                },
              ]
            : []),
        ],
      },
      select: { id: true },
    });
    return notifications.map((row) => row.id);
  }

  async deleteNotificationsInTransaction(
    tx: Prisma.TransactionClient,
    notificationIds: readonly string[],
  ): Promise<void> {
    if (notificationIds.length === 0) return;
    await tx.notification.deleteMany({
      where: { id: { in: [...notificationIds] } },
    });
  }

  async deleteUserPreferencesAndInstallationsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.notificationPreference.deleteMany({ where: { userId } });
    await tx.pushInstallation.deleteMany({ where: { userId } });
  }

  async ensurePreferenceInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<NotificationPreference> {
    return tx.notificationPreference.upsert({
      where: { userId },
      update: {},
      create: { userId },
    });
  }

  async upsertPreferenceInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    update: NotificationPreferenceUpdate,
  ): Promise<NotificationPreference> {
    return tx.notificationPreference.upsert({
      where: { userId },
      create: { userId, ...update },
      update,
    });
  }
}
