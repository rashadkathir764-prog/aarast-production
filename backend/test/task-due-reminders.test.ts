import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionEntityType,
  NotificationType,
  UserStatus,
} from "@prisma/client";
import {
  isTaskDueReminderDay,
  taskDueNotice,
  weddingCountdownMilestone,
  weddingCountdownRow,
} from "../src/notifications/plan-reminders";
import { OutboxService } from "../src/platform/outbox/outbox.service";
import { pushNotificationCopy } from "../src/push/push-notification.policy";
import { startOfRiyadhDay } from "../src/shared-kernel/time/business-day";
import { notificationsService, tasksService } from "./support/owner-ports";

// RA-BE-189: a task's due reminder is sent 7, 1 and 0 days before, once per
// task, step and due date, to the assignee and the owner, with the real
// distance in its words. RA-BE-190: the wedding day has its own step.

const DAY_MS = 24 * 60 * 60 * 1000;
const today = startOfRiyadhDay(new Date("2026-10-11T09:00:00.000Z"));
const task = (dueDate: string, id = "task-1") => ({
  id,
  weddingPlanId: "plan-1",
  title: "تأكيد القاعة",
  dueDate: new Date(dueDate),
});

test("a task is reminded a week, a day and on its day, and a late one once", () => {
  for (const days of [7, 1, 0, -1, -9]) assert.equal(isTaskDueReminderDay(days), true, String(days));
  for (const days of [2, 3, 4, 5, 6, 8, 30]) assert.equal(isTaskDueReminderDay(days), false, String(days));
});

test("the phone text says the real distance: بعد أسبوع, غدًا, اليوم", () => {
  const week = taskDueNotice("owner-1", task("2026-10-18T00:00:00.000Z"), today);
  const tomorrow = taskDueNotice("owner-1", task("2026-10-12T00:00:00.000Z"), today);
  const todayRow = taskDueNotice("owner-1", task("2026-10-11T00:00:00.000Z"), today);
  assert.equal(week.title, "مهمة بعد أسبوع");
  assert.equal(tomorrow.title, "مهمة غدًا");
  assert.equal(todayRow.title, "مهمة اليوم");
  assert.deepEqual(
    [week, tomorrow, todayRow].map((row) => (row.data as Record<string, unknown>).daysUntil),
    [7, 1, 0],
  );
  for (const row of [week, tomorrow, todayRow]) assert.equal(row.type, NotificationType.TASK_DUE_SOON);

  const expected: Array<[number, string]> = [
    [7, "بعد أسبوع"],
    [1, "غدًا"],
    [0, "اليوم"],
  ];
  for (const [daysUntil, words] of expected) {
    const copy = pushNotificationCopy(NotificationType.TASK_DUE_SOON, { daysUntil });
    assert.match(copy.body, new RegExp(words, "u"), String(daysUntil));
    assert.match(copy.body, /في اعّرست/u);
    // B5: no title of the task, no imperative in either gender.
    assert.equal(copy.body.includes("القاعة"), false);
  }
  // A «ذكّرني» time carries no distance and keeps the plain words.
  assert.match(pushNotificationCopy(NotificationType.TASK_DUE_SOON, {}).body, /اقترب/u);
});

test("a reminder key is per reader, task, step and due date: a moved date re-arms", () => {
  const key = (userId: string, dueDate: string, now = today) =>
    taskDueNotice(userId, task(dueDate), now).dedupeKey;
  const weekKey = key("owner-1", "2026-10-18T00:00:00.000Z");
  assert.equal(weekKey, key("owner-1", "2026-10-18T00:00:00.000Z"), "a rescan is the same row");
  assert.notEqual(weekKey, key("assignee-1", "2026-10-18T00:00:00.000Z"));
  // The same due date a day later is the next step, a new key.
  const tomorrowKey = key("owner-1", "2026-10-18T00:00:00.000Z", new Date(today.getTime() + 6 * DAY_MS));
  const todayKey = key("owner-1", "2026-10-18T00:00:00.000Z", new Date(today.getTime() + 7 * DAY_MS));
  assert.equal(new Set([weekKey, tomorrowKey, todayKey]).size, 3);
  // Another task has its own, and a moved due date its own again.
  assert.notEqual(
    weekKey,
    taskDueNotice("owner-1", task("2026-10-18T00:00:00.000Z", "task-2"), today).dedupeKey,
  );
  assert.notEqual(
    taskDueNotice("owner-1", task("2026-10-18T00:00:00.000Z"), today).dedupeKey,
    taskDueNotice(
      "owner-1",
      task("2026-10-19T00:00:00.000Z"),
      new Date(today.getTime() + DAY_MS),
    ).dedupeKey,
  );
  const late = taskDueNotice("owner-1", task("2026-10-09T00:00:00.000Z"), today);
  assert.equal(late.type, NotificationType.TASK_OVERDUE);
  assert.equal(
    late.dedupeKey,
    taskDueNotice("owner-1", task("2026-10-09T00:00:00.000Z"), new Date(today.getTime() + 3 * DAY_MS)).dedupeKey,
    "a late task is told once, not each day",
  );
});

// RA-BE-190: the wedding day was one step with the day before, so the day
// before's notice kept «ألف مبروك» from ever going out.
test("the wedding day is its own step with its own key", () => {
  assert.equal(weddingCountdownMilestone(1), 1);
  assert.equal(weddingCountdownMilestone(0), 0);
  const plan = { id: "plan-1", weddingDate: new Date("2026-10-12T00:00:00.000Z") };
  const dayBefore = weddingCountdownRow("member-1", plan, today);
  const weddingDay = weddingCountdownRow("member-1", plan, new Date(today.getTime() + DAY_MS));
  assert.ok(dayBefore && weddingDay);
  assert.equal(dayBefore.title, "العرس غدًا");
  assert.equal(weddingDay.title, "اليوم يوم العرس");
  assert.equal(weddingDay.body, "ألف مبروك!");
  assert.notEqual(dayBefore.dedupeKey, weddingDay.dedupeKey);
  assert.equal((weddingDay.data as Record<string, unknown>).daysUntil, 0);
  assert.equal(
    pushNotificationCopy(NotificationType.WEDDING_COUNTDOWN, weddingDay.data).title,
    "اليوم عرسك",
  );
});

/** The scan over one plan: an owner, an assignee, the plan's bride and a contributor. */
async function scan(
  tasks: Array<Record<string, unknown>>,
  options?: { dayReminders?: boolean; onlyTaskReminderTimes?: boolean },
  locks: string[] = [],
) {
  const captured: Array<Record<string, any>> = [];
  const plan = {
    id: "plan-1",
    ownerUserId: "owner-1",
    status: "PLANNING",
    weddingDate: null,
    currency: "YER",
    sharedMembers: [
      { userId: "assignee-1", role: "HELPER", receiveNotifications: true, canManageTasks: true, canViewMoney: false },
      { userId: "bride-1", role: "BRIDE", receiveNotifications: true, canManageTasks: true, canViewMoney: false },
      { userId: "contributor-1", role: "CONTRIBUTOR", receiveNotifications: true, canManageTasks: true, canViewMoney: false },
    ],
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings) ? query.strings.join(" ") : String(query);
      if (sql.includes("pg_try_advisory_xact_lock")) {
        locks.push(sql.replace(/\s+/g, " ").trim());
        return [{ locked: true }];
      }
      if (sql.includes('FROM "User"')) {
        return ["owner-1", "assignee-1", "bride-1", "contributor-1"].map((id) => ({
          id,
          status: UserStatus.ACTIVE,
        }));
      }
      return [{ id: plan.id }];
    },
    weddingPlan: { findMany: async () => [plan] },
    weddingTask: { findMany: async () => tasks },
    paymentSchedule: { findMany: async () => [] },
    budgetCategory: { findMany: async () => [] },
    loanRepayment: { findMany: async () => [] },
    fundingSource: { findMany: async () => [] },
    contributionEvent: {
      findMany: async () => [
        {
          entityId: "task-week",
          entityType: ContributionEntityType.TASK,
          historyScope: { weddingPlanId: plan.id },
          contributorTenure: { actorUserId: "contributor-1" },
        },
      ],
    },
    notificationPreference: { findMany: async () => [] },
    notification: {
      createManyAndReturn: async ({ data }: { data: any[] }) => {
        captured.push(...data);
        return data.map((item, index) => ({ ...item, id: `notification-${index}` }));
      },
    },
    outboxEvent: { create: async () => ({ id: "outbox" }) },
  };
  const service = notificationsService(
    { $transaction: async (operation: (client: typeof tx) => unknown) => operation(tx) } as any,
    {} as any,
    new OutboxService(),
  );
  await service.generateDueNotifications(options);
  return captured;
}

const inDays = (days: number) => new Date(Date.now() + days * DAY_MS);
const scanTask = (id: string, days: number, extra: Record<string, unknown> = {}) => ({
  id,
  weddingPlanId: "plan-1",
  assigneeUserId: null,
  title: id,
  dueDate: inDays(days),
  reminderAt: null,
  status: "TODO",
  ...extra,
});

test("the scan reminds the assignee and the owner on step days only, not every follower", async () => {
  const rows = await scan([
    scanTask("task-week", 7, { assigneeUserId: "assignee-1" }),
    scanTask("task-three", 3, { assigneeUserId: "assignee-1" }),
    scanTask("task-today", 0),
  ]);
  assert.deepEqual(
    rows.map((row) => `${row.userId}:${row.entityId}:${row.type}`).sort(),
    [
      `assignee-1:task-week:${NotificationType.TASK_DUE_SOON}`,
      `owner-1:task-today:${NotificationType.TASK_DUE_SOON}`,
      `owner-1:task-week:${NotificationType.TASK_DUE_SOON}`,
    ],
  );
  // The bride and a contributor followed the task and are no longer told.
  const week = rows.find((row) => row.entityId === "task-week" && row.userId === "owner-1")!;
  assert.equal(week.title, "مهمة بعد أسبوع");
  assert.equal(rows.find((row) => row.entityId === "task-today")!.title, "مهمة اليوم");
});

test("a private task still reminds only its account", async () => {
  const rows = await scan([
    scanTask("task-private", 1, { assigneeUserId: "assignee-1", privateToUserId: "owner-1" }),
  ]);
  assert.deepEqual(rows.map((row) => row.userId), ["owner-1"]);
});

test("a scan in quiet hours leaves the day reminders and keeps a «ذكّرني» time", async () => {
  const reminderAt = new Date(Date.now() - 30 * 60 * 1000);
  const tasks = [
    scanTask("task-due", 1, { assigneeUserId: "assignee-1" }),
    scanTask("task-ping", 20, { reminderAt }),
  ];
  const night = await scan(tasks, { dayReminders: false });
  assert.deepEqual(
    night.map((row) => `${row.userId}:${row.entityId}`).sort(),
    ["owner-1:task-ping"],
  );
  const morning = await scan(tasks, { dayReminders: true });
  assert.deepEqual(
    morning.map((row) => `${row.userId}:${row.entityId}`).sort(),
    ["assignee-1:task-due", "owner-1:task-due", "owner-1:task-ping"],
  );
});

test("the five-minute scan makes only a task's own reminder time, under its own lock and the hourly scan's key", async () => {
  const reminderAt = new Date(Date.now() - 2 * 60 * 1000);
  const tasks = [
    scanTask("task-due", 1, { assigneeUserId: "assignee-1" }),
    scanTask("task-ping", 20, { reminderAt }),
  ];
  const fiveMinuteLocks: string[] = [];
  const fast = await scan(tasks, { onlyTaskReminderTimes: true }, fiveMinuteLocks);
  assert.deepEqual(fast.map((row) => `${row.userId}:${row.entityId}`), ["owner-1:task-ping"]);
  assert.match(fiveMinuteLocks.join(" "), /pg_try_advisory_xact_lock\(20260711, 8\)/);
  // Even in the day the five-minute scan makes no day reminder.
  const hourlyLocks: string[] = [];
  const hourly = await scan(tasks, { dayReminders: true }, hourlyLocks);
  assert.match(hourlyLocks.join(" "), /pg_try_advisory_xact_lock\(20260711, 3\)/);
  // The same reminder under the same key: the second scan to write it is a
  // duplicate the table skips, never a second notice.
  const ping = hourly.find((row) => row.entityId === "task-ping")!;
  assert.equal(fast[0]!.dedupeKey, ping.dedupeKey);
});

/** `notifyTaskDue` over one plan: who was written to. */
async function notifyDue(actorUserId: string | undefined) {
  const recipients: string[] = [];
  const plan = {
    id: "plan-1",
    ownerUserId: "owner-1",
    status: "PLANNING",
    sharedMembers: [
      { userId: "assignee-1", role: "HELPER", canManageTasks: true, receiveNotifications: true },
      { userId: "bride-1", role: "BRIDE", canManageTasks: true, receiveNotifications: true },
    ],
  };
  const task = {
    id: "task-1",
    weddingPlanId: "plan-1",
    assigneeUserId: "assignee-1",
    title: "تأكيد القاعة",
    dueDate: inDays(1),
    status: "TODO",
    privateToUserId: null,
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings) ? query.strings.join(" ") : String(query);
      if (sql.includes('FROM "User"')) {
        if (query.values?.length === 1) return [{ id: query.values[0], status: UserStatus.ACTIVE }];
        return ["owner-1", "assignee-1", "bride-1"].map((id) => ({ id, status: UserStatus.ACTIVE }));
      }
      return [{ id: "locked" }];
    },
    user: { findMany: async () => [] },
    weddingPlan: { findUnique: async () => plan },
    weddingTask: { findUnique: async () => task },
    notificationPreference: { findUnique: async () => null },
    notification: {
      findUnique: async () => null,
      create: async ({ data }: { data: any }) => {
        recipients.push(`${data.userId}:${data.dedupeKey}`);
        return { ...data, id: `notification-${data.userId}`, createdAt: new Date(), readAt: null, archivedAt: null };
      },
    },
    outboxEvent: { create: async () => ({ id: "outbox" }) },
  };
  const service = notificationsService(
    { $transaction: async (operation: (client: typeof tx) => unknown) => operation(tx) } as any,
    {} as any,
    new OutboxService(),
  );
  await service.notifyTaskDue(task as any, actorUserId);
  return recipients.sort();
}

test("a due date moved to tomorrow tells the assignee and the owner, not the one who moved it", async () => {
  const told = await notifyDue("owner-1");
  assert.equal(told.length, 1);
  assert.match(told[0]!, /^assignee-1:assignee-1:TASK_DUE_SOON:task:task-1:due:\d{4}-\d{2}-\d{2}:in:1$/u);
  // The assignee moved it: the owner hears, the assignee does not.
  const toOwner = await notifyDue("assignee-1");
  assert.deepEqual(toOwner.map((entry) => entry.split(":")[0]), ["owner-1"]);
  // Both are told when nobody is the actor, and the key is the scan's own
  // (reader, type, task, due day, step), so the scan does not repeat it.
  assert.deepEqual((await notifyDue(undefined)).map((entry) => entry.split(":")[0]), ["assignee-1", "owner-1"]);
});

// RA-BE-189: no reminder on creation; an edit tells the others, not the actor.
function taskRow(overrides: Record<string, unknown> = {}) {
  const at = new Date("2026-07-11T00:00:00.000Z");
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
    taskCategory: null,
    reminderAt: null,
    status: "TODO",
    priority: "MEDIUM",
    privateToUserId: null,
    createdAt: at,
    updatedAt: at,
    checklistItems: [],
    ...overrides,
  };
}

async function tasksWriting(act: (service: any) => Promise<unknown>) {
  const calls: Array<{ task: any; actorUserId: unknown }> = [];
  const prisma: any = {
    weddingTask: {
      findUnique: async () => taskRow(),
      create: async ({ data }: { data: Record<string, unknown> }) => taskRow(data),
      update: async ({ data }: { data: Record<string, unknown> }) => taskRow(data),
    },
    weddingPlan: { findUnique: async () => ({ ownerUserId: "user-1" }) },
    sharedMember: { findUnique: async () => null },
    $queryRaw: async () => [{ id: "task-1" }],
  };
  prisma.$transaction = async (operation: (tx: any) => Promise<unknown>) => operation(prisma);
  const permissions = {
    canViewMoney: () => true,
    assertTaskManageableInTransaction: async () => ({
      plan: { ownerUserId: "user-1", persona: null },
      isOwner: true,
      sharedMember: null,
    }),
  };
  const service = tasksService(
    prisma,
    permissions as any,
    {
      notifyTaskDue: async (task: unknown, actorUserId: unknown) => {
        calls.push({ task, actorUserId });
      },
    } as any,
    {
      recordForContextInTransaction: async () => undefined,
      ensureTenureInTransaction: async () => undefined,
      recordInTransaction: async () => undefined,
    } as any,
    { qualifyingEntityIds: async () => [], qualifyingEntityIdsInTransaction: async () => [] } as any,
  );
  await act(service);
  return calls;
}

test("creating a task tells nobody of its due date", async () => {
  const calls = await tasksWriting((service) =>
    service.create({ id: "user-1" } as any, "plan-1", {
      title: "تأكيد القاعة",
      dueDate: inDays(1).toISOString(),
    }),
  );
  assert.equal(calls.length, 0);
});

test("moving a due date tells the others with the editor as the actor; any other edit does not", async () => {
  const moved = await tasksWriting((service) =>
    service.update({ id: "user-1" } as any, "task-1", { dueDate: inDays(1).toISOString() }),
  );
  assert.equal(moved.length, 1);
  assert.equal(moved[0]!.actorUserId, "user-1");
  const renamed = await tasksWriting((service) =>
    service.update({ id: "user-1" } as any, "task-1", { title: "تأكيد الفرقة" }),
  );
  assert.equal(renamed.length, 0);
});
