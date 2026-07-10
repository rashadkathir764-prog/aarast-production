import { Injectable, NotFoundException } from '@nestjs/common';
import {
  InstallmentStatus,
  Notification,
  NotificationPriority,
  NotificationType,
  Prisma,
  SharedMember,
  WeddingPlan,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import {
  endOfRiyadhDay,
  startOfRiyadhDay,
} from '../common/time/business-day';
import { PrismaService } from '../prisma/prisma.service';
import { OutboxEventTypes } from '../outbox/outbox.constants';
import { OutboxService } from '../outbox/outbox.service';
import { PermissionService, PlanAccessContext } from '../sharing/permission.service';

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
  ): Promise<NotificationResponse[]> {
    const planId = this.optionalText(weddingPlanId);
    await this.ensureDueNotifications(currentUser, planId);

    const notifications = await this.prisma.notification.findMany({
      where: {
        userId: currentUser.id,
        archivedAt: null,
        ...(type ? { type } : {}),
        ...(unreadOnly ? { readAt: null } : {}),
        ...(planId ? { weddingPlanId: planId } : {}),
      },
      orderBy: [{ createdAt: 'desc' }],
      take: 100,
    });

    return notifications.map((notification) => this.toResponse(notification));
  }

  async unreadCount(
    currentUser: AuthenticatedUser,
    weddingPlanId?: string,
  ): Promise<{ count: number }> {
    const planId = this.optionalText(weddingPlanId);
    await this.ensureDueNotifications(currentUser, planId);

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
    await this.ensureDueNotifications(currentUser, planId);

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
      const notification = await this.prisma.$transaction(async (tx) => {
        const created = await tx.notification.create({
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
        await this.outbox.enqueue(tx, {
          type: OutboxEventTypes.notificationCreated,
          aggregateType: 'notification',
          aggregateId: created.id,
          payload: {
            notificationId: created.id,
            userId: created.userId,
          },
        });
        return created;
      });
      return this.toResponse(notification);
    } catch (error) {
      if (
        input.dedupeKey &&
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        const existing = await this.prisma.notification.findUnique({
          where: { dedupeKey: input.dedupeKey },
        });
        if (existing) return this.toResponse(existing);
      }
      throw error;
    }
  }

  async createForPlanParticipants(
    weddingPlanId: string,
    input: Omit<CreateNotificationInput, 'userId' | 'weddingPlanId'>,
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
      throw new NotFoundException('Wedding plan not found');
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

  private async ensureDueNotifications(
    currentUser: AuthenticatedUser,
    weddingPlanId: string | null,
  ) {
    const contexts = weddingPlanId
      ? [await this.permissions.assertPlanReadable(weddingPlanId, currentUser)]
      : await this.findAccessiblePlanningContexts(currentUser);

    await Promise.all(
      contexts.map((context) =>
        this.ensureDueNotificationsForContext(currentUser, context),
      ),
    );
  }

  private async findAccessiblePlanningContexts(
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext[]> {
    const [ownedPlans, sharedMembers] = await Promise.all([
      this.prisma.weddingPlan.findMany({
        where: {
          ownerUserId: currentUser.id,
          status: WeddingPlanStatus.PLANNING,
        },
      }),
      this.prisma.sharedMember.findMany({
        where: {
          userId: currentUser.id,
          weddingPlan: { status: WeddingPlanStatus.PLANNING },
        },
        include: { weddingPlan: true },
      }),
    ]);

    return [
      ...ownedPlans.map((plan) => ({
        plan,
        isOwner: true,
        sharedMember: null,
      })),
      ...sharedMembers.map((member) => ({
        plan: member.weddingPlan,
        isOwner: false,
        sharedMember: this.toSharedMember(member),
      })),
    ];
  }

  private async ensureDueNotificationsForContext(
    currentUser: AuthenticatedUser,
    context: PlanAccessContext,
  ) {
    const today = startOfRiyadhDay();
    const dueWindowEnd = new Date(today);
    dueWindowEnd.setDate(dueWindowEnd.getDate() + 7);
    const dueWindowEndOfDay = endOfRiyadhDay(dueWindowEnd);

    const tasks = await this.prisma.weddingTask.findMany({
      where: {
        weddingPlanId: context.plan.id,
        dueDate: { not: null, lte: dueWindowEndOfDay },
        status: {
          notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
        },
      },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
      take: 25,
    });

    const canReadDebts = this.permissions.canReadFinancial(context, 'debts');
    const installments = canReadDebts
      ? await this.prisma.installment.findMany({
          where: {
            dueDate: { not: null, lte: dueWindowEndOfDay },
            status: {
              in: [InstallmentStatus.PENDING, InstallmentStatus.OVERDUE],
            },
            debt: { weddingPlanId: context.plan.id },
          },
          include: {
            debt: { select: { title: true, creditorName: true } },
          },
          orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
          take: 25,
        })
      : [];

    await Promise.all([
      ...tasks.map((task) => {
        const overdue = task.dueDate ? task.dueDate < today : false;
        const type = overdue
          ? NotificationType.TASK_OVERDUE
          : NotificationType.TASK_DUE_SOON;
        return this.createNotification({
          userId: currentUser.id,
          weddingPlanId: task.weddingPlanId,
          type,
          title: overdue ? 'مهمة متأخرة' : 'مهمة قريبة',
          body: `${task.title} - ${overdue ? 'تجاوزت موعدها' : 'تستحق قريباً'} (${this.formatDate(task.dueDate)}).`,
          data: {
            taskId: task.id,
            weddingPlanId: task.weddingPlanId,
            dueDate: task.dueDate?.toISOString(),
          },
          priority: overdue
            ? NotificationPriority.HIGH
            : NotificationPriority.NORMAL,
          entityType: 'task',
          entityId: task.id,
          routeTarget: `/wedding-plans/${task.weddingPlanId}/tasks`,
          dedupeKey: `${currentUser.id}:${type}:task:${task.id}`,
        });
      }),
      ...installments.map((installment) => {
        const overdue =
          installment.status === InstallmentStatus.OVERDUE ||
          (installment.dueDate ? installment.dueDate < today : false);
        const type = overdue
          ? NotificationType.INSTALLMENT_OVERDUE
          : NotificationType.INSTALLMENT_DUE_SOON;
        return this.createNotification({
          userId: currentUser.id,
          weddingPlanId: context.plan.id,
          type,
          title: overdue ? 'قسط متأخر' : 'قسط قريب',
          body: `${installment.debt.title} - قسط بقيمة ${installment.amount.toString()} ${overdue ? 'متأخر' : 'يستحق قريباً'} (${this.formatDate(installment.dueDate)}).`,
          data: {
            installmentId: installment.id,
            debtId: installment.debtId,
            weddingPlanId: context.plan.id,
            dueDate: installment.dueDate?.toISOString(),
            creditorName: installment.debt.creditorName,
          },
          priority: overdue
            ? NotificationPriority.HIGH
            : NotificationPriority.NORMAL,
          entityType: 'installment',
          entityId: installment.id,
          routeTarget: `/debts/${installment.debtId}`,
          dedupeKey: `${currentUser.id}:${type}:installment:${installment.id}`,
        });
      }),
    ]);
  }

  private async findOwnedOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<Notification> {
    const notification = await this.prisma.notification.findFirst({
      where: { id, userId: currentUser.id },
    });

    if (!notification) {
      throw new NotFoundException('Notification not found');
    }

    return notification;
  }

  private optionalText(value: string | undefined): string | null {
    const trimmed = value?.trim() ?? '';
    return trimmed || null;
  }

  private formatDate(date: Date | null): string {
    if (!date) return 'بدون تاريخ';
    return `${date.getUTCDate()}/${date.getUTCMonth() + 1}/${date.getUTCFullYear()}`;
  }

  private toSharedMember(
    member: SharedMember & { weddingPlan: WeddingPlan },
  ): SharedMember {
    const { weddingPlan: _weddingPlan, ...sharedMember } = member;
    return sharedMember;
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
