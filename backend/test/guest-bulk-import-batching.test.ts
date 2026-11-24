import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { GuestsService } from "../src/guests/guests.service";

// RA-BE-181: the guest import made about five queries for every guest inside
// its one transaction (the plan's events, the group, the phone, the insert,
// the events' links and their read), up to 200 guests. It now reads each
// thing once for the whole list and writes the guests, and their links to
// the plan's events, in one statement each, so the number of queries does not
// grow with the list.

const owner = { id: "owner-1" } as any;
const ownerContext = {
  plan: { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" },
  isOwner: true,
  sharedMember: null,
};
const day = new Date("2026-11-07T09:00:00.000Z");

interface Options {
  /** Phones already saved in the plan. */
  savedPhones?: string[];
  events?: Array<{ id: string; type: string }>;
}

function harness(options: Options = {}) {
  const log: string[] = [];
  const created: any[] = [];
  const invites: Array<{ guestId: string; planEventId: string }> = [];
  const saved = new Set(options.savedPhones ?? []);
  const tx: any = {
    $queryRaw: async () => {
      log.push("groupLock");
      return [{ id: "locked" }];
    },
    guest: {
      count: async () => {
        log.push("count");
        return 0;
      },
      findMany: async ({ where }: any) => {
        log.push("duplicates");
        const wanted: string[] = where.normalizedPhone.in;
        return wanted
          .filter((phone) => saved.has(phone))
          .map((normalizedPhone) => ({ normalizedPhone }));
      },
      findFirst: async () => {
        log.push("duplicate");
        return null;
      },
      create: async () => {
        log.push("create");
        throw new Error("one insert per guest");
      },
      createManyAndReturn: async ({ data }: any) => {
        log.push("insertGuests");
        const rows = data.map((row: any, index: number) => ({
          id: `g-${created.length + index}`,
          createdAt: day,
          updatedAt: day,
          rsvpLinkVersion: 0,
          weddingAnsweredVersion: null,
          linkOpenedAt: null,
          ...row,
        }));
        created.push(...rows);
        return rows;
      },
    },
    guestEventInvite: {
      createMany: async ({ data }: any) => {
        log.push("insertInvites");
        invites.push(...data);
        return { count: data.length };
      },
      deleteMany: async () => {
        log.push("deleteInvites");
        return { count: 0 };
      },
      findMany: async ({ where }: any) => {
        log.push("readInvites");
        return invites
          .filter((invite) => where.guestId.in.includes(invite.guestId))
          .map((invite) => ({
            ...invite,
            attendanceStatus: "PENDING",
            companionsCount: 0,
            respondedAt: null,
            answeredVersion: null,
          }));
      },
    },
  };
  tx.$transaction = async (operation: (client: any) => Promise<unknown>) =>
    operation(tx);
  const recorded: string[] = [];
  const service = new (GuestsService as any)(
    tx,
    {
      assertGuestManageableInTransaction: async () => {
        log.push("lock");
        return ownerContext;
      },
    },
    {
      recordManyForContextInTransaction: async (_tx: unknown, _ctx: unknown, inputs: any[]) => {
        log.push("recordMany");
        recorded.push(...inputs.map((input) => input.entityId));
      },
    },
    { qualifyingEntityIdsInTransaction: async () => [] },
    {
      listPlanEvents: async () => {
        log.push("planEvents");
        return options.events ?? [];
      },
    },
  ) as GuestsService;
  return { service, log, created, invites, recorded };
}

const items = (count: number, extra: (index: number) => object = () => ({})) =>
  Array.from({ length: count }, (_, index) => ({
    name: `ضيف ${index}`,
    phone: `+96777${String(1000000 + index)}`,
    ...extra(index),
  }));

const withEvents = {
  events: [
    { id: "wedding", type: "WEDDING" },
    { id: "ev-a", type: "CUSTOM" },
    { id: "ev-b", type: "CUSTOM" },
  ],
};

const importOf = (count: number) =>
  items(count, (index) => ({ groupId: "grp-1", eventIds: index % 2 ? ["ev-a"] : ["ev-a", "ev-b"] }));

test("the number of queries does not grow with the list", async () => {
  const small = harness(withEvents);
  await small.service.bulkCreate(owner, "plan-1", { items: importOf(3) } as any);
  const large = harness(withEvents);
  await large.service.bulkCreate(owner, "plan-1", { items: importOf(120) } as any);

  assert.equal(small.log.length, large.log.length, small.log.join(","));
  assert.ok(large.log.length <= 10, `${large.log.length}: ${large.log.join(",")}`);
  assert.equal(large.created.length, 120);
  assert.equal(large.log.filter((entry) => entry === "insertGuests").length, 1);
  assert.equal(large.log.filter((entry) => entry === "insertInvites").length, 1);
  assert.equal(large.log.filter((entry) => entry === "planEvents").length, 1);
  assert.equal(large.log.filter((entry) => entry === "groupLock").length, 1, "one lock for the one group");
  assert.equal(large.log.filter((entry) => entry === "duplicates").length, 1);
  assert.equal(large.log.filter((entry) => entry === "recordMany").length, 1, "one call to record the list");
});

test("each guest comes back in the order given, with its own events, and is recorded", async () => {
  const { service, invites, recorded } = harness(withEvents);
  const { created } = await service.bulkCreate(owner, "plan-1", {
    items: importOf(4),
  } as any);
  assert.deepEqual(
    created.map((guest) => guest.name),
    ["ضيف 0", "ضيف 1", "ضيف 2", "ضيف 3"],
  );
  assert.deepEqual(
    created.map((guest) => guest.events.map((event) => event.planEventId).sort()),
    [["ev-a", "ev-b"], ["ev-a"], ["ev-a", "ev-b"], ["ev-a"]],
  );
  assert.equal(invites.length, 6);
  assert.deepEqual(recorded, created.map((guest) => guest.id));
});

test("a guest with no events asks nothing of them", async () => {
  const { service, log } = harness();
  const { created } = await service.bulkCreate(owner, "plan-1", {
    items: items(5),
  } as any);
  assert.equal(created.length, 5);
  assert.ok(created.every((guest) => guest.events.length === 0));
  assert.ok(!log.includes("planEvents"));
  assert.ok(!log.includes("insertInvites"));
  assert.ok(!log.includes("groupLock"));
});

const isDuplicate = (error: any) => error?.getStatus?.() === 409;

test("a phone the plan already has, or twice in the list, refuses the whole list", async () => {
  const saved = harness({ savedPhones: ["+967771000002"] });
  await assert.rejects(
    saved.service.bulkCreate(owner, "plan-1", { items: items(4) } as any),
    isDuplicate,
  );
  assert.equal(saved.created.length, 0, "nothing is written");

  const twice = harness();
  const list = items(3);
  list[2] = { ...list[2], phone: list[0].phone };
  await assert.rejects(
    twice.service.bulkCreate(owner, "plan-1", { items: list } as any),
    isDuplicate,
  );
  assert.equal(twice.created.length, 0);
});

test("an event that is not the plan's refuses the list before any guest is written", async () => {
  const { service, created } = harness(withEvents);
  await assert.rejects(
    service.bulkCreate(owner, "plan-1", {
      items: items(3, (index) => ({ eventIds: index === 2 ? ["ev-zzz"] : ["ev-a"] })),
    } as any),
    (error: any) => error?.response?.code === "GUEST_EVENT_UNKNOWN",
  );
  assert.equal(created.length, 0);
});
