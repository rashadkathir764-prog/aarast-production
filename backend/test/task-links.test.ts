import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BookingsService } from "../src/marketplace/bookings.service";
import { TasksPortService } from "../src/modules/tasks/infrastructure/tasks-port.service";
import { isPlanItemBooked } from "../src/modules/marketplace/public/plan-booked-services";
import { starterTaskService } from "../src/tasks/task-starter-services";
import { manualStatusPatch } from "../src/tasks/task-status-patch";
import { TasksService } from "../src/tasks/tasks.service";
import { WeddingCostsService } from "../src/wedding-costs/wedding-costs.service";

// R4: a task about a money item closes when the item is booked, a task about
// a payment closes when it is paid, and undoing either reopens what it closed.

function fakeTasks() {
  const calls: any[] = [];
  return {
    calls,
    tx: {
      weddingTask: {
        updateMany: async (args: any) => {
          calls.push(args);
          return { count: 1 };
        },
      },
    } as any,
  };
}

test("RA-BE-67: an edit that sends the same status keeps the mark that a link closed the task", () => {
  // The phone sends the status with every edit (a fixed typo in the title).
  assert.deepEqual(manualStatusPatch("DONE", "DONE"), {});
  assert.deepEqual(manualStatusPatch("DONE", undefined), {});
  // A status changed by hand is the person's: no link undoes it later.
  assert.deepEqual(manualStatusPatch("DONE", "TODO"), { status: "TODO", autoClosedAt: null });
  assert.deepEqual(manualStatusPatch("TODO", "DONE"), { status: "DONE", autoClosedAt: null });
});

test("a settled link closes its open tasks and marks them closed by the link", async () => {
  const { calls, tx } = fakeTasks();
  const at = new Date("2027-01-01T10:00:00.000Z");

  await new TasksPortService().syncLinkedTasks(
    tx,
    "plan-1",
    { budgetCategoryId: "item-photo" },
    true,
    at,
  );

  assert.deepEqual(calls, [
    {
      where: {
        weddingPlanId: "plan-1",
        linkedBudgetCategoryId: "item-photo",
        status: { in: ["TODO", "IN_PROGRESS"] },
      },
      data: { status: "DONE", autoClosedAt: at },
    },
  ]);
});

test("an undone link reopens only what the link itself closed", async () => {
  const { calls, tx } = fakeTasks();

  await new TasksPortService().syncLinkedTasks(
    tx,
    "plan-1",
    { scheduleId: "schedule-1" },
    false,
  );

  assert.deepEqual(calls, [
    {
      where: {
        weddingPlanId: "plan-1",
        linkedScheduleId: "schedule-1",
        status: "DONE",
        autoClosedAt: { not: null },
      },
      data: { status: "TODO", autoClosedAt: null },
    },
  ]);
});

test("a schedule that is gone takes its link off the tasks, which stay open", async () => {
  const { calls, tx } = fakeTasks();

  await new TasksPortService().unlinkTasks(tx, "plan-1", { scheduleId: "schedule-1" });

  assert.deepEqual(calls, [
    {
      where: { weddingPlanId: "plan-1", linkedScheduleId: "schedule-1" },
      data: { linkedScheduleId: null, linkedCostId: null, autoClosedAt: null },
    },
  ]);
});

const owners = (input: {
  bookings?: Array<{ quoteRequestId: string; quoteOfferId: string | null }>;
  costs?: Array<{ id: string; quoteOfferId: string; budgetCategoryId: string }>;
  outside?: string[];
}) => ({
  providers: { listPlanConfirmedBookings: async () => input.bookings ?? [] },
  finance: {
    listCostsForOffers: async () => input.costs ?? [],
    listOutsidePartyItemIds: async () => input.outside ?? [],
  },
}) as any;

test("an item is booked by a confirmed booking filed under it", async () => {
  const booked = owners({
    bookings: [{ quoteRequestId: "quote-1", quoteOfferId: "offer-1" }],
    costs: [{ id: "cost-1", quoteOfferId: "offer-1", budgetCategoryId: "item-photo" }],
  });

  assert.equal(await isPlanItemBooked({} as any, booked, "plan-1", "item-photo"), true);
  assert.equal(await isPlanItemBooked({} as any, booked, "plan-1", "item-hall"), false);
});

test("an item is booked by an agreement with someone outside", async () => {
  const outside = owners({ outside: ["item-hall"] });

  assert.equal(await isPlanItemBooked({} as any, outside, "plan-1", "item-hall"), true);
});

test("only the starter tasks that name a service wait on a money item", () => {
  assert.equal(starterTaskService("task-shared-photo"), "التصوير");
  assert.equal(starterTaskService("task-bride-coiffeur"), "الكوافير");
  assert.equal(starterTaskService("task-shared-invites"), null);
  assert.equal(starterTaskService("no-such-template"), null);
});

test("a task from a starter that names a service waits on that item", async () => {
  const seen: any[] = [];
  const service = new TasksService(
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {
      findItemForService: async (_tx: unknown, _plan: string, name: string) => {
        seen.push(name);
        return "item-photo";
      },
      isPlanItem: async () => true,
      listCostsForOffers: async () => [],
      listOutsidePartyItemIds: async () => [],
    } as any,
    { listPlanConfirmedBookings: async () => [] } as any,
  );

  const link = await (service as any).linkForNewTask({}, "plan-1", {
    title: "حجز المصور",
    starterKey: "task-shared-photo",
  });

  assert.deepEqual(seen, ["التصوير"]);
  assert.deepEqual(link, {
    linkedBudgetCategoryId: "item-photo",
    linkedCostId: null,
    linkedScheduleId: null,
    settled: false,
  });
});

test("a task added after its item was booked is already finished", async () => {
  const service = new TasksService(
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {
      isPlanItem: async () => true,
      listCostsForOffers: async () => [],
      listOutsidePartyItemIds: async () => ["item-hall"],
    } as any,
    { listPlanConfirmedBookings: async () => [] } as any,
  );

  const link = await (service as any).resolveLink({}, "plan-1", {
    linkedBudgetCategoryId: "item-hall",
  });

  assert.equal(link.settled, true);
});

test("a link to another plan's item or payment is refused", async () => {
  const service = new TasksService(
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    { isPlanItem: async () => false, findPlanSchedule: async () => null } as any,
    { listPlanConfirmedBookings: async () => [] } as any,
  );
  const refused = (error: any) => error?.response?.code === "TASK_LINK_NOT_IN_PLAN";

  await assert.rejects(
    (service as any).resolveLink({}, "plan-1", { linkedBudgetCategoryId: "x" }),
    refused,
  );
  await assert.rejects(
    (service as any).resolveLink({}, "plan-1", { linkedScheduleId: "x" }),
    refused,
  );
});

test("a payment task keeps the agreement it opens and closes only with its payment", async () => {
  const service = new TasksService(
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    { findPlanSchedule: async () => ({ costId: "cost-1", settled: true }) } as any,
    {} as any,
  );

  const link = await (service as any).resolveLink({}, "plan-1", {
    linkedScheduleId: "schedule-1",
    linkedBudgetCategoryId: "item-hall",
  });

  assert.deepEqual(link, {
    linkedBudgetCategoryId: null,
    linkedCostId: "cost-1",
    linkedScheduleId: "schedule-1",
    settled: true,
  });
});

test("a reader who does not see the money gets no link to it", () => {
  const service = new TasksService(
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );
  const task = {
    id: "task-1",
    checklistItems: [],
    privateToUserId: null,
    linkedBudgetCategoryId: "item-photo",
    linkedCostId: "cost-1",
    linkedScheduleId: "schedule-1",
    autoClosedAt: null,
  };

  const hidden = (service as any).toResponse(task, true, false);
  const shown = (service as any).toResponse(task, true, true);

  assert.equal(hidden.linkedBudgetCategoryId, null);
  assert.equal(hidden.linkedCostId, null);
  assert.equal(hidden.linkedScheduleId, null);
  assert.equal(shown.linkedBudgetCategoryId, "item-photo");
});

test("an agreement paid in full settles the payments still waiting", async () => {
  const seen: any[] = [];
  const service = new WeddingCostsService(
    {} as any,
    {} as any,
    {} as any,
    {} as any,
    undefined,
    undefined,
    undefined,
    {
      syncLinkedTasks: async (...args: any[]) => {
        seen.push(args.slice(1));
      },
    } as any,
  );
  const tx = {
    paymentSchedule: {
      findMany: async () => [
        { id: "schedule-1", weddingCost: { weddingPlanId: "plan-1" } },
      ],
      updateMany: async () => ({ count: 1 }),
    },
  };

  await (service as any).cancelPendingSchedulesWhenPaid(tx, "cost-1", "PAID");

  assert.deepEqual(seen, [["plan-1", { scheduleId: "schedule-1" }, true]]);
});

test("moving an agreement between items settles both once", async () => {
  const seen: any[] = [];
  const service = new WeddingCostsService(
    {} as any,
    {} as any,
    { listPlanConfirmedBookings: async () => [] } as any,
    {} as any,
    undefined,
    undefined,
    {
      listCostsForOffers: async () => [],
      listOutsidePartyItemIds: async () => ["item-new"],
    } as any,
    {
      syncLinkedTasks: async (...args: any[]) => {
        seen.push(args.slice(1));
      },
    } as any,
  );

  await (service as any).syncItemTasks({}, "plan-1", ["item-old", "item-new"]);
  await (service as any).syncItemTasks({}, "plan-1", ["item-new", "item-new"]);

  assert.deepEqual(seen, [
    ["plan-1", { budgetCategoryId: "item-old" }, false],
    ["plan-1", { budgetCategoryId: "item-new" }, true],
    ["plan-1", { budgetCategoryId: "item-new" }, true],
  ]);
});

function bookingWith(tasks: any, itemBooked: boolean) {
  const booking = {
    id: "booking-1",
    status: "CONFIRMED",
    eventDate: new Date("2099-01-21T00:00:00.000Z"),
    providerId: "provider-1",
    quoteRequestId: "quote-1",
    quoteOfferId: "offer-1",
    quoteRequest: { weddingPlanId: "plan-1" },
  };
  const service = new BookingsService(
    {} as any,
    {} as any,
    {} as any,
    {
      listCostsForOffers: async () => [
        { id: "cost-1", quoteOfferId: "offer-1", budgetCategoryId: "item-photo" },
      ],
      listOutsidePartyItemIds: async () => [],
    } as any,
    {
      listPlanConfirmedBookings: async () =>
        itemBooked ? [{ quoteRequestId: "quote-1", quoteOfferId: "offer-1" }] : [],
    } as any,
    tasks,
  );
  return { service, booking };
}

test("a booking moved closes or reopens the tasks of its item", async () => {
  const seen: any[] = [];
  const tasks = {
    syncLinkedTasks: async (...args: any[]) => {
      seen.push(args.slice(1));
    },
  };

  const confirmed = bookingWith(tasks, true);
  await (confirmed.service as any).syncItemTasks({}, confirmed.booking);
  const cancelled = bookingWith(tasks, false);
  await (cancelled.service as any).syncItemTasks({}, cancelled.booking);

  assert.deepEqual(seen, [
    ["plan-1", { budgetCategoryId: "item-photo" }, true],
    ["plan-1", { budgetCategoryId: "item-photo" }, false],
  ]);
});
