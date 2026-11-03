import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionEntityType,
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  SharedMemberRole,
} from "@prisma/client";
import { GuestsService } from "../src/guests/guests.service";

// D80 (a refinement of D52): every participant reads every guest name of the
// plan; a helper with the guests right edits, and reads the phone and notes
// of, only the guests they added. The owner keeps everything.

const now = new Date("2026-11-03T09:00:00.000Z");

function guestRow(
  id: string,
  options: { groupId?: string | null; phone?: string } = {},
) {
  return {
    id,
    weddingPlanId: "plan-1",
    groupId: options.groupId ?? null,
    name: `Guest ${id}`,
    normalizedName: `Guest ${id}`,
    phone: options.phone ?? "+967777000001",
    normalizedPhone: options.phone ?? "+967777000001",
    side: GuestSide.GROOM,
    status: GuestStatus.CONFIRMED,
    invitationStatus: GuestInvitationStatus.SENT,
    attendanceStatus: GuestAttendanceStatus.CONFIRMED,
    seatsCount: 1,
    companionsCount: 2,
    notes: `private note ${id}`,
    createdAt: now,
    updatedAt: now,
  };
}

function groupRow(id: string) {
  return {
    id,
    weddingPlanId: "plan-1",
    name: `Group ${id}`,
    notes: `private group note ${id}`,
    sortOrder: 0,
    createdAt: now,
    updatedAt: now,
  };
}

const ownerGroup = groupRow("group-owner");
const helperGroup = groupRow("group-helper");
const ownerGuest = guestRow("guest-owner", {
  groupId: ownerGroup.id,
  phone: "+967777000002",
});
const helperGuest = guestRow("guest-helper", { phone: "+967777000003" });

const ownerContext = {
  plan: { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" },
  isOwner: true,
  sharedMember: null,
};

function memberContext(canManageGuests: boolean) {
  return {
    plan: { id: "plan-1", ownerUserId: "owner-1", status: "ACTIVE" },
    isOwner: false,
    sharedMember: {
      id: "member-h",
      weddingPlanId: "plan-1",
      userId: "helper-1",
      role: SharedMemberRole.CONTRIBUTOR,
      canManageGuests,
      canManageTasks: false,
      authorityVersion: 1,
      receiveNotifications: true,
      createdAt: now,
      updatedAt: now,
    },
  };
}

/** A database whose reads honour the `id in` filter the old rule sent. */
function database() {
  const byIds = <T extends { id: string }>(rows: T[], where: any) =>
    where?.id?.in ? rows.filter((row) => where.id.in.includes(row.id)) : rows;
  const tx: any = {
    guest: {
      findMany: async ({ where, include }: any) =>
        byIds([ownerGuest, helperGuest], where).map((row) =>
          include
            ? {
                ...row,
                group:
                  row.groupId === ownerGroup.id
                    ? { name: ownerGroup.name }
                    : null,
              }
            : row,
        ),
      findUnique: async ({ where }: any) =>
        [ownerGuest, helperGuest].find((row) => row.id === where.id) ?? null,
      delete: async () => {
        throw new Error("a guest outside the scope must not be deleted");
      },
      update: async () => {
        throw new Error("a guest outside the scope must not be updated");
      },
    },
    guestGroup: {
      findMany: async ({ where }: any) =>
        byIds([ownerGroup, helperGroup], where),
      count: async ({ where }: any) =>
        byIds([ownerGroup, helperGroup], where).length,
    },
    $queryRaw: async () => [{ id: "locked" }],
  };
  tx.$transaction = async (operation: (client: any) => Promise<unknown>) =>
    operation(tx);
  return tx;
}

function service(context: any) {
  const canManage = context.isOwner || context.sharedMember?.canManageGuests;
  return new (GuestsService as any)(
    database(),
    {
      assertPlanReadable: async () => context,
      assertPlanReadableInTransaction: async () => context,
      assertGuestManageableInTransaction: async () => context,
      canManageGuests: () => Boolean(canManage),
    },
    { recordForContextInTransaction: async () => undefined },
    {
      qualifyingEntityIds: async () => [],
      qualifyingEntityIdsInTransaction: async (
        _tx: unknown,
        _planId: string,
        _actorId: string,
        entityTypes: ContributionEntityType[],
      ) =>
        entityTypes.includes(ContributionEntityType.GUEST_GROUP)
          ? [helperGroup.id]
          : [helperGuest.id],
    },
  ) as GuestsService;
}

const helper = { id: "helper-1" } as any;
const owner = { id: "owner-1" } as any;

test("D80: a helper with the guests right reads every guest name, the phone and notes only of their own", async () => {
  const rows = await service(memberContext(true)).findForPlan(
    helper,
    "plan-1",
  );
  const byId = new Map(rows.map((row) => [row.id, row]));

  assert.deepEqual(
    [...byId.keys()].sort(),
    [helperGuest.id, ownerGuest.id].sort(),
    "the helper reads the whole plan's guest list",
  );
  const own = byId.get(helperGuest.id)!;
  assert.equal(own.phone, helperGuest.phone);
  assert.equal(own.notes, helperGuest.notes);
  assert.equal(own.editable, true);

  const groom = byId.get(ownerGuest.id)!;
  assert.equal(groom.name, ownerGuest.name);
  assert.equal(groom.attendanceStatus, GuestAttendanceStatus.CONFIRMED);
  assert.equal(groom.companionsCount, 2);
  assert.equal(groom.phone, null, "the groom's guest number stays his");
  assert.equal(groom.notes, null);
  assert.equal(groom.editable, false);
  assert.equal(groom.groupId, ownerGroup.id, "group names are readable");
});

test("D80: the owner reads and edits every guest", async () => {
  const rows = await service(ownerContext).findForPlan(owner, "plan-1");
  assert.equal(rows.length, 2);
  for (const row of rows) {
    assert.notEqual(row.phone, null);
    assert.notEqual(row.notes, null);
    assert.equal(row.editable, true);
  }
});

test("D80: a participant without the guests right still reads no live guest rows here", async () => {
  const viewer = service(memberContext(false));
  assert.deepEqual(await viewer.findForPlan(helper, "plan-1"), []);
  assert.deepEqual(await viewer.findGroups(helper, "plan-1"), []);
  assert.equal((await viewer.summary(helper, "plan-1")).totalGuests, 0);
});

test("D80: a helper's figures count the whole plan", async () => {
  const summary = await service(memberContext(true)).summary(helper, "plan-1");
  assert.equal(summary.totalGuests, 2);
  assert.equal(summary.confirmed, 2);
  assert.equal(summary.groupsCount, 2);
  assert.equal(summary.byGroup[ownerGroup.name], 1);
});

test("D80: a helper reads every group, the notes and edits only of their own", async () => {
  const groups = await service(memberContext(true)).findGroups(
    helper,
    "plan-1",
  );
  const byId = new Map(groups.map((group) => [group.id, group]));
  assert.deepEqual(
    [...byId.keys()].sort(),
    [helperGroup.id, ownerGroup.id].sort(),
  );
  assert.equal(byId.get(helperGroup.id)!.notes, helperGroup.notes);
  assert.equal(byId.get(helperGroup.id)!.editable, true);
  assert.equal(byId.get(ownerGroup.id)!.name, ownerGroup.name);
  assert.equal(byId.get(ownerGroup.id)!.notes, null);
  assert.equal(byId.get(ownerGroup.id)!.editable, false);

  const ownerGroups = await service(ownerContext).findGroups(owner, "plan-1");
  assert.ok(ownerGroups.every((group) => group.editable && group.notes));
});

test("D80: a helper still cannot open, change or remove the groom's guest", async () => {
  const svc = service(memberContext(true));
  await assert.rejects(() => svc.findOne(helper, ownerGuest.id), /Guest not found/);
  await assert.rejects(
    () => svc.update(helper, ownerGuest.id, { name: "Changed" }),
    /Guest not found/,
  );
  await assert.rejects(() => svc.remove(helper, ownerGuest.id), /Guest not found/);
});
