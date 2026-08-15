import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  NotificationPriority,
  NotificationType,
  Prisma,
  SharedMember,
  WeddingTask,
  WeddingTaskChecklistItem,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import { ListQueryDto, pageArgs } from "../platform/http/list-query.dto";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { endOfRiyadhDay, startOfRiyadhDay } from "../shared-kernel/time/business-day";
import { ContributionHistoryService } from "../contribution-history/contribution-history.service";
import { buildContributionSnapshot } from "../contribution-history/contribution-snapshot.builder";
import { ContributorScopeService } from "../contribution-history/contributor-scope.service";
import { PrismaService } from "../platform/database/prisma.service";
import { NotificationsService } from "../notifications/notifications.service";
import {
  livePlanAuthorizationWhere,
  PermissionService,
  PlanAccessContext,
  TASK_PERMISSION_REVOKED,
  TASK_PERMISSION_REVOKED_MESSAGE,
} from "../sharing/permission.service";
import { AssignTaskDto } from "./dto/assign-task.dto";
import { CreateChecklistItemDto } from "./dto/create-checklist-item.dto";
import { CreateTaskDto } from "./dto/create-task.dto";
import { UpdateChecklistItemDto } from "./dto/update-checklist-item.dto";
import { UpdateTaskDto } from "./dto/update-task.dto";

export interface TaskResponse {
  id: string;
  weddingPlanId: string;
  assigneeUserId: string | null;
  responsibleName: string | null;
  responsiblePhone: string | null;
  responsibleSource: string | null;
  title: string;
  description: string | null;
  dueDate: Date | null;
  taskCategory: string | null;
  reminderAt: Date | null;
  status: WeddingTaskStatus;
  priority: WeddingTaskPriority;
  createdAt: Date;
  updatedAt: Date;
}

export interface ChecklistItemResponse {
  id: string;
  taskId: string;
  title: string;
  isDone: boolean;
  sortOrder: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface TaskSummaryResponse {
  weddingPlanId: string;
  totalTasks: number;
  total: number;
  completedTasks: number;
  completed: number;
  openTasks: number;
  pendingInProgress: number;
  overdueTasks: number;
  overdue: number;
  todayTasks: number;
  dueToday: number;
  highPriority: number;
  assignedToMe: number;
  assigneeSummary: {
    assignedToMe: number;
    assignedCount: number;
    unassignedCount: number;
  };
  byStatus: Record<WeddingTaskStatus, number>;
  byPriority: Record<WeddingTaskPriority, number>;
}

@Injectable()
export class TasksService {
  private readonly logger = new Logger(TasksService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
    private readonly notifications: NotificationsService,
    private readonly contributionHistory: ContributionHistoryService,
    private readonly contributorScope: ContributorScopeService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateTaskDto,
  ): Promise<TaskResponse> {
    const task = await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      const created = await tx.weddingTask.create({
        data: {
          weddingPlanId,
          assigneeUserId: null,
          responsibleName: this.optionalText(dto.responsibleName),
          responsiblePhone: this.optionalText(dto.responsiblePhone),
          responsibleSource: this.optionalText(dto.responsibleSource),
          title: this.requiredText(dto.title, "title"),
          description: this.optionalText(dto.description),
          dueDate: this.optionalDate(dto.dueDate, "dueDate"),
          taskCategory: this.optionalText(dto.taskCategory),
          reminderAt: this.optionalDate(dto.reminderAt, "reminderAt"),
          status: dto.status ?? WeddingTaskStatus.TODO,
          priority: dto.priority ?? WeddingTaskPriority.MEDIUM,
        },
      });
      await this.recordTaskContribution(tx, context, created, {
        action: ContributionAction.CREATED,
        dedupeKey: `task:${created.id}:created:${created.createdAt.toISOString()}`,
        occurredAt: created.createdAt,
      });
      return created;
    });
    await this.notifyTaskDueBestEffort(task);

    return this.toResponse(task);
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query?: ListQueryDto,
  ): Promise<TaskResponse[]> {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const canManageTasks = this.permissions.canManageTasks(context);
    const contributorScope = await this.liveTaskScope(
      context,
      currentUser.id,
    );
    if (contributorScope !== null && !canManageTasks) return [];
    const livePlanAuthorization =
      livePlanAuthorizationWhere(
        context,
        currentUser.id,
        ["canManageTasks"],
      );

    const tasks = await this.prisma.weddingTask.findMany({
      where: {
        weddingPlanId,
        weddingPlan: { is: livePlanAuthorization },
        ...(contributorScope
          ? {
              OR: [
                { assigneeUserId: currentUser.id },
                { id: { in: [...contributorScope] } },
              ],
            }
          : {}),
      },
      orderBy: [{ dueDate: "asc" }, { createdAt: "asc" }],
      ...pageArgs(query),
    });

    return tasks
      .filter(
        (task) =>
          contributorScope === null ||
          task.assigneeUserId === currentUser.id ||
          contributorScope.has(task.id),
      )
      .map((task) => this.toResponse(task, canManageTasks));
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<TaskResponse> {
    const task = await this.findTaskOrThrow(id);
    const context = await this.permissions.assertPlanReadable(
      task.weddingPlanId,
      currentUser,
    );
    const canManageTasks = this.permissions.canManageTasks(context);
    const contributorScope = await this.liveTaskScope(
      context,
      currentUser.id,
    );
    if (contributorScope !== null && !canManageTasks) {
      throw this.taskPermissionDenied();
    }
    const visibleTask = await this.prisma.weddingTask.findFirst({
      where: {
        id,
        weddingPlanId: task.weddingPlanId,
        weddingPlan: {
          is: livePlanAuthorizationWhere(
            context,
            currentUser.id,
            ["canManageTasks"],
          ),
        },
        ...(contributorScope
          ? {
              OR: [
                { assigneeUserId: currentUser.id },
                { id: { in: [...contributorScope] } },
              ],
            }
          : {}),
      },
    });
    if (!visibleTask) throw new NotFoundException("Task not found");
    return this.toResponse(visibleTask, canManageTasks);
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateTaskDto,
  ): Promise<TaskResponse> {
    const existing = await this.findTaskOrThrow(id);
    const manualResponsibility = this.manualResponsibilityUpdate(dto);
    const task = await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        existing.weddingPlanId,
        currentUser,
      );
      const current = await this.findTaskInTransactionOrThrow(
        tx,
        id,
        existing.weddingPlanId,
      );
      await this.assertTaskInMutationScope(tx, context, currentUser.id, current);
      const updated = await tx.weddingTask.update({
        where: { id },
        data: {
          ...(dto.title !== undefined
            ? { title: this.requiredText(dto.title, "title") }
            : {}),
          ...(dto.description !== undefined
            ? { description: this.optionalText(dto.description) }
            : {}),
          ...(dto.dueDate !== undefined
            ? { dueDate: this.optionalDate(dto.dueDate, "dueDate") }
            : {}),
          ...(dto.taskCategory !== undefined
            ? { taskCategory: this.optionalText(dto.taskCategory) }
            : {}),
          ...manualResponsibility,
          ...(dto.reminderAt !== undefined
            ? { reminderAt: this.optionalDate(dto.reminderAt, "reminderAt") }
            : {}),
          ...(dto.status !== undefined ? { status: dto.status } : {}),
          ...(dto.priority !== undefined ? { priority: dto.priority } : {}),
        },
      });
      const action = this.taskUpdateAction(current.status, updated.status);
      await this.recordTaskContribution(tx, context, updated, {
        action,
        dedupeKey: `task:${updated.id}:${action.toLowerCase()}:${updated.updatedAt.toISOString()}`,
      });
      return updated;
    });
    await this.notifyTaskDueBestEffort(task);

    return this.toResponse(task);
  }

  async assign(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AssignTaskDto,
  ): Promise<TaskResponse> {
    const existing = await this.findTaskOrThrow(id);
    const assigneeUserId = this.optionalText(dto.assigneeUserId);

    const task = await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        existing.weddingPlanId,
        currentUser,
      );
      const assigneeAccess = assigneeUserId
        ? await this.assertAssigneeBelongsToPlanInTransaction(
            tx,
            context.plan.ownerUserId,
            existing.weddingPlanId,
            assigneeUserId,
          )
        : { receiveNotifications: false, member: null };
      const currentTask = await this.findTaskInTransactionOrThrow(
        tx,
        id,
        existing.weddingPlanId,
      );
      await this.assertTaskInMutationScope(
        tx,
        context,
        currentUser.id,
        currentTask,
      );
      const updated = await tx.weddingTask.update({
        where: { id },
        data: {
          assigneeUserId,
          ...(assigneeUserId
            ? {
                responsibleName: null,
                responsiblePhone: null,
                responsibleSource: null,
              }
          : {}),
        },
      });
      if (currentTask.assigneeUserId !== assigneeUserId) {
        const actorAction = assigneeUserId
          ? ContributionAction.ASSIGNED
          : ContributionAction.UNASSIGNED;
        await this.recordTaskContribution(tx, context, updated, {
          action: actorAction,
          dedupeKey: `task:${updated.id}:${actorAction.toLowerCase()}:actor:${currentUser.id}:${updated.updatedAt.toISOString()}`,
        });
        if (
          assigneeAccess.member &&
          assigneeAccess.member.userId !== context.sharedMember?.userId
        ) {
          await this.recordTaskForMember(
            tx,
            assigneeAccess.member,
            updated,
            ContributionAction.ASSIGNED,
          );
        }
        if (
          currentTask.assigneeUserId &&
          currentTask.assigneeUserId !== context.sharedMember?.userId
        ) {
          const previousMember = await tx.sharedMember.findUnique({
            where: {
              weddingPlanId_userId: {
                weddingPlanId: existing.weddingPlanId,
                userId: currentTask.assigneeUserId,
              },
            },
          });
          if (previousMember) {
            await this.recordTaskForMember(
              tx,
              previousMember,
              updated,
              ContributionAction.UNASSIGNED,
            );
          }
        }
      }
      if (
        assigneeUserId &&
        assigneeAccess.receiveNotifications &&
        assigneeUserId !== currentUser.id &&
        assigneeUserId !== currentTask.assigneeUserId
      ) {
        await this.notifications.createNotificationInTransaction(tx, {
          userId: assigneeUserId,
          weddingPlanId: updated.weddingPlanId,
          type: NotificationType.TASK_ASSIGNED,
          priority:
            updated.priority === WeddingTaskPriority.URGENT
              ? NotificationPriority.HIGH
              : NotificationPriority.NORMAL,
          title: "مهمة جديدة",
          body: `تم إسناد مهمة «${updated.title}» إليك.`,
          entityType: "task",
          entityId: updated.id,
          routeTarget: `/wedding-plans/${updated.weddingPlanId}/tasks`,
          data: {
            taskId: updated.id,
            weddingPlanId: updated.weddingPlanId,
          },
          dedupeKey: `task-assigned:${updated.id}:${assigneeUserId}:${updated.updatedAt.toISOString()}`,
        });
      }
      return updated;
    });

    return this.toResponse(task);
  }

  async createChecklistItem(
    currentUser: AuthenticatedUser,
    taskId: string,
    dto: CreateChecklistItemDto,
  ): Promise<ChecklistItemResponse> {
    const task = await this.findTaskOrThrow(taskId);
    const item = await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        task.weddingPlanId,
        currentUser,
      );
      const currentTask = await this.findTaskInTransactionOrThrow(
        tx,
        taskId,
        task.weddingPlanId,
      );
      await this.assertTaskInMutationScope(
        tx,
        context,
        currentUser.id,
        currentTask,
      );
      const created = await tx.weddingTaskChecklistItem.create({
        data: {
          taskId,
          title: this.requiredText(dto.title, "title"),
          isDone: dto.isDone ?? false,
          sortOrder: dto.sortOrder ?? 0,
        },
      });
      await this.recordChecklistContribution(
        tx,
        context,
        created,
        ContributionAction.CREATED,
      );
      return created;
    });

    return this.toChecklistItemResponse(item);
  }

  async updateChecklistItem(
    currentUser: AuthenticatedUser,
    taskId: string,
    itemId: string,
    dto: UpdateChecklistItemDto,
  ): Promise<ChecklistItemResponse> {
    const item = await this.findChecklistItemOrThrow(taskId, itemId);
    const updated = await runSerializableTransaction(
      this.prisma,
      async (tx) => {
        const context = await this.permissions.assertTaskManageableInTransaction(
          tx,
          item.task.weddingPlanId,
          currentUser,
        );
        const currentTask = await this.findTaskInTransactionOrThrow(
          tx,
          taskId,
          item.task.weddingPlanId,
        );
        await this.assertTaskInMutationScope(
          tx,
          context,
          currentUser.id,
          currentTask,
        );
        const currentItem = await this.findChecklistItemInTransactionOrThrow(
          tx,
          taskId,
          itemId,
        );
        const result = await tx.weddingTaskChecklistItem.update({
          where: { id: itemId },
          data: {
            ...(dto.title !== undefined
              ? { title: this.requiredText(dto.title, "title") }
              : {}),
            ...(dto.isDone !== undefined ? { isDone: dto.isDone } : {}),
            ...(dto.sortOrder !== undefined
              ? { sortOrder: dto.sortOrder }
              : {}),
          },
        });
        const action =
          !currentItem.isDone && result.isDone
            ? ContributionAction.COMPLETED
            : currentItem.isDone && !result.isDone
              ? ContributionAction.REOPENED
              : ContributionAction.UPDATED;
        await this.recordChecklistContribution(tx, context, result, action);
        return result;
      },
    );

    return this.toChecklistItemResponse(updated);
  }

  async removeChecklistItem(
    currentUser: AuthenticatedUser,
    taskId: string,
    itemId: string,
  ): Promise<{ id: string; deleted: true }> {
    const item = await this.findChecklistItemOrThrow(taskId, itemId);
    await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        item.task.weddingPlanId,
        currentUser,
      );
      const currentTask = await this.findTaskInTransactionOrThrow(
        tx,
        taskId,
        item.task.weddingPlanId,
      );
      await this.assertTaskInMutationScope(
        tx,
        context,
        currentUser.id,
        currentTask,
      );
      const currentItem = await this.findChecklistItemInTransactionOrThrow(
        tx,
        taskId,
        itemId,
      );
      await this.recordChecklistContribution(
        tx,
        context,
        currentItem,
        ContributionAction.DELETED,
      );
      await tx.weddingTaskChecklistItem.delete({ where: { id: itemId } });
    });
    return { id: itemId, deleted: true };
  }

  async summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<TaskSummaryResponse> {
    const context = await this.permissions.assertPlanReadable(
      weddingPlanId,
      currentUser,
    );
    const canManageTasks = this.permissions.canManageTasks(context);
    const contributorScope = await this.liveTaskScope(
      context,
      currentUser.id,
    );
    const livePlanAuthorization =
      livePlanAuthorizationWhere(
        context,
        currentUser.id,
        ["canManageTasks"],
      );

    const today = this.startOfToday();
    const endOfToday = this.endOfToday(today);
    const rows =
      contributorScope !== null && !canManageTasks
        ? []
        : await this.prisma.weddingTask.findMany({
             where: {
               weddingPlanId,
               weddingPlan: { is: livePlanAuthorization },
              ...(contributorScope
                ? {
                    OR: [
                      { assigneeUserId: currentUser.id },
                      { id: { in: [...contributorScope] } },
                    ],
                  }
                : {}),
            },
          });
    const tasks = rows.filter(
      (task) =>
        contributorScope === null ||
        task.assigneeUserId === currentUser.id ||
        contributorScope.has(task.id),
    );

    const byStatus = this.emptyStatusCounts();
    const byPriority = this.emptyPriorityCounts();
    let completedTasks = 0;
    let overdueTasks = 0;
    let todayTasks = 0;
    let assignedToMe = 0;
    let assignedCount = 0;

    for (const task of tasks) {
      byStatus[task.status]++;
      byPriority[task.priority]++;
      if (task.status === WeddingTaskStatus.DONE) completedTasks++;
      if (task.assigneeUserId === currentUser.id) assignedToMe++;
      if (task.assigneeUserId) assignedCount++;
      if (
        task.dueDate &&
        task.dueDate < today &&
        task.status !== WeddingTaskStatus.DONE &&
        task.status !== WeddingTaskStatus.CANCELLED
      ) {
        overdueTasks++;
      }
      if (
        task.dueDate &&
        task.dueDate >= today &&
        task.dueDate <= endOfToday &&
        task.status !== WeddingTaskStatus.DONE &&
        task.status !== WeddingTaskStatus.CANCELLED
      ) {
        todayTasks++;
      }
    }

    return {
      weddingPlanId,
      totalTasks: tasks.length,
      total: tasks.length,
      completedTasks,
      completed: completedTasks,
      openTasks: tasks.filter(
        (task) =>
          task.status !== WeddingTaskStatus.DONE &&
          task.status !== WeddingTaskStatus.CANCELLED,
      ).length,
      pendingInProgress:
        byStatus[WeddingTaskStatus.TODO] +
        byStatus[WeddingTaskStatus.IN_PROGRESS],
      overdueTasks,
      overdue: overdueTasks,
      todayTasks,
      dueToday: todayTasks,
      highPriority:
        byPriority[WeddingTaskPriority.HIGH] +
        byPriority[WeddingTaskPriority.URGENT],
      assignedToMe,
      assigneeSummary: {
        assignedToMe,
        assignedCount,
        unassignedCount: tasks.length - assignedCount,
      },
      byStatus,
      byPriority,
    };
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findTaskOrThrow(id);
    await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        existing.weddingPlanId,
        currentUser,
      );
      const current = await this.findTaskInTransactionOrThrow(
        tx,
        id,
        existing.weddingPlanId,
      );
      await this.assertTaskInMutationScope(tx, context, currentUser.id, current);
      await this.recordTaskContribution(tx, context, current, {
        action: ContributionAction.DELETED,
        dedupeKey: `task:${current.id}:deleted:${current.updatedAt.toISOString()}`,
      });
      await tx.weddingTask.delete({ where: { id } });
    });
    return { id, deleted: true };
  }

  private async findTaskOrThrow(id: string): Promise<WeddingTask> {
    const task = await this.prisma.weddingTask.findUnique({ where: { id } });

    if (!task) {
      throw new NotFoundException("Task not found");
    }

    return task;
  }

  private async findChecklistItemOrThrow(
    taskId: string,
    itemId: string,
  ): Promise<WeddingTaskChecklistItem & { task: WeddingTask }> {
    const item = await this.prisma.weddingTaskChecklistItem.findFirst({
      where: { id: itemId, taskId },
      include: { task: true },
    });

    if (!item) {
      throw new NotFoundException("Checklist item not found");
    }

    return item;
  }

  private async findTaskInTransactionOrThrow(
    tx: Prisma.TransactionClient,
    id: string,
    weddingPlanId: string,
  ): Promise<WeddingTask> {
    const locked = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingTask"
        WHERE "id" = ${id}
          AND "weddingPlanId" = ${weddingPlanId}
        FOR UPDATE
      `,
    );
    if (locked.length !== 1) {
      throw new NotFoundException("Task not found");
    }
    const task = await tx.weddingTask.findUnique({ where: { id } });
    if (!task) {
      throw new NotFoundException("Task not found");
    }
    return task;
  }

  private async findChecklistItemInTransactionOrThrow(
    tx: Prisma.TransactionClient,
    taskId: string,
    itemId: string,
  ): Promise<WeddingTaskChecklistItem> {
    const locked = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingTaskChecklistItem"
        WHERE "id" = ${itemId}
          AND "taskId" = ${taskId}
        FOR UPDATE
      `,
    );
    if (locked.length !== 1) {
      throw new NotFoundException("Checklist item not found");
    }
    const item = await tx.weddingTaskChecklistItem.findUnique({
      where: { id: itemId },
    });
    if (!item) {
      throw new NotFoundException("Checklist item not found");
    }
    return item;
  }

  private async assertAssigneeBelongsToPlanInTransaction(
    tx: Prisma.TransactionClient,
    planOwnerUserId: string,
    weddingPlanId: string,
    assigneeUserId: string,
  ): Promise<{
    receiveNotifications: boolean;
    member: SharedMember | null;
  }> {
    if (planOwnerUserId === assigneeUserId) {
      return { receiveNotifications: true, member: null };
    }

    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "userId" = ${assigneeUserId}
        FOR SHARE
      `,
    );
    const member = await tx.sharedMember.findUnique({
      where: {
        weddingPlanId_userId: {
          weddingPlanId,
          userId: assigneeUserId,
        },
      },
    });

    if (!member) {
      throw new BadRequestException("assigneeUserId must belong to the plan");
    }
    if (!member.canManageTasks) {
      throw new BadRequestException(
        "assigneeUserId must have task permission",
      );
    }
    return { receiveNotifications: member.receiveNotifications, member };
  }

  private isContributor(context: PlanAccessContext): boolean {
    return !context.isOwner && Boolean(context.sharedMember);
  }

  private async liveTaskScope(
    context: PlanAccessContext,
    actorUserId: string,
  ): Promise<Set<string> | null> {
    if (!this.isContributor(context)) return null;
    if (!this.permissions.canManageTasks(context)) return new Set<string>();
    return new Set(
      await this.contributorScope.qualifyingEntityIds(
        context.plan.id,
        actorUserId,
        [ContributionEntityType.TASK],
        [ContributionAction.CREATED, ContributionAction.COMPLETED],
      ),
    );
  }

  private async assertTaskInMutationScope(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    actorUserId: string,
    task: WeddingTask,
  ): Promise<void> {
    if (!this.isContributor(context)) return;
    if (task.assigneeUserId === actorUserId) return;
    const ids = await this.contributorScope.qualifyingEntityIdsInTransaction(
      tx,
      task.weddingPlanId,
      actorUserId,
      [ContributionEntityType.TASK],
      [ContributionAction.CREATED, ContributionAction.COMPLETED],
    );
    if (!ids.includes(task.id)) throw new NotFoundException("Task not found");
  }

  private taskUpdateAction(
    previous: WeddingTaskStatus,
    next: WeddingTaskStatus,
  ): ContributionAction {
    if (previous !== WeddingTaskStatus.DONE && next === WeddingTaskStatus.DONE) {
      return ContributionAction.COMPLETED;
    }
    if (previous === WeddingTaskStatus.DONE && next !== WeddingTaskStatus.DONE) {
      return ContributionAction.REOPENED;
    }
    if (previous !== next) return ContributionAction.STATUS_CHANGED;
    return ContributionAction.UPDATED;
  }

  private async recordTaskContribution(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    task: WeddingTask,
    input: {
      action: ContributionAction;
      dedupeKey: string;
      occurredAt?: Date;
    },
  ): Promise<void> {
    await this.contributionHistory.recordForContextInTransaction(tx, context, {
      section: ContributionSection.TASKS,
      entityType: ContributionEntityType.TASK,
      entityId: task.id,
      action: input.action,
      snapshot: buildContributionSnapshot(ContributionEntityType.TASK, task),
      dedupeKey: input.dedupeKey,
      requiredPermission: ContributionPermission.MANAGE_TASKS,
      occurredAt: input.occurredAt ?? task.updatedAt,
    });
  }

  private async recordTaskForMember(
    tx: Prisma.TransactionClient,
    member: SharedMember,
    task: WeddingTask,
    action: ContributionAction,
  ): Promise<void> {
    await this.contributionHistory.ensureTenureInTransaction(tx, member);
    await this.contributionHistory.recordInTransaction(tx, {
      weddingPlanId: member.weddingPlanId,
      actorUserId: member.userId,
      section: ContributionSection.TASKS,
      entityType: ContributionEntityType.TASK,
      entityId: task.id,
      action,
      snapshot: buildContributionSnapshot(ContributionEntityType.TASK, task),
      dedupeKey: `task:${task.id}:${action.toLowerCase()}:member:${member.id}:${task.updatedAt.toISOString()}`,
      requiredPermission: ContributionPermission.MANAGE_TASKS,
      authorityVersion: member.authorityVersion,
      occurredAt: task.updatedAt,
    });
  }

  private async recordChecklistContribution(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    item: WeddingTaskChecklistItem,
    action: ContributionAction,
  ): Promise<void> {
    await this.contributionHistory.recordForContextInTransaction(tx, context, {
      section: ContributionSection.TASKS,
      entityType: ContributionEntityType.TASK_CHECKLIST_ITEM,
      entityId: item.id,
      action,
      snapshot: buildContributionSnapshot(
        ContributionEntityType.TASK_CHECKLIST_ITEM,
        {
          title: item.title,
          status: item.isDone ? "DONE" : "TODO",
        },
      ),
      dedupeKey: `task-checklist:${item.id}:${action.toLowerCase()}:${item.updatedAt.toISOString()}`,
      requiredPermission: ContributionPermission.MANAGE_TASKS,
      occurredAt: item.updatedAt,
    });
  }

  private taskPermissionDenied(): ForbiddenException {
    return new ForbiddenException({
      statusCode: 403,
      code: TASK_PERMISSION_REVOKED,
      message: TASK_PERMISSION_REVOKED_MESSAGE,
    });
  }

  private async notifyTaskDueBestEffort(task: WeddingTask): Promise<void> {
    try {
      await this.notifications.notifyTaskDue(task);
    } catch (error) {
      this.logger.warn(
        `Deferred task reminder repair for task ${task.id}: ${error instanceof Error ? error.name : "UnknownError"}`,
      );
    }
  }

  private requiredText(value: string, field: string): string {
    const trimmed = value.trim();
    if (!trimmed) {
      throw new BadRequestException(`${field} must not be empty`);
    }
    return trimmed;
  }

  private optionalText(value: string | null | undefined): string | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    return trimmed || null;
  }

  private optionalDate(
    value: string | null | undefined,
    field: string,
  ): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;

    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException(`${field} must be a valid ISO date string`);
    }
    return new Date(timestamp);
  }

  private manualResponsibilityUpdate(dto: UpdateTaskDto) {
    const hasUpdate =
      dto.responsibleName !== undefined ||
      dto.responsiblePhone !== undefined ||
      dto.responsibleSource !== undefined;
    if (!hasUpdate) return {};

    const responsibleName = this.optionalText(dto.responsibleName);
    const responsiblePhone = this.optionalText(dto.responsiblePhone);
    const responsibleSource = this.optionalText(dto.responsibleSource);
    const hasManualResponsible =
      responsibleName !== null ||
      responsiblePhone !== null ||
      responsibleSource !== null;

    return {
      responsibleName,
      responsiblePhone,
      responsibleSource,
      ...(hasManualResponsible ? { assigneeUserId: null } : {}),
    };
  }

  private toResponse(
    task: WeddingTask,
    includeResponsiblePhone = true,
  ): TaskResponse {
    return {
      id: task.id,
      weddingPlanId: task.weddingPlanId,
      assigneeUserId: task.assigneeUserId,
      responsibleName: task.responsibleName,
      responsiblePhone: includeResponsiblePhone ? task.responsiblePhone : null,
      responsibleSource: task.responsibleSource,
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      taskCategory: task.taskCategory,
      reminderAt: task.reminderAt,
      status: task.status,
      priority: task.priority,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }

  private toChecklistItemResponse(
    item: WeddingTaskChecklistItem,
  ): ChecklistItemResponse {
    return {
      id: item.id,
      taskId: item.taskId,
      title: item.title,
      isDone: item.isDone,
      sortOrder: item.sortOrder,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    };
  }

  private startOfToday(): Date {
    return startOfRiyadhDay();
  }

  private endOfToday(today: Date): Date {
    return endOfRiyadhDay(today);
  }

  private emptyStatusCounts(): Record<WeddingTaskStatus, number> {
    return {
      [WeddingTaskStatus.TODO]: 0,
      [WeddingTaskStatus.IN_PROGRESS]: 0,
      [WeddingTaskStatus.DONE]: 0,
      [WeddingTaskStatus.CANCELLED]: 0,
    };
  }

  private emptyPriorityCounts(): Record<WeddingTaskPriority, number> {
    return {
      [WeddingTaskPriority.LOW]: 0,
      [WeddingTaskPriority.MEDIUM]: 0,
      [WeddingTaskPriority.HIGH]: 0,
      [WeddingTaskPriority.URGENT]: 0,
    };
  }
}
