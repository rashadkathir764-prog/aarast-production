import type { NotificationPreference, Prisma } from '@prisma/client';

export const NOTIFICATIONS_ERASURE_PORT = Symbol('NOTIFICATIONS_ERASURE_PORT');

export interface OwnedNotificationScope {
  userId: string;
  weddingPlanIds: readonly string[];
  quoteRequestIds: readonly string[];
}

export interface NotificationPreferenceUpdate {
  smsEnabled?: boolean;
  whatsappEnabled?: boolean;
  emailEnabled?: boolean;
  taskRemindersEnabled?: boolean;
  paymentRemindersEnabled?: boolean;
  providerMessagesEnabled?: boolean;
}

// Notifications owns `Notification`, `NotificationPreference` and
// `PushInstallation`. Identity's account erasure and its settings endpoints
// reach these rows through this port on their own transactions.
export interface NotificationsErasurePort {
  /** Ids of the notifications addressed to the user, to the plans, or about the quote requests. */
  listOwnedNotificationIds(
    tx: Prisma.TransactionClient,
    scope: OwnedNotificationScope,
  ): Promise<string[]>;
  deleteNotificationsInTransaction(
    tx: Prisma.TransactionClient,
    notificationIds: readonly string[],
  ): Promise<void>;
  /** The explicit equivalents of the User cascades for a retained administrator identity. */
  deleteUserPreferencesAndInstallationsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
  /** Reads the user's preference row, creating the default row when it does not exist. */
  ensurePreferenceInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<NotificationPreference>;
  upsertPreferenceInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    update: NotificationPreferenceUpdate,
  ): Promise<NotificationPreference>;
}
