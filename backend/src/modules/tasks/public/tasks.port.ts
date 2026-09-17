import type {
  Prisma,
  WeddingTask,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from '@prisma/client';

export const TASKS_PORT = Symbol('TASKS_PORT');

export interface ImportedTaskInput {
  title: string;
  description: string | null;
  dueDate: Date | null;
  taskCategory: string | null;
  reminderAt: Date | null;
  status: WeddingTaskStatus;
  priority: WeddingTaskPriority;
}

// Tasks owns `WeddingTask` and `WeddingTaskChecklistItem`. Planning's local
// plan import creates the imported tasks through this port inside its
// transaction and reports their count.
/** The task rows a reminder scan walks: due at or before `dueBefore`, not done, not cancelled. */
export interface DueTaskQuery {
  weddingPlanIds: readonly string[];
  dueBefore: Date;
  /** Narrows to these tasks (the re-read under the row locks). */
  taskIds?: readonly string[];
}

export interface TasksPort {
  /** The tasks assigned to the user in the given plans. */
  listAssignedTasks(
    client: Prisma.TransactionClient,
    userId: string,
    weddingPlanIds: readonly string[],
  ): Promise<Array<Pick<WeddingTask, 'id' | 'weddingPlanId'>>>;
  listDueTasks(
    client: Prisma.TransactionClient,
    query: DueTaskQuery,
  ): Promise<WeddingTask[]>;
  /** Locks the task row (of that plan) for share and returns it. */
  lockTaskForShareInTransaction(
    tx: Prisma.TransactionClient,
    taskId: string,
    weddingPlanId: string,
  ): Promise<WeddingTask | null>;
  /** Locks the task rows for share in id order. */
  lockTaskRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    taskIds: readonly string[],
  ): Promise<void>;
  /** Whether the plan's task is assigned to the user or is one of the given tasks. */
  isTaskVisibleToContributor(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    taskId: string,
    userId: string,
    contributedTaskIds: readonly string[],
  ): Promise<boolean>;
  createImportedTasksInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    tasks: readonly ImportedTaskInput[],
  ): Promise<void>;
  countPlanTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<number>;
  /** Account erasure: deletes the plans' tasks (checklist items cascade). */
  deletePlanTasksInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  /** Retained administrator identity: clears the user from the tasks assigned to them. */
  unassignUserTasksInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
}
