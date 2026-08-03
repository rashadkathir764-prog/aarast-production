import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  NotificationPriority,
  NotificationType,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { TasksService } from "../src/tasks/tasks.service";

const now = new Date("2026-07-11T00:00:00.000Z");

const contributionHistory = {
  recordForContextInTransaction: async () => undefined,
  ensureTenureInTransaction: async () => undefined,
  recordInTransaction: async () => undefined,
};
const contributorScope = {
  qualifyingEntityIds: async () => [],
  qualifyingEntityIdsInTransaction: async () => [],
};

function task(overrides: Record<string, unknown> = {}) {
  return {
    id: "task-1",
    weddingPlanId: "plan-1",
    assigneeUserId: null,
    responsibleName: null,
    responsiblePhone: null,
    responsibleSource: null,
    title: "تأكيد القاعة",
    description: null,
    dueDate: null,
    taskCategory: "VENUE",
    reminderAt: null,
    status: WeddingTaskStatus.TODO,
    priority: WeddingTaskPriority.MEDIUM,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

test("account task creation persists optional manual responsibility", async () => {
  let createdData: Record<string, unknown> | undefined;
  const prisma: any = {
    weddingTask: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        createdData = data;
        return task(data);
      },
    },
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const permissions = {
    assertTaskManageableInTransaction: async () => undefined,
  };
  const service = new TasksService(
    prisma as any,
    permissions as any,
    {
      notifyTaskDue: async () => undefined,
    } as any,
    contributionHistory as any,
    contributorScope as any,
  );

  const result = await service.create({ id: "user-1" } as any, "plan-1", {
    title: "تأكيد القاعة",
    responsibleName: "محمد",
    responsiblePhone: "+967777123456",
    responsibleSource: "manual",
  } as any);

  assert.equal(createdData?.responsibleName, "محمد");
  assert.equal(createdData?.responsiblePhone, "+967777123456");
  assert.equal(createdData?.responsibleSource, "manual");
  assert.equal((result as any).responsibleName, "محمد");
  assert.equal((result as any).responsiblePhone, "+967777123456");
  assert.equal((result as any).responsibleSource, "manual");
});

test("assigning a plan participant clears manual responsibility", async () => {
  let updatedData: Record<string, unknown> | undefined;
  const prisma: any = {
    weddingTask: {
      findUnique: async () => task({ responsibleName: "محمد" }),
      update: async ({ data }: { data: Record<string, unknown> }) => {
        updatedData = data;
        return task(data);
      },
    },
    weddingPlan: { findUnique: async () => ({ ownerUserId: "user-1" }) },
    sharedMember: { findUnique: async () => null },
    $queryRaw: async () => [{ id: "task-1" }],
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const permissions = {
    assertTaskManageableInTransaction: async () => ({
      plan: { ownerUserId: "user-1" },
      isOwner: true,
      sharedMember: null,
    }),
  };
  const service = new TasksService(
    prisma as any,
    permissions as any,
    {
      notifyTaskDue: async () => undefined,
    } as any,
    contributionHistory as any,
    contributorScope as any,
  );

  await service.assign({ id: "user-1" } as any, "task-1", {
    assigneeUserId: "user-1",
  });

  assert.deepEqual(updatedData, {
    assigneeUserId: "user-1",
    responsibleName: null,
    responsiblePhone: null,
    responsibleSource: null,
  });
});

test("assigning a notification-enabled contributor creates one durable task notification", async () => {
  const notificationCalls: Array<{ client: unknown; input: any }> = [];
  const prisma: any = {
    weddingTask: {
      findUnique: async () => task(),
      update: async ({ data }: { data: Record<string, unknown> }) =>
        task({
          ...data,
          assigneeUserId: "contributor-1",
          updatedAt: new Date("2026-07-11T00:01:00.000Z"),
        }),
    },
    sharedMember: {
      findUnique: async () => ({
        id: "member-contributor-1",
        weddingPlanId: "plan-1",
        userId: "contributor-1",
        role: "CONTRIBUTOR",
        canManageTasks: true,
        authorityVersion: 1,
        receiveNotifications: true,
        createdAt: now,
        updatedAt: now,
      }),
    },
    $queryRaw: async () => [{ id: "locked" }],
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const permissions = {
    assertTaskManageableInTransaction: async () => ({
      plan: { ownerUserId: "owner-1" },
      isOwner: true,
      sharedMember: null,
    }),
  };
  const notifications = {
    notifyTaskDue: async () => undefined,
    createNotificationInTransaction: async (client: unknown, input: any) => {
      notificationCalls.push({ client, input });
    },
  };
  const service = new TasksService(
    prisma as any,
    permissions as any,
    notifications as any,
    contributionHistory as any,
    contributorScope as any,
  );

  await service.assign({ id: "owner-1" } as any, "task-1", {
    assigneeUserId: "contributor-1",
  });

  assert.equal(notificationCalls.length, 1);
  assert.equal(notificationCalls[0]?.client, prisma);
  assert.equal(
    notificationCalls[0]?.input.type,
    NotificationType.TASK_ASSIGNED,
  );
  assert.equal(
    notificationCalls[0]?.input.priority,
    NotificationPriority.NORMAL,
  );
  assert.equal(
    notificationCalls[0]?.input.routeTarget,
    "/wedding-plans/plan-1/tasks",
  );
  assert.deepEqual(notificationCalls[0]?.input.data, {
    taskId: "task-1",
    weddingPlanId: "plan-1",
  });
});

test("reassigning the same contributor does not duplicate the task notification", async () => {
  let notificationCount = 0;
  const prisma: any = {
    weddingTask: {
      findUnique: async () => task({ assigneeUserId: "contributor-1" }),
      update: async ({ data }: { data: Record<string, unknown> }) =>
        task({ ...data, assigneeUserId: "contributor-1" }),
    },
    sharedMember: {
      findUnique: async () => ({
        id: "member-contributor-1",
        weddingPlanId: "plan-1",
        userId: "contributor-1",
        role: "CONTRIBUTOR",
        canManageTasks: true,
        authorityVersion: 1,
        receiveNotifications: true,
        createdAt: now,
        updatedAt: now,
      }),
    },
    $queryRaw: async () => [{ id: "locked" }],
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) =>
    operation(prisma);
  const service = new TasksService(
    prisma as any,
    {
      assertTaskManageableInTransaction: async () => ({
        plan: { ownerUserId: "owner-1" },
        isOwner: true,
        sharedMember: null,
      }),
    } as any,
    {
      notifyTaskDue: async () => undefined,
      createNotificationInTransaction: async () => {
        notificationCount += 1;
      },
    } as any,
    contributionHistory as any,
    contributorScope as any,
  );

  await service.assign({ id: "owner-1" } as any, "task-1", {
    assigneeUserId: "contributor-1",
  });

  assert.equal(notificationCount, 0);
});

test("read-only plan members receive no live task rows", async () => {
  const prisma = {
    weddingTask: {
      findMany: async () => [
        task({
          responsibleName: "محمد",
          responsiblePhone: "+967777123456",
          responsibleSource: "manual",
        }),
      ],
    },
  };
  const permissions = {
    assertPlanReadable: async () => ({
      isOwner: false,
      sharedMember: { canManageTasks: false, role: "VIEWER" },
    }),
    canManageTasks: () => false,
  };
  const service = new TasksService(
    prisma as any,
    permissions as any,
    {
      notifyTaskDue: async () => undefined,
    } as any,
    contributionHistory as any,
    contributorScope as any,
  );

  const result = await service.findForPlan(
    { id: "viewer-1" } as any,
    "plan-1",
  );

  assert.deepEqual(result, []);
});
