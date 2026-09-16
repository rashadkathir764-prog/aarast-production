import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import type { ImportedTaskInput, TasksPort } from '../public/tasks.port';

@Injectable()
export class TasksPortService implements TasksPort {
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
