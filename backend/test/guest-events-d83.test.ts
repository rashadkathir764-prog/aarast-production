import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { GuestsService } from "../src/guests/guests.service";

// D83: a guest is invited to the wedding by being a guest; the plan's other
// events (the lunch, the aqd...) are chosen for them when they are added or
// edited, each with its own reply, and the summary counts them per event.

const now = new Date("2026-11-03T09:00:00.000Z");
const owner = { id: "owner-1" } as any;
const ownerContext = {
  plan: { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" },
  isOwner: true,
  sharedMember: null,
};
const planEvents = [
  { id: "event-wedding", weddingPlanId: "plan-1", type: "WEDDING", title: null, date: now, timeSlot: null, exactTime: null, placeLabel: null },
  { id: "event-lunch", weddingPlanId: "plan-1", type: "LUNCH", title: null, date: now, timeSlot: "DHUHR", exactTime: null, placeLabel: null },
  { id: "event-aqd", weddingPlanId: "plan-1", type: "AQD", title: "العقد", date: null, timeSlot: null, exactTime: null, placeLabel: null },
];

function database() {
  const guests = new Map<string, any>();
  const invites: any[] = [];
  let nextId = 1;
  const tx: any = {
    $queryRaw: async () => [{ id: "locked" }],
    guest: {
      create: async ({ data }: any) => {
        const row = { id: `guest-${nextId++}`, ...data, createdAt: now, updatedAt: now };
        guests.set(row.id, row);
        return row;
      },
      findUnique: async ({ where }: any) => guests.get(where.id) ?? null,
      findFirst: async () => null,
      findMany: async () => [...guests.values()],
      // D99: an add counts the plan's guests first.
      count: async () => guests.size,
      update: async ({ where, data }: any) => {
        const row = { ...guests.get(where.id), ...data, updatedAt: now };
        guests.set(where.id, row);
        return row;
      },
    },
    guestEventInvite: {
      findMany: async ({ where }: any) =>
        invites.filter((row) => where.guestId.in.includes(row.guestId)),
      deleteMany: async ({ where }: any) => {
        for (let index = invites.length - 1; index >= 0; index -= 1) {
          const row = invites[index];
          if (row.guestId === where.guestId && !where.planEventId.notIn.includes(row.planEventId)) {
            invites.splice(index, 1);
          }
        }
        return { count: 0 };
      },
      createMany: async ({ data }: any) => {
        for (const entry of data) {
          if (!invites.some((row) => row.guestId === entry.guestId && row.planEventId === entry.planEventId)) {
            invites.push({ ...entry, attendanceStatus: "PENDING", companionsCount: 0, respondedAt: null });
          }
        }
        return { count: data.length };
      },
    },
    guestGroup: { count: async () => 0, findMany: async () => [] },
  };
  tx.$transaction = async (operation: (client: any) => Promise<unknown>) => operation(tx);
  return { tx, guests, invites };
}

function service(db: ReturnType<typeof database>) {
  return new (GuestsService as any)(
    db.tx,
    {
      assertPlanReadableInTransaction: async () => ownerContext,
      assertGuestManageableInTransaction: async () => ownerContext,
      canManageGuests: () => true,
    },
    { recordForContextInTransaction: async () => undefined },
    { qualifyingEntityIds: async () => [], qualifyingEntityIdsInTransaction: async () => [] },
    { listPlanEvents: async () => planEvents },
  ) as GuestsService;
}

test("a new guest is invited to the chosen events; the wedding needs no choice", async () => {
  const db = database();
  const guests = service(db);
  const created = await guests.create(owner, "plan-1", {
    name: "عمي صالح",
    eventIds: ["event-lunch"],
  } as any);
  assert.deepEqual(
    created.events.map((event) => [event.planEventId, event.attendanceStatus]),
    [["event-lunch", "PENDING"]],
  );
  const plain = await guests.create(owner, "plan-1", { name: "خالد" } as any);
  assert.deepEqual(plain.events, []);
});

test("an event the plan does not have, or the wedding row itself, is refused", async () => {
  const db = database();
  const guests = service(db);
  await assert.rejects(
    guests.create(owner, "plan-1", { name: "س", eventIds: ["event-other"] } as any),
    (error: any) => error?.response?.code === "GUEST_EVENT_UNKNOWN",
  );
  await assert.rejects(
    guests.create(owner, "plan-1", { name: "س", eventIds: ["event-wedding"] } as any),
    (error: any) => error?.response?.code === "GUEST_EVENT_UNKNOWN",
  );
  assert.equal(db.guests.size, 0, "nothing is saved when the events are refused");
});

test("editing the events keeps the replies of the events that stay", async () => {
  const db = database();
  const guests = service(db);
  const created = await guests.create(owner, "plan-1", {
    name: "عمي صالح",
    eventIds: ["event-lunch", "event-aqd"],
  } as any);
  // The guest answered the lunch through their link.
  const lunch = db.invites.find((row) => row.planEventId === "event-lunch");
  Object.assign(lunch, { attendanceStatus: "CONFIRMED", companionsCount: 2, respondedAt: now });

  const updated = await guests.update(owner, created.id, { eventIds: ["event-lunch"] } as any);
  assert.deepEqual(
    updated.events.map((event) => [event.planEventId, event.attendanceStatus, event.companionsCount]),
    [["event-lunch", "CONFIRMED", 2]],
  );
  // An edit that says nothing about events leaves them as they are.
  const renamed = await guests.update(owner, created.id, { name: "صالح" } as any);
  assert.equal(renamed.events.length, 1);
  const [listed] = await guests.findForPlan(owner, "plan-1");
  assert.equal(listed.events[0].planEventId, "event-lunch");
});

test("the summary counts the invited and their replies per event", async () => {
  const db = database();
  const guests = service(db);
  await guests.create(owner, "plan-1", { name: "أ", eventIds: ["event-lunch"] } as any);
  await guests.create(owner, "plan-1", { name: "ب", eventIds: ["event-lunch", "event-aqd"] } as any);
  await guests.create(owner, "plan-1", { name: "ج" } as any);
  Object.assign(db.invites[0], { attendanceStatus: "CONFIRMED", companionsCount: 1 });

  const summary = await guests.summary(owner, "plan-1");
  assert.deepEqual(summary.byEvent, [
    { planEventId: "event-lunch", label: "الغداء", invited: 2, confirmed: 1, declined: 0, pending: 1, companions: 1 },
    { planEventId: "event-aqd", label: "العقد", invited: 1, confirmed: 0, declined: 0, pending: 1, companions: 0 },
  ]);
});
