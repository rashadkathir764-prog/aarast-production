import { Injectable } from '@nestjs/common';
import { Prisma, type WeddingTask, WeddingTaskStatus } from '@prisma/client';
import type {
  DueTaskQuery,
  ImportedTaskInput,
  TasksPort,
} from '../public/tasks.port';

@Injectable()
export class TasksPortService implements TasksPort {
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
        dueDate: { not: null, lte: query.dueBefore },
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
        OR: [
          { assigneeUserId: userId },
          { id: { in: [...contributedTaskIds] } },
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
