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
  /**
   * G36: also the open tasks whose own «ذكّرني» time fell in this window,
   * whatever their due date.
   */
  reminderWindow?: { from: Date; to: Date };
}

/**
 * Which of a plan's tasks a reader sees: all (owner or partner), none
 * (revoked), or the contributor's own work. Never another account's private
 * task (V1 checklist 4.10).
 */
export type TaskReadScope =
  | { kind: 'all'; readerUserId: string }
  | { kind: 'none' }
  | { kind: 'contributor'; assigneeUserId: string; taskIds: readonly string[] };

export interface PlanTaskDashboard {
  urgentTasks: WeddingTask[];
  nextTask: WeddingTask | null;
  totalTasks: number;
  completedTasks: number;
  openTasks: number;
  overdueTasks: number;
  todayTasks: number;
}

/**
 * A task as every plan member reads it (D52): what it is, where it stands,
 * when it is due and who does it. Never its description (it may carry an
 * amount), its checklist or the responsible person's phone.
 */
export type ReadableTask = Pick<
  WeddingTask,
  'id' | 'title' | 'status' | 'dueDate' | 'assigneeUserId' | 'responsibleName'
>;

/** R4: what a task waits on: a money item, or one payment. */
export type TaskLink = { budgetCategoryId: string } | { scheduleId: string };

export interface TasksPort {
  /**
   * R4: the link settled (the item booked, the payment paid): its open tasks
   * close. Unsettled: the tasks it closed reopen, never one closed by hand.
   */
  syncLinkedTasks(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    link: TaskLink,
    settled: boolean,
    at?: Date,
  ): Promise<void>;
  /** R4: the item or the payment is gone: its tasks stay, without the link. */
  unlinkTasks(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    link: TaskLink,
  ): Promise<void>;
  /** D52: the plan's tasks every member reads (not cancelled, never another account's private task), in due order. */
  listReadableTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    readerUserId: string,
  ): Promise<ReadableTask[]>;
  /** The plan's open tasks the reader sees, in due order, at most `take` (the home dashboard). */
  listUpcomingTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    take: number,
    readerUserId: string,
  ): Promise<WeddingTask[]>;
  /** The plan dashboard's task counters and its two urgent tasks and next task, inside the reader's scope. */
  getPlanTaskDashboard(
    client: Prisma.TransactionClient,
    input: {
      weddingPlanId: string;
      scope: TaskReadScope;
      today: Date;
      endOfToday: Date;
    },
  ): Promise<PlanTaskDashboard>;
  /** The plan's dated open tasks in due order, inside the reader's scope (the timeline). */
  listDatedOpenTasks(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scope: TaskReadScope,
  ): Promise<WeddingTask[]>;
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
  /** Account erasure (V1 checklist 4.10): the account's private tasks in other plans go with it (checklist items cascade). */
  deletePrivateTasksInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
  /** Retained administrator identity: clears the user from the tasks assigned to them. */
  unassignUserTasksInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
}
