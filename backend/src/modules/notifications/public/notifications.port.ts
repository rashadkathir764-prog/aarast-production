import {
  NotificationPriority,
  NotificationType,
  Prisma,
  WeddingTask,
} from '@prisma/client';

export const NOTIFICATIONS_PORT = Symbol('NOTIFICATIONS_PORT');

export interface NotificationResponse {
  id: string;
  userId: string;
  weddingPlanId: string | null;
  type: NotificationType;
  priority: NotificationPriority;
  title: string;
  body: string;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
  data: Prisma.JsonValue | null;
  readAt: Date | null;
  archivedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateNotificationInput {
  userId: string;
  weddingPlanId?: string | null;
  type: NotificationType;
  priority?: NotificationPriority;
  title: string;
  body: string;
  entityType?: string | null;
  entityId?: string | null;
  routeTarget?: string | null;
  data?: Prisma.InputJsonValue;
  dedupeKey?: string;
}

export type NotificationPurgeClient = Pick<
  Prisma.TransactionClient,
  'notification' | 'outboxEvent'
>;

export type NotificationCreateClient = Pick<
  Prisma.TransactionClient,
  '$queryRaw' | 'notification' | 'notificationPreference' | 'outboxEvent'
>;

export type NotificationVisibilityClient = Pick<
  Prisma.TransactionClient,
  | 'conversation'
  | 'contributionEvent'
  | 'notification'
  | 'paymentSchedule'
  | 'provider'
  | 'sharedMember'
  | 'weddingTask'
>;

export interface NotificationsPort {
  createNotificationInTransaction(
    client: NotificationCreateClient,
    input: CreateNotificationInput,
  ): Promise<NotificationResponse | null>;
  resolveProviderUpdateRecipientInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string | null,
    requestedUserId: string,
  ): Promise<string>;
  notifyTaskDue(task: WeddingTask): Promise<void>;
  purgeMoneyForMember(
    client: NotificationPurgeClient,
    userId: string,
    weddingPlanId: string,
  ): Promise<number>;
  visibilityWhereForUser(
    userId: string,
    client?: NotificationVisibilityClient,
  ): Promise<Prisma.NotificationWhereInput | null>;
}
