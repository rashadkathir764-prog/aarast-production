import type { Prisma } from '@prisma/client';

export const NOTIFICATIONS_ADMIN_PORT = Symbol('NOTIFICATIONS_ADMIN_PORT');

export interface AdminNotificationReport {
  total: number;
  unread: number;
  archived: number;
  high: number;
  urgent: number;
}

// Notifications owns the notification rows. The back office reads only
// their counts, for the report (a02), through this port on the client it
// passes. The desk has no notifications page (D56), so it neither lists nor
// changes anyone's notifications.
export interface NotificationsAdminPort {
  getReport(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<AdminNotificationReport>;
}
