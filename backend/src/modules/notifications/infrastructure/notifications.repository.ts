import { NotificationPriority, NotificationType, Prisma } from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';
import {
  MONEY_NOTIFICATION_ENTITY_TYPES,
  type CreateNotificationInput,
  type NotificationVisibilityWhere,
  type PlanVisibilityWhere,
  type ProviderAudienceWhere,
} from '../public/notifications.port';

type Client = Prisma.TransactionClient | PrismaService;

export interface DueNotificationRow {
  userId: string;
  weddingPlanId: string;
  type: NotificationType;
  priority: NotificationPriority;
  title: string;
  body: string;
  data: Prisma.InputJsonValue;
  entityType: string;
  entityId: string;
  routeTarget: string;
  dedupeKey: string;
}

export class NotificationsRepository {
  listVisible(
    tx: Prisma.TransactionClient, userId: string, planId: string | null,
    type: NotificationType | undefined, unreadOnly: boolean,
    visibility: NotificationVisibilityWhere, page: number, limit: number,
  ) {
    const where = {
      userId, archivedAt: null,
      ...(type ? { type } : {}),
      ...(unreadOnly ? { readAt: null } : {}),
      ...(planId ? { weddingPlanId: planId } : {}),
      AND: visibility,
    } satisfies Prisma.NotificationWhereInput;
    return Promise.all([
      tx.notification.count({ where }),
      tx.notification.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);
  }

  countUnread(tx: Prisma.TransactionClient, userId: string, planId: string | null, visibility: NotificationVisibilityWhere) {
    return tx.notification.count({
      where: { userId, readAt: null, archivedAt: null, ...(planId ? { weddingPlanId: planId } : {}), AND: visibility },
    });
  }

  markRead(tx: Prisma.TransactionClient, id: string, at: Date) {
    return tx.notification.update({ where: { id }, data: { readAt: at } });
  }

  hasPlanAudience(tx: Prisma.TransactionClient, userId: string, planId: string, providerAudience: ProviderAudienceWhere | null) {
    return tx.notification.findFirst({
      where: {
        userId, weddingPlanId: planId,
        OR: [
          { type: NotificationType.SHARING_INVITATION, entityType: 'plan_invite' },
          ...(providerAudience ? [providerAudience] : []),
        ],
      },
      select: { id: true },
    });
  }

  unreadVisibleIds(tx: Prisma.TransactionClient, userId: string, planVisibility: PlanVisibilityWhere, visibility: NotificationVisibilityWhere) {
    return tx.notification.findMany({
      where: { userId, readAt: null, archivedAt: null, AND: [planVisibility, visibility] },
      select: { id: true },
    });
  }

  recheckUnreadVisibleIds(tx: Prisma.TransactionClient, userId: string, planVisibility: PlanVisibilityWhere, visibility: NotificationVisibilityWhere, ids: readonly string[]) {
    return tx.notification.findMany({
      where: { userId, readAt: null, archivedAt: null, AND: [planVisibility, visibility], id: { in: [...ids] } },
      select: { id: true },
    });
  }

  markVisibleIdsRead(tx: Prisma.TransactionClient, ids: readonly string[], at: Date) {
    return tx.notification.updateMany({ where: { id: { in: [...ids] } }, data: { readAt: at } });
  }

  deleteNotification(tx: Prisma.TransactionClient, id: string) {
    return tx.notification.delete({ where: { id } });
  }

  archiveNotification(tx: Prisma.TransactionClient, id: string, at: Date, existingReadAt: Date | null) {
    return tx.notification.update({
      where: { id }, data: { archivedAt: at, readAt: existingReadAt ?? at },
    });
  }

  findByDedupeKey(client: Client, dedupeKey: string) {
    return client.notification.findUnique({ where: { dedupeKey } });
  }

  notificationPreference(client: Prisma.TransactionClient, userId: string) {
    return client.notificationPreference.findUnique({
      where: { userId },
      select: { taskRemindersEnabled: true, paymentRemindersEnabled: true, providerMessagesEnabled: true },
    });
  }

  /** Writes a notification whose words are already in the recipient's form. */
  createNotification(
    client: Prisma.TransactionClient,
    input: CreateNotificationInput & { title: string; body: string },
  ) {
    return client.notification.create({
      data: {
        userId: input.userId,
        weddingPlanId: input.weddingPlanId ?? null,
        type: input.type,
        priority: input.priority ?? NotificationPriority.NORMAL,
        title: input.title,
        body: input.body,
        entityType: input.entityType ?? null,
        entityId: input.entityId ?? null,
        routeTarget: input.routeTarget ?? null,
        data: input.data,
        dedupeKey: input.dedupeKey,
      },
    });
  }

  dashboard(tx: Prisma.TransactionClient, userId: string, weddingPlanId: string, visibility: NotificationVisibilityWhere | null) {
    const where = {
      userId, weddingPlanId, archivedAt: null,
      ...(visibility ? { AND: visibility } : {}),
    } satisfies Prisma.NotificationWhereInput;
    const important = { in: [NotificationPriority.HIGH, NotificationPriority.URGENT] };
    return Promise.all([
      tx.notification.count({ where: { ...where, readAt: null } }),
      tx.notification.count({ where: { ...where, priority: important } }),
      tx.notification.findMany({ where, orderBy: { createdAt: 'desc' }, take: 3 }),
      tx.notification.findFirst({
        where: { ...where, priority: important },
        orderBy: [{ priority: 'desc' }, { createdAt: 'desc' }],
      }),
    ]);
  }

  providerMessagePreferences(tx: Prisma.TransactionClient, userIds: readonly string[]) {
    return tx.notificationPreference.findMany({
      where: { userId: { in: [...userIds] } },
      select: { userId: true, providerMessagesEnabled: true },
    });
  }

  dueReminderPreferences(tx: Prisma.TransactionClient, userIds: readonly string[]) {
    return tx.notificationPreference.findMany({
      where: { userId: { in: [...userIds] } },
      select: {
        userId: true,
        taskRemindersEnabled: true,
        paymentRemindersEnabled: true,
        providerMessagesEnabled: true,
      },
    });
  }

  tryLockDueScheduler(tx: Prisma.TransactionClient) {
    return tx.$queryRaw<Array<{ locked: boolean }>>`
      SELECT pg_try_advisory_xact_lock(20260711, 3) AS locked
    `;
  }

  createDueNotifications(tx: Prisma.TransactionClient, rows: DueNotificationRow[]) {
    return tx.notification.createManyAndReturn({ data: rows, skipDuplicates: true });
  }

  moneyNotificationIds(tx: Prisma.TransactionClient, userId: string, weddingPlanId: string) {
    return tx.notification.findMany({
      where: {
        userId,
        weddingPlanId,
        entityType: { in: [...MONEY_NOTIFICATION_ENTITY_TYPES] },
      },
      select: { id: true },
    });
  }

  deleteNotificationIds(tx: Prisma.TransactionClient, ids: readonly string[]) {
    return tx.notification.deleteMany({ where: { id: { in: [...ids] } } });
  }

  findOwned(tx: Prisma.TransactionClient, id: string, userId: string) {
    return tx.notification.findFirst({ where: { id, userId } });
  }

  unreadPlanIds(tx: Prisma.TransactionClient, userId: string, weddingPlanId: string | null) {
    return tx.notification.findMany({
      where: { userId, readAt: null, archivedAt: null, weddingPlanId: weddingPlanId ?? { not: null } },
      select: { weddingPlanId: true },
    });
  }

  lockRowsForUpdate(tx: Prisma.TransactionClient, ids: readonly string[]) {
    return tx.$queryRaw(
      Prisma.sql`SELECT "id" FROM "Notification" WHERE "id" IN (${Prisma.join([...ids])}) ORDER BY "id" ASC FOR UPDATE`,
    );
  }
}
