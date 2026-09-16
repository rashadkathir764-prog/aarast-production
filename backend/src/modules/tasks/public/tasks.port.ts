import type {
  Prisma,
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
export interface TasksPort {
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
