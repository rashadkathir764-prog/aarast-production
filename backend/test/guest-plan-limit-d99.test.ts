import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { GuestsService } from "../src/guests/guests.service";
import { PLAN_GUESTS_MAX } from "../src/modules/guests/public/guest-text-limits";

// D99 (RA-BE-62): a plan holds up to PLAN_GUESTS_MAX guests and its list is
// read whole. The list used to stop at the general cap of 1000 without a
// word, and the phone replaces its copy with what arrives, so the oldest
// guests of a big wedding vanished from it.

const owner = { id: "owner-1" } as any;
const ownerContext = {
  plan: { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" },
  isOwner: true,
  sharedMember: null,
};
const day = new Date("2026-11-07T09:00:00.000Z");

function guestRow(index: number, createdAt = new Date(day.getTime() + index * 1000)) {
  return {
    id: `guest-${String(index).padStart(5, "0")}`,
    weddingPlanId: "plan-1",
    groupId: null,
    name: `ضيف ${index}`,
    normalizedName: `ضيف ${index}`,
    phone: null,
    normalizedPhone: null,
    side: "OTHER",
    status: "INVITED",
    invitationStatus: "NOT_SENT",
    attendanceStatus: "PENDING",
    seatsCount: 1,
    companionsCount: 0,
    notes: null,
    createdAt,
    updatedAt: createdAt,
  };
}

/** Rows ordered and paged as Postgres would by `orderBy`, `take` and `skip`. */
function database(seed: any[] = []) {
  const rows = [...seed];
  const log: string[] = [];
  let nextId = 1;
  const compare = (orderBy: Array<Record<string, "asc" | "desc">>) => (a: any, b: any) => {
    for (const rule of orderBy) {
      const [key, direction] = Object.entries(rule)[0];
      const left = a[key] instanceof Date ? a[key].getTime() : a[key];
      const right = b[key] instanceof Date ? b[key].getTime() : b[key];
      if (left === right) continue;
      return (left < right ? -1 : 1) * (direction === "desc" ? -1 : 1);
    }
    return 0;
  };
  const tx: any = {
    $queryRaw: async () => [{ id: "locked" }],
    guest: {
      findMany: async ({ where, orderBy = [], take, skip = 0 }: any) => {
        log.push("list");
        const listed = rows
          .filter((row) => row.weddingPlanId === where.weddingPlanId)
          .sort(compare(orderBy));
        return listed.slice(skip, take === undefined ? undefined : skip + take);
      },
      count: async ({ where }: any) => {
        log.push("count");
        assert.equal(Object.keys(where).length, 1, "the count is the plan's whole list");
        return rows.filter((row) => row.weddingPlanId === where.weddingPlanId).length;
      },
      findFirst: async () => null,
      create: async ({ data }: any) => {
        log.push("create");
        const row = { ...guestRow(0), ...data, id: `new-${nextId++}`, createdAt: day, updatedAt: day };
        rows.push(row);
        return row;
      },
    },
    guestEventInvite: { findMany: async () => [] },
  };
  tx.$transaction = async (operation: (client: any) => Promise<unknown>) => operation(tx);
  return { tx, rows, log };
}

function service(db: ReturnType<typeof database>) {
  return new (GuestsService as any)(
    db.tx,
    {
      assertPlanReadableInTransaction: async (client: unknown) => {
        assert.equal(client, db.tx);
        return ownerContext;
      },
      // The plan's lock is taken here (WeddingPlan FOR SHARE), first.
      assertGuestManageableInTransaction: async (client: unknown) => {
        assert.equal(client, db.tx);
        db.log.push("lock");
        return ownerContext;
      },
      canManageGuests: () => true,
    },
    { recordForContextInTransaction: async () => undefined },
    { qualifyingEntityIdsInTransaction: async () => [] },
    { listPlanEvents: async () => [] },
  ) as GuestsService;
}

/** The refusal, with how many the plan already has (the phone says the same). */
const isPlanFull = (count: number) => (error: any) => {
  assert.equal(error?.getStatus?.(), 422);
  assert.equal(error.response.code, "PLAN_GUESTS_LIMIT");
  assert.equal(
    error.response.message,
    `الخطة تشيل ${PLAN_GUESTS_MAX} اسم بالكثير، وفيها الحين ${count}.`,
  );
  return true;
};

test("D99: the plan's list comes back whole, past the general cap of 1000", async () => {
  const db = database(Array.from({ length: 1200 }, (_, index) => guestRow(index)));
  const listed = await service(db).findForPlan(owner, "plan-1");
  assert.equal(listed.length, 1200);
  // Newest first, as before.
  assert.equal(listed[0].id, "guest-01199");
  assert.equal(listed[1199].id, "guest-00000");
});

test("D99: guests added in the same instant keep one order, so pages never skip or repeat one", async () => {
  const db = database([guestRow(1, day), guestRow(2, day), guestRow(3, day)]);
  const listed = await service(db).findForPlan(owner, "plan-1");
  assert.deepEqual(
    listed.map((guest) => guest.id),
    ["guest-00003", "guest-00002", "guest-00001"],
  );
});

test("D99: a client that asks for a page still gets that page", async () => {
  const db = database(Array.from({ length: 300 }, (_, index) => guestRow(index)));
  const page = await service(db).findForPlan(owner, "plan-1", { take: 50, skip: 100 } as any);
  assert.equal(page.length, 50);
  assert.equal(page[0].id, "guest-00199");
  assert.equal(page[49].id, "guest-00150");
});

test("D99: a plan at its limit refuses one more guest with its reason, and saves nothing", async () => {
  const db = database(Array.from({ length: PLAN_GUESTS_MAX }, (_, index) => guestRow(index)));
  await assert.rejects(
    service(db).create(owner, "plan-1", { name: "ضيف زائد" } as any),
    isPlanFull(PLAN_GUESTS_MAX),
  );
  assert.equal(db.rows.length, PLAN_GUESTS_MAX);
  assert.ok(!db.log.includes("create"));
});

test("D99: a list that would pass the limit is refused whole and says how many the plan has", async () => {
  const db = database(Array.from({ length: PLAN_GUESTS_MAX - 1 }, (_, index) => guestRow(index)));
  const guests = service(db);
  await assert.rejects(
    guests.bulkCreate(owner, "plan-1", { items: [{ name: "أ" }, { name: "ب" }] } as any),
    isPlanFull(PLAN_GUESTS_MAX - 1),
  );
  assert.equal(db.rows.length, PLAN_GUESTS_MAX - 1, "nothing of the list is saved");

  // The last place is still there for one guest.
  await guests.create(owner, "plan-1", { name: "أ" } as any);
  assert.equal(db.rows.length, PLAN_GUESTS_MAX);
});

test("D99: the plan is counted after its lock, in the transaction that adds", async () => {
  const db = database([guestRow(1)]);
  const guests = service(db);
  await guests.create(owner, "plan-1", { name: "أ" } as any);
  assert.deepEqual(db.log, ["lock", "count", "create"]);

  db.log.length = 0;
  await guests.bulkCreate(owner, "plan-1", { items: [{ name: "ب" }, { name: "ج" }] } as any);
  assert.deepEqual(db.log, ["lock", "count", "create", "create"]);
});
