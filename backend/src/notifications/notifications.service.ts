import {
  BadRequestException,
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
  UserStatus,
  WeddingPlanStatus,
  WeddingTask,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { endOfRiyadhDay, startOfRiyadhDay } from "../common/time/business-day";
import { PrismaService } from "../platform/database/prisma.service";
import { OutboxEventTypes } from "../outbox/outbox.constants";
import { OutboxService } from "../outbox/outbox.service";
import {
  assertProviderOperational,
  isProviderOperational,
  PROVIDER_PORTAL_ROUTE,
} from "../provider-dashboard/provider-access-policy";
import {
  PermissionService,
  PlanAccessContext,
} from "../sharing/permission.service";
import { isPushNotificationType } from "../push/push-notification.policy";
import {
  assertActiveMutationActorInTransaction,
  lockUserLifecycleRowsInTransaction,
} from "../users/user-lifecycle-lock";

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

type NotificationPurgeClient = Pick<
  Prisma.TransactionClient,
  "notification" | "outboxEvent"
>;

type NotificationCreateClient = Pick<
  Prisma.TransactionClient,
  "$queryRaw" | "notification" | "notificationPreference" | "outboxEvent"
>;

type NotificationContentPreference = Pick<
  NotificationPreference,
  "taskRemindersEnabled" | "paymentRemindersEnabled" | "providerMessagesEnabled"
>;

type OwnedProviderLifecycle = {
  id: string;
  status: ProviderStatus;
} | null;

type NotificationVisibilityClient = Pick<
  Prisma.TransactionClient,
  | "conversation"
  | "contributionEvent"
  | "notification"
  | "paymentSchedule"
  | "provider"
  | "sharedMember"
  | "weddingTask"
>;

@Injectable()
export class NotificationsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly outbox: OutboxService,
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
        const where: Prisma.NotificationWhereInput = {
          userId: currentUser.id,
          archivedAt: null,
          ...(type ? { type } : {}),
          ...(unreadOnly ? { readAt: null } : {}),
          ...(planId ? { weddingPlanId: planId } : {}),
          AND: visibility,
        };
        const [count, rows] = await Promise.all([
          tx.notification.count({ where }),
          tx.notification.findMany({
            where,
            orderBy: [{ createdAt: "desc" }, { id: "desc" }],
            skip: (page - 1) * limit,
            take: limit,
          }),
        ]);
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
      return tx.notification.count({
        where: {
          userId: currentUser.id,
          readAt: null,
          archivedAt: null,
          ...(planId ? { weddingPlanId: planId } : {}),
          AND: visibility,
        },
      });
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

      const notification = await tx.notification.update({
        where: { id },
        data: { readAt: new Date() },
      });
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
        !(await tx.notification.findFirst({
          where: {
            userId: currentUser.id,
            weddingPlanId: planId,
            OR: [
              {
                type: NotificationType.SHARING_INVITATION,
                entityType: "plan_invite",
              },
              ...(providerAudience ? [providerAudience] : []),
            ],
          },
          select: { id: true },
        }))
      ) {
        throw new NotFoundException("Wedding plan not found");
      }
      const visibility = await this.notificationVisibilityWhere(
        currentUser.id,
        provider,
        tx,
      );
      const planVisibility: Prisma.NotificationWhereInput = planId
        ? { weddingPlanId: planId }
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
      const where: Prisma.NotificationWhereInput = {
        userId: currentUser.id,
        readAt: null,
        archivedAt: null,
        AND: [planVisibility, visibility],
      };
      const seed = await tx.notification.findMany({
        where,
        select: { id: true },
      });
      const ids = seed.map((notification) => notification.id).sort();
      if (ids.length === 0) return { updated: 0 };

      await this.lockNotificationRowsForUpdate(tx, ids);
      const stillVisible = await tx.notification.findMany({
        where: {
          ...where,
          id: { in: ids },
        },
        select: { id: true },
      });
      const visibleIds = stillVisible
        .map((notification) => notification.id)
        .sort();
      if (visibleIds.length === 0) return { updated: 0 };

      const result = await tx.notification.updateMany({
        where: { id: { in: visibleIds } },
        data: { readAt: new Date() },
      });
      return { updated: result.count };
    });
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      await this.lockOwnedForMutation(tx, currentUser, id);
      await tx.notification.delete({ where: { id } });
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
      const notification = await tx.notification.update({
        where: { id },
        data: {
          archivedAt: now,
          readAt: existing.readAt ?? now,
        },
      });
      return this.toResponse(notification);
    });
  }

  async createNotification(
    input: CreateNotificationInput,
  ): Promise<NotificationResponse | null> {
    if (input.dedupeKey) {
      const existing = await this.prisma.notification.findUnique({
        where: { dedupeKey: input.dedupeKey },
      });
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
        const existing = await this.prisma.notification.findUnique({
          where: { dedupeKey: input.dedupeKey },
        });
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
      const recipient = await client.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "User"
          WHERE "id" = ${input.userId}
          FOR SHARE
        `,
      );
      if (recipient.length !== 1) {
        throw new NotFoundException("Notification recipient not found");
      }
      const preference = await client.notificationPreference.findUnique({
        where: { userId: input.userId },
        select: {
          taskRemindersEnabled: true,
          paymentRemindersEnabled: true,
          providerMessagesEnabled: true,
        },
      });
      if (!this.preferenceEnabled(preferenceKey, preference)) {
        return null;
      }
    }

    const created = await client.notification.create({
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
    await this.enqueueNotificationDelivery(client, created);
    return this.toResponse(created);
  }

  async resolveProviderUpdateRecipientInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string | null,
    requestedUserId: string,
  ): Promise<string> {
    if (!weddingPlanId) return requestedUserId;

    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "userId" = ${requestedUserId}
        FOR SHARE
      `,
    );
    const plan = await tx.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      select: {
        ownerUserId: true,
        sharedMembers: {
          where: { userId: requestedUserId },
          select: { canManageProviders: true },
        },
      },
    });
    if (!plan) throw new NotFoundException("Wedding plan not found");
    if (plan.ownerUserId === requestedUserId) return requestedUserId;
    return plan.sharedMembers[0]?.canManageProviders
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
      const seed = await tx.weddingPlan.findUnique({
        where: { id: weddingPlanId },
        select: {
          ownerUserId: true,
          sharedMembers: {
            where: { receiveNotifications: true },
            select: { userId: true, canManageTasks: true },
          },
        },
      });
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

      const planLock = await tx.$queryRaw<Array<{ id: string }>>(
        Prisma.sql`
          SELECT "id"
          FROM "WeddingPlan"
          WHERE "id" = ${weddingPlanId}
          FOR SHARE
        `,
      );
      if (planLock.length !== 1) {
        throw new NotFoundException("Wedding plan not found");
      }
      await tx.$queryRaw(
        Prisma.sql`
          SELECT "id"
          FROM "SharedMember"
          WHERE "weddingPlanId" = ${weddingPlanId}
          ORDER BY "id" ASC
          FOR SHARE
        `,
      );

      const plan = await tx.weddingPlan.findUnique({
        where: { id: weddingPlanId },
        select: {
          ownerUserId: true,
          status: true,
          sharedMembers: {
            where: { receiveNotifications: true },
            select: { userId: true, canManageTasks: true },
          },
        },
      });
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
          const existing = await tx.notification.findUnique({
            where: { dedupeKey },
          });
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
        const taskLock = await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT "id"
            FROM "WeddingTask"
            WHERE "id" = ${task.id}
              AND "weddingPlanId" = ${task.weddingPlanId}
            FOR SHARE
          `,
        );
        if (taskLock.length !== 1) return null;
        const currentTask = await tx.weddingTask.findUnique({
          where: { id: task.id },
        });
        if (!currentTask || currentTask.weddingPlanId !== task.weddingPlanId) {
          return null;
        }
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
    const events = await tx.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId: task.weddingPlanId },
        contributorTenure: {
          actorUserId: { in: taskMembers.map((member) => member.userId) },
        },
        entityType: ContributionEntityType.TASK,
        entityId: task.id,
        action: {
          in: [ContributionAction.CREATED, ContributionAction.COMPLETED],
        },
      },
      select: {
        contributorTenure: { select: { actorUserId: true } },
      },
    });
    const contributors = new Set(
      events.flatMap((event) =>
        event.contributorTenure.actorUserId
          ? [event.contributorTenure.actorUserId]
          : [],
      ),
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
        const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
          SELECT pg_try_advisory_xact_lock(20260711, 3) AS locked
        `;
        if (!lock?.locked) return null;

        const today = startOfRiyadhDay();
        const dueWindowEnd = new Date(today);
        dueWindowEnd.setDate(dueWindowEnd.getDate() + 7);
        const dueWindowEndOfDay = endOfRiyadhDay(dueWindowEnd);
        const plans = await tx.weddingPlan.findMany({
          where: { status: WeddingPlanStatus.PLANNING },
          include: {
            sharedMembers: { where: { receiveNotifications: true } },
          },
        });
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
        await tx.$queryRaw(
          Prisma.sql`
            SELECT "id"
            FROM "WeddingPlan"
            WHERE "id" IN (${Prisma.join(seedPlanIds)})
            ORDER BY "id" ASC
            FOR SHARE
          `,
        );
        await tx.$queryRaw(
          Prisma.sql`
            SELECT "id"
            FROM "SharedMember"
            WHERE "weddingPlanId" IN (${Prisma.join(seedPlanIds)})
            ORDER BY "weddingPlanId" ASC, "id" ASC
            FOR SHARE
          `,
        );

        const livePlans = await tx.weddingPlan.findMany({
          where: {
            id: { in: seedPlanIds },
            status: WeddingPlanStatus.PLANNING,
          },
          include: {
            sharedMembers: { where: { receiveNotifications: true } },
          },
        });
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
        const [taskSeeds, paymentScheduleSeeds] = await Promise.all([
          tx.weddingTask.findMany({
            where: {
              weddingPlanId: { in: planIds },
              dueDate: { not: null, lte: dueWindowEndOfDay },
              status: {
                notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
              },
            },
          }),
          tx.paymentSchedule.findMany({
            where: {
              dueDate: { lte: dueWindowEndOfDay },
              status: PaymentScheduleStatus.PENDING,
              weddingCost: {
                weddingPlanId: { in: planIds },
                status: { not: "CANCELLED" },
              },
            },
            include: {
              weddingCost: {
                select: {
                  weddingPlanId: true,
                  title: true,
                  partyName: true,
                  provider: { select: { businessName: true } },
                },
              },
            },
          }),
        ]);
        const taskIds = taskSeeds.map((task) => task.id).sort();
        if (taskIds.length > 0) {
          await tx.$queryRaw(
            Prisma.sql`
              SELECT "id"
              FROM "WeddingTask"
              WHERE "id" IN (${Prisma.join(taskIds)})
              ORDER BY "id" ASC
              FOR SHARE
            `,
          );
        }
        const costIds = [
          ...new Set(
            paymentScheduleSeeds.map((schedule) => schedule.weddingCostId),
          ),
        ].sort();
        if (costIds.length > 0) {
          await tx.$queryRaw(
            Prisma.sql`
              SELECT "id"
              FROM "WeddingCost"
              WHERE "id" IN (${Prisma.join(costIds)})
              ORDER BY "id" ASC
              FOR SHARE
            `,
          );
        }
        const scheduleIds = paymentScheduleSeeds
          .map((schedule) => schedule.id)
          .sort();
        if (scheduleIds.length > 0) {
          await tx.$queryRaw(
            Prisma.sql`
              SELECT "id"
              FROM "PaymentSchedule"
              WHERE "id" IN (${Prisma.join(scheduleIds)})
              ORDER BY "id" ASC
              FOR SHARE
            `,
          );
        }
        const [tasks, paymentSchedules, preferences] = await Promise.all([
          taskIds.length === 0
            ? Promise.resolve([])
            : tx.weddingTask.findMany({
                where: {
                  id: { in: taskIds },
                  weddingPlanId: { in: planIds },
                  dueDate: { not: null, lte: dueWindowEndOfDay },
                  status: {
                    notIn: [
                      WeddingTaskStatus.DONE,
                      WeddingTaskStatus.CANCELLED,
                    ],
                  },
                },
              }),
          scheduleIds.length === 0
            ? Promise.resolve([])
            : tx.paymentSchedule.findMany({
                where: {
                  id: { in: scheduleIds },
                  dueDate: { lte: dueWindowEndOfDay },
                  status: PaymentScheduleStatus.PENDING,
                  weddingCost: {
                    weddingPlanId: { in: planIds },
                    status: { not: "CANCELLED" },
                  },
                },
                include: {
                  weddingCost: {
                    select: {
                      weddingPlanId: true,
                      title: true,
                      partyName: true,
                      provider: { select: { businessName: true } },
                    },
                  },
                },
              }),
          tx.notificationPreference.findMany({
            where: { userId: { in: recipientUserIds } },
            select: {
              userId: true,
              taskRemindersEnabled: true,
              paymentRemindersEnabled: true,
              providerMessagesEnabled: true,
            },
          }),
        ]);

        const contributorEvents = await tx.contributionEvent.findMany({
          where: {
            historyScope: { weddingPlanId: { in: planIds } },
            contributorTenure: {
              actorUserId: { in: recipientUserIds },
            },
            entityId: { not: null },
            OR: [
              {
                entityType: ContributionEntityType.TASK,
                action: {
                  in: [
                    ContributionAction.CREATED,
                    ContributionAction.COMPLETED,
                  ],
                },
              },
              {
                entityType: ContributionEntityType.WEDDING_COST,
                action: {
                  in: [
                    ContributionAction.CREATED,
                    ContributionAction.COMPLETED,
                    ContributionAction.PAYMENT_RECORDED,
                  ],
                },
              },
            ],
          },
          select: {
            entityId: true,
            entityType: true,
            historyScope: { select: { weddingPlanId: true } },
            contributorTenure: { select: { actorUserId: true } },
          },
        });
        const contributedTaskIdsByRecipient = new Map<string, Set<string>>();
        const contributedCostIdsByRecipient = new Map<string, Set<string>>();
        for (const event of contributorEvents) {
          if (
            !event.entityId ||
            !event.historyScope.weddingPlanId ||
            !event.contributorTenure.actorUserId
          ) {
            continue;
          }
          const key = this.planRecipientScopeKey(
            event.historyScope.weddingPlanId,
            event.contributorTenure.actorUserId,
          );
          const target =
            event.entityType === ContributionEntityType.TASK
              ? contributedTaskIdsByRecipient
              : contributedCostIdsByRecipient;
          const ids = target.get(key) ?? new Set<string>();
          ids.add(event.entityId);
          target.set(key, ids);
        }

        const plansById = new Map(lockedPlans.map((plan) => [plan.id, plan]));
        const preferencesByUserId = new Map(
          preferences.map((preference) => [preference.userId, preference]),
        );
        const rows: Prisma.NotificationCreateManyInput[] = [];
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
                        schedule.weddingCost.provider?.businessName ??
                        schedule.weddingCost.partyName,
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
        const created = await tx.notification.createManyAndReturn({
          data: rows,
          skipDuplicates: true,
        });
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
    const notifications = await client.notification.findMany({
      where: {
        userId,
        weddingPlanId,
        entityType: "payment_schedule",
      },
      select: { id: true },
    });
    const ids = notifications.map((notification) => notification.id);
    if (ids.length === 0) return 0;

    await client.outboxEvent.deleteMany({
      where: {
        aggregateType: "notification",
        aggregateId: { in: ids },
      },
    });
    const deleted = await client.notification.deleteMany({
      where: { id: { in: ids } },
    });
    return deleted.count;
  }

  async visibilityWhereForUser(
    userId: string,
    client: NotificationVisibilityClient = this.prisma,
  ): Promise<Prisma.NotificationWhereInput | null> {
    const provider = await this.findOwnedProviderLifecycle(userId, client);
    return this.notificationVisibilityWhere(userId, provider, client);
  }

  private async notificationVisibilityWhere(
    userId: string,
    provider: OwnedProviderLifecycle,
    client: NotificationVisibilityClient,
  ): Promise<Prisma.NotificationWhereInput> {
    const providerVisibility =
      this.providerNotificationVisibilityWhere(provider);
    const visibility = [
      this.planNotificationVisibilityWhere(userId, provider),
      this.moneyNotificationVisibilityWhere(userId),
      await this.entityNotificationVisibilityWhere(client, userId),
    ];
    if (providerVisibility) visibility.push(providerVisibility);
    return { AND: visibility };
  }

  private planNotificationVisibilityWhere(
    userId: string,
    provider: OwnedProviderLifecycle,
  ): Prisma.NotificationWhereInput {
    const providerAudience = this.operationalProviderAudienceWhere(provider);
    return {
      OR: [
        { weddingPlanId: null },
        {
          type: NotificationType.SHARING_INVITATION,
          entityType: "plan_invite",
        },
        ...(providerAudience ? [providerAudience] : []),
        {
          weddingPlan: {
            is: {
              OR: [
                { ownerUserId: userId },
                {
                  sharedMembers: {
                    some: { userId },
                  },
                },
              ],
            },
          },
        },
      ],
    };
  }

  private moneyNotificationVisibilityWhere(
    userId: string,
  ): Prisma.NotificationWhereInput {
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
        {
          weddingPlan: {
            is: {
              OR: [
                { ownerUserId: userId },
                {
                  sharedMembers: {
                    some: {
                      userId,
                      OR: [
                        { canViewMoney: true },
                        { canManageMoney: true },
                      ],
                    },
                  },
                },
              ],
            },
          },
        },
      ],
    };
  }

  private async entityNotificationVisibilityWhere(
    client: NotificationVisibilityClient,
    userId: string,
  ): Promise<Prisma.NotificationWhereInput> {
    const memberships = await client.sharedMember.findMany({
      where: { userId },
      select: {
        weddingPlanId: true,
        canManageTasks: true,
        canViewMoney: true,
      },
    });
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

    const [assignedTasks, events] = await Promise.all([
      taskMemberships.length === 0
        ? Promise.resolve([])
        : client.weddingTask.findMany({
            where: {
              weddingPlanId: {
                in: taskMemberships.map((member) => member.weddingPlanId),
              },
              assigneeUserId: userId,
            },
            select: { id: true, weddingPlanId: true },
          }),
      relevantPlanIds.length === 0
        ? Promise.resolve([])
        : client.contributionEvent.findMany({
            where: {
              historyScope: { weddingPlanId: { in: relevantPlanIds } },
              contributorTenure: { actorUserId: userId },
              entityId: { not: null },
              OR: [
                {
                  entityType: ContributionEntityType.TASK,
                  action: {
                    in: [
                      ContributionAction.CREATED,
                      ContributionAction.COMPLETED,
                    ],
                  },
                },
                {
                  entityType: ContributionEntityType.WEDDING_COST,
                  action: {
                    in: [
                      ContributionAction.CREATED,
                      ContributionAction.COMPLETED,
                      ContributionAction.PAYMENT_RECORDED,
                    ],
                  },
                },
              ],
            },
            select: {
              entityId: true,
              entityType: true,
              historyScope: { select: { weddingPlanId: true } },
            },
          }),
    ]);

    const taskIdsByPlan = new Map<string, Set<string>>();
    const costIdsByPlan = new Map<string, Set<string>>();
    for (const task of assignedTasks) {
      this.addScopedEntityId(taskIdsByPlan, task.weddingPlanId, task.id);
    }
    for (const event of events) {
      if (!event.entityId || !event.historyScope.weddingPlanId) continue;
      if (event.entityType === ContributionEntityType.TASK) {
        this.addScopedEntityId(
          taskIdsByPlan,
          event.historyScope.weddingPlanId,
          event.entityId,
        );
      } else if (event.entityType === ContributionEntityType.WEDDING_COST) {
        this.addScopedEntityId(
          costIdsByPlan,
          event.historyScope.weddingPlanId,
          event.entityId,
        );
      }
    }

    const costClauses = [...costIdsByPlan.entries()].flatMap(
      ([weddingPlanId, ids]) =>
        ids.size === 0
          ? []
          : [
              {
                weddingCost: {
                  weddingPlanId,
                  id: { in: [...ids] },
                },
              },
            ],
    );
    const paymentSchedules =
      costClauses.length === 0
        ? []
        : await client.paymentSchedule.findMany({
            where: { OR: costClauses },
            select: {
              id: true,
              weddingCost: { select: { weddingPlanId: true } },
            },
          });
    const scheduleIdsByPlan = new Map<string, Set<string>>();
    for (const schedule of paymentSchedules) {
      this.addScopedEntityId(
        scheduleIdsByPlan,
        schedule.weddingCost.weddingPlanId,
        schedule.id,
      );
    }

    const taskClauses = taskMemberships.flatMap((member) => {
      const ids = taskIdsByPlan.get(member.weddingPlanId);
      if (!ids || ids.size === 0) return [];
      return [
        {
          AND: [
            { weddingPlanId: member.weddingPlanId },
            { entityId: { in: [...ids] } },
            {
              weddingPlan: {
                is: {
                  sharedMembers: {
                    some: { userId, canManageTasks: true },
                  },
                },
              },
            },
          ],
        },
      ];
    });
    const paymentClauses = moneyMemberships.flatMap((member) => {
      const ids = scheduleIdsByPlan.get(member.weddingPlanId);
      if (!ids || ids.size === 0) return [];
      return [
        {
          AND: [
            { weddingPlanId: member.weddingPlanId },
            { entityId: { in: [...ids] } },
            {
              weddingPlan: {
                is: {
                  sharedMembers: {
                    some: { userId, canViewMoney: true },
                  },
                },
              },
            },
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
                { weddingPlan: { is: { ownerUserId: userId } } },
                ...taskClauses,
              ],
            },
          ],
        },
        {
          AND: [
            { entityType: "payment_schedule" },
            {
              OR: [
                { weddingPlan: { is: { ownerUserId: userId } } },
                ...paymentClauses,
              ],
            },
          ],
        },
      ],
    };
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
    const seed = await tx.notification.findFirst({
      where: { id, userId: currentUser.id },
    });
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
    const notification = await tx.notification.findFirst({
      where: { id, userId: currentUser.id },
    });
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
    const seed = await tx.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      select: { ownerUserId: true },
    });
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
    const planLock = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingPlan"
        WHERE "id" = ${weddingPlanId}
        FOR SHARE
      `,
    );
    if (planLock.length !== 1) {
      throw new NotFoundException("Notification not found");
    }
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "userId" = ${currentUser.id}
        FOR SHARE
      `,
    );
    const plan = await tx.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      select: { ownerUserId: true },
    });
    if (!plan || plan.ownerUserId !== seed.ownerUserId) {
      throw new NotFoundException("Notification not found");
    }
  }

  private async lockAllPlanAccessForNotifications(
    tx: Prisma.TransactionClient,
    currentUser: AuthenticatedUser,
    weddingPlanId: string | null = null,
  ): Promise<string[]> {
    const notificationPlans = await tx.notification.findMany({
      where: {
        userId: currentUser.id,
        readAt: null,
        archivedAt: null,
        weddingPlanId: weddingPlanId ?? { not: null },
      },
      select: { weddingPlanId: true },
    });
    const planIds = [
      ...new Set([
        ...(weddingPlanId ? [weddingPlanId] : []),
        ...notificationPlans.flatMap((notification) =>
          notification.weddingPlanId ? [notification.weddingPlanId] : [],
        ),
      ]),
    ].sort();
    const seedPlans =
      planIds.length === 0
        ? []
        : await tx.weddingPlan.findMany({
            where: { id: { in: planIds } },
            select: { id: true, ownerUserId: true },
          });
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

    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingPlan"
        WHERE "id" IN (${Prisma.join(planIds)})
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" IN (${Prisma.join(planIds)})
        ORDER BY "weddingPlanId" ASC, "id" ASC
        FOR SHARE
      `,
    );
    const livePlans = await tx.weddingPlan.findMany({
      where: { id: { in: planIds } },
      select: {
        id: true,
        ownerUserId: true,
        sharedMembers: {
          where: { userId: currentUser.id },
          select: { userId: true },
        },
      },
    });
    const lockedUserIds = new Set(
      lockedUsers.map((lockedUser) => lockedUser.id),
    );
    return livePlans
      .filter(
        (plan) =>
          lockedUserIds.has(plan.ownerUserId) &&
          (plan.ownerUserId === currentUser.id ||
            plan.sharedMembers.length === 1),
      )
      .map((plan) => plan.id)
      .sort();
  }

  private async lockOwnedProviderLifecycle(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<OwnedProviderLifecycle> {
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "userId" = ${userId}
        FOR SHARE
      `,
    );
    return tx.provider.findUnique({
      where: { userId },
      select: { id: true, status: true },
    });
  }

  private async lockNotificationRowsForUpdate(
    tx: Prisma.TransactionClient,
    notificationIds: readonly string[],
  ): Promise<void> {
    const ids = [...new Set(notificationIds)].sort();
    if (ids.length === 0) return;
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "Notification"
        WHERE "id" IN (${Prisma.join(ids)})
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
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
      const task = await client.weddingTask.findFirst({
        where: {
          id: entityId,
          weddingPlanId,
          OR: [
            { assigneeUserId: userId },
            { id: { in: contributedTaskIds } },
          ],
        },
        select: { id: true },
      });
      if (!task) throw new NotFoundException("Notification not found");
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
      const schedule = await client.paymentSchedule.findFirst({
        where: {
          id: entityId,
          weddingCost: {
            weddingPlanId,
            id: { in: contributedCostIds },
          },
        },
        select: { id: true },
      });
      if (!schedule) throw new NotFoundException("Notification not found");
    }
  }

  private async qualifyingContributionEntityIds(
    client: Pick<NotificationVisibilityClient, "contributionEvent">,
    weddingPlanId: string,
    userId: string,
    entityType: ContributionEntityType,
    actions: readonly ContributionAction[],
  ): Promise<string[]> {
    const events = await client.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId },
        contributorTenure: { actorUserId: userId },
        entityType,
        action: { in: [...actions] },
        entityId: { not: null },
      },
      select: { entityId: true },
      distinct: ["entityId"],
    });
    return events.flatMap((event) => (event.entityId ? [event.entityId] : []));
  }

  private async findOwnedOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
    client: Prisma.TransactionClient,
  ): Promise<Notification> {
    const [notification, provider] = await Promise.all([
      client.notification.findFirst({
        where: { id, userId: currentUser.id },
      }),
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
    client: Pick<NotificationVisibilityClient, "provider"> = this.prisma,
  ): Promise<OwnedProviderLifecycle> {
    return client.provider.findUnique({
      where: { userId },
      select: { id: true, status: true },
    });
  }

  private providerNotificationVisibilityWhere(
    provider: OwnedProviderLifecycle,
  ): Prisma.NotificationWhereInput | null {
    if (isProviderOperational(provider)) return null;

    const visibility: Prisma.NotificationWhereInput[] = [
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
  ): Prisma.NotificationWhereInput | null {
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
      const conversation = await client.conversation.findUnique({
        where: { id: notification.entityId },
        select: {
          provider: {
            select: { userId: true, status: true },
          },
        },
      });
      if (conversation?.provider.userId === currentUserId) {
        legacyProviderChat = true;
        assertProviderOperational(conversation.provider);
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
