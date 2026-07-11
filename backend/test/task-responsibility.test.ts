import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { TasksService } from "../src/tasks/tasks.service";

const now = new Date("2026-07-11T00:00:00.000Z");

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
  const prisma = {
    weddingTask: {
      create: async ({ data }: { data: Record<string, unknown> }) => {
        createdData = data;
        return task(data);
      },
    },
  };
  const permissions = { assertTaskManageable: async () => undefined };
  const service = new TasksService(prisma as any, permissions as any);

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
  const prisma = {
    weddingTask: {
      findUnique: async () => task({ responsibleName: "محمد" }),
      update: async ({ data }: { data: Record<string, unknown> }) => {
        updatedData = data;
        return task(data);
      },
    },
    weddingPlan: { findUnique: async () => ({ ownerUserId: "user-1" }) },
    sharedMember: { findUnique: async () => null },
  };
  const permissions = { assertTaskManageable: async () => undefined };
  const service = new TasksService(prisma as any, permissions as any);

  await service.assign(
    { id: "user-1" } as any,
    "task-1",
    { assigneeUserId: "user-1" },
  );

  assert.deepEqual(updatedData, {
    assigneeUserId: "user-1",
    responsibleName: null,
    responsiblePhone: null,
    responsibleSource: null,
  });
});

test("read-only plan members never receive a manual responsible phone", async () => {
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
  const service = new TasksService(prisma as any, permissions as any);

  const [result] = await service.findForPlan(
    { id: "viewer-1" } as any,
    "plan-1",
  );

  assert.equal(result.responsibleName, "محمد");
  assert.equal(result.responsiblePhone, null);
  assert.equal(result.responsibleSource, "manual");
});
