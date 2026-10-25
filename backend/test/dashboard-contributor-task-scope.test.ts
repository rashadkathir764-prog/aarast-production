import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  Prisma,
  SharedMemberRole,
  WeddingPlanStatus,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { dashboardService } from "./support/owner-ports";

const plan = {
  id: "plan-1",
  ownerUserId: "owner-1",
  title: "Plan",
  weddingDate: new Date("2027-01-01T00:00:00.000Z"),
  city: null,
  location: null,
  estimatedBudget: null,
  currency: "YER",
  status: WeddingPlanStatus.PLANNING,
  importMigrationId: null,
  createdAt: new Date("2026-01-01T00:00:00.000Z"),
  updatedAt: new Date("2026-01-01T00:00:00.000Z"),
};

const task = (
  id: string,
  assigneeUserId: string,
  privateToUserId: string | null = null,
) => ({
  id,
  weddingPlanId: plan.id,
  assigneeUserId,
  privateToUserId,
  responsibleName: null,
  responsiblePhone: null,
  responsibleSource: null,
  title: `Task ${id}`,
  description: null,
  dueDate: new Date("2020-01-01T00:00:00.000Z"),
  taskCategory: null,
  reminderAt: null,
  status: WeddingTaskStatus.TODO,
  priority: WeddingTaskPriority.HIGH,
  createdAt: new Date("2026-01-01T00:00:00.000Z"),
  updatedAt: new Date("2026-01-01T00:00:00.000Z"),
});

test("revoked task permission removes assigned task details and every dashboard task count", async () => {
  const assignedAfterRevocation = task("assigned-after-revocation", "contributor-a");
  const fixture = dashboardFixture({
    canManageTasks: false,
    tasks: [assignedAfterRevocation],
    qualifyingTaskIds: [],
  });

  const result = await fixture.service.getWeddingPlanDashboardSummary(
    { id: "contributor-a" } as any,
    plan.id,
  );

  assert.deepEqual(result.taskSummary, {
    total: 0,
    completed: 0,
    pendingInProgress: 0,
    overdue: 0,
    dueToday: 0,
  });
  assert.equal(result.totalTasks, 0);
  assert.equal(result.membershipId, "member-a");
  assert.equal(result.membershipAuthorityVersion, 1);
  assert.equal(result.nextTask, null);
  assert.equal(
    result.importantItems.some((item) => item.type.startsWith("TASK_")),
    false,
  );
  assert.equal(fixture.qualifyingCalls.length, 0);
  assert.ok(
    fixture.taskQueries.every(
      (where) => !mentionsAssignee(where, "contributor-a"),
    ),
  );
});

test("active task permission keeps assigned and historical own work while isolating contributor B", async () => {
  const assignedToA = task("assigned-a", "contributor-a");
  const previousOwnWork = task("previous-own-a", "owner-1");
  const contributorBTask = task("task-b", "contributor-b");
  const fixture = dashboardFixture({
    canManageTasks: true,
    tasks: [assignedToA, previousOwnWork, contributorBTask],
    qualifyingTaskIds: [previousOwnWork.id],
  });

  const result = await fixture.service.getWeddingPlanDashboardSummary(
    { id: "contributor-a" } as any,
    plan.id,
  );

  assert.equal(result.totalTasks, 2);
  assert.equal(result.taskSummary.total, 2);
  assert.equal(result.taskSummary.pendingInProgress, 2);
  assert.equal(result.nextTask?.id, assignedToA.id);
  const serialized = JSON.stringify(result);
  assert.equal(serialized.includes(assignedToA.id), true);
  assert.equal(serialized.includes(previousOwnWork.id), true);
  assert.equal(serialized.includes(contributorBTask.id), false);
  assert.equal(fixture.qualifyingCalls.length, 1);
  assert.deepEqual(fixture.qualifyingCalls[0], {
    weddingPlanId: plan.id,
    actorUserId: "contributor-a",
    entityTypes: [ContributionEntityType.TASK],
    actions: [
      ContributionAction.CREATED,
      ContributionAction.COMPLETED,
      ContributionAction.PAYMENT_RECORDED,
    ],
  });
});

test("a task private to another account never reaches the dashboard, even when assigned or contributed (V1 4.10)", async () => {
  const assignedToA = task("assigned-a", "contributor-a");
  const ownerPrivateAssigned = task("owner-private-assigned", "contributor-a", "owner-1");
  const ownerPrivateContributed = task("owner-private-contributed", "owner-1", "owner-1");
  const fixture = dashboardFixture({
    canManageTasks: true,
    tasks: [assignedToA, ownerPrivateAssigned, ownerPrivateContributed],
    qualifyingTaskIds: [ownerPrivateContributed.id],
  });

  const result = await fixture.service.getWeddingPlanDashboardSummary(
    { id: "contributor-a" } as any,
    plan.id,
  );

  assert.equal(result.totalTasks, 1);
  assert.equal(result.nextTask?.id, assignedToA.id);
  const serialized = JSON.stringify(result);
  assert.equal(serialized.includes("owner-private"), false);
});

test("contributor dashboard keeps owner budget private while reporting only scoped costs on the authorization transaction", async () => {
  const fixture = dashboardFixture({
    canManageTasks: false,
    tasks: [],
    qualifyingTaskIds: [],
    canViewMoney: true,
    estimatedBudget: "1000000",
    costs: [
      { id: "cost-a", totalAmount: "100", paidAmount: "40" },
      { id: "cost-b", totalAmount: "900000", paidAmount: "0" },
    ],
    qualifyingCostIds: ["cost-a"],
  });

  const result = await fixture.service.getWeddingPlanDashboardSummary(
    { id: "contributor-a" } as any,
    plan.id,
  );

  assert.equal(result.budgetTotal, null);
  assert.equal(result.remainingBudget, null);
  assert.equal(result.moneySummary.totalBudget, null);
  assert.equal(result.moneySummary.remainingBudget, null);
  assert.equal(result.moneySummary.overBudget, null);
  assert.equal(result.confirmedCostTotal, "100.00");
  assert.equal(result.paidTotal, "40.00");
  assert.equal(result.outstandingTotal, "60.00");
  assert.equal(
    result.financialWarnings.some((warning) => warning.type === "BUDGET_EXCEEDED"),
    false,
  );
  assert.equal(
    result.importantItems.some((item) => item.type === "SET_BUDGET"),
    false,
  );
  assert.equal(fixture.authorizationTx, fixture.queryTx);
  assert.equal(fixture.authorizationTx, fixture.notificationTx);
});

function dashboardFixture(input: {
  canManageTasks: boolean;
  tasks: ReturnType<typeof task>[];
  qualifyingTaskIds: string[];
  canViewMoney?: boolean;
  estimatedBudget?: string | null;
  costs?: Array<{ id: string; totalAmount: string; paidAmount: string }>;
  qualifyingCostIds?: string[];
}) {
  const taskQueries: any[] = [];
  const qualifyingCalls: Array<Record<string, unknown>> = [];
  const weddingTask = {
    findMany: async ({ where, take }: any) => {
      taskQueries.push(where);
      return matchingTasks(input.tasks, where).slice(0, take ?? input.tasks.length);
    },
    findFirst: async ({ where }: any) => {
      taskQueries.push(where);
      return matchingTasks(input.tasks, where)[0] ?? null;
    },
    count: async ({ where }: any) => {
      taskQueries.push(where);
      return matchingTasks(input.tasks, where).length;
    },
  };
  const emptyModel = new Proxy(
    {},
    {
      get: (_target, property) => async () =>
        property === "count" ? 0 : property === "findFirst" ? null : [],
    },
  );
  const weddingCost = {
    findMany: async ({ where }: any) =>
      (input.costs ?? [])
        .filter((cost) => !where.id?.in || where.id.in.includes(cost.id))
        // V1 checklist 4.10: the private-cost pre-filter, as the database
        // applies it (these fixtures hold no private cost).
        .filter(
          (cost: any) =>
            !where.privateToUserId ||
            (cost.privateToUserId != null &&
              cost.privateToUserId !== where.NOT?.privateToUserId),
        )
        .map((cost) => ({
          ...cost,
          totalAmount: new Prisma.Decimal(cost.totalAmount),
          paidAmount: new Prisma.Decimal(cost.paidAmount),
          // Every cost belongs to a budget category, as in the database.
          budgetCategory: { name: "أخرى" },
        })),
  };
  // D59: the dashboard reads finance's one money read, which counts the
  // payment ledger; each fixture cost's paid amount is one payment.
  const costPayment = {
    findMany: async ({ where }: any) =>
      (input.costs ?? [])
        .filter(
          (cost) =>
            !where.weddingCost?.id?.in || where.weddingCost.id.in.includes(cost.id),
        )
        .filter((cost) => new Prisma.Decimal(cost.paidAmount).gt(0))
        .map((cost) => ({
          weddingCostId: cost.id,
          amount: new Prisma.Decimal(cost.paidAmount),
          entryType: "PAYMENT",
        })),
  };
  const tx = new Proxy(
    { weddingTask, weddingCost, costPayment } as Record<string, unknown>,
    {
      get: (target, property: string) => target[property] ?? emptyModel,
    },
  );
  let authorizationTx: unknown;
  let queryTx: unknown;
  let notificationTx: unknown;
  const prisma = new Proxy(
    {
      weddingTask,
      weddingCost,
      $transaction: async (operation: (client: unknown) => Promise<unknown>) =>
        operation(tx as any),
    } as Record<string, unknown>,
    {
      get: (target, property: string) => target[property] ?? emptyModel,
    },
  );
  const sharedMember = {
    id: "member-a",
    weddingPlanId: plan.id,
    userId: "contributor-a",
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: input.canViewMoney ?? false,
    canManageMoney: false,
    canManageTasks: input.canManageTasks,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canEditPlan: false,
    receiveNotifications: true,
    authorityVersion: 1,
    createdAt: new Date("2026-01-01T00:00:00.000Z"),
    updatedAt: new Date("2026-01-01T00:00:00.000Z"),
  };
  const permissions = {
    assertPlanReadable: async () => ({
      plan,
      isOwner: false,
      sharedMember,
    }),
    assertPlanReadableInTransaction: async (client: unknown) => {
      authorizationTx = client;
      return {
        plan: {
          ...plan,
          estimatedBudget:
            input.estimatedBudget === undefined || input.estimatedBudget === null
              ? null
              : { toString: () => input.estimatedBudget },
        },
        isOwner: false,
        sharedMember,
      };
    },
    canViewMoney: () => input.canViewMoney ?? false,
    canManageMoney: () => false,
    canManageTasks: () => input.canManageTasks,
    canManageGuests: () => false,
    canManageProviders: () => false,
    canManageMembers: () => false,
    canManagePlan: () => false,
  };
  const contributorScope = {
    qualifyingEntityIds: async (
      weddingPlanId: string,
      actorUserId: string,
      entityTypes: ContributionEntityType[],
      actions: ContributionAction[],
    ) => {
      qualifyingCalls.push({
        weddingPlanId,
        actorUserId,
        entityTypes,
        actions,
      });
      return entityTypes.includes(ContributionEntityType.TASK)
        ? input.qualifyingTaskIds
        : entityTypes.includes(ContributionEntityType.WEDDING_COST)
          ? input.qualifyingCostIds ?? []
          : [];
    },
    qualifyingEntityIdsInTransaction: async (
      client: unknown,
      weddingPlanId: string,
      actorUserId: string,
      entityTypes: ContributionEntityType[],
      actions: ContributionAction[],
    ) => {
      queryTx = client;
      return contributorScope.qualifyingEntityIds(
        weddingPlanId,
        actorUserId,
        entityTypes,
        actions,
      );
    },
  };
  const service = dashboardService(
    prisma as any,
    permissions as any,
    {
      visibilityWhereForUser: async (
        _userId: string,
        client: unknown,
      ) => {
        notificationTx = client;
        return null;
      },
    } as any,
    contributorScope as any,
    { summary: async () => ({}) } as any,
  );
  return {
    service,
    taskQueries,
    qualifyingCalls,
    get authorizationTx() {
      return authorizationTx;
    },
    get queryTx() {
      return queryTx;
    },
    get notificationTx() {
      return notificationTx;
    },
  };
}

function matchingTasks(tasks: ReturnType<typeof task>[], where: any) {
  return tasks.filter((candidate) => {
    if (candidate.weddingPlanId !== where.weddingPlanId) return false;
    if (!matchesVisibility(candidate, where)) return false;
    if (where.status && !matchesStatus(candidate.status, where.status)) return false;
    if (where.dueDate && !matchesDate(candidate.dueDate, where.dueDate)) return false;
    return true;
  });
}

// Evaluates the visibility part of a task where: id lists, assignee and
// privacy equality, and nested AND / OR, as Prisma would.
function matchesVisibility(candidate: ReturnType<typeof task>, where: any): boolean {
  if (where.id?.in && !where.id.in.includes(candidate.id)) return false;
  if ("assigneeUserId" in where && where.assigneeUserId !== candidate.assigneeUserId) {
    return false;
  }
  if ("privateToUserId" in where && where.privateToUserId !== candidate.privateToUserId) {
    return false;
  }
  if (where.AND && !where.AND.every((clause: any) => matchesVisibility(candidate, clause))) {
    return false;
  }
  if (where.OR && !where.OR.some((clause: any) => matchesVisibility(candidate, clause))) {
    return false;
  }
  return true;
}

function mentionsAssignee(where: any, userId: string): boolean {
  if (!where || typeof where !== "object") return false;
  if (where.assigneeUserId === userId) return true;
  return [...(where.AND ?? []), ...(where.OR ?? [])].some((clause: any) =>
    mentionsAssignee(clause, userId),
  );
}

function matchesStatus(status: WeddingTaskStatus, where: any) {
  if (typeof where === "string") return status === where;
  if (where.in && !where.in.includes(status)) return false;
  if (where.notIn && where.notIn.includes(status)) return false;
  return true;
}

function matchesDate(date: Date | null, where: any) {
  if (!date) return false;
  if (where.lt && !(date < where.lt)) return false;
  if (where.lte && !(date <= where.lte)) return false;
  if (where.gte && !(date >= where.gte)) return false;
  return true;
}
