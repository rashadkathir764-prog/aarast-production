import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionEntityType,
  NotificationPriority,
  NotificationType,
  UserStatus,
} from "@prisma/client";
import { NotificationsService } from "../src/notifications/notifications.service";
import { OutboxService } from "../src/platform/outbox/outbox.service";

const now = new Date("2026-08-02T00:00:00.000Z");

function notificationRow(
  entityType: "task" | "payment_schedule",
  entityId: string,
) {
  return {
    id: `notification-${entityId}`,
    userId: "contributor-1",
    weddingPlanId: "plan-1",
    type:
      entityType === "task"
        ? NotificationType.TASK_DUE_SOON
        : NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
    priority: NotificationPriority.NORMAL,
    title: "Scoped reminder",
    body: "Must not leak after the live scope changes.",
    entityType,
    entityId,
    routeTarget: "/hidden",
    data: null,
    dedupeKey: null,
    readAt: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
  };
}

function directReadHarness(
  row: ReturnType<typeof notificationRow>,
  options: {
    qualifyingEntityIds?: string[];
    onContributionWhere?: (where: unknown) => void;
  } = {},
) {
  const qualifyingEntityIds = options.qualifyingEntityIds ?? [];
  const prisma = {
    notification: {
      findFirst: async ({ where }: { where: { id: string; userId: string } }) =>
        where.id === row.id && where.userId === row.userId ? row : null,
    },
    provider: { findUnique: async () => null },
    conversation: { findUnique: async () => null },
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        options.onContributionWhere?.(where);
        return qualifyingEntityIds.map((entityId) => ({ entityId }));
      },
    },
    weddingTask: {
      findFirst: async () =>
        qualifyingEntityIds.includes(row.entityId) ? { id: row.entityId } : null,
    },
    paymentSchedule: {
      findFirst: async () =>
        qualifyingEntityIds.includes(row.entityId) ? { id: row.entityId } : null,
    },
    $transaction: async (operation: (tx: unknown) => unknown) =>
      operation(prisma),
  };
  const permissions = {
    assertPlanReadable: async () => ({
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: false,
      sharedMember: {
        id: "member-1",
        weddingPlanId: "plan-1",
        userId: "contributor-1",
        canManageTasks: true,
        canViewMoney: true,
      },
    }),
    assertPlanReadableInTransaction: async () => ({
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: false,
      sharedMember: {
        id: "member-1",
        weddingPlanId: "plan-1",
        userId: "contributor-1",
        canManageTasks: true,
        canViewMoney: true,
      },
    }),
    canManageTasks: () => true,
    canViewMoney: () => true,
  };
  const contributorScope = {
    qualifyingEntityIds: async () => [],
    qualifyingEntityIdsInTransaction: async () => [],
  };
  const service = new (NotificationsService as any)(
    prisma,
    permissions,
    new OutboxService(),
    contributorScope,
  ) as NotificationsService;
  return { service };
}

test("direct task notification reads reject a stale row outside the contributor live scope", async () => {
  const row = notificationRow("task", "task-owned-by-another-contributor");
  const { service } = directReadHarness(row);

  await assert.rejects(
    () => service.findOne({ id: row.userId } as any, row.id),
    /Notification not found/,
  );
});

test("direct payment notification reads reject a schedule whose cost is outside contributor scope", async () => {
  const row = notificationRow("payment_schedule", "schedule-for-another-cost");
  const { service } = directReadHarness(row);

  await assert.rejects(
    () => service.findOne({ id: row.userId } as any, row.id),
    /Notification not found/,
  );
});

test("direct reads accept qualifying contributions from a previous tenure when membership and permission are current", async () => {
  const row = notificationRow("task", "task-from-previous-tenure");
  let contributionWhere: unknown;
  const { service } = directReadHarness(row, {
    qualifyingEntityIds: [row.entityId],
    onContributionWhere: (where) => {
      contributionWhere = where;
    },
  });

  const result = await service.findOne({ id: row.userId } as any, row.id);

  assert.equal(result.id, row.id);
  assert.doesNotMatch(JSON.stringify(contributionWhere), /endedAt/);
});

test("direct notification mutations reject stale task rows before writing", async () => {
  const row = notificationRow("task", "task-owned-by-another-contributor");
  const { service } = directReadHarness(row);

  await assert.rejects(
    () => service.markRead({ id: row.userId } as any, row.id),
    /Notification not found/,
  );
});

test("list visibility carries live task and qualifying cost scope into the database predicate", async () => {
  let contributionWhere: unknown;
  const prisma = {
    provider: { findUnique: async () => null },
    sharedMember: {
      findMany: async () => [
        {
          weddingPlanId: "plan-1",
          canManageTasks: true,
          canViewMoney: true,
        },
      ],
    },
    weddingTask: {
      findMany: async () => [
        { id: "task-assigned", weddingPlanId: "plan-1" },
      ],
    },
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        contributionWhere = where;
        return [
        {
          entityId: "task-created",
          entityType: ContributionEntityType.TASK,
          historyScope: { weddingPlanId: "plan-1" },
        },
        {
          entityId: "cost-contributed",
          entityType: ContributionEntityType.WEDDING_COST,
          historyScope: { weddingPlanId: "plan-1" },
        },
        ];
      },
    },
    paymentSchedule: {
      findMany: async () => [
        {
          id: "schedule-for-contributed-cost",
          weddingCost: { weddingPlanId: "plan-1" },
        },
      ],
    },
  };
  const service = new NotificationsService(
    prisma as any,
    {} as any,
    new OutboxService(),
  );

  const predicate = await service.visibilityWhereForUser("contributor-1");
  const serialized = JSON.stringify(predicate);

  assert.match(serialized, /task-assigned/);
  assert.match(serialized, /task-created/);
  assert.match(serialized, /schedule-for-contributed-cost/);
  assert.match(serialized, /canManageTasks/);
  assert.match(serialized, /canViewMoney/);
  assert.doesNotMatch(serialized, /task-from-another-contributor/);
  assert.doesNotMatch(serialized, /schedule-for-another-cost/);
  assert.doesNotMatch(JSON.stringify(contributionWhere), /endedAt/);
});

test("scheduled reminders target only each contributor's current task or qualifying cost", async () => {
  const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1_000);
  const plan = {
    id: "plan-1",
    ownerUserId: "owner-1",
    status: "PLANNING",
    sharedMembers: [
      {
        userId: "member-a",
        receiveNotifications: true,
        canManageTasks: true,
        canViewMoney: true,
      },
      {
        userId: "member-b",
        receiveNotifications: true,
        canManageTasks: true,
        canViewMoney: false,
      },
      {
        userId: "member-c",
        receiveNotifications: true,
        canManageTasks: false,
        canViewMoney: true,
      },
    ],
  };
  const tasks = [
    {
      id: "task-a",
      weddingPlanId: plan.id,
      assigneeUserId: "member-a",
      title: "Task A",
      dueDate,
      status: "TODO",
    },
    {
      id: "task-b",
      weddingPlanId: plan.id,
      assigneeUserId: null,
      title: "Task B",
      dueDate,
      status: "TODO",
    },
  ];
  const schedules = [
    {
      id: "schedule-a",
      weddingCostId: "cost-a",
      amount: { toString: () => "1" },
      dueDate,
      status: "PENDING",
      weddingCost: {
        weddingPlanId: plan.id,
        title: "Cost A",
        partyName: null,
        provider: null,
      },
    },
    {
      id: "schedule-c",
      weddingCostId: "cost-c",
      amount: { toString: () => "1" },
      dueDate,
      status: "PENDING",
      weddingCost: {
        weddingPlanId: plan.id,
        title: "Cost C",
        partyName: null,
        provider: null,
      },
    },
  ];
  const captured: Array<Record<string, unknown>> = [];
  let contributionWhere: unknown;
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes("pg_try_advisory_xact_lock")) {
        return [{ locked: true }];
      }
      if (sql.includes('FROM "User"')) {
        if (sql.includes('WHERE "id" =')) {
          return [{ id: query.values?.[0] ?? "recipient" }];
        }
        return ["owner-1", "member-a", "member-b", "member-c"].map(
          (id) => ({ id, status: UserStatus.ACTIVE }),
        );
      }
      return [{ id: plan.id }];
    },
    weddingPlan: { findMany: async () => [plan] },
    weddingTask: { findMany: async () => tasks },
    paymentSchedule: { findMany: async () => schedules },
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        contributionWhere = where;
        return [
        {
          entityId: "cost-a",
          entityType: ContributionEntityType.WEDDING_COST,
          historyScope: { weddingPlanId: plan.id },
          contributorTenure: { actorUserId: "member-a" },
        },
        {
          entityId: "task-b",
          entityType: ContributionEntityType.TASK,
          historyScope: { weddingPlanId: plan.id },
          contributorTenure: { actorUserId: "member-b" },
        },
        {
          entityId: "task-a",
          entityType: ContributionEntityType.TASK,
          historyScope: { weddingPlanId: plan.id },
          contributorTenure: { actorUserId: "member-c" },
        },
        {
          entityId: "cost-c",
          entityType: ContributionEntityType.WEDDING_COST,
          historyScope: { weddingPlanId: plan.id },
          contributorTenure: { actorUserId: "member-c" },
        },
        ];
      },
    },
    notificationPreference: { findMany: async () => [] },
    notification: {
      createManyAndReturn: async ({ data }: { data: any[] }) => {
        captured.push(...data);
        return data.map((item, index) => ({
          ...item,
          id: `notification-${index}`,
        }));
      },
    },
    outboxEvent: { create: async () => ({ id: "outbox" }) },
  };
  const service = new NotificationsService(
    {
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    new OutboxService(),
  );

  await service.generateDueNotifications();

  const pairs = captured
    .map((row) => `${row.userId}:${row.entityId}`)
    .sort();
  assert.deepEqual(pairs, [
    "member-a:schedule-a",
    "member-a:task-a",
    "member-b:task-b",
    "member-c:schedule-c",
    "owner-1:schedule-a",
    "owner-1:schedule-c",
    "owner-1:task-a",
    "owner-1:task-b",
  ]);
  assert.doesNotMatch(JSON.stringify(contributionWhere), /endedAt/);
});

test("immediate task-due notifications use the same contributor scope as the scheduler", async () => {
  const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1_000);
  const task = {
    id: "task-1",
    weddingPlanId: "plan-1",
    assigneeUserId: "member-a",
    responsibleName: null,
    responsiblePhone: null,
    responsibleSource: null,
    title: "Scoped task",
    description: null,
    dueDate,
    taskCategory: null,
    reminderAt: null,
    status: "TODO",
    priority: "MEDIUM",
    createdAt: now,
    updatedAt: now,
  };
  const plan = {
    ownerUserId: "owner-1",
    status: "PLANNING",
    sharedMembers: [
      { userId: "member-a", canManageTasks: true },
      { userId: "member-b", canManageTasks: true },
      { userId: "member-c", canManageTasks: false },
    ],
  };
  const recipients: string[] = [];
  let contributionWhere: unknown;
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        if (sql.includes('WHERE "id" =')) {
          return [{ id: query.values?.[0] ?? "recipient" }];
        }
        return ["owner-1", "member-a", "member-b", "member-c"].map(
          (id) => ({ id, status: UserStatus.ACTIVE }),
        );
      }
      return [{ id: "locked" }];
    },
    weddingPlan: { findUnique: async () => plan },
    weddingTask: { findUnique: async () => task },
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        contributionWhere = where;
        return [
          { contributorTenure: { actorUserId: "member-b" } },
          { contributorTenure: { actorUserId: "member-c" } },
        ];
      },
    },
    notificationPreference: { findUnique: async () => null },
    notification: {
      findUnique: async () => null,
      create: async ({ data }: { data: any }) => {
        recipients.push(data.userId);
        return {
          ...notificationRow("task", task.id),
          id: `notification-${data.userId}`,
          userId: data.userId,
          weddingPlanId: task.weddingPlanId,
          type: data.type,
          title: data.title,
          body: data.body,
          entityType: data.entityType,
          entityId: data.entityId,
          routeTarget: data.routeTarget,
          data: data.data ?? null,
          dedupeKey: data.dedupeKey ?? null,
        };
      },
    },
    outboxEvent: { create: async () => ({ id: "outbox" }) },
  };
  const service = new NotificationsService(
    {
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    new OutboxService(),
  );

  await service.notifyTaskDue(task as any);

  assert.deepEqual(recipients.sort(), ["member-a", "member-b", "owner-1"]);
  assert.doesNotMatch(JSON.stringify(contributionWhere), /endedAt/);
});

test("provider quote updates fall back to the plan owner after requester provider permission is revoked", async () => {
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: "owner-1", status: UserStatus.ACTIVE },
          { id: "contributor-1", status: UserStatus.ACTIVE },
        ];
      }
      return [{ id: "plan-1" }];
    },
    weddingPlan: {
      findUnique: async () => ({
        ownerUserId: "owner-1",
        sharedMembers: [{ canManageProviders: false }],
      }),
    },
    sharedMember: {
      findUnique: async () => ({
        userId: "contributor-1",
        weddingPlanId: "plan-1",
        canManageProviders: false,
      }),
    },
  };
  const service = new (NotificationsService as any)(
    {} as any,
    {} as any,
    new OutboxService(),
    {} as any,
  );

  const resolved = await service.resolveProviderUpdateRecipientInTransaction(
    tx,
    "plan-1",
    "contributor-1",
  );

  assert.equal(resolved, "owner-1");
});
