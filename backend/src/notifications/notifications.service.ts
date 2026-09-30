import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  Notification,
  NotificationPreference,
  NotificationPriority,
  NotificationType,
  PaymentScheduleStatus,
  Prisma,
  ProviderStatus,
  SharedMember,
  UserStatus,
  WeddingPlanStatus,
  WeddingTask,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { endOfRiyadhDay, startOfRiyadhDay } from "../shared-kernel/time/business-day";
import { PrismaService } from "../platform/database/prisma.service";
import { OutboxEventTypes } from "../platform/outbox/outbox.constants";
import { OutboxService } from "../platform/outbox/outbox.service";
import {
  assertProviderOperational,
  isProviderOperational,
  PROVIDER_PORTAL_ROUTE,
} from "../modules/marketplace/public/provider-access-policy";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
} from "../modules/collaboration/public/collaboration-permission.port";
import { isPushNotificationType } from "../push/push-notification.policy";
import {
  assertActiveMutationActorInTransaction,
  lockUserLifecycleRowsInTransaction,
} from "../modules/identity/public/user-lifecycle-lock";
import {
  type CreateNotificationInput,
  type EntityVisibilityWhere,
  type MoneyVisibilityWhere,
  type NotificationCreateClient,
  type NotificationPurgeClient,
  type NotificationResponse,
  type NotificationsPort,
  type NotificationVisibilityClient,
  type NotificationVisibilityWhere,
  type PlanNotificationDashboard,
  type PlanVisibilityWhere,
  type ProviderAudienceWhere,
  type ProviderMessagePreference,
  type ProviderVisibilityWhere,
  type ScopedEntityClause,
} from "../modules/notifications/public/notifications.port";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort,
} from "../modules/collaboration/public/collaboration-scope.port";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../modules/finance/public/finance.port";
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from "../modules/marketplace/public/provider-read.port";
import {
  CONVERSATION_LIFECYCLE_PORT,
  type ConversationLifecyclePort,
} from "../modules/messaging/public/conversation-lifecycle.port";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../modules/planning/public/plan-read.port";
import {
  TASKS_PORT,
  type TasksPort,
} from "../modules/tasks/public/tasks.port";
import { purgeOutboxEventsForAggregatesInTransaction } from "../platform/outbox/outbox-purge";
import {
  NotificationsRepository,
  type DueNotificationRow,
} from "../modules/notifications/infrastructure/notifications.repository";

type PlanParticipantNotificationInput = Omit<
  CreateNotificationInput,
  "userId" | "weddingPlanId"
>;

export interface NotificationPageResponse {
  items: NotificationResponse[];
  page: number;
  limit: number;
  total: number;
  totalPages: number;
  hasMore: boolean;
}

type NotificationContentPreference = Pick<
  NotificationPreference,
  "taskRemindersEnabled" | "paymentRemindersEnabled" | "providerMessagesEnabled"
>;

type OwnedProviderLifecycle = {
  id: string;
  status: ProviderStatus;
} | null;

@Injectable()
export class NotificationsService implements NotificationsPort {
  private readonly repository = new NotificationsRepository();
  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    private readonly outbox: OutboxService,
    @Inject(PLAN_READ_PORT) private readonly plans: PlanReadPort,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly scope: CollaborationScopePort,
    @Inject(TASKS_PORT) private readonly tasks: TasksPort,
    @Inject(FINANCE_PORT) private readonly finance: FinancePort,
    @Inject(PROVIDER_READ_PORT) private readonly providers: ProviderReadPort,
    @Inject(CONVERSATION_LIFECYCLE_PORT)
    private readonly conversations: ConversationLifecyclePort,
  ) {}

  async list(
    currentUser: AuthenticatedUser,
    weddingPlanId?: string,
    type?: NotificationType,
    unreadOnly = false,
    pageValue?: string,
    limitValue?: string,
  ): Promise<NotificationPageResponse> {
    const planId = this.optionalText(weddingPlanId);
    const page = this.positiveInteger(pageValue ?? "1", "page");
    const limit = Math.min(
      this.positiveInteger(limitValue ?? "20", "limit"),
      50,
    );
    const { total, notifications } = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const provider = await this.findOwnedProviderLifecycle(currentUser.id, tx);
        const visibility = await this.notificationVisibilityWhere(
          currentUser.id,
          provider,
          tx,
        );
        const [count, rows] = await this.repository.listVisible(
          tx, currentUser.id, planId, type, unreadOnly, visibility, page, limit,
        );
        return { total: count, notifications: rows };
      },
    );

    const totalPages = total === 0 ? 0 : Math.ceil(total / limit);
    return {
      items: notifications.map((notification) => this.toResponse(notification)),
      page,
      limit,
      total,
      totalPages,
      hasMore: page < totalPages,
    };
  }

  async unreadCount(
    currentUser: AuthenticatedUser,
    weddingPlanId?: string,
  ): Promise<{ count: number }> {
    const planId = this.optionalText(weddingPlanId);
    const count = await runSerializableTransaction(this.prisma, async (tx) => {
      const provider = await this.findOwnedProviderLifecycle(currentUser.id, tx);
      const visibility = await this.notificationVisibilityWhere(
        currentUser.id,
        provider,
        tx,
      );
      return this.repository.countUnread(tx, currentUser.id, planId, visibility);
    });

    return { count };
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<NotificationResponse> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const notification = await this.findOwnedOrThrow(currentUser, id, tx);
      return this.toResponse(notification);
    });
  }

  async markRead(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<NotificationResponse> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const existing = await this.lockOwnedForMutation(tx, currentUser, id);
      if (existing.readAt) return this.toResponse(existing);

      const notification = await this.repository.markRead(tx, id, new Date());
      return this.toResponse(notification);
    });
  }

  async markAllRead(
    currentUser: AuthenticatedUser,
    weddingPlanId?: string,
  ): Promise<{ updated: number }> {
    const planId = this.optionalText(weddingPlanId);
    return runSerializableTransaction(this.prisma, async (tx) => {
      const accessiblePlanIds = await this.lockAllPlanAccessForNotifications(
        tx,
        currentUser,
        planId,
      );
      const provider = await this.lockOwnedProviderLifecycle(
        tx,
        currentUser.id,
      );
      const providerAudience = this.operationalProviderAudienceWhere(provider);
      if (
        planId &&
        !accessiblePlanIds.includes(planId) &&
        !(await this.repository.hasPlanAudience(
          tx, currentUser.id, planId, providerAudience,
        ))
      ) {
        throw new NotFoundException("Wedding plan not found");
      }
      const visibility = await this.notificationVisibilityWhere(
        currentUser.id,
        provider,
        tx,
      );
      const planVisibility: PlanVisibilityWhere = planId
        ? { OR: [{ weddingPlanId: { in: [planId] } }] }
        : {
            OR: [
              { weddingPlanId: null },
              {
                type: NotificationType.SHARING_INVITATION,
                entityType: "plan_invite",
              },
              ...(providerAudience ? [providerAudience] : []),
              ...(accessiblePlanIds.length > 0
                ? [{ weddingPlanId: { in: accessiblePlanIds } }]
                : []),
            ],
          };
      const seed = await this.repository.unreadVisibleIds(
        tx, currentUser.id, planVisibility, visibility,
      );
      const ids = seed.map((notification) => notification.id).sort();
      if (ids.length === 0) return { updated: 0 };

      await this.lockNotificationRowsForUpdate(tx, ids);
      const stillVisible = await this.repository.recheckUnreadVisibleIds(
        tx, currentUser.id, planVisibility, visibility, ids,
      );
      const visibleIds = stillVisible
        .map((notification) => notification.id)
        .sort();
      if (visibleIds.length === 0) return { updated: 0 };

      const result = await this.repository.markVisibleIdsRead(tx, visibleIds, new Date());
      return { updated: result.count };
    });
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      await this.lockOwnedForMutation(tx, currentUser, id);
      await this.repository.deleteNotification(tx, id);
      return { id, deleted: true };
    });
  }

  async archive(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<NotificationResponse> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const existing = await this.lockOwnedForMutation(tx, currentUser, id);
      if (existing.archivedAt) return this.toResponse(existing);

      const now = new Date();
      const notification = await this.repository.archiveNotification(
        tx, id, now, existing.readAt,
      );
      return this.toResponse(notification);
    });
  }

  async createNotification(
    input: CreateNotificationInput,
  ): Promise<NotificationResponse | null> {
    if (input.dedupeKey) {
      const existing = await this.repository.findByDedupeKey(this.prisma, input.dedupeKey);
      if (existing) return this.toResponse(existing);
    }

    try {
      return await this.prisma.$transaction((tx) =>
        this.createNotificationInTransaction(tx, input),
      );
    } catch (error) {
      if (
        input.dedupeKey &&
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        const existing = await this.repository.findByDedupeKey(this.prisma, input.dedupeKey);
        if (existing) return this.toResponse(existing);
      }
      throw error;
    }
  }

  async createNotificationInTransaction(
    client: NotificationCreateClient,
    input: CreateNotificationInput,
  ): Promise<NotificationResponse | null> {
    const preferenceKey = this.preferenceKeyForType(input.type);
    if (preferenceKey) {
      // The recipient's lifecycle row is identity's: locked for share there.
      const recipient = await lockUserLifecycleRowsInTransaction(client, [
        input.userId,
      ]);
      if (recipient.length !== 1) {
        throw new NotFoundException("Notification recipient not found");
      }
      const preference = await this.repository.notificationPreference(client, input.userId);
      if (!this.preferenceEnabled(preferenceKey, preference)) {
        return null;
      }
    }

    const created = await this.repository.createNotification(client, input);
    await this.enqueueNotificationDelivery(client, created);
    return this.toResponse(created);
  }

  async getPlanNotificationDashboard(
    client: Prisma.TransactionClient,
    userId: string,
    weddingPlanId: string,
  ): Promise<PlanNotificationDashboard> {
    const visibility = await this.visibilityWhereForUser(userId, client);
    const [unreadCount, highPriorityCount, latest, latestImportant] =
      await this.repository.dashboard(client, userId, weddingPlanId, visibility);
    return { unreadCount, highPriorityCount, latest, latestImportant };
  }

  async listProviderMessagePreferences(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<ProviderMessagePreference[]> {
    if (userIds.length === 0) return [];
    return this.repository.providerMessagePreferences(client, userIds);
  }

  async resolveProviderUpdateRecipientInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string | null,
    requestedUserId: string,
  ): Promise<string> {
    if (!weddingPlanId) return requestedUserId;

    // The membership row is collaboration's and the plan planning's: the
    // lock and the reads run through their ports on this transaction.
    await this.permissions.lockMembershipsForShareInTransaction(
      tx,
      weddingPlanId,
      [requestedUserId],
    );
    const plan = await this.plans.getPlan(tx, weddingPlanId);
    if (!plan) throw new NotFoundException("Wedding plan not found");
    if (plan.ownerUserId === requestedUserId) return requestedUserId;
    const membership = await this.permissions.getMembership(
      tx,
      weddingPlanId,
      requestedUserId,
    );
    return membership?.canManageProviders
      ? requestedUserId
      : plan.ownerUserId;
  }

  async createForPlanParticipants(
    weddingPlanId: string,
    input: PlanParticipantNotificationInput,
    excludedUserIds: string[] = [],
  ): Promise<NotificationResponse[]> {
    return this.createForPlanParticipantsAtomically(
      weddingPlanId,
      async () => input,
      excludedUserIds,
    );
  }

  private async createForPlanParticipantsAtomically(
    weddingPlanId: string,
    inputFactory: (
      tx: Prisma.TransactionClient,
    ) => Promise<PlanParticipantNotificationInput | null>,
    excludedUserIds: string[] = [],
    recipientScopeFactory?: (
      tx: Prisma.TransactionClient,
      plan: {
        ownerUserId: string;
        sharedMembers: Array<{ userId: string; canManageTasks: boolean }>;
      },
    ) => Promise<ReadonlySet<string>>,
  ): Promise<NotificationResponse[]> {
    const operation = async (
      tx: Prisma.TransactionClient,
    ): Promise<NotificationResponse[]> => {
      // The plan and its members are planning's and collaboration's rows,
      // read through their ports on this transaction (seed, then re-read
      // under the row locks below).
      const seed = await this.planWithNotifiedMembers(tx, weddingPlanId);
      if (!seed) {
        throw new NotFoundException("Wedding plan not found");
      }

      const seedRecipientIds = [
        ...new Set([
          seed.ownerUserId,
          ...seed.sharedMembers.map((member) => member.userId),
        ]),
      ].sort();
      const lockedUsers = await lockUserLifecycleRowsInTransaction(
        tx,
        seedRecipientIds,
      );
      const activeLockedUserIds = new Set(
        lockedUsers
          .filter((lockedUser) => lockedUser.status === UserStatus.ACTIVE)
          .map((lockedUser) => lockedUser.id),
      );

      const planLock = await this.plans.lockPlanRowForShareInTransaction(
        tx,
        weddingPlanId,
      );
      if (planLock.length !== 1) {
        throw new NotFoundException("Wedding plan not found");
      }
      await this.permissions.lockPlanMembershipsForShareInTransaction(tx, [
        weddingPlanId,
      ]);

      const plan = await this.planWithNotifiedMembers(tx, weddingPlanId);
      if (!plan || plan.ownerUserId !== seed.ownerUserId) {
        throw new NotFoundException("Wedding plan not found");
      }
      if (plan.status !== WeddingPlanStatus.PLANNING) {
        return [];
      }

      const input = await inputFactory(tx);
      if (!input) return [];
      const scopedRecipients = recipientScopeFactory
        ? await recipientScopeFactory(tx, plan)
        : null;
      const excluded = new Set(excludedUserIds);
      const userIds = [
        ...new Set([
          plan.ownerUserId,
          ...plan.sharedMembers.map((member) => member.userId),
        ]),
      ]
        .filter(
          (userId) =>
            activeLockedUserIds.has(userId) &&
            !excluded.has(userId) &&
            (!scopedRecipients || scopedRecipients.has(userId)),
        )
        .sort();
      const notifications: NotificationResponse[] = [];
      for (const userId of userIds) {
        const dedupeKey = input.dedupeKey
          ? `${userId}:${input.dedupeKey}`
          : undefined;
        if (dedupeKey) {
          const existing = await this.repository.findByDedupeKey(tx, dedupeKey);
          if (existing) {
            notifications.push(this.toResponse(existing));
            continue;
          }
        }
        const created = await this.createNotificationInTransaction(tx, {
          ...input,
          userId,
          weddingPlanId,
          dedupeKey,
        });
        if (created) notifications.push(created);
      }
      return notifications;
    };

    try {
      return await runSerializableTransaction(this.prisma, operation);
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        return runSerializableTransaction(this.prisma, operation);
      }
      throw error;
    }
  }

  async notifyTaskDue(task: WeddingTask): Promise<void> {
    if (
      !task.dueDate ||
      task.status === WeddingTaskStatus.DONE ||
      task.status === WeddingTaskStatus.CANCELLED
    ) {
      return;
    }
    let lockedTask: WeddingTask | null = null;
    await this.createForPlanParticipantsAtomically(
      task.weddingPlanId,
      async (tx) => {
        // The task row is tasks': locked for share and re-read there.
        const currentTask = await this.tasks.lockTaskForShareInTransaction(
          tx,
          task.id,
          task.weddingPlanId,
        );
        if (!currentTask) return null;
        lockedTask = currentTask;
        return this.taskDueNotificationInput(currentTask);
      },
      [],
      async (tx, plan) =>
        this.taskDueRecipientIdsInTransaction(tx, plan, lockedTask),
    );
  }

  private async taskDueRecipientIdsInTransaction(
    tx: Prisma.TransactionClient,
    plan: {
      ownerUserId: string;
      sharedMembers: Array<{ userId: string; canManageTasks: boolean }>;
    },
    task: WeddingTask | null,
  ): Promise<ReadonlySet<string>> {
    const recipients = new Set([plan.ownerUserId]);
    if (!task) return recipients;
    const taskMembers = plan.sharedMembers.filter(
      (member) => member.canManageTasks,
    );
    if (taskMembers.length === 0) return recipients;
    // Who contributed to the task is collaboration's history, read through
    // its port on this transaction.
    const contributions = await this.scope.listQualifyingContributionsInTransaction(
      tx,
      [task.weddingPlanId],
      taskMembers.map((member) => member.userId),
      [
        {
          entityType: ContributionEntityType.TASK,
          actions: [ContributionAction.CREATED, ContributionAction.COMPLETED],
        },
      ],
    );
    const contributors = new Set(
      contributions
        .filter((contribution) => contribution.entityId === task.id)
        .map((contribution) => contribution.actorUserId),
    );
    for (const member of taskMembers) {
      if (
        task.assigneeUserId === member.userId ||
        contributors.has(member.userId)
      ) {
        recipients.add(member.userId);
      }
    }
    return recipients;
  }

  private taskDueNotificationInput(
    task: WeddingTask,
  ): PlanParticipantNotificationInput | null {
    if (
      !task.dueDate ||
      task.status === WeddingTaskStatus.DONE ||
      task.status === WeddingTaskStatus.CANCELLED
    ) {
      return null;
    }
    const today = startOfRiyadhDay();
    const dueWindowEnd = new Date(today);
    dueWindowEnd.setDate(dueWindowEnd.getDate() + 7);
    if (task.dueDate > endOfRiyadhDay(dueWindowEnd)) return null;

    const overdue = task.dueDate < today;
    const type = overdue
      ? NotificationType.TASK_OVERDUE
      : NotificationType.TASK_DUE_SOON;
    return {
      type,
      title: overdue ? "مهمة متأخرة" : "مهمة قريبة",
      body: `${task.title} - ${overdue ? "تجاوزت موعدها" : "تستحق قريباً"} (${this.formatDate(task.dueDate)}).`,
      data: {
        taskId: task.id,
        weddingPlanId: task.weddingPlanId,
        dueDate: task.dueDate.toISOString(),
      },
      priority: overdue
        ? NotificationPriority.HIGH
        : NotificationPriority.NORMAL,
      entityType: "task",
      entityId: task.id,
      routeTarget: `/wedding-plans/${task.weddingPlanId}/tasks`,
      dedupeKey: `${type}:task:${task.id}`,
    };
  }

  async generateDueNotifications(): Promise<number | null> {
    return this.prisma.$transaction(
      async (tx) => {
        const [lock] = await this.repository.tryLockDueScheduler(tx);
        if (!lock?.locked) return null;

        const today = startOfRiyadhDay();
        const dueWindowEnd = new Date(today);
        dueWindowEnd.setDate(dueWindowEnd.getDate() + 7);
        const dueWindowEndOfDay = endOfRiyadhDay(dueWindowEnd);
        // The planning plans and their notified members are planning's and
        // collaboration's rows, read through their ports on this
        // transaction (seed, then re-read under the row locks below).
        const plans = await this.plansWithNotifiedMembers(
          tx,
          await this.plans.listPlansInStatus(tx, WeddingPlanStatus.PLANNING),
        );
        if (plans.length === 0) return 0;

        const seedPlanIds = plans.map((plan) => plan.id).sort();
        const seedRecipientUserIds = [
          ...new Set(
            plans.flatMap((plan) => [
              plan.ownerUserId,
              ...plan.sharedMembers.map((member) => member.userId),
            ]),
          ),
        ].sort();
        const lockedUsers = await lockUserLifecycleRowsInTransaction(
          tx,
          seedRecipientUserIds,
        );
        const activeLockedUserIds = new Set(
          lockedUsers
            .filter((lockedUser) => lockedUser.status === UserStatus.ACTIVE)
            .map((lockedUser) => lockedUser.id),
        );
        await this.plans.lockPlanRowsForShareInTransaction(tx, seedPlanIds);
        await this.permissions.lockPlanMembershipsForShareInTransaction(
          tx,
          seedPlanIds,
        );

        const livePlans = await this.plansWithNotifiedMembers(
          tx,
          (await this.plans.getPlans(tx, seedPlanIds)).filter(
            (plan) => plan.status === WeddingPlanStatus.PLANNING,
          ),
        );
        const lockedPlans = livePlans
          .filter((plan) => activeLockedUserIds.has(plan.ownerUserId))
          .map((plan) => ({
            ...plan,
            sharedMembers: plan.sharedMembers.filter((member) =>
              activeLockedUserIds.has(member.userId),
            ),
          }));
        if (lockedPlans.length === 0) return 0;

        const planIds = lockedPlans.map((plan) => plan.id);
        const recipientUserIds = [
          ...new Set(
            lockedPlans.flatMap((plan) => [
              plan.ownerUserId,
              ...plan.sharedMembers.map((member) => member.userId),
            ]),
          ),
        ];
        // The due tasks and pending schedules are tasks' and finance's rows:
        // seeded, locked for share and re-read through their ports on this
        // transaction in the same order (tasks, costs, schedules).
        const dueTasks = { weddingPlanIds: planIds, dueBefore: dueWindowEndOfDay };
        const [taskSeeds, paymentScheduleSeeds] = await Promise.all([
          this.tasks.listDueTasks(tx, dueTasks),
          this.finance.listDuePaymentSchedules(tx, dueTasks),
        ]);
        const taskIds = taskSeeds.map((task) => task.id).sort();
        await this.tasks.lockTaskRowsForShareInTransaction(tx, taskIds);
        const costIds = [
          ...new Set(
            paymentScheduleSeeds.map((schedule) => schedule.weddingCostId),
          ),
        ].sort();
        await this.finance.lockCostRowsForShareInTransaction(tx, costIds);
        const scheduleIds = paymentScheduleSeeds
          .map((schedule) => schedule.id)
          .sort();
        await this.finance.lockPaymentScheduleRowsForShareInTransaction(
          tx,
          scheduleIds,
        );
        const [tasks, paymentSchedules, preferences] = await Promise.all([
          this.tasks.listDueTasks(tx, { ...dueTasks, taskIds }),
          this.finance.listDuePaymentSchedules(tx, { ...dueTasks, scheduleIds }),
          this.repository.dueReminderPreferences(tx, recipientUserIds),
        ]);
        // The provider a cost names is marketplace's row.
        const providerNames = new Map(
          (
            await this.providers.getProviders(tx, [
              ...new Set(
                paymentSchedules.flatMap((schedule) =>
                  schedule.weddingCost.providerId
                    ? [schedule.weddingCost.providerId]
                    : [],
                ),
              ),
            ])
          ).map((provider) => [provider.id, provider.businessName]),
        );

        // Who contributed to which task or cost is collaboration's history.
        const contributions = await this.scope.listQualifyingContributionsInTransaction(
          tx,
          planIds,
          recipientUserIds,
          [
            {
              entityType: ContributionEntityType.TASK,
              actions: [ContributionAction.CREATED, ContributionAction.COMPLETED],
            },
            {
              entityType: ContributionEntityType.WEDDING_COST,
              actions: [
                ContributionAction.CREATED,
                ContributionAction.COMPLETED,
                ContributionAction.PAYMENT_RECORDED,
              ],
            },
          ],
        );
        const contributedTaskIdsByRecipient = new Map<string, Set<string>>();
        const contributedCostIdsByRecipient = new Map<string, Set<string>>();
        for (const contribution of contributions) {
          const key = this.planRecipientScopeKey(
            contribution.weddingPlanId,
            contribution.actorUserId,
          );
          const target =
            contribution.entityType === ContributionEntityType.TASK
              ? contributedTaskIdsByRecipient
              : contributedCostIdsByRecipient;
          const ids = target.get(key) ?? new Set<string>();
          ids.add(contribution.entityId);
          target.set(key, ids);
        }

        const plansById = new Map(lockedPlans.map((plan) => [plan.id, plan]));
        const preferencesByUserId = new Map(
          preferences.map((preference) => [preference.userId, preference]),
        );
        const rows: DueNotificationRow[] = [];
        for (const task of tasks) {
          const plan = plansById.get(task.weddingPlanId);
          if (!plan || !task.dueDate) continue;
          const overdue = task.dueDate < today;
          const type = overdue
            ? NotificationType.TASK_OVERDUE
            : NotificationType.TASK_DUE_SOON;
          const recipients = new Set([
            plan.ownerUserId,
            ...plan.sharedMembers
              .filter((member) => {
                if (!member.canManageTasks) return false;
                if (task.assigneeUserId === member.userId) return true;
                return Boolean(
                  contributedTaskIdsByRecipient
                    .get(this.planRecipientScopeKey(plan.id, member.userId))
                    ?.has(task.id),
                );
              })
              .map((member) => member.userId),
          ]);
          for (const userId of recipients) {
            if (
              !this.preferenceEnabled(
                "taskRemindersEnabled",
                preferencesByUserId.get(userId),
              )
            ) {
              continue;
            }
            rows.push({
              userId,
              weddingPlanId: plan.id,
              type,
              priority: overdue
                ? NotificationPriority.HIGH
                : NotificationPriority.NORMAL,
              title: overdue ? "مهمة متأخرة" : "مهمة قريبة",
              body: `${task.title} - ${overdue ? "تجاوزت موعدها" : "تستحق قريباً"} (${this.formatDate(task.dueDate)}).`,
              data: {
                taskId: task.id,
                weddingPlanId: plan.id,
                dueDate: task.dueDate.toISOString(),
              },
              entityType: "task",
              entityId: task.id,
              routeTarget: `/wedding-plans/${plan.id}/tasks`,
              dedupeKey: `${userId}:${type}:task:${task.id}`,
            });
          }
        }

        for (const schedule of paymentSchedules) {
          const plan = plansById.get(schedule.weddingCost.weddingPlanId);
          if (!plan) continue;
          const overdue = schedule.dueDate < today;
          const type = overdue
            ? NotificationType.PAYMENT_SCHEDULE_OVERDUE
            : NotificationType.PAYMENT_SCHEDULE_DUE_SOON;
          const recipients = [
            plan.ownerUserId,
            ...plan.sharedMembers
              .filter(
                (member) =>
                  member.canViewMoney &&
                  contributedCostIdsByRecipient
                    .get(this.planRecipientScopeKey(plan.id, member.userId))
                    ?.has(schedule.weddingCostId) === true,
              )
              .map((member) => member.userId),
          ];
          for (const userId of new Set(recipients)) {
            if (
              !this.preferenceEnabled(
                "paymentRemindersEnabled",
                preferencesByUserId.get(userId),
              )
            ) {
              continue;
            }
            const isOwnerRecipient = userId === plan.ownerUserId;
            rows.push({
              userId,
              weddingPlanId: plan.id,
              type,
              priority: overdue
                ? NotificationPriority.HIGH
                : NotificationPriority.NORMAL,
              title: overdue ? "موعد دفع متأخر" : "موعد دفع قريب",
              body: isOwnerRecipient
                ? `${schedule.weddingCost.title} - دفعة بقيمة ${schedule.amount.toString()} ${overdue ? "متأخرة" : "تستحق قريباً"} (${this.formatDate(schedule.dueDate)}).`
                : `لديك موعد دفع ${overdue ? "متأخر" : "قريب"} (${this.formatDate(schedule.dueDate)}). افتح تبويب المال لعرض التفاصيل.`,
              data: {
                paymentScheduleId: schedule.id,
                weddingCostId: schedule.weddingCostId,
                weddingPlanId: plan.id,
                dueDate: schedule.dueDate.toISOString(),
                ...(isOwnerRecipient
                  ? {
                      partyName:
                        (schedule.weddingCost.providerId
                          ? providerNames.get(schedule.weddingCost.providerId)
                          : undefined) ?? schedule.weddingCost.partyName,
                    }
                  : {}),
              },
              entityType: "payment_schedule",
              entityId: schedule.id,
              routeTarget: `/wedding-plans/${plan.id}/money/costs/${schedule.weddingCostId}/schedules/${schedule.id}`,
              dedupeKey: `${userId}:${type}:payment-schedule:${schedule.id}`,
            });
          }
        }

        if (rows.length === 0) return 0;
        const created = await this.repository.createDueNotifications(tx, rows);
        for (const notification of created) {
          await this.enqueueNotificationDelivery(tx, notification);
        }
        return created.length;
      },
      { timeout: 120_000 },
    );
  }

  private preferenceKeyForType(
    type: NotificationType,
  ): keyof NotificationContentPreference | null {
    switch (type) {
      case NotificationType.TASK_DUE_SOON:
      case NotificationType.TASK_OVERDUE:
      case NotificationType.TASK_ASSIGNED:
        return "taskRemindersEnabled";
      case NotificationType.PAYMENT_SCHEDULE_DUE_SOON:
      case NotificationType.PAYMENT_SCHEDULE_OVERDUE:
        return "paymentRemindersEnabled";
      case NotificationType.QUOTE_REQUEST_SUBMITTED:
      case NotificationType.QUOTE_OFFER_RECEIVED:
      case NotificationType.QUOTE_ACCEPTED:
      case NotificationType.QUOTE_REJECTED:
      case NotificationType.CHAT_MESSAGE_RECEIVED:
        return "providerMessagesEnabled";
      default:
        return null;
    }
  }

  private preferenceEnabled(
    key: keyof NotificationContentPreference,
    preference: NotificationContentPreference | null | undefined,
  ): boolean {
    return preference?.[key] !== false;
  }

  private async enqueueNotificationDelivery(
    client: NotificationCreateClient,
    notification: Pick<Notification, "id" | "userId" | "type">,
  ): Promise<void> {
    await this.outbox.enqueue(client, {
      type: OutboxEventTypes.notificationCreated,
      aggregateType: "notification",
      aggregateId: notification.id,
      payload: {
        notificationId: notification.id,
        userId: notification.userId,
      },
    });
    if (!isPushNotificationType(notification.type)) return;
    await this.outbox.enqueue(client, {
      type: OutboxEventTypes.pushNotificationRequested,
      aggregateType: "notification",
      aggregateId: notification.id,
      payload: {
        notificationId: notification.id,
      },
    });
  }

  async purgeMoneyForMember(
    client: NotificationPurgeClient,
    userId: string,
    weddingPlanId: string,
  ): Promise<number> {
    const notifications = await this.repository.moneyNotificationIds(
      client, userId, weddingPlanId,
    );
    const ids = notifications.map((notification) => notification.id);
    if (ids.length === 0) return 0;

    // The pending deliveries are platform's outbox rows.
    await purgeOutboxEventsForAggregatesInTransaction(client, {
      notificationIds: ids,
      conversationIds: [],
    });
    const deleted = await this.repository.deleteNotificationIds(client, ids);
    return deleted.count;
  }

  async visibilityWhereForUser(
    userId: string,
    client: NotificationVisibilityClient = this.prisma,
  ): Promise<NotificationVisibilityWhere | null> {
    const provider = await this.findOwnedProviderLifecycle(userId, client);
    return this.notificationVisibilityWhere(userId, provider, client);
  }

  // The reader's plan access (ownership: planning; membership and its
  // flags: collaboration) is read once through the ports on the caller's
  // client and applied to the notification table by plan id. The three
  // where builders used to embed the same access as `weddingPlan: { is:
  // ... }` joins on planning's and collaboration's tables.
  private async notificationVisibilityWhere(
    userId: string,
    provider: OwnedProviderLifecycle,
    client: NotificationVisibilityClient,
  ): Promise<NotificationVisibilityWhere> {
    const [ownedPlanIds, memberships] = await Promise.all([
      this.plans.listOwnedPlanIds(client, userId),
      this.permissions.listMemberships(client, userId),
    ]);
    const providerVisibility =
      this.providerNotificationVisibilityWhere(provider);
    const visibility: NotificationVisibilityWhere["AND"] = [
      this.planNotificationVisibilityWhere(
        provider,
        [...new Set([...ownedPlanIds, ...memberships.map((member) => member.weddingPlanId)])],
      ),
      this.moneyNotificationVisibilityWhere([
        ...new Set([
          ...ownedPlanIds,
          ...memberships
            .filter((member) => member.canViewMoney || member.canManageMoney)
            .map((member) => member.weddingPlanId),
        ]),
      ]),
      await this.entityNotificationVisibilityWhere(
        client,
        userId,
        ownedPlanIds,
        memberships,
      ),
    ];
    if (providerVisibility) visibility.push(providerVisibility);
    return { AND: visibility };
  }

  private planNotificationVisibilityWhere(
    provider: OwnedProviderLifecycle,
    accessiblePlanIds: string[],
  ): PlanVisibilityWhere {
    const providerAudience = this.operationalProviderAudienceWhere(provider);
    return {
      OR: [
        { weddingPlanId: null },
        {
          type: NotificationType.SHARING_INVITATION,
          entityType: "plan_invite",
        },
        ...(providerAudience ? [providerAudience] : []),
        { weddingPlanId: { in: accessiblePlanIds } },
      ],
    };
  }

  private moneyNotificationVisibilityWhere(
    moneyPlanIds: string[],
  ): MoneyVisibilityWhere {
    const moneyTypes = [
      NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
      NotificationType.PAYMENT_SCHEDULE_OVERDUE,
    ];
    return {
      OR: [
        {
          AND: [
            { type: { notIn: moneyTypes } },
            {
              OR: [
                { entityType: null },
                { entityType: { not: "payment_schedule" } },
              ],
            },
          ],
        },
        { weddingPlanId: { in: moneyPlanIds } },
      ],
    };
  }

  private async entityNotificationVisibilityWhere(
    client: NotificationVisibilityClient,
    userId: string,
    ownedPlanIds: string[],
    memberships: ReadonlyArray<{
      weddingPlanId: string;
      canManageTasks: boolean;
      canViewMoney: boolean;
    }>,
  ): Promise<EntityVisibilityWhere> {
    const taskMemberships = memberships.filter(
      (member) => member.canManageTasks,
    );
    const moneyMemberships = memberships.filter((member) => member.canViewMoney);
    const relevantPlanIds = [
      ...new Set(
        [...taskMemberships, ...moneyMemberships].map(
          (member) => member.weddingPlanId,
        ),
      ),
    ];

    // The assigned tasks are tasks' rows, the contributions collaboration's.
    const [assignedTasks, contributions] = await Promise.all([
      this.tasks.listAssignedTasks(
        client,
        userId,
        taskMemberships.map((member) => member.weddingPlanId),
      ),
      this.scope.listQualifyingContributionsInTransaction(
        client,
        relevantPlanIds,
        [userId],
        [
          {
            entityType: ContributionEntityType.TASK,
            actions: [ContributionAction.CREATED, ContributionAction.COMPLETED],
          },
          {
            entityType: ContributionEntityType.WEDDING_COST,
            actions: [
              ContributionAction.CREATED,
              ContributionAction.COMPLETED,
              ContributionAction.PAYMENT_RECORDED,
            ],
          },
        ],
      ),
    ]);

    const taskIdsByPlan = new Map<string, Set<string>>();
    const costIdsByPlan = new Map<string, Set<string>>();
    for (const task of assignedTasks) {
      this.addScopedEntityId(taskIdsByPlan, task.weddingPlanId, task.id);
    }
    for (const contribution of contributions) {
      if (contribution.entityType === ContributionEntityType.TASK) {
        this.addScopedEntityId(
          taskIdsByPlan,
          contribution.weddingPlanId,
          contribution.entityId,
        );
      } else if (contribution.entityType === ContributionEntityType.WEDDING_COST) {
        this.addScopedEntityId(
          costIdsByPlan,
          contribution.weddingPlanId,
          contribution.entityId,
        );
      }
    }

    // The schedules of the contributed costs are finance's rows.
    const paymentSchedules = await this.finance.listPaymentScheduleIdsForCosts(
      client,
      [...costIdsByPlan.entries()].map(([weddingPlanId, ids]) => ({
        weddingPlanId,
        costIds: [...ids],
      })),
    );
    const scheduleIdsByPlan = new Map<string, Set<string>>();
    for (const schedule of paymentSchedules) {
      this.addScopedEntityId(
        scheduleIdsByPlan,
        schedule.weddingPlanId,
        schedule.id,
      );
    }

    const scopedClauses = (
      scopedMemberships: ReadonlyArray<{ weddingPlanId: string }>,
      idsByPlan: Map<string, Set<string>>,
    ): ScopedEntityClause[] =>
      scopedMemberships.flatMap((member) => {
        const ids = idsByPlan.get(member.weddingPlanId);
        if (!ids || ids.size === 0) return [];
        return [
          {
            AND: [
              { weddingPlanId: member.weddingPlanId },
              { entityId: { in: [...ids] } },
            ],
          },
        ];
      });

    return {
      OR: [
        { entityType: null },
        { entityType: { notIn: ["task", "payment_schedule"] } },
        {
          AND: [
            { entityType: "task" },
            {
              OR: [
                { weddingPlanId: { in: ownedPlanIds } },
                ...scopedClauses(taskMemberships, taskIdsByPlan),
              ],
            },
          ],
        },
        {
          AND: [
            { entityType: "payment_schedule" },
            {
              OR: [
                { weddingPlanId: { in: ownedPlanIds } },
                ...scopedClauses(moneyMemberships, scheduleIdsByPlan),
              ],
            },
          ],
        },
      ],
    };
  }

  /** A plan with the members that receive notifications (planning's and collaboration's rows through their ports). */
  private async planWithNotifiedMembers(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ) {
    const plan = await this.plans.getPlan(client, weddingPlanId);
    if (!plan) return null;
    const [withMembers] = await this.plansWithNotifiedMembers(client, [plan]);
    return withMembers;
  }

  private async plansWithNotifiedMembers<T extends { id: string }>(
    client: Prisma.TransactionClient,
    plans: T[],
  ): Promise<Array<T & { sharedMembers: SharedMember[] }>> {
    const members = await this.permissions.listPlanMembers(
      client,
      plans.map((plan) => plan.id),
    );
    return plans.map((plan) => ({
      ...plan,
      sharedMembers: members.filter(
        (member) =>
          member.weddingPlanId === plan.id && member.receiveNotifications,
      ),
    }));
  }

  private addScopedEntityId(
    target: Map<string, Set<string>>,
    weddingPlanId: string,
    entityId: string,
  ): void {
    const ids = target.get(weddingPlanId) ?? new Set<string>();
    ids.add(entityId);
    target.set(weddingPlanId, ids);
  }

  private planRecipientScopeKey(
    weddingPlanId: string,
    userId: string,
  ): string {
    return `${weddingPlanId}\u0000${userId}`;
  }

  private async lockOwnedForMutation(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<Notification> {
    const seed = await this.repository.findOwned(tx, id, currentUser.id);
    if (!seed) {
      throw new NotFoundException("Notification not found");
    }

    let canViewMoney = false;
    let provider: OwnedProviderLifecycle | undefined;
    let planContext: PlanAccessContext | null = null;
    const seedData = this.notificationData(seed);
    const seedDeclaresProviderAudience =
      seedData?.recipientAudience === "PROVIDER";
    if (
      seed.weddingPlanId &&
      !this.isPlanInviteNotification(seed) &&
      seedDeclaresProviderAudience
    ) {
      await assertActiveMutationActorInTransaction(tx, currentUser.id);
      provider = await this.lockOwnedProviderLifecycle(tx, currentUser.id);
      await this.assertProviderNotificationVisible(
        seed,
        currentUser.id,
        provider,
        tx,
      );
      if (!this.isOperationalProviderAudienceNotification(seed, provider)) {
        throw new NotFoundException("Notification not found");
      }
    } else if (seed.weddingPlanId) {
      if (this.isPlanInviteNotification(seed)) {
        await this.lockPlanInviteNotificationContext(
          tx,
          seed.weddingPlanId,
          currentUser,
        );
      } else {
        const context = await this.permissions.assertPlanReadableInTransaction(
          tx,
          seed.weddingPlanId,
          currentUser,
        );
        planContext = context;
        canViewMoney = this.permissions.canViewMoney(context);
        if (this.isMoneyNotification(seed) && !canViewMoney) {
          throw new NotFoundException("Notification not found");
        }
        await this.assertScopedEntityNotificationVisible(
          tx,
          context,
          currentUser.id,
          seed,
        );
      }
    } else {
      await assertActiveMutationActorInTransaction(tx, currentUser.id);
    }

    if (provider === undefined) {
      provider = await this.lockOwnedProviderLifecycle(tx, currentUser.id);
    }
    await this.lockNotificationRowsForUpdate(tx, [id]);
    const notification = await this.repository.findOwned(tx, id, currentUser.id);
    if (
      !notification ||
      notification.weddingPlanId !== seed.weddingPlanId ||
      this.isMoneyNotification(notification) !==
        this.isMoneyNotification(seed) ||
      this.isPlanInviteNotification(notification) !==
        this.isPlanInviteNotification(seed)
    ) {
      throw new NotFoundException("Notification not found");
    }

    await this.assertProviderNotificationVisible(
      notification,
      currentUser.id,
      provider,
      tx,
    );
    if (this.isMoneyNotification(notification) && !canViewMoney) {
      throw new NotFoundException("Notification not found");
    }
    if (planContext) {
      await this.assertScopedEntityNotificationVisible(
        tx,
        planContext,
        currentUser.id,
        notification,
      );
    }
    return notification;
  }

  private async lockPlanInviteNotificationContext(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<void> {
    // The plan is planning's row and the membership collaboration's:
    // read and locked through their ports in the lifecycle order.
    const seed = await this.plans.getPlan(tx, weddingPlanId);
    if (!seed) {
      throw new NotFoundException("Notification not found");
    }
    const users = await lockUserLifecycleRowsInTransaction(tx, [
      currentUser.id,
      seed.ownerUserId,
    ]);
    const actor = users.find((user) => user.id === currentUser.id);
    if (
      !actor ||
      actor.status !== UserStatus.ACTIVE ||
      !users.some((user) => user.id === seed.ownerUserId)
    ) {
      throw new NotFoundException("Notification not found");
    }
    const planLock = await this.plans.lockPlanRowForShareInTransaction(
      tx,
      weddingPlanId,
    );
    if (planLock.length !== 1) {
      throw new NotFoundException("Notification not found");
    }
    await this.permissions.lockMembershipsForShareInTransaction(
      tx,
      weddingPlanId,
      [currentUser.id],
    );
    const plan = await this.plans.getPlan(tx, weddingPlanId);
    if (!plan || plan.ownerUserId !== seed.ownerUserId) {
      throw new NotFoundException("Notification not found");
    }
  }

  private async lockAllPlanAccessForNotifications(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    weddingPlanId: string | null = null,
  ): Promise<string[]> {
    const notificationPlans = await this.repository.unreadPlanIds(
      tx, currentUser.id, weddingPlanId,
    );
    const planIds = [
      ...new Set([
        ...(weddingPlanId ? [weddingPlanId] : []),
        ...notificationPlans.flatMap((notification) =>
          notification.weddingPlanId ? [notification.weddingPlanId] : [],
        ),
      ]),
    ].sort();
    // The plans and the reader's memberships are planning's and
    // collaboration's rows: read and locked through their ports.
    const seedPlans = await this.plans.getPlans(tx, planIds);
    const lockedUsers = await lockUserLifecycleRowsInTransaction(tx, [
      currentUser.id,
      ...seedPlans.map((plan) => plan.ownerUserId),
    ]);
    const actor = lockedUsers.find(
      (lockedUser) => lockedUser.id === currentUser.id,
    );
    if (!actor || actor.status !== UserStatus.ACTIVE) {
      throw new NotFoundException("User not found");
    }
    if (planIds.length === 0) return [];

    await this.plans.lockPlanRowsForShareInTransaction(tx, planIds);
    await this.permissions.lockPlanMembershipsForShareInTransaction(tx, planIds);
    const livePlans = await this.plans.getPlans(tx, planIds);
    const memberPlanIds = new Set(
      (await this.permissions.listMemberships(tx, currentUser.id)).map(
        (membership) => membership.weddingPlanId,
      ),
    );
    const lockedUserIds = new Set(
      lockedUsers.map((lockedUser) => lockedUser.id),
    );
    return livePlans
      .filter(
        (plan) =>
          lockedUserIds.has(plan.ownerUserId) &&
          (plan.ownerUserId === currentUser.id || memberPlanIds.has(plan.id)),
      )
      .map((plan) => plan.id)
      .sort();
  }

  private async lockOwnedProviderLifecycle(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<OwnedProviderLifecycle> {
    // The provider row is marketplace's: locked for share and read there.
    return this.providers.lockOwnedProviderForShareInTransaction(tx, userId);
  }

  private async lockNotificationRowsForUpdate(
    tx: Prisma.TransactionClient,
    notificationIds: readonly string[],
  ): Promise<void> {
    const ids = [...new Set(notificationIds)].sort();
    if (ids.length === 0) return;
    await this.repository.lockRowsForUpdate(tx, ids);
  }

  private isMoneyNotification(
    notification: Pick<Notification, "entityType" | "type">,
  ): boolean {
    return (
      notification.entityType === "payment_schedule" ||
      notification.type === NotificationType.PAYMENT_SCHEDULE_DUE_SOON ||
      notification.type === NotificationType.PAYMENT_SCHEDULE_OVERDUE
    );
  }

  private isPlanInviteNotification(
    notification: Pick<Notification, "entityType" | "type">,
  ): boolean {
    return (
      notification.type === NotificationType.SHARING_INVITATION &&
      notification.entityType === "plan_invite"
    );
  }

  private async assertScopedEntityNotificationVisible(
    client: NotificationVisibilityClient,
    context: PlanAccessContext,
    userId: string,
    notification: Pick<Notification, "entityType" | "entityId" | "weddingPlanId">,
  ): Promise<void> {
    if (context.isOwner) return;
    const weddingPlanId = notification.weddingPlanId;
    const entityId = notification.entityId;
    if (!weddingPlanId || !entityId) {
      if (
        notification.entityType === "task" ||
        notification.entityType === "payment_schedule"
      ) {
        throw new NotFoundException("Notification not found");
      }
      return;
    }

    if (notification.entityType === "task") {
      if (!this.permissions.canManageTasks(context)) {
        throw new NotFoundException("Notification not found");
      }
      const contributedTaskIds = await this.qualifyingContributionEntityIds(
        client,
        weddingPlanId,
        userId,
        ContributionEntityType.TASK,
        [ContributionAction.CREATED, ContributionAction.COMPLETED],
      );
      // Whether the task is assigned to or contributed by the reader is
      // tasks' row.
      if (
        !(await this.tasks.isTaskVisibleToContributor(
          client,
          weddingPlanId,
          entityId,
          userId,
          contributedTaskIds,
        ))
      ) {
        throw new NotFoundException("Notification not found");
      }
      return;
    }

    if (notification.entityType === "payment_schedule") {
      if (!this.permissions.canViewMoney(context)) {
        throw new NotFoundException("Notification not found");
      }
      const contributedCostIds = await this.qualifyingContributionEntityIds(
        client,
        weddingPlanId,
        userId,
        ContributionEntityType.WEDDING_COST,
        [
          ContributionAction.CREATED,
          ContributionAction.COMPLETED,
          ContributionAction.PAYMENT_RECORDED,
        ],
      );
      if (contributedCostIds.length === 0) {
        throw new NotFoundException("Notification not found");
      }
      // Whether the schedule belongs to a contributed cost is finance's row.
      if (
        !(await this.finance.isPaymentScheduleOfCosts(
          client,
          weddingPlanId,
          entityId,
          contributedCostIds,
        ))
      ) {
        throw new NotFoundException("Notification not found");
      }
    }
  }

  /** The reader's qualifying contributions in the plan: collaboration's history, matched by the actor's reference as every other scope is. */
  private qualifyingContributionEntityIds(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    entityType: ContributionEntityType,
    actions: readonly ContributionAction[],
  ): Promise<string[]> {
    return this.scope.qualifyingEntityIdsInTransaction(
      client,
      weddingPlanId,
      userId,
      [entityType],
      actions,
    );
  }

  private async findOwnedOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
    client: Prisma.TransactionClient,
  ): Promise<Notification> {
    const [notification, provider] = await Promise.all([
      this.repository.findOwned(client, id, currentUser.id),
      this.findOwnedProviderLifecycle(currentUser.id, client),
    ]);

    if (!notification) {
      throw new NotFoundException("Notification not found");
    }

    await this.assertProviderNotificationVisible(
      notification,
      currentUser.id,
      provider,
      client,
    );
    if (
      this.isOperationalProviderAudienceNotification(notification, provider)
    ) {
      return notification;
    }

    if (
      notification.weddingPlanId &&
      !this.isPlanInviteNotification(notification)
    ) {
      const context = await this.permissions.assertPlanReadableInTransaction(
        client,
        notification.weddingPlanId,
        currentUser,
      );
      if (
        this.isMoneyNotification(notification) &&
        !this.permissions.canViewMoney(context)
      ) {
        throw new NotFoundException("Notification not found");
      }
      await this.assertScopedEntityNotificationVisible(
        client,
        context,
        currentUser.id,
        notification,
      );
    } else if (this.isMoneyNotification(notification)) {
      throw new NotFoundException("Notification not found");
    }

    return notification;
  }

  private async findOwnedProviderLifecycle(
    userId: string,
    client: NotificationVisibilityClient = this.prisma,
  ): Promise<OwnedProviderLifecycle> {
    // The provider row is marketplace's, read through its port.
    return this.providers.getProviderByUserId(client, userId);
  }

  private providerNotificationVisibilityWhere(
    provider: OwnedProviderLifecycle,
  ): ProviderVisibilityWhere | null {
    if (isProviderOperational(provider)) return null;

    const visibility: ProviderVisibilityWhere["AND"] = [
      {
        NOT: {
          AND: [
            {
              data: {
                path: ["recipientAudience"],
                not: Prisma.AnyNull,
              },
            },
            {
              data: {
                path: ["recipientAudience"],
                equals: "PROVIDER",
              },
            },
          ],
        },
      },
      {
        NOT: {
          AND: [
            { entityType: { not: null } },
            { routeTarget: { not: null } },
            { entityType: "quote_request" },
            { routeTarget: PROVIDER_PORTAL_ROUTE },
          ],
        },
      },
    ];
    if (provider) {
      visibility.push({
        NOT: {
          AND: [
            { type: NotificationType.CHAT_MESSAGE_RECEIVED },
            { entityType: { not: null } },
            { entityType: "conversation" },
            {
              data: {
                path: ["providerId"],
                not: Prisma.AnyNull,
              },
            },
            {
              data: {
                path: ["providerId"],
                equals: provider.id,
              },
            },
          ],
        },
      });
    }

    return { AND: visibility };
  }

  private operationalProviderAudienceWhere(
    provider: OwnedProviderLifecycle,
  ): ProviderAudienceWhere | null {
    if (!provider || !isProviderOperational(provider)) return null;
    return {
      AND: [
        {
          data: {
            path: ["recipientAudience"],
            equals: "PROVIDER",
          },
        },
        {
          data: {
            path: ["providerId"],
            equals: provider.id,
          },
        },
      ],
    };
  }

  private isOperationalProviderAudienceNotification(
    notification: Notification,
    provider: OwnedProviderLifecycle,
  ): boolean {
    if (!provider || !isProviderOperational(provider)) return false;
    const data = this.notificationData(notification);
    return (
      !this.isMoneyNotification(notification) &&
      data?.recipientAudience === "PROVIDER" &&
      data.providerId === provider.id
    );
  }

  private async assertProviderNotificationVisible(
    notification: Notification,
    currentUserId: string,
    provider: OwnedProviderLifecycle,
    client: NotificationVisibilityClient = this.prisma,
  ): Promise<void> {
    const data = this.notificationData(notification);
    const explicitProviderAudience = data?.recipientAudience === "PROVIDER";
    if (explicitProviderAudience) {
      if (!provider || data.providerId !== provider.id) {
        throw new NotFoundException("Notification not found");
      }
      assertProviderOperational(provider);
      return;
    }
    if (isProviderOperational(provider)) return;

    const legacyProviderQuote =
      notification.entityType === "quote_request" &&
      notification.routeTarget === PROVIDER_PORTAL_ROUTE;
    let legacyProviderChat =
      notification.type === NotificationType.CHAT_MESSAGE_RECEIVED &&
      notification.entityType === "conversation" &&
      provider !== null &&
      data?.providerId === provider.id;

    if (
      !legacyProviderChat &&
      notification.type === NotificationType.CHAT_MESSAGE_RECEIVED &&
      notification.entityType === "conversation" &&
      notification.entityId
    ) {
      // The conversation is messaging's row and its provider marketplace's.
      const conversationProviderId =
        await this.conversations.findConversationProviderId(
          client,
          notification.entityId,
        );
      const conversationProvider = conversationProviderId
        ? await this.providers.getProvider(client, conversationProviderId)
        : null;
      if (conversationProvider?.userId === currentUserId) {
        legacyProviderChat = true;
        assertProviderOperational(conversationProvider);
      }
    }

    if (explicitProviderAudience || legacyProviderQuote || legacyProviderChat) {
      assertProviderOperational(provider);
    }
  }

  private notificationData(
    notification: Notification,
  ): Record<string, unknown> | null {
    return notification.data &&
      typeof notification.data === "object" &&
      !Array.isArray(notification.data)
      ? (notification.data as Record<string, unknown>)
      : null;
  }

  private optionalText(value: string | undefined): string | null {
    const trimmed = value?.trim() ?? "";
    return trimmed || null;
  }

  private positiveInteger(value: string, field: string): number {
    if (!/^\d+$/.test(value)) {
      throw new BadRequestException(`${field} must be a positive integer`);
    }
    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed < 1) {
      throw new BadRequestException(`${field} must be a positive integer`);
    }
    return parsed;
  }

  private formatDate(date: Date | null): string {
    if (!date) return "بدون تاريخ";
    return `${date.getUTCDate()}/${date.getUTCMonth() + 1}/${date.getUTCFullYear()}`;
  }

  private toResponse(notification: Notification): NotificationResponse {
    return {
      id: notification.id,
      userId: notification.userId,
      weddingPlanId: notification.weddingPlanId,
      type: notification.type,
      priority: notification.priority,
      title: notification.title,
      body: notification.body,
      entityType: notification.entityType,
      entityId: notification.entityId,
      routeTarget: notification.routeTarget,
      data: notification.data,
      readAt: notification.readAt,
      archivedAt: notification.archivedAt,
      createdAt: notification.createdAt,
      updatedAt: notification.updatedAt,
    };
  }
}
