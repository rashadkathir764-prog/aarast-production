import {
  Notification,
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

// The caller's transaction (or the shared client). Notifications reads the
// other contexts' rows through their ports on it, so the whole client is
// required; the earlier picks named the foreign tables notifications read
// itself, which are gone.
export type NotificationPurgeClient = Prisma.TransactionClient;
export type NotificationCreateClient = Prisma.TransactionClient;
export type NotificationVisibilityClient = Prisma.TransactionClient;

// The visibility filter a reader's notifications must satisfy, declared by
// its exact keys: plan visibility, money visibility, entity visibility and
// (for a non-operational provider account) the provider-audience
// exclusions. Ownership and membership are planning's and collaboration's
// rows, read through their ports and applied to the notification table by
// plan id; the shape is declared so the ownership scan can prove it.
type JsonPathEquals = { data: { path: string[]; equals: string } };
type JsonPathPresent = { data: { path: string[]; not: typeof Prisma.AnyNull } };
export interface ProviderAudienceWhere {
  AND: [JsonPathEquals, JsonPathEquals];
}
export interface PlanVisibilityWhere {
  OR: Array<
    | { weddingPlanId: null }
    | { type: NotificationType; entityType: string }
    | ProviderAudienceWhere
    | { weddingPlanId: { in: string[] } }
  >;
}
/** The entity types of money notifications: visible only with money access, purged when it is lost. */
export const MONEY_NOTIFICATION_ENTITY_TYPES = [
  'payment_schedule',
  'budget_category',
  'loan_repayment',
] as const;
export interface MoneyVisibilityWhere {
  OR: [
    {
      AND: [
        { type: { notIn: NotificationType[] } },
        { OR: [{ entityType: null }, { entityType: { notIn: string[] } }] },
      ];
    },
    { weddingPlanId: { in: string[] } },
  ];
}
export type ScopedEntityClause =
  | { weddingPlanId: { in: string[] } }
  | { AND: [{ weddingPlanId: string }, { entityId: { in: string[] } }] };
export interface EntityVisibilityWhere {
  OR: [
    { entityType: null },
    { entityType: { notIn: string[] } },
    { AND: [{ entityType: string }, { OR: ScopedEntityClause[] }] },
    { AND: [{ entityType: string }, { OR: ScopedEntityClause[] }] },
  ];
}
export type ProviderExclusionClause =
  | JsonPathEquals
  | JsonPathPresent
  | { entityType: { not: null } }
  | { entityType: string }
  | { routeTarget: { not: null } }
  | { routeTarget: string }
  | { type: NotificationType };
export interface ProviderVisibilityWhere {
  AND: Array<{ NOT: { AND: ProviderExclusionClause[] } }>;
}
export interface NotificationVisibilityWhere {
  AND: Array<
    | PlanVisibilityWhere
    | MoneyVisibilityWhere
    | EntityVisibilityWhere
    | ProviderVisibilityWhere
  >;
}

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
  ): Promise<NotificationVisibilityWhere | null>;
  /** The plan dashboard's notification counters, its three latest notifications and the latest important one. */
  getPlanNotificationDashboard(
    client: Prisma.TransactionClient,
    userId: string,
    weddingPlanId: string,
  ): Promise<PlanNotificationDashboard>;
  /** Whether each recipient still accepts provider-message notifications (missing rows accept). */
  listProviderMessagePreferences(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<ProviderMessagePreference[]>;
}

/** What the plan dashboard shows of the reader's notifications for the plan, under the reader's visibility. */
export interface PlanNotificationDashboard {
  unreadCount: number;
  highPriorityCount: number;
  latest: Notification[];
  latestImportant: Notification | null;
}

export interface ProviderMessagePreference {
  userId: string;
  providerMessagesEnabled: boolean;
}
