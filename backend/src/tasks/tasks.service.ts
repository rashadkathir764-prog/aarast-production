import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import {
  WeddingTask,
  WeddingTaskChecklistItem,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { PrismaService } from '../prisma/prisma.service';
import { PermissionService } from '../sharing/permission.service';
import { AssignTaskDto } from './dto/assign-task.dto';
import { CreateChecklistItemDto } from './dto/create-checklist-item.dto';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateChecklistItemDto } from './dto/update-checklist-item.dto';
import { UpdateTaskDto } from './dto/update-task.dto';

export interface TaskResponse {
  id: string;
  weddingPlanId: string;
  assigneeUserId: string | null;
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
  completedTasks: number;
  openTasks: number;
  overdueTasks: number;
  todayTasks: number;
  assignedToMe: number;
  byStatus: Record<WeddingTaskStatus, number>;
  byPriority: Record<WeddingTaskPriority, number>;
}

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly permissions: PermissionService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateTaskDto,
  ): Promise<TaskResponse> {
    await this.permissions.assertTaskManageable(weddingPlanId, currentUser);

    const task = await this.prisma.weddingTask.create({
      data: {
        weddingPlanId,
        assigneeUserId: null,
        title: this.requiredText(dto.title, 'title'),
        description: this.optionalText(dto.description),
        dueDate: this.optionalDate(dto.dueDate, 'dueDate'),
        taskCategory: this.optionalText(dto.taskCategory),
        reminderAt: this.optionalDate(dto.reminderAt, 'reminderAt'),
        status: dto.status ?? WeddingTaskStatus.TODO,
        priority: dto.priority ?? WeddingTaskPriority.MEDIUM,
      },
    });

    return this.toResponse(task);
  }

  async findForPlan(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<TaskResponse[]> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);

    const tasks = await this.prisma.weddingTask.findMany({
      where: { weddingPlanId },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    });

    return tasks.map((task) => this.toResponse(task));
  }

  async findOne(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<TaskResponse> {
    const task = await this.findTaskOrThrow(id);
    await this.permissions.assertPlanReadable(task.weddingPlanId, currentUser);
    return this.toResponse(task);
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateTaskDto,
  ): Promise<TaskResponse> {
    const existing = await this.findTaskOrThrow(id);
    await this.permissions.assertTaskManageable(existing.weddingPlanId, currentUser);

    const task = await this.prisma.weddingTask.update({
      where: { id },
      data: {
        ...(dto.title !== undefined
          ? { title: this.requiredText(dto.title, 'title') }
          : {}),
        ...(dto.description !== undefined
          ? { description: this.optionalText(dto.description) }
          : {}),
        ...(dto.dueDate !== undefined
          ? { dueDate: this.optionalDate(dto.dueDate, 'dueDate') }
          : {}),
        ...(dto.taskCategory !== undefined
          ? { taskCategory: this.optionalText(dto.taskCategory) }
          : {}),
        ...(dto.reminderAt !== undefined
          ? { reminderAt: this.optionalDate(dto.reminderAt, 'reminderAt') }
          : {}),
        ...(dto.status !== undefined ? { status: dto.status } : {}),
        ...(dto.priority !== undefined ? { priority: dto.priority } : {}),
      },
    });

    return this.toResponse(task);
  }

  async assign(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AssignTaskDto,
  ): Promise<TaskResponse> {
    const existing = await this.findTaskOrThrow(id);
    await this.permissions.assertTaskManageable(existing.weddingPlanId, currentUser);
    const assigneeUserId = this.optionalText(dto.assigneeUserId);

    if (assigneeUserId) {
      await this.assertAssigneeBelongsToPlan(existing.weddingPlanId, assigneeUserId);
    }

    const task = await this.prisma.weddingTask.update({
      where: { id },
      data: { assigneeUserId },
    });

    return this.toResponse(task);
  }

  async createChecklistItem(
    currentUser: AuthenticatedUser,
    taskId: string,
    dto: CreateChecklistItemDto,
  ): Promise<ChecklistItemResponse> {
    const task = await this.findTaskOrThrow(taskId);
    await this.permissions.assertTaskManageable(task.weddingPlanId, currentUser);

    const item = await this.prisma.weddingTaskChecklistItem.create({
      data: {
        taskId,
        title: this.requiredText(dto.title, 'title'),
        isDone: dto.isDone ?? false,
        sortOrder: dto.sortOrder ?? 0,
      },
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
    await this.permissions.assertTaskManageable(
      item.task.weddingPlanId,
      currentUser,
    );

    const updated = await this.prisma.weddingTaskChecklistItem.update({
      where: { id: itemId },
      data: {
        ...(dto.title !== undefined
          ? { title: this.requiredText(dto.title, 'title') }
          : {}),
        ...(dto.isDone !== undefined ? { isDone: dto.isDone } : {}),
        ...(dto.sortOrder !== undefined ? { sortOrder: dto.sortOrder } : {}),
      },
    });

    return this.toChecklistItemResponse(updated);
  }

  async removeChecklistItem(
    currentUser: AuthenticatedUser,
    taskId: string,
    itemId: string,
  ): Promise<{ id: string; deleted: true }> {
    const item = await this.findChecklistItemOrThrow(taskId, itemId);
    await this.permissions.assertTaskManageable(
      item.task.weddingPlanId,
      currentUser,
    );
    await this.prisma.weddingTaskChecklistItem.delete({ where: { id: itemId } });
    return { id: itemId, deleted: true };
  }

  async summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<TaskSummaryResponse> {
    await this.permissions.assertPlanReadable(weddingPlanId, currentUser);

    const today = this.startOfToday();
    const endOfToday = this.endOfToday(today);
    const tasks = await this.prisma.weddingTask.findMany({
      where: { weddingPlanId },
    });

    const byStatus = this.emptyStatusCounts();
    const byPriority = this.emptyPriorityCounts();
    let completedTasks = 0;
    let overdueTasks = 0;
    let todayTasks = 0;
    let assignedToMe = 0;

    for (const task of tasks) {
      byStatus[task.status]++;
      byPriority[task.priority]++;
      if (task.status === WeddingTaskStatus.DONE) completedTasks++;
      if (task.assigneeUserId === currentUser.id) assignedToMe++;
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
      completedTasks,
      openTasks: tasks.filter(
        (task) =>
          task.status !== WeddingTaskStatus.DONE &&
          task.status !== WeddingTaskStatus.CANCELLED,
      ).length,
      overdueTasks,
      todayTasks,
      assignedToMe,
      byStatus,
      byPriority,
    };
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    const existing = await this.findTaskOrThrow(id);
    await this.permissions.assertTaskManageable(existing.weddingPlanId, currentUser);
    await this.prisma.weddingTask.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findTaskOrThrow(
    id: string,
  ): Promise<WeddingTask> {
    const task = await this.prisma.weddingTask.findUnique({ where: { id } });

    if (!task) {
      throw new NotFoundException('Task not found');
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
      throw new NotFoundException('Checklist item not found');
    }

    return item;
  }

  private async assertAssigneeBelongsToPlan(
    weddingPlanId: string,
    assigneeUserId: string,
  ): Promise<void> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
      select: { ownerUserId: true },
    });

    if (plan?.ownerUserId === assigneeUserId) return;

    const member = await this.prisma.sharedMember.findUnique({
      where: {
        weddingPlanId_userId: {
          weddingPlanId,
          userId: assigneeUserId,
        },
      },
    });

    if (!member) {
      throw new BadRequestException('assigneeUserId must belong to the plan');
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

  private optionalDate(value: string | null | undefined, field: string): Date | null {
    if (value === undefined || value === null) return null;
    const trimmed = value.trim();
    if (!trimmed) return null;

    const timestamp = Date.parse(trimmed);
    if (Number.isNaN(timestamp)) {
      throw new BadRequestException(`${field} must be a valid ISO date string`);
    }
    return new Date(timestamp);
  }

  private toResponse(task: WeddingTask): TaskResponse {
    return {
      id: task.id,
      weddingPlanId: task.weddingPlanId,
      assigneeUserId: task.assigneeUserId,
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
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), now.getDate());
  }

  private endOfToday(today: Date): Date {
    const end = new Date(today);
    end.setHours(23, 59, 59, 999);
    return end;
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
