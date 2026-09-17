import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  SharedMemberRole,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from "@prisma/client";
import { tasksService } from "./support/owner-ports";

const now = new Date("2026-08-02T09:00:00.000Z");

function task(id: string, assigneeUserId: string) {
  return {
    id,
    weddingPlanId: "plan-1",
    assigneeUserId,
    responsibleName: null,
    responsiblePhone: null,
    responsibleSource: null,
    title: `مهمة ${id}`,
    description: null,
    dueDate: null,
    taskCategory: null,
    reminderAt: null,
    status: WeddingTaskStatus.TODO,
    priority: WeddingTaskPriority.MEDIUM,
    createdAt: now,
    updatedAt: now,
  };
}

test("contributor A never receives contributor B task rows from the plan task list", async () => {
  const contributorATask = task("task-a", "contributor-a");
  const contributorBTask = task("task-b", "contributor-b");
  const service = tasksService(
    {
      weddingTask: {
        findMany: async () => [contributorATask, contributorBTask],
      },
    } as any,
    {
      assertPlanReadable: async () => ({
        plan: { id: "plan-1", ownerUserId: "owner-1" },
        isOwner: false,
        sharedMember: {
          userId: "contributor-a",
          role: SharedMemberRole.CONTRIBUTOR,
          canManageTasks: true,
        },
      }),
      canManageTasks: () => true,
    } as any,
    { notifyTaskDue: async () => undefined } as any,
    {} as any,
    { qualifyingEntityIds: async () => [] } as any,
  );

  const visible = await service.findForPlan(
    { id: "contributor-a" } as any,
    "plan-1",
  );

  assert.deepEqual(
    visible.map((entry) => entry.id),
    ["task-a"],
  );
});
