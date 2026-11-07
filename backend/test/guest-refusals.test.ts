import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { GuestsService } from "../src/guests/guests.service";

// RA-BE-82: a refusal in guests says what happened in Arabic, with a code.
// An English one reaches the phone as its generic line for the status, and a
// 409 there reads «تغيّرت البيانات قبل الحفظ. حدّث الصفحة», which no refresh
// fixes; a queued change refused that way stays refused with a false reason.

const owner = { id: "owner-1" } as any;
const ownerContext = {
  plan: { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" },
  isOwner: true,
  sharedMember: null,
};
const now = new Date("2026-11-07T09:00:00.000Z");
const arabic = /[؀-ۿ]/;

const existingGuest = {
  id: "guest-1",
  weddingPlanId: "plan-1",
  groupId: null,
  name: "عمي صالح",
  normalizedName: "عمي صالح",
  phone: null,
  normalizedPhone: null,
  side: "OTHER",
  status: "INVITED",
  invitationStatus: "NOT_SENT",
  attendanceStatus: "PENDING",
  seatsCount: 1,
  companionsCount: 0,
  notes: null,
  createdAt: now,
  updatedAt: now,
};
const existingGroup = {
  id: "group-1",
  weddingPlanId: "plan-1",
  name: "آل الحمدي",
  notes: null,
  sortOrder: 0,
  createdAt: now,
  updatedAt: now,
};

function uniqueViolation() {
  return new Prisma.PrismaClientKnownRequestError("Unique constraint failed", {
    code: "P2002",
    clientVersion: "test",
  });
}

function database(options: { groupInPlan?: boolean } = {}) {
  const writes: string[] = [];
  const tx: any = {
    // Locks: the guest and the group rows are the plan's, except a group
    // that is not in the plan.
    $queryRaw: async (query: { strings?: readonly string[] }) =>
      query.strings?.join("").includes('FROM "GuestGroup"') && options.groupInPlan === false
        ? []
        : [{ id: "locked" }],
    guest: {
      count: async () => 1,
      findFirst: async () => null,
      findUnique: async ({ where }: any) => (where.id === existingGuest.id ? existingGuest : null),
      create: async () => {
        writes.push("guest.create");
        return existingGuest;
      },
      update: async () => {
        writes.push("guest.update");
        return existingGuest;
      },
    },
    guestGroup: {
      findUnique: async ({ where }: any) => (where.id === existingGroup.id ? existingGroup : null),
      // The plan already has a group by the name asked for.
      create: async () => {
        throw uniqueViolation();
      },
      update: async () => {
        throw uniqueViolation();
      },
    },
    guestEventInvite: { findMany: async () => [] },
  };
  tx.$transaction = async (operation: (client: any) => Promise<unknown>) => operation(tx);
  return { tx, writes };
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
    { qualifyingEntityIdsInTransaction: async () => [] },
    { listPlanEvents: async () => [] },
  ) as GuestsService;
}

const refusedWith = (status: number, code: string) => (error: any) => {
  assert.equal(error?.getStatus?.(), status);
  assert.equal(error.response?.code, code);
  assert.match(error.response.message, arabic, `${code} speaks Arabic`);
  return true;
};

test("RA-BE-82: a group name the plan already has is refused as taken, in Arabic", async () => {
  const guests = service(database());
  await assert.rejects(
    guests.createGroup(owner, "plan-1", { name: "آل الحمدي" } as any),
    refusedWith(409, "DUPLICATE_VALUE"),
  );
  await assert.rejects(
    guests.updateGroup(owner, existingGroup.id, { name: "آل الحمدي" } as any),
    refusedWith(409, "DUPLICATE_VALUE"),
  );
});

test("RA-BE-82: a name of only spaces is refused with its code, and nothing is written", async () => {
  const db = database();
  const guests = service(db);
  await assert.rejects(
    guests.create(owner, "plan-1", { name: "   " } as any),
    refusedWith(400, "GUEST_NAME_REQUIRED"),
  );
  await assert.rejects(
    guests.update(owner, existingGuest.id, { name: " \t " } as any),
    refusedWith(400, "GUEST_NAME_REQUIRED"),
  );
  await assert.rejects(
    guests.createGroup(owner, "plan-1", { name: "  " } as any),
    refusedWith(400, "GUEST_GROUP_NAME_REQUIRED"),
  );
  await assert.rejects(
    guests.updateGroup(owner, existingGroup.id, { name: "  " } as any),
    refusedWith(400, "GUEST_GROUP_NAME_REQUIRED"),
  );
  assert.deepEqual(db.writes, []);
});

test("RA-BE-82: a group that is not the plan's is refused with its code", async () => {
  const db = database({ groupInPlan: false });
  const guests = service(db);
  await assert.rejects(
    guests.create(owner, "plan-1", { name: "خالد", groupId: "group-elsewhere" } as any),
    refusedWith(400, "GUEST_GROUP_NOT_IN_PLAN"),
  );
  await assert.rejects(
    guests.update(owner, existingGuest.id, { groupId: "group-elsewhere" } as any),
    refusedWith(400, "GUEST_GROUP_NOT_IN_PLAN"),
  );
  assert.deepEqual(db.writes, []);
});
