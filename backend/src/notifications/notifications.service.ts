import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  Notification,
  NotificationPriority,
  NotificationType,
  PaymentScheduleStatus,
  Prisma,
  WeddingPlanStatus,
  WeddingTask,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { endOfRiyadhDay, startOfRiyadhDay } from "../common/time/business-day";
import { PrismaService } from "../prisma/prisma.service";
import { OutboxEventTypes } from "../outbox/outbox.constants";
import { OutboxService } from "../outbox/outbox.service";
import { PermissionService } from "../sharing/permission.service";

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
  "notification" | "outboxEvent"
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
    const where: Prisma.NotificationWhereInput = {
      userId: currentUser.id,
      archivedAt: null,
      ...(type ? { type } : {}),
      ...(unreadOnly ? { readAt: null } : {}),
      ...(planId ? { weddingPlanId: planId } : {}),
    };
    const [total, notifications] = await this.prisma.$transaction([
      this.prisma.notification.count({ where }),
      this.prisma.notification.findMany({
        where,
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        skip: (page - 1) * limit,
        take: limit,
      }),
    ]);

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
    const count = await this.prisma.notification.count({
      where: {
        userId: currentUser.id,
        readAt: null,
        archivedAt: null,
        ...(planId ? { weddingPlanId: planId } : {}),
      },
    });

    return { count };
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<NotificationResponse> {
    const notification = await this.findOwnedOrThrow(currentUser, id);
    return this.toResponse(notification);
  }

  async markRead(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<NotificationResponse> {
    const existing = await this.findOwnedOrThrow(currentUser, id);
    if (existing.readAt) return this.toResponse(existing);

    const notification = await this.prisma.notification.update({
      where: { id },
      data: { readAt: new Date() },
    });

    return this.toResponse(notification);
  }

  async markAllRead(
    currentUser: AuthenticatedUser,
    weddingPlanId?: string,
  ): Promise<{ updated: number }> {
    const planId = this.optionalText(weddingPlanId);
    const result = await this.prisma.notification.updateMany({
      where: {
        userId: currentUser.id,
        readAt: null,
        archivedAt: null,
        ...(planId ? { weddingPlanId: planId } : {}),
      },
      data: { readAt: new Date() },
    });

    return { updated: result.count };
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    await this.findOwnedOrThrow(currentUser, id);
    await this.prisma.notification.delete({ where: { id } });
    return { id, deleted: true };
  }

  async archive(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<NotificationResponse> {
    const existing = await this.findOwnedOrThrow(currentUser, id);
    if (existing.archivedAt) return this.toResponse(existing);

    const now = new Date();
    const notification = await this.prisma.notification.update({
      where: { id },
      data: {
        archivedAt: now,
        readAt: existing.readAt ?? now,
      },
    });
    return this.toResponse(notification);
  }

  async createNotification(
    input: CreateNotificationInput,
  ): Promise<NotificationResponse> {
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
  ): Promise<NotificationResponse> {
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
    await this.outbox.enqueue(client, {
      type: OutboxEventTypes.notificationCreated,
      aggregateType: "notification",
      aggregateId: created.id,
      payload: {
        notificationId: created.id,
        userId: created.userId,
      },
    });
    return this.toResponse(created);
  }

  async createForPlanParticipants(
    weddingPlanId: string,
    input: Omit<CreateNotificationInput, "userId" | "weddingPlanId">,
    excludedUserIds: string[] = [],
  ): Promise<NotificationResponse[]> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      select: {
        ownerUserId: true,
        sharedMembers: {
          where: { receiveNotifications: true },
          select: { userId: true },
        },
      },
    });
    if (!plan) {
      throw new NotFoundException("Wedding plan not found");
    }

    const excluded = new Set(excludedUserIds);
    const userIds = new Set([
      plan.ownerUserId,
      ...plan.sharedMembers.map((member) => member.userId),
    ]);
    return Promise.all(
      [...userIds]
        .filter((userId) => !excluded.has(userId))
        .map((userId) =>
          this.createNotification({
            ...input,
            userId,
            weddingPlanId,
            dedupeKey: input.dedupeKey
              ? `${userId}:${input.dedupeKey}`
              : undefined,
          }),
        ),
    );
  }

  async notifyTaskDue(task: WeddingTask): Promise<void> {
    if (
      !task.dueDate ||
      task.status === WeddingTaskStatus.DONE ||
      task.status === WeddingTaskStatus.CANCELLED
    ) {
      return;
    }
    const today = startOfRiyadhDay();
    const dueWindowEnd = new Date(today);
    dueWindowEnd.setDate(dueWindowEnd.getDate() + 7);
    if (task.dueDate > endOfRiyadhDay(dueWindowEnd)) return;

    const overdue = task.dueDate < today;
    const type = overdue
      ? NotificationType.TASK_OVERDUE
      : NotificationType.TASK_DUE_SOON;
    await this.createForPlanParticipants(task.weddingPlanId, {
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
    });
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

        const planIds = plans.map((plan) => plan.id);
        const [tasks, paymentSchedules] = await Promise.all([
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

        const plansById = new Map(plans.map((plan) => [plan.id, plan]));
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
            ...plan.sharedMembers.map((member) => member.userId),
          ]);
          for (const userId of recipients) {
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
              .filter((member) =>
                this.permissions.canViewMoney({
                  plan,
                  isOwner: false,
                  sharedMember: member,
                }),
              )
              .map((member) => member.userId),
          ];
          for (const userId of new Set(recipients)) {
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
          await this.outbox.enqueue(tx, {
            type: OutboxEventTypes.notificationCreated,
            aggregateType: "notification",
            aggregateId: notification.id,
            payload: {
              notificationId: notification.id,
              userId: notification.userId,
            },
          });
        }
        return created.length;
      },
      { timeout: 120_000 },
    );
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

  private async findOwnedOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<Notification> {
    const notification = await this.prisma.notification.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!notification) {
      throw new NotFoundException("Notification not found");
    }

    if (
      notification.entityType === "payment_schedule" &&
      notification.weddingPlanId
    ) {
      await this.permissions.assertMoneyReadable(
        notification.weddingPlanId,
        currentUser,
      );
    }

    return notification;
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
