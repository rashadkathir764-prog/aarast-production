import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpException, NotFoundException } from "@nestjs/common";
import {
  NotificationPriority,
  NotificationType,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { notificationsService } from "./support/owner-ports";
import { OutboxService } from "../src/platform/outbox/outbox.service";

const user = {
  id: "11111111-1111-4111-8111-111111111111",
  name: "Member",
  phone: "+967700000001",
} as any;
const ownerUserId = "22222222-2222-4222-8222-222222222222";
const memberUserId = "33333333-3333-4333-8333-333333333333";
const providerId = "44444444-4444-4444-8444-444444444444";
const planId = "55555555-5555-4555-8555-555555555555";
const notificationId = "66666666-6666-4666-8666-666666666666";
const now = new Date("2026-07-26T00:00:00.000Z");

function notification(
  overrides: Record<string, unknown> = {},
) {
  return {
    id: notificationId,
    userId: user.id,
    weddingPlanId: null,
    type: NotificationType.GENERAL,
    priority: NotificationPriority.NORMAL,
    title: "Notification",
    body: "Notification body",
    entityType: null,
    entityId: null,
    routeTarget: null,
    data: null,
    dedupeKey: null,
    readAt: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  } as any;
}

function errorCode(error: unknown): unknown {
  if (!(error instanceof HttpException)) return undefined;
  const response = error.getResponse();
  return typeof response === "object" && response !== null
    ? (response as { code?: unknown }).code
    : undefined;
}

test("financial mark-read rechecks live money access inside the transaction", async () => {
  const row = notification({
    weddingPlanId: planId,
    type: NotificationType.PAYMENT_SCHEDULE_DUE_SOON,
    entityType: "payment_schedule",
  });
  let writes = 0;
  let transactions = 0;
  const notificationModel = {
    findFirst: async () => row,
    update: async () => {
      writes += 1;
      return { ...row, readAt: now };
    },
  };
  const tx = {
    $queryRaw: async () => [{ id: notificationId }],
    notification: notificationModel,
    provider: { findUnique: async () => null },
  };
  const prisma = {
    notification: notificationModel,
    provider: { findUnique: async () => null },
    $transaction: async (operation: (client: typeof tx) => unknown) => {
      transactions += 1;
      return operation(tx);
    },
  };
  const permissions = {
    assertMoneyReadable: async () => ({
      plan: { id: planId, ownerUserId },
      isOwner: false,
      sharedMember: { canViewMoney: true },
    }),
    assertPlanReadableInTransaction: async () => ({
      plan: { id: planId, ownerUserId },
      isOwner: false,
      sharedMember: { canViewMoney: false, canManageMoney: false },
    }),
    canViewMoney: () => false,
  };
  const service = notificationsService(
    prisma as any,
    permissions as any,
    new OutboxService(),
  );

  await assert.rejects(
    () => service.markRead(user, notificationId),
    NotFoundException,
  );
  assert.equal(transactions, 1);
  assert.equal(writes, 0);
});

test("provider suspension committed before archive wins without a notification write", async () => {
  const row = notification({
    data: { providerId, recipientAudience: "PROVIDER" },
  });
  let writes = 0;
  const notificationModel = {
    findFirst: async () => row,
    update: async () => {
      writes += 1;
      return { ...row, archivedAt: now, readAt: now };
    },
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [{ id: user.id, status: UserStatus.ACTIVE }];
      }
      return [{ id: notificationId }];
    },
    notification: notificationModel,
    provider: {
      findUnique: async () => ({
        id: providerId,
        userId: user.id,
        status: "SUSPENDED",
      }),
    },
    conversation: { findUnique: async () => null },
  };
  const prisma = {
    notification: notificationModel,
    provider: {
      findUnique: async () => ({
        id: providerId,
        userId: user.id,
        status: "ACTIVE",
      }),
    },
    conversation: { findUnique: async () => null },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const service = notificationsService(
    prisma as any,
    {} as any,
    new OutboxService(),
  );

  await assert.rejects(
    () => service.archive(user, notificationId),
    (error: unknown) => {
      assert.equal(errorCode(error), "PROVIDER_NOT_ACTIVE");
      return true;
    },
  );
  assert.equal(writes, 0);
});

test("plan-scoped mark-all fails closed when membership was revoked", async () => {
  let writes = 0;
  const tx = {
    notification: {
      findMany: async () => [{ weddingPlanId: planId }],
      findFirst: async () => null,
      updateMany: async () => {
        writes += 1;
        return { count: 1 };
      },
    },
    weddingPlan: {
      findMany: async () => [
        {
          id: planId,
          ownerUserId,
          sharedMembers: [],
        },
      ],
    },
    provider: { findUnique: async () => null },
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: user.id, status: UserStatus.ACTIVE },
          { id: ownerUserId, status: UserStatus.ACTIVE },
        ];
      }
      return [{ id: planId }];
    },
  };
  const prisma = {
    provider: { findUnique: async () => null },
    notification: {
      updateMany: async () => {
        writes += 1;
        return { count: 1 };
      },
    },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const service = notificationsService(
    prisma as any,
    {} as any,
    new OutboxService(),
  );

  await assert.rejects(
    () => service.markAllRead(user, planId),
    NotFoundException,
  );
  assert.equal(writes, 0);
});

test("plan participant generation re-reads membership after lifecycle locks", async () => {
  const stalePlan = {
    id: planId,
    ownerUserId,
    status: WeddingPlanStatus.PLANNING,
    sharedMembers: [{ userId: memberUserId }],
  };
  const livePlan = {
    id: planId,
    ownerUserId,
    status: WeddingPlanStatus.PLANNING,
    sharedMembers: [],
  };
  let planReads = 0;
  const createdFor: string[] = [];
  const notificationModel = {
    findUnique: async () => null,
    create: async ({ data }: any) => {
      createdFor.push(data.userId);
      return notification({
        id: `notification-${data.userId}`,
        userId: data.userId,
        weddingPlanId: data.weddingPlanId,
        type: data.type,
        dedupeKey: data.dedupeKey ?? null,
      });
    },
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: ownerUserId, status: UserStatus.ACTIVE },
          { id: memberUserId, status: UserStatus.ACTIVE },
        ];
      }
      return [{ id: planId }];
    },
    weddingPlan: {
      findUnique: async () => {
        planReads += 1;
        return planReads === 1 ? stalePlan : livePlan;
      },
    },
    notification: notificationModel,
    notificationPreference: { findUnique: async () => null },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
  const prisma = {
    weddingPlan: { findUnique: async () => stalePlan },
    notification: {
      ...notificationModel,
      findUnique: async () => null,
    },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const service = notificationsService(
    prisma as any,
    {} as any,
    new OutboxService(),
  );

  const created = await service.createForPlanParticipants(planId, {
    type: NotificationType.GENERAL,
    title: "Plan event",
    body: "Plan event body",
    dedupeKey: "plan-event",
  });

  assert.deepEqual(createdFor, [ownerUserId]);
  assert.deepEqual(created.map((item) => item.userId), [ownerUserId]);
  assert.equal(planReads, 2);
});

test("scheduler re-reads recipients after member revocation", async () => {
  const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1_000);
  const stalePlan = {
    id: planId,
    ownerUserId,
    status: "PLANNING",
    sharedMembers: [
      {
        userId: memberUserId,
        receiveNotifications: true,
        canViewMoney: false,
        canManageMoney: false,
      },
    ],
  };
  const livePlan = { ...stalePlan, sharedMembers: [] };
  let planReads = 0;
  let captured: any[] = [];
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes("pg_try_advisory_xact_lock")) {
        return [{ locked: true }];
      }
      if (sql.includes('FROM "User"')) {
        return [
          { id: ownerUserId, status: UserStatus.ACTIVE },
          { id: memberUserId, status: UserStatus.ACTIVE },
        ];
      }
      return [{ id: planId }];
    },
    weddingPlan: {
      findMany: async () => {
        planReads += 1;
        return planReads === 1 ? [stalePlan] : [livePlan];
      },
    },
    weddingTask: {
      findMany: async () => [
        {
          id: "task-1",
          weddingPlanId: planId,
          title: "Task",
          dueDate,
          status: "TODO",
        },
      ],
    },
    paymentSchedule: { findMany: async () => [] },
    budgetCategory: { findMany: async () => [] },
    loanRepayment: { findMany: async () => [] },
    contributionEvent: { findMany: async () => [] },
    notificationPreference: { findMany: async () => [] },
    notification: {
      createManyAndReturn: async ({ data }: any) => {
        captured = data;
        return data.map((item: any, index: number) => ({
          ...item,
          id: `notification-${index}`,
        }));
      },
    },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const service = notificationsService(
    prisma as any,
    {} as any,
    new OutboxService(),
  );

  assert.equal(await service.generateDueNotifications(), 1);
  assert.deepEqual(captured.map((item) => item.userId), [ownerUserId]);
  assert.equal(planReads, 2);
});

test("list and unread count include defensive live task and money predicates", async () => {
  const whereInputs: any[] = [];
  const notificationModel = {
    count: async ({ where }: any) => {
      whereInputs.push(where);
      return 0;
    },
    findMany: async ({ where }: any) => {
      whereInputs.push(where);
      return [];
    },
  };
  const prisma = {
    provider: { findUnique: async () => null },
    notification: notificationModel,
    sharedMember: {
      findMany: async () => [
        {
          weddingPlanId: planId,
          canManageTasks: true,
          canViewMoney: true,
        },
      ],
    },
    weddingTask: {
      findMany: async () => [{ id: "task-live", weddingPlanId: planId }],
    },
    contributionEvent: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
    $transaction: async (operation: unknown) =>
      typeof operation === "function"
        ? (operation as (client: unknown) => unknown)(prisma)
        : Promise.all(operation as unknown[]),
  };
  const service = notificationsService(
    prisma as any,
    {} as any,
    new OutboxService(),
  );

  await service.list(user);
  await service.unreadCount(user);

  assert.equal(whereInputs.length, 3);
  for (const where of whereInputs) {
    const serialized = JSON.stringify(where);
    assert.match(serialized, /payment_schedule/);
    assert.match(serialized, /task/);
    // The membership flags used to be re-checked by a join on the
    // membership row; they are read through the port when the predicate
    // is built and scope the plan clauses: the member's plan for tasks
    // and money, the live task the member may see.
    assert.ok(serialized.includes(`"weddingPlanId":{"in":["${planId}"]}`));
    assert.ok(serialized.includes(`{"weddingPlanId":"${planId}"},{"entityId":{"in":["task-live"]}}`));
    assert.doesNotMatch(serialized, /sharedMembers|"weddingPlan":\{/);
    assert.match(serialized, /SHARING_INVITATION/);
    assert.match(serialized, /plan_invite/);
  }
});

test("a plan-invite notification remains mutable before membership exists", async () => {
  const invite = notification({
    weddingPlanId: planId,
    type: NotificationType.SHARING_INVITATION,
    entityType: "plan_invite",
    entityId: "invite-1",
  });
  let writes = 0;
  const notificationModel = {
    findFirst: async () => invite,
    update: async () => {
      writes += 1;
      return { ...invite, readAt: now };
    },
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: user.id, status: UserStatus.ACTIVE },
          { id: ownerUserId, status: UserStatus.ACTIVE },
        ];
      }
      return [{ id: planId }];
    },
    weddingPlan: {
      findUnique: async () => ({ id: planId, ownerUserId }),
    },
    notification: notificationModel,
    provider: { findUnique: async () => null },
    conversation: { findUnique: async () => null },
  };
  const prisma = {
    notification: notificationModel,
    provider: { findUnique: async () => null },
    conversation: { findUnique: async () => null },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const permissions = {
    assertPlanReadableInTransaction: async () => {
      throw new NotFoundException("Wedding plan not found");
    },
  };
  const service = notificationsService(
    prisma as any,
    permissions as any,
    new OutboxService(),
  );

  const result = await service.markRead(user, notificationId);
  assert.equal(result.readAt, now);
  assert.equal(writes, 1);
});

test("scheduler re-reads task and schedule lifecycle rows after locking", async () => {
  const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1_000);
  const plan = {
    id: planId,
    ownerUserId,
    status: "PLANNING",
    sharedMembers: [],
  };
  let taskReads = 0;
  let scheduleReads = 0;
  let writes = 0;
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes("pg_try_advisory_xact_lock")) {
        return [{ locked: true }];
      }
      if (sql.includes('FROM "User"')) {
        return [{ id: ownerUserId, status: UserStatus.ACTIVE }];
      }
      return [{ id: planId }];
    },
    weddingPlan: { findMany: async () => [plan] },
    weddingTask: {
      findMany: async () => {
        taskReads += 1;
        return taskReads === 1
          ? [
              {
                id: "task-stale",
                weddingPlanId: planId,
                title: "Task",
                dueDate,
                status: "TODO",
              },
            ]
          : [];
      },
    },
    budgetCategory: { findMany: async () => [] },
    loanRepayment: { findMany: async () => [] },
    paymentSchedule: {
      findMany: async () => {
        scheduleReads += 1;
        return scheduleReads === 1
          ? [
              {
                id: "schedule-stale",
                weddingCostId: "cost-stale",
                amount: { toString: () => "10" },
                dueDate,
                status: "PENDING",
                weddingCost: {
                  weddingPlanId: planId,
                  title: "Cost",
                  partyName: null,
                  provider: null,
                },
              },
            ]
          : [];
      },
    },
    contributionEvent: { findMany: async () => [] },
    notificationPreference: { findMany: async () => [] },
    notification: {
      createManyAndReturn: async () => {
        writes += 1;
        return [];
      },
    },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
  const service = notificationsService(
    {
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    new OutboxService(),
  );

  assert.equal(await service.generateDueNotifications(), 0);
  assert.equal(taskReads, 2);
  assert.equal(scheduleReads, 2);
  assert.equal(writes, 0);
});

test("notifyTaskDue re-reads the locked task instead of trusting its argument", async () => {
  const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1_000);
  const staleTask = {
    id: "task-1",
    weddingPlanId: planId,
    title: "Stale task",
    dueDate,
    status: "TODO",
  } as any;
  const plan = {
    id: planId,
    ownerUserId,
    status: WeddingPlanStatus.PLANNING,
    sharedMembers: [],
  };
  let writes = 0;
  const notificationModel = {
    findUnique: async () => null,
    create: async ({ data }: any) => {
      writes += 1;
      return notification({
        id: "created-task-notification",
        userId: data.userId,
        weddingPlanId: planId,
        type: data.type,
      });
    },
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [{ id: ownerUserId, status: UserStatus.ACTIVE }];
      }
      return [{ id: planId }];
    },
    weddingPlan: { findUnique: async () => plan },
    weddingTask: {
      findUnique: async () => ({ ...staleTask, status: "DONE" }),
    },
    notification: notificationModel,
    notificationPreference: { findUnique: async () => null },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
  const service = notificationsService(
    {
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    new OutboxService(),
  );

  await service.notifyTaskDue(staleTask);
  assert.equal(writes, 0);
});

test("notifyTaskDue stops before reading the task when the locked plan is archived", async () => {
  const dueDate = new Date(Date.now() + 24 * 60 * 60 * 1_000);
  const task = {
    id: "task-archived-plan",
    weddingPlanId: planId,
    title: "Archived plan task",
    dueDate,
    status: "TODO",
  } as any;
  const archivedPlan = {
    id: planId,
    ownerUserId,
    status: WeddingPlanStatus.ARCHIVED,
    sharedMembers: [],
  };
  let taskReads = 0;
  let writes = 0;
  const notificationModel = {
    findUnique: async () => null,
    create: async () => {
      writes += 1;
      return notification();
    },
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings)
        ? query.strings.join(" ")
        : String(query);
      if (sql.includes('FROM "User"')) {
        return [{ id: ownerUserId, status: UserStatus.ACTIVE }];
      }
      return [{ id: planId }];
    },
    weddingPlan: { findUnique: async () => archivedPlan },
    weddingTask: {
      findUnique: async () => {
        taskReads += 1;
        return task;
      },
    },
    notification: notificationModel,
    notificationPreference: { findUnique: async () => null },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
  const service = notificationsService(
    {
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    new OutboxService(),
  );

  await service.notifyTaskDue(task);
  assert.equal(taskReads, 0);
  assert.equal(writes, 0);
});
