import type {
  Notification,
  NotificationPriority,
  NotificationType,
  Prisma,
} from '@prisma/client';

export const NOTIFICATIONS_ADMIN_PORT = Symbol('NOTIFICATIONS_ADMIN_PORT');

export interface AdminNotificationFilter {
  type?: NotificationType;
  priority?: NotificationPriority;
  unreadOnly?: boolean;
  /** `text` matches the title or entity type; `userIds` are the recipients identity matched for it. */
  search?: { text: string; userIds: readonly string[] };
}

export interface AdminNotificationReport {
  total: number;
  unread: number;
  archived: number;
  high: number;
  urgent: number;
}

// Notifications owns the notification rows. The back office lists and
// triages them through this port on the client it passes (its authorized
// serializable transaction, or the shared Prisma service); every mutation
// takes the notification's row lock first and returns null (false for the
// delete) when the notification does not exist.
export interface NotificationsAdminPort {
  /** Newest first. */
  listNotifications(
    client: Prisma.TransactionClient,
    filter: AdminNotificationFilter,
    page: { skip: number; take: number },
  ): Promise<{ total: number; items: Notification[] }>;
  /** Neither read nor archived. */
  countUnreadNotifications(client: Prisma.TransactionClient): Promise<number>;
  getReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminNotificationReport>;
  markNotificationReadInTransaction(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<Notification | null>;
  /** Archives the notification, reading it too when it is still unread. */
  archiveNotificationInTransaction(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<Notification | null>;
  deleteNotificationInTransaction(
    tx: Prisma.TransactionClient,
    notificationId: string,
  ): Promise<boolean>;
}
