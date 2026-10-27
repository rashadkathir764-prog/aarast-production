import { Injectable } from '@nestjs/common';
import { Prisma, type WeddingTask, WeddingTaskStatus } from '@prisma/client';
import type {
  DueTaskQuery,
  ImportedTaskInput,
  PlanTaskDashboard,
  ReadableTask,
  TaskReadScope,
  TasksPort,
} from '../public/tasks.port';
import { visibleToReader } from './task-work.repository';

const openStatuses = () => ({
  notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
});

function scopeWhere(scope: TaskReadScope) {
  switch (scope.kind) {
    case 'all':
      return visibleToReader(scope.readerUserId);
    case 'none':
      return { id: { in: [] as string[] } };
    case 'contributor':
      return {
        AND: [
          visibleToReader(scope.assigneeUserId),
          {
            OR: [
              { assigneeUserId: scope.assigneeUserId },
              { id: { in: [...scope.taskIds] } },
            ],
          },
        ],
      };
  }
}

@Injectable()
export class TasksPortService implements TasksPort {
  async listReadableTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    readerUserId: string,
  ): Promise<ReadableTask[]> {
    return client.weddingTask.findMany({
      where: {
        weddingPlanId,
        status: { not: WeddingTaskStatus.CANCELLED },
        ...visibleToReader(readerUserId),
      },
      select: {
        id: true,
        title: true,
        status: true,
        dueDate: true,
        assigneeUserId: true,
        responsibleName: true,
      },
      orderBy: [
        { dueDate: { sort: 'asc', nulls: 'last' } },
        { createdAt: 'asc' },
        { id: 'asc' },
      ],
    });
  }

  async listUpcomingTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    take: number,
    readerUserId: string,
  ): Promise<WeddingTask[]> {
    return client.weddingTask.findMany({
      where: { weddingPlanId, status: openStatuses(), ...visibleToReader(readerUserId) },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
      take,
    });
  }

  async getPlanTaskDashboard(
    client: Prisma.TransactionClient,
    input: {
      weddingPlanId: string;
      scope: TaskReadScope;
      today: Date;
      endOfToday: Date;
    },
  ): Promise<PlanTaskDashboard> {
    const base = { weddingPlanId: input.weddingPlanId, ...scopeWhere(input.scope) };
    const [urgentTasks, nextTask, totalTasks, completedTasks, openTasks, overdueTasks, todayTasks] =
      await Promise.all([
        client.weddingTask.findMany({
          where: { ...base, dueDate: { lte: input.endOfToday }, status: openStatuses() },
          orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
          take: 2,
        }),
        client.weddingTask.findFirst({
          where: { ...base, status: openStatuses() },
          orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
        }),
        client.weddingTask.count({ where: base }),
        client.weddingTask.count({ where: { ...base, status: WeddingTaskStatus.DONE } }),
        client.weddingTask.count({
          where: { ...base, status: { in: [WeddingTaskStatus.TODO, WeddingTaskStatus.IN_PROGRESS] } },
        }),
        client.weddingTask.count({
          where: { ...base, dueDate: { lt: input.today }, status: openStatuses() },
        }),
        client.weddingTask.count({
          where: { ...base, dueDate: { gte: input.today, lte: input.endOfToday }, status: openStatuses() },
        }),
      ]);
    return { urgentTasks, nextTask, totalTasks, completedTasks, openTasks, overdueTasks, todayTasks };
  }

  async listDatedOpenTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scope: TaskReadScope,
  ): Promise<WeddingTask[]> {
    return client.weddingTask.findMany({
      where: {
        weddingPlanId,
        dueDate: { not: null },
        status: openStatuses(),
        ...scopeWhere(scope),
      },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    });
  }

  async listAssignedTasks(
    client: Prisma.TransactionClient,
    userId: string,
    weddingPlanIds: readonly string[],
  ): Promise<Array<Pick<WeddingTask, 'id' | 'weddingPlanId'>>> {
    if (weddingPlanIds.length === 0) return [];
    return client.weddingTask.findMany({
      where: {
        weddingPlanId: { in: [...weddingPlanIds] },
        assigneeUserId: userId,
      },
      select: { id: true, weddingPlanId: true },
    });
  }

  async listDueTasks(
    client: Prisma.TransactionClient,
    query: DueTaskQuery,
  ): Promise<WeddingTask[]> {
    if (query.weddingPlanIds.length === 0 || query.taskIds?.length === 0) {
      return [];
    }
    return client.weddingTask.findMany({
      where: {
        ...(query.taskIds ? { id: { in: [...query.taskIds] } } : {}),
        weddingPlanId: { in: [...query.weddingPlanIds] },
        OR: [
          { dueDate: { not: null, lte: query.dueBefore } },
          ...(query.reminderWindow
            ? [
                {
                  reminderAt: {
                    gte: query.reminderWindow.from,
                    lte: query.reminderWindow.to,
                  },
                },
              ]
            : []),
        ],
        status: {
          notIn: [WeddingTaskStatus.DONE, WeddingTaskStatus.CANCELLED],
        },
      },
    });
  }

  async lockTaskForShareInTransaction(
    tx: Prisma.TransactionClient,
    taskId: string,
    weddingPlanId: string,
  ): Promise<WeddingTask | null> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingTask"
        WHERE "id" = ${taskId}
          AND "weddingPlanId" = ${weddingPlanId}
        FOR SHARE
      `,
    );
    if (rows.length !== 1) return null;
    const task = await tx.weddingTask.findUnique({ where: { id: taskId } });
    return task && task.weddingPlanId === weddingPlanId ? task : null;
  }

  async lockTaskRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    taskIds: readonly string[],
  ): Promise<void> {
    const sortedIds = [...new Set(taskIds)].sort();
    if (sortedIds.length === 0) return;
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingTask"
        WHERE "id" = ANY(${sortedIds}::text[])
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
  }

  async isTaskVisibleToContributor(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    taskId: string,
    userId: string,
    contributedTaskIds: readonly string[],
  ): Promise<boolean> {
    const task = await client.weddingTask.findFirst({
      where: {
        id: taskId,
        weddingPlanId,
        AND: [
          visibleToReader(userId),
          {
            OR: [
              { assigneeUserId: userId },
              { id: { in: [...contributedTaskIds] } },
            ],
          },
        ],
      },
      select: { id: true },
    });
    return task !== null;
  }

  async createImportedTasksInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    tasks: readonly ImportedTaskInput[],
  ): Promise<void> {
    if (tasks.length === 0) return;
    await tx.weddingTask.createMany({
      data: tasks.map((task) => ({ weddingPlanId, ...task })),
    });
  }

  async countPlanTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<number> {
    return client.weddingTask.count({ where: { weddingPlanId } });
  }

  async deletePlanTasksInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    await tx.weddingTask.deleteMany({
      where: { weddingPlanId: { in: [...weddingPlanIds] } },
    });
  }

  async deletePrivateTasksInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    const tasks = await tx.weddingTask.findMany({
      where: { privateToUserId: userId },
      select: { id: true },
    });
    if (tasks.length === 0) return;
    await tx.weddingTask.deleteMany({
      where: { id: { in: tasks.map((task) => task.id) } },
    });
  }

  async unassignUserTasksInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.weddingTask.updateMany({
      where: { assigneeUserId: userId },
      data: { assigneeUserId: null },
    });
  }
}
