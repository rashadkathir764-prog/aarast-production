import { Prisma, WeddingTaskPriority, WeddingTaskStatus } from '@prisma/client';
import type { LiveAuthorizationFilter } from '../../collaboration/public/collaboration-permission.port';
import { ListQueryDto, pageArgs } from '../../../platform/http/list-query.dto';
import { PrismaService } from '../../../platform/database/prisma.service';

export interface TaskCreateValues {
  weddingPlanId: string;
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
}

/** Every task row a response is built from carries its checklist in order. */
const withChecklist = {
  checklistItems: {
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
  },
} satisfies Prisma.WeddingTaskInclude;

export function createTask(tx: Prisma.TransactionClient, values: TaskCreateValues) {
  return tx.weddingTask.create({
    include: withChecklist,
    data: {
      weddingPlanId: values.weddingPlanId,
      assigneeUserId: null,
      responsibleName: values.responsibleName,
      responsiblePhone: values.responsiblePhone,
      responsibleSource: values.responsibleSource,
      title: values.title,
      description: values.description,
      dueDate: values.dueDate,
      taskCategory: values.taskCategory,
      reminderAt: values.reminderAt,
      status: values.status,
      priority: values.priority,
    },
  });
}

function scopedTaskWhere(
  weddingPlanId: string,
  actorUserId: string,
  contributorIds: readonly string[] | null,
  liveFilter: LiveAuthorizationFilter,
  id?: string,
) {
  return {
    ...(id ? { id } : {}),
    weddingPlanId,
    ...(contributorIds
      ? {
          OR: [
            { assigneeUserId: actorUserId },
            { id: { in: [...contributorIds] } },
          ],
        }
      : {}),
    ...liveFilter,
  };
}

export function listLivePlanTasks(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  actorUserId: string,
  contributorIds: readonly string[] | null,
  liveFilter: LiveAuthorizationFilter,
  query?: ListQueryDto,
) {
  return tx.weddingTask.findMany({
    where: scopedTaskWhere(weddingPlanId, actorUserId, contributorIds, liveFilter),
    include: withChecklist,
    orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    ...pageArgs(query),
  });
}

export function findLivePlanTask(
  tx: Prisma.TransactionClient,
  id: string,
  weddingPlanId: string,
  actorUserId: string,
  contributorIds: readonly string[] | null,
  liveFilter: LiveAuthorizationFilter,
) {
  return tx.weddingTask.findFirst({
    where: scopedTaskWhere(weddingPlanId, actorUserId, contributorIds, liveFilter, id),
    include: withChecklist,
  });
}

export function listLiveTasksForSummary(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  actorUserId: string,
  contributorIds: readonly string[] | null,
  liveFilter: LiveAuthorizationFilter,
) {
  return tx.weddingTask.findMany({
    where: scopedTaskWhere(weddingPlanId, actorUserId, contributorIds, liveFilter),
  });
}

export interface TaskUpdateValues {
  title?: string;
  description?: string | null;
  dueDate?: Date | null;
  taskCategory?: string | null;
  responsibleName?: string | null;
  responsiblePhone?: string | null;
  responsibleSource?: string | null;
  assigneeUserId?: string | null;
  reminderAt?: Date | null;
  status?: WeddingTaskStatus;
  priority?: WeddingTaskPriority;
}

export function updateTask(tx: Prisma.TransactionClient, id: string, values: TaskUpdateValues) {
  return tx.weddingTask.update({
    where: { id },
    include: withChecklist,
    data: {
      ...(values.title !== undefined ? { title: values.title } : {}),
      ...(values.description !== undefined ? { description: values.description } : {}),
      ...(values.dueDate !== undefined ? { dueDate: values.dueDate } : {}),
      ...(values.taskCategory !== undefined ? { taskCategory: values.taskCategory } : {}),
      ...(values.responsibleName !== undefined ? { responsibleName: values.responsibleName } : {}),
      ...(values.responsiblePhone !== undefined ? { responsiblePhone: values.responsiblePhone } : {}),
      ...(values.responsibleSource !== undefined ? { responsibleSource: values.responsibleSource } : {}),
      ...(values.assigneeUserId !== undefined ? { assigneeUserId: values.assigneeUserId } : {}),
      ...(values.reminderAt !== undefined ? { reminderAt: values.reminderAt } : {}),
      ...(values.status !== undefined ? { status: values.status } : {}),
      ...(values.priority !== undefined ? { priority: values.priority } : {}),
    },
  });
}

export function assignTask(tx: Prisma.TransactionClient, id: string, assigneeUserId: string | null) {
  return tx.weddingTask.update({
    where: { id },
    include: withChecklist,
    data: {
      assigneeUserId,
      ...(assigneeUserId
        ? { responsibleName: null, responsiblePhone: null, responsibleSource: null }
        : {}),
    },
  });
}

export function createChecklistItem(
  tx: Prisma.TransactionClient,
  taskId: string,
  title: string,
  isDone: boolean,
  sortOrder: number,
) {
  return tx.weddingTaskChecklistItem.create({
    data: { taskId, title, isDone, sortOrder },
  });
}

export function updateChecklistItem(
  tx: Prisma.TransactionClient,
  id: string,
  values: { title?: string; isDone?: boolean; sortOrder?: number },
) {
  return tx.weddingTaskChecklistItem.update({
    where: { id },
    data: {
      ...(values.title !== undefined ? { title: values.title } : {}),
      ...(values.isDone !== undefined ? { isDone: values.isDone } : {}),
      ...(values.sortOrder !== undefined ? { sortOrder: values.sortOrder } : {}),
    },
  });
}

export function deleteChecklistItem(tx: Prisma.TransactionClient, id: string) {
  return tx.weddingTaskChecklistItem.delete({ where: { id } });
}

export function deleteTask(tx: Prisma.TransactionClient, id: string) {
  return tx.weddingTask.delete({ where: { id } });
}

export function findTaskById(client: PrismaService | Prisma.TransactionClient, id: string) {
  return client.weddingTask.findUnique({ where: { id } });
}

export function findChecklistItemWithTask(
  client: PrismaService,
  taskId: string,
  itemId: string,
) {
  return client.weddingTaskChecklistItem.findFirst({
    where: { id: itemId, taskId },
    include: { task: true },
  });
}

export async function lockTaskForUpdate(
  tx: Prisma.TransactionClient,
  id: string,
  weddingPlanId: string,
): Promise<boolean> {
  const locked = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "WeddingTask"
      WHERE "id" = ${id}
        AND "weddingPlanId" = ${weddingPlanId}
      FOR UPDATE
    `,
  );
  return locked.length === 1;
}

export async function lockChecklistItemForUpdate(
  tx: Prisma.TransactionClient,
  taskId: string,
  itemId: string,
): Promise<boolean> {
  const locked = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "WeddingTaskChecklistItem"
      WHERE "id" = ${itemId}
        AND "taskId" = ${taskId}
      FOR UPDATE
    `,
  );
  return locked.length === 1;
}

export function findChecklistItemById(tx: Prisma.TransactionClient, id: string) {
  return tx.weddingTaskChecklistItem.findUnique({ where: { id } });
}
