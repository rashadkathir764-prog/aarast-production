import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { WeddingTaskPriority, WeddingTaskStatus } from "@prisma/client";
import { TasksService } from "../src/tasks/tasks.service";
import { tasksService } from "./support/owner-ports";

// A task's checklist could be created, edited and deleted but never read:
// task responses carried no items and no route listed them. Every task read
// and write response now carries the ordered checklist.

const now = new Date("2026-10-11T09:00:00.000Z");

const ownerContext = {
  plan: { id: "plan-1", ownerUserId: "owner-1", weddingDate: null, status: "ACTIVE" },
  isOwner: true,
  sharedMember: null,
} as any;

function permissions() {
  return {
    assertPlanReadable: async () => ownerContext,
    assertPlanReadableInTransaction: async () => ownerContext,
    assertTaskManageableInTransaction: async () => ownerContext,
    canManageTasks: () => true,
    canViewMoney: () => true,
  } as any;
}

function item(id: string, sortOrder: number, isDone = false) {
  return {
    id,
    taskId: "task-1",
    title: `بند ${id}`,
    isDone,
    sortOrder,
    createdAt: now,
    updatedAt: now,
  };
}

const taskRow = {
  id: "task-1",
  weddingPlanId: "plan-1",
  assigneeUserId: null,
  responsibleName: null,
  responsiblePhone: null,
  responsibleSource: null,
  title: "حجز القاعة",
  description: null,
  dueDate: null,
  taskCategory: null,
  reminderAt: null,
  status: WeddingTaskStatus.TODO,
  priority: WeddingTaskPriority.MEDIUM,
  createdAt: now,
  updatedAt: now,
  checklistItems: [item("a", 0, true), item("b", 1)],
};

test("task list and detail carry the ordered checklist", async () => {
  const queries: any[] = [];
  const prisma = {
    weddingTask: {
      findMany: async (args: any) => {
        queries.push(args);
        return [taskRow];
      },
      findUnique: async () => taskRow,
      findFirst: async (args: any) => {
        queries.push(args);
        return taskRow;
      },
    },
  } as any;
  const tasks = tasksService(
    prisma,
    permissions(),
    { notifyTaskDue: async () => undefined },
    {},
    { qualifyingEntityIds: async () => [] },
  ) as TasksService;
  const owner = { id: "owner-1" } as any;

  const [listed] = await tasks.findForPlan(owner, "plan-1");
  const detail = await tasks.findOne(owner, "task-1");

  for (const response of [listed, detail]) {
    assert.deepEqual(
      response.checklist.map((entry) => [entry.id, entry.isDone, entry.sortOrder]),
      [
        ["a", true, 0],
        ["b", false, 1],
      ],
    );
    assert.equal(response.checklist[0].title, "بند a");
  }
  for (const query of queries) {
    assert.deepEqual(query.include?.checklistItems?.orderBy, [
      { sortOrder: "asc" },
      { createdAt: "asc" },
    ]);
  }
});
