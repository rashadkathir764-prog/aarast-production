import {
  BadRequestException,
  ForbiddenException,
  Inject,
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
import {
  runRetryableTransaction,
  runSerializableTransaction,
} from "../platform/database/serializable-transaction";
import { endOfRiyadhDay, startOfRiyadhDay } from "../shared-kernel/time/business-day";
import {
  COLLABORATION_HISTORY_PORT,
  type CollaborationHistoryPort as ContributionHistoryService,
} from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import {
  COLLABORATION_SCOPE_PORT,
  type CollaborationScopePort as ContributorScopeService,
} from "../modules/collaboration/public/collaboration-scope.port";
import { PrismaService } from "../platform/database/prisma.service";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort as PermissionService,
  PlanAccessContext,
  TASK_PERMISSION_REVOKED,
  TASK_PERMISSION_REVOKED_MESSAGE,
  seesWholePlan,
} from "../modules/collaboration/public/collaboration-permission.port";
import {
  FINANCE_PORT,
  type FinancePort,
} from "../modules/finance/public/finance.port";
import { isPlanItemBooked } from "../modules/marketplace/public/plan-booked-services";
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from "../modules/marketplace/public/provider-read.port";
import { starterTaskService } from "./task-starter-services";
import { manualStatusPatch } from "./task-status-patch";
import { AssignTaskDto } from "./dto/assign-task.dto";
import { CreateChecklistItemDto } from "./dto/create-checklist-item.dto";
import { CreatePlanTaskDto } from "./dto/create-plan-task.dto";
import { UpdateChecklistItemDto } from "./dto/update-checklist-item.dto";
import { UpdateTaskDto } from "./dto/update-task.dto";
import { noticeRoutes } from "../shared-kernel/routes/notification-routes";
import { weekdayDayMonthWords } from "../shared-kernel/voice/day-words";
import {
  assignTask,
  createChecklistItem,
  createTask,
  deleteChecklistItem,
  deleteTask,
  findChecklistItemById,
  findChecklistItemWithTask,
  findLivePlanTask,
  findTaskById,
  listLivePlanTasks,
  listLiveTasksForSummary,
  lockChecklistItemForUpdate,
  lockTaskForUpdate,
  shiftOpenTaskDates,
  updateChecklistItem,
  updateTask,
} from '../modules/tasks/infrastructure/task-work.repository';

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
  /** V1 checklist 4.10: seen by the reader alone (only its account ever receives it). */
  isPrivate: boolean;
  /** The task's checklist, ordered by sortOrder then creation. */
  checklist: ChecklistItemResponse[];
  /** R4: what it waits on, for a reader who sees the money. */
  linkedBudgetCategoryId: string | null;
  linkedCostId: string | null;
  linkedScheduleId: string | null;
  /** R4: when the booking or the payment finished it. */
  autoClosedAt: Date | null;
}

/** R4: the link a request asks for, read and checked against the plan. */
interface TaskLinkValues {
  linkedBudgetCategoryId: string | null;
  linkedCostId: string | null;
  linkedScheduleId: string | null;
  settled: boolean;
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
  /** V1 checklist 4.10: the reader (owner or partner) may keep a new task private. */
  canKeepPrivateTask: boolean;
}

@Injectable()
export class TasksService {
  private readonly logger = new Logger(TasksService.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(COLLABORATION_PERMISSION_PORT)
    private readonly permissions: PermissionService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
    @Inject(COLLABORATION_HISTORY_PORT)
    private readonly contributionHistory: ContributionHistoryService,
    @Inject(COLLABORATION_SCOPE_PORT)
    private readonly contributorScope: ContributorScopeService,
    @Inject(FINANCE_PORT)
    private readonly finance?: FinancePort,
    @Inject(PROVIDER_READ_PORT)
    private readonly providers?: ProviderReadPort,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreatePlanTaskDto,
  ): Promise<TaskResponse> {
    const task = await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      const link = await this.linkForNewTask(
        tx,
        weddingPlanId,
        dto,
        context.plan.persona,
      );
      const created = await createTask(tx, {
          weddingPlanId,
          responsibleName: this.optionalText(dto.responsibleName),
          responsiblePhone: this.optionalText(dto.responsiblePhone),
          responsibleSource: this.optionalText(dto.responsibleSource),
          title: this.requiredText(dto.title, "title"),
          description: this.optionalText(dto.description),
          dueDate: this.optionalDate(dto.dueDate, "dueDate"),
          taskCategory: this.optionalText(dto.taskCategory),
          reminderAt: this.optionalDate(dto.reminderAt, "reminderAt"),
          status: link?.settled
            ? WeddingTaskStatus.DONE
            : (dto.status ?? WeddingTaskStatus.TODO),
          priority: dto.priority ?? WeddingTaskPriority.MEDIUM,
          privateToUserId: this.privateOwnerForNewTask(context, currentUser, dto.isPrivate),
          linkedBudgetCategoryId: link?.linkedBudgetCategoryId,
          linkedCostId: link?.linkedCostId,
          linkedScheduleId: link?.linkedScheduleId,
          autoClosedAt: link?.settled ? new Date() : null,
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

  /**
   * The wedding moved (V1 checklist 4.13): the owner moves the plan's open
   * dated tasks by the same number of days. The app asks first; nothing
   * moves on its own when the date changes.
   */
  async shiftOpenDueDates(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    days: number,
  ): Promise<{ shifted: number }> {
    if (!Number.isInteger(days) || days === 0) {
      throw new BadRequestException("days must be a whole number of days other than 0");
    }
    const shifted = await runSerializableTransaction(this.prisma, async (tx) => {
      const context = await this.permissions.assertTaskManageableInTransaction(
        tx,
        weddingPlanId,
        currentUser,
      );
      if (!seesWholePlan(context)) {
        throw new ForbiddenException("Only the plan owner or partner moves every task");
      }
      return shiftOpenTaskDates(tx, weddingPlanId, days, currentUser.id);
    });
    return { shifted };
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
    // The final read re-checks current ownership/membership and the task
    // permission through the owners and applies the result to the task table,
    // in one snapshot with the read (as the single statement it replaces).
    const tasks = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          context,
          currentUser.id,
          ["canManageTasks"],
        );
        return listLivePlanTasks(
          tx,
          weddingPlanId,
          currentUser.id,
          contributorScope ? [...contributorScope] : null,
          liveFilter,
          query,
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );

    return tasks
      .filter(
        (task) =>
          contributorScope === null ||
          task.assigneeUserId === currentUser.id ||
          contributorScope.has(task.id),
      )
      .map((task) =>
        this.toResponse(task, canManageTasks, this.permissions.canViewMoney(context)),
      );
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
    const visibleTask = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          context,
          currentUser.id,
          ["canManageTasks"],
        );
        return findLivePlanTask(
          tx,
          id,
          task.weddingPlanId,
          currentUser.id,
          contributorScope ? [...contributorScope] : null,
          liveFilter,
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
    if (!visibleTask) throw new NotFoundException("Task not found");
    return this.toResponse(
      visibleTask,
      canManageTasks,
      this.permissions.canViewMoney(context),
    );
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
      // V1 checklist 4.10: privacy is chosen when the task is created; a
      // shared task never becomes private (it would vanish from the other
      // side), and only the account it is private to reaches it to share it.
      if (dto.isPrivate === true && !current.privateToUserId) {
        throw new BadRequestException({
          statusCode: 400,
          code: "TASK_PRIVACY_AT_CREATION_ONLY",
          message: "A shared task cannot become private",
        });
      }
      const link = await this.linkForUpdate(tx, existing.weddingPlanId, dto);
      const updated = await updateTask(tx, id, {
          ...(dto.isPrivate === false ? { privateToUserId: null } : {}),
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
          ...manualStatusPatch(current.status, dto.status),
          ...(dto.priority !== undefined ? { priority: dto.priority } : {}),
          ...(link
            ? {
                linkedBudgetCategoryId: link.linkedBudgetCategoryId,
                linkedCostId: link.linkedCostId,
                linkedScheduleId: link.linkedScheduleId,
                ...(link.settled && current.status !== WeddingTaskStatus.DONE
                  ? { status: WeddingTaskStatus.DONE, autoClosedAt: new Date() }
                  : {}),
              }
            : {}),
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
      // A private task stays with its account (V1 checklist 4.10).
      if (
        currentTask.privateToUserId &&
        assigneeUserId &&
        assigneeUserId !== currentTask.privateToUserId
      ) {
        throw new BadRequestException({
          statusCode: 400,
          code: "TASK_PRIVATE_ASSIGNMENT",
          message: "A private task is assigned only to its own account",
        });
      }
      const updated = await assignTask(tx, id, assigneeUserId);
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
          const previousMember = await this.permissions.getMembership(
            tx,
            existing.weddingPlanId,
            currentTask.assigneeUserId,
          );
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
          title: "مهمة جديدة عليك",
          body: updated.dueDate
            ? `${updated.title} · ${weekdayDayMonthWords(updated.dueDate)}`
            : updated.title,
          entityType: "task",
          entityId: updated.id,
          routeTarget: noticeRoutes.task(updated.weddingPlanId, updated.id),
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
      const created = await createChecklistItem(
        tx,
        taskId,
        this.requiredText(dto.title, "title"),
        dto.isDone ?? false,
        dto.sortOrder ?? 0,
      );
      await this.recordChecklistContribution(
        tx,
        context,
        currentTask,
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
        const result = await updateChecklistItem(tx, itemId, {
            ...(dto.title !== undefined
              ? { title: this.requiredText(dto.title, "title") }
              : {}),
            ...(dto.isDone !== undefined ? { isDone: dto.isDone } : {}),
            ...(dto.sortOrder !== undefined
              ? { sortOrder: dto.sortOrder }
              : {}),
        });
        const action =
          !currentItem.isDone && result.isDone
            ? ContributionAction.COMPLETED
            : currentItem.isDone && !result.isDone
              ? ContributionAction.REOPENED
              : ContributionAction.UPDATED;
        await this.recordChecklistContribution(tx, context, currentTask, result, action);
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
        currentTask,
        currentItem,
        ContributionAction.DELETED,
      );
      await deleteChecklistItem(tx, itemId);
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
    const today = this.startOfToday();
    const endOfToday = this.endOfToday(today);
    const rows =
      contributorScope !== null && !canManageTasks
        ? []
        : await runRetryableTransaction(
            this.prisma,
            async (tx) =>
              listLiveTasksForSummary(
                tx,
                weddingPlanId,
                currentUser.id,
                contributorScope ? [...contributorScope] : null,
                await this.permissions.liveAuthorizationFilter(
                  tx,
                  context,
                  currentUser.id,
                  ["canManageTasks"],
                ),
              ),
            { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
          );
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

    // A cancelled task is neither done nor one of the plan's tasks, as the
    // home and the tasks list count them.
    const countedTasks = tasks.length - byStatus[WeddingTaskStatus.CANCELLED];
    return {
      weddingPlanId,
      totalTasks: countedTasks,
      total: countedTasks,
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
      canKeepPrivateTask: canManageTasks && seesWholePlan(context),
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
      await deleteTask(tx, id);
    });
    return { id, deleted: true };
  }

  private async findTaskOrThrow(id: string): Promise<WeddingTask> {
    const task = await findTaskById(this.prisma, id);

    if (!task) {
      throw new NotFoundException("Task not found");
    }

    return task;
  }

  private async findChecklistItemOrThrow(
    taskId: string,
    itemId: string,
  ): Promise<WeddingTaskChecklistItem & { task: WeddingTask }> {
    const item = await findChecklistItemWithTask(this.prisma, taskId, itemId);

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
    if (!(await lockTaskForUpdate(tx, id, weddingPlanId))) {
      throw new NotFoundException("Task not found");
    }
    const task = await findTaskById(tx, id);
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
    if (!(await lockChecklistItemForUpdate(tx, taskId, itemId))) {
      throw new NotFoundException("Checklist item not found");
    }
    const item = await findChecklistItemById(tx, itemId);
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

    // The membership row is collaboration's: locked for share and read there.
    const member = await this.permissions.lockMembershipForShareInTransaction(
      tx,
      weddingPlanId,
      assigneeUserId,
    );

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
    return !seesWholePlan(context) && Boolean(context.sharedMember);
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
    // Another account's private task does not exist for the actor (V1 checklist 4.10).
    if (task.privateToUserId && task.privateToUserId !== actorUserId) {
      throw new NotFoundException("Task not found");
    }
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
    // A private task's snapshot would show it in the plan's contribution
    // history, so it is not recorded (V1 checklist 4.10).
    if (task.privateToUserId) return;
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
    if (task.privateToUserId) return;
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
    task: WeddingTask,
    item: WeddingTaskChecklistItem,
    action: ContributionAction,
  ): Promise<void> {
    if (task.privateToUserId) return;
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

  /** The account a new task is private to, or null for the shared plan (V1 checklist 4.10). */
  private privateOwnerForNewTask(
    context: PlanAccessContext,
    currentUser: AuthenticatedUser,
    isPrivate: boolean | undefined,
  ): string | null {
    if (!isPrivate) return null;
    if (!seesWholePlan(context)) {
      throw new ForbiddenException({
        statusCode: 403,
        code: "TASK_PRIVACY_NOT_ALLOWED",
        message: "Only the plan owner or partner keeps a private task",
      });
    }
    return currentUser.id;
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
    task: WeddingTask & { checklistItems: WeddingTaskChecklistItem[] },
    includeResponsiblePhone = true,
    includeMoneyLinks = true,
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
      isPrivate: task.privateToUserId !== null,
      checklist: task.checklistItems.map((item) =>
        this.toChecklistItemResponse(item),
      ),
      // They open the money, which this reader may not see.
      linkedBudgetCategoryId: includeMoneyLinks ? task.linkedBudgetCategoryId : null,
      linkedCostId: includeMoneyLinks ? task.linkedCostId : null,
      linkedScheduleId: includeMoneyLinks ? task.linkedScheduleId : null,
      autoClosedAt: task.autoClosedAt,
    };
  }

  /** R4: what a new task waits on: the one asked for, else its template's item. */
  private async linkForNewTask(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    dto: CreatePlanTaskDto,
    planPersona: string | null = null,
  ): Promise<TaskLinkValues | null> {
    if (dto.linkedBudgetCategoryId || dto.linkedScheduleId) {
      return this.resolveLink(tx, weddingPlanId, dto);
    }
    const service = dto.starterKey ? starterTaskService(dto.starterKey) : null;
    if (!service || !this.finance) return null;
    const linkedBudgetCategoryId = await this.finance.findItemForService(
      tx,
      weddingPlanId,
      service,
      planPersona,
    );
    return linkedBudgetCategoryId
      ? this.resolveLink(tx, weddingPlanId, { linkedBudgetCategoryId })
      : null;
  }

  /** R4: null when the request leaves the link as it is. */
  private async linkForUpdate(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    dto: UpdateTaskDto,
  ): Promise<TaskLinkValues | null> {
    if (
      dto.linkedBudgetCategoryId === undefined &&
      dto.linkedScheduleId === undefined
    ) {
      return null;
    }
    return this.resolveLink(tx, weddingPlanId, dto);
  }

  /** A task waits on one thing: the payment when both are named. */
  private async resolveLink(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    wanted: {
      linkedBudgetCategoryId?: string | null;
      linkedScheduleId?: string | null;
    },
  ): Promise<TaskLinkValues> {
    const scheduleId = this.optionalText(wanted.linkedScheduleId);
    if (scheduleId) {
      const schedule = await this.finance?.findPlanSchedule(
        tx,
        weddingPlanId,
        scheduleId,
      );
      if (!schedule) this.refuseLink();
      return {
        linkedBudgetCategoryId: null,
        linkedCostId: schedule.costId,
        linkedScheduleId: scheduleId,
        settled: schedule.settled,
      };
    }
    const budgetCategoryId = this.optionalText(wanted.linkedBudgetCategoryId);
    if (!budgetCategoryId) {
      return {
        linkedBudgetCategoryId: null,
        linkedCostId: null,
        linkedScheduleId: null,
        settled: false,
      };
    }
    const { finance, providers } = this;
    if (
      !finance ||
      !providers ||
      !(await finance.isPlanItem(tx, weddingPlanId, budgetCategoryId))
    ) {
      this.refuseLink();
    }
    return {
      linkedBudgetCategoryId: budgetCategoryId,
      linkedCostId: null,
      linkedScheduleId: null,
      settled: await isPlanItemBooked(
        tx,
        { providers, finance },
        weddingPlanId,
        budgetCategoryId,
      ),
    };
  }

  private refuseLink(): never {
    throw new BadRequestException({
      statusCode: 400,
      code: "TASK_LINK_NOT_IN_PLAN",
      message: "A task links to an item or a payment of its own plan",
    });
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
