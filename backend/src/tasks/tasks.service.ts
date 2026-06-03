import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { WeddingPlan, WeddingTask, WeddingTaskPriority, WeddingTaskStatus } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';
import { OwnershipContextService } from '../auth/ownership-context.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateTaskDto } from './dto/create-task.dto';
import { UpdateTaskDto } from './dto/update-task.dto';

export interface TaskResponse {
  id: string;
  weddingPlanId: string;
  title: string;
  description: string | null;
  dueDate: Date | null;
  status: WeddingTaskStatus;
  priority: WeddingTaskPriority;
  createdAt: Date;
  updatedAt: Date;
}

@Injectable()
export class TasksService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ownershipContext: OwnershipContextService,
  ) {}

  async create(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    dto: CreateTaskDto,
  ): Promise<TaskResponse> {
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const task = await this.prisma.weddingTask.create({
      data: {
        weddingPlanId,
        title: this.requiredText(dto.title, 'title'),
        description: this.optionalText(dto.description),
        dueDate: this.optionalDate(dto.dueDate, 'dueDate'),
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
    await this.findOwnedWeddingPlanOrThrow(currentUser, weddingPlanId);

    const tasks = await this.prisma.weddingTask.findMany({
      where: { weddingPlanId },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    });

    return tasks.map((task) => this.toResponse(task));
  }

  async update(
    currentUser: AuthenticatedUser,
    id: string,
    dto: UpdateTaskDto,
  ): Promise<TaskResponse> {
    await this.findOwnedTaskOrThrow(currentUser, id);

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
        ...(dto.status !== undefined ? { status: dto.status } : {}),
        ...(dto.priority !== undefined ? { priority: dto.priority } : {}),
      },
    });

    return this.toResponse(task);
  }

  async remove(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<{ id: string; deleted: true }> {
    await this.findOwnedTaskOrThrow(currentUser, id);
    await this.prisma.weddingTask.delete({ where: { id } });
    return { id, deleted: true };
  }

  private async findOwnedTaskOrThrow(
    currentUser: AuthenticatedUser,
    id: string,
  ): Promise<WeddingTask> {
    const task = await this.prisma.weddingTask.findUnique({ where: { id } });

    if (!task) {
      throw new NotFoundException('Task not found');
    }

    await this.findOwnedWeddingPlanOrThrow(currentUser, task.weddingPlanId);
    return task;
  }

  private async findOwnedWeddingPlanOrThrow(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
  ): Promise<WeddingPlan> {
    const plan = await this.prisma.weddingPlan.findUnique({
      where: { id: weddingPlanId },
    });

    if (!plan || !this.ownershipContext.isOwner(currentUser, plan.ownerUserId)) {
      throw new NotFoundException('Wedding plan not found');
    }

    return plan;
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
      title: task.title,
      description: task.description,
      dueDate: task.dueDate,
      status: task.status,
      priority: task.priority,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    };
  }
}
