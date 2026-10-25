import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ForbiddenException, NotFoundException } from "@nestjs/common";
import {
  BookingStatus,
  GuestAttendanceStatus,
  SharedMemberRole,
  UserRole,
  WeddingPlanStatus,
  WeddingTaskStatus,
} from "@prisma/client";
import { DashboardService } from "../src/dashboard/dashboard.service";
import { firstNameOf } from "../src/dashboard/plan-read-view";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { rolePermissionDefaults } from "../src/modules/collaboration/internal/plan-permissions";
import { readsPlanSections } from "../src/modules/collaboration/public/collaboration-permission.port";
import { GuestsPortService } from "../src/modules/guests/infrastructure/guests-port.service";
import { QuoteReadService } from "../src/modules/marketplace/infrastructure/quote-read.service";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";
import { TasksPortService } from "../src/modules/tasks/infrastructure/tasks-port.service";

// D52: reading is separate from editing. Every member of a plan, in every
// role, reads its tasks, its guests by name and reply and its bookings;
// editing keeps its manage flags; money and phones never reach this read.

const PLAN = {
  id: "plan-1",
  ownerUserId: "owner-1",
  status: WeddingPlanStatus.PLANNING,
};
const ALL_ROLES = Object.values(SharedMemberRole);

function member(role: SharedMemberRole, userId = "member-1") {
  return {
    id: `membership-${role}`,
    weddingPlanId: PLAN.id,
    userId,
    role,
    authorityVersion: 1,
    ...rolePermissionDefaults(role),
  };
}

/** A real permission service over one plan and (at most) one membership. */
function permissionsFor(membership: ReturnType<typeof member> | null) {
  return new PermissionService(
    {
      weddingPlan: { findUnique: async () => PLAN },
      sharedMember: { findUnique: async () => membership },
    } as any,
    new PlanReadService(),
  );
}

// The owners' rows carry the fields a careless serializer would leak: a task
// description with an amount, a guest phone, a booking note. The read view
// lists its fields by hand, so none of them may appear in the response.
const SECRET_STRINGS = [
  "500,000",
  "+967777000999",
  "سري: العربون",
  "contact-phone",
];

function fakeOwners(calls: string[] = []) {
  return {
    tasks: {
      listReadableTasks: async (_tx: unknown, planId: string, reader: string) => {
        calls.push(`tasks:${planId}:${reader}`);
        return [
          {
            id: "t1",
            title: "ادفع دفعة القاعة",
            status: WeddingTaskStatus.TODO,
            dueDate: new Date("2026-10-27T00:00:00.000Z"),
            assigneeUserId: "owner-1",
            responsibleName: null,
            description: "500,000 ر.ي",
            responsiblePhone: "+967777000999",
          },
          {
            id: "t2",
            title: "رتّب الغداء",
            status: WeddingTaskStatus.TODO,
            dueDate: null,
            assigneeUserId: "helper-1",
            responsibleName: null,
          },
          {
            id: "t3",
            title: "حجز سيارات الزفة",
            status: WeddingTaskStatus.DONE,
            dueDate: null,
            assigneeUserId: null,
            responsibleName: "الوالد",
          },
          {
            id: "t4",
            title: "مهمتي",
            status: WeddingTaskStatus.DONE,
            dueDate: null,
            assigneeUserId: "member-1",
            responsibleName: null,
          },
        ];
      },
    },
    guests: {
      listReadableGuests: async () => [
        {
          id: "g1",
          name: "عبدالله الحمدي",
          attendanceStatus: GuestAttendanceStatus.CONFIRMED,
          phone: "+967777000999",
        },
        { id: "g2", name: "ياسر الأهدل", attendanceStatus: GuestAttendanceStatus.DECLINED },
        { id: "g3", name: "يحيى السنيدار", attendanceStatus: GuestAttendanceStatus.PENDING },
      ],
    },
    quotes: {
      listReadableBookings: async () => [
        {
          id: "b1",
          providerId: "p1",
          businessName: "قاعة سبأ",
          primaryCategoryId: "venue",
          serviceTitle: "قاعة الأفراح",
          status: "CONFIRMED",
          eventDate: new Date("2027-01-21T00:00:00.000Z"),
          note: "سري: العربون",
          contactPhone: "contact-phone",
        },
      ],
    },
    users: {
      getAppIdentities: async (_tx: unknown, ids: readonly string[]) =>
        [
          { id: "owner-1", name: "محمد علي", appName: null, role: UserRole.USER, phone: "+967777000999" },
          { id: "helper-1", name: "صالح", appName: null, role: UserRole.USER, phone: "+967777000999" },
        ].filter((user) => ids.includes(user.id)),
    },
    catalog: {
      getCategories: async (_tx: unknown, ids: readonly string[]) =>
        ids.includes("venue") ? [{ id: "venue", nameAr: "قاعات" }] : [],
    },
  } as any;
}

function dashboardFor(
  membership: ReturnType<typeof member> | null,
  isOwner = false,
  calls: string[] = [],
) {
  const permissions = {
    assertPlanReadableInTransaction: async () => {
      const context = { plan: PLAN, isOwner, sharedMember: membership };
      if (!readsPlanSections(context as any)) {
        throw new NotFoundException("Wedding plan not found");
      }
      return context;
    },
  };
  const prisma = { $transaction: async (operation: any) => operation({}) };
  return new DashboardService(
    prisma as any,
    permissions as any,
    {} as any,
    fakeOwners(calls),
  );
}

test("every role reads the plan's sections; no membership reads nothing", () => {
  for (const role of ALL_ROLES) {
    assert.equal(
      readsPlanSections({ isOwner: false, sharedMember: member(role) as any }),
      true,
      role,
    );
  }
  assert.equal(readsPlanSections({ isOwner: true, sharedMember: null }), true);
  assert.equal(readsPlanSections({ isOwner: false, sharedMember: null }), false);
});

test("role x endpoint: the read view opens for the owner and every role, 404 for an outsider", async () => {
  const owner = await dashboardFor(null, true).getPlanReadView(
    { id: "owner-1" } as any,
    PLAN.id,
  );
  assert.equal(owner.tasks.total, 4);

  for (const role of ALL_ROLES) {
    const calls: string[] = [];
    const view = await dashboardFor(member(role), false, calls).getPlanReadView(
      { id: "member-1" } as any,
      PLAN.id,
    );
    assert.equal(view.weddingPlanId, PLAN.id, role);
    assert.equal(view.tasks.total, 4, role);
    assert.equal(view.tasks.done, 2, role);
    assert.equal(view.guests.total, 3, role);
    assert.equal(view.bookings.items.length, 1, role);
    // The tasks owner is asked as this reader, so another account's
    // private task never comes back.
    assert.deepEqual(calls, [`tasks:${PLAN.id}:member-1`], role);
  }

  await assert.rejects(
    () => dashboardFor(null).getPlanReadView({ id: "stranger" } as any, PLAN.id),
    NotFoundException,
  );
});

test("the read view carries no money, no phone, no note and no description", async () => {
  const view = await dashboardFor(member(SharedMemberRole.VIEWER)).getPlanReadView(
    { id: "member-1" } as any,
    PLAN.id,
  );
  const json = JSON.stringify(view);
  for (const secret of SECRET_STRINGS) {
    assert.equal(json.includes(secret), false, secret);
  }
  for (const key of [
    "amount",
    "budget",
    "price",
    "paid",
    "funding",
    "phone",
    "description",
    "note",
    "assigneeUserId",
    "providerId",
  ]) {
    assert.equal(json.toLowerCase().includes(`"${key.toLowerCase()}`), false, key);
  }
  assert.deepEqual(Object.keys(view).sort(), ["bookings", "guests", "tasks", "weddingPlanId"]);
  assert.deepEqual(Object.keys(view.tasks.items[0]).sort(), [
    "assignee",
    "dueDate",
    "id",
    "status",
    "title",
  ]);
  assert.deepEqual(Object.keys(view.guests.items[0]).sort(), [
    "attendanceStatus",
    "id",
    "name",
  ]);
  assert.deepEqual(Object.keys(view.bookings.items[0]).sort(), [
    "businessName",
    "categoryName",
    "eventDate",
    "id",
    "serviceTitle",
    "status",
  ]);
});

test("tasks name who does them by first name only; guests are counted by reply", async () => {
  const view = await dashboardFor(member(SharedMemberRole.VIEWER)).getPlanReadView(
    { id: "member-1" } as any,
    PLAN.id,
  );
  assert.deepEqual(
    view.tasks.items.map((task) => task.assignee),
    [
      { kind: "OWNER", firstName: "محمد" },
      { kind: "MEMBER", firstName: "صالح" },
      { kind: "PERSON", firstName: "الوالد" },
      { kind: "YOU", firstName: null },
    ],
  );
  assert.equal(view.guests.confirmed, 1);
  assert.equal(view.guests.pending, 1);
  assert.equal(view.guests.declined, 1);
  assert.equal(view.bookings.items[0].categoryName, "قاعات");
  assert.equal(firstNameOf("  محمد   علي "), "محمد");
  assert.equal(firstNameOf("   "), null);
});

test("role x write: a viewer edits nothing and reads no money; the other roles keep their flags", async () => {
  const user = { id: "member-1" } as any;
  for (const role of ALL_ROLES) {
    const flags = rolePermissionDefaults(role);
    const permissions = permissionsFor(member(role));
    const expect = async (allowed: boolean, run: () => Promise<unknown>, what: string) => {
      if (allowed) {
        await run();
        return;
      }
      await assert.rejects(
        run,
        (error: unknown) =>
          error instanceof NotFoundException || error instanceof ForbiddenException,
        `${role} ${what}`,
      );
    };
    await permissions.assertPlanReadable(PLAN.id, user);
    await expect(flags.canManageTasks, () => permissions.assertTaskManageable(PLAN.id, user), "tasks");
    await expect(flags.canManageGuests, () => permissions.assertGuestManageable(PLAN.id, user), "guests");
    await expect(
      flags.canManageProviders,
      () => permissions.assertProviderManageable(PLAN.id, user),
      "providers",
    );
    await expect(flags.canViewMoney, () => permissions.assertMoneyReadable(PLAN.id, user), "money");
  }

  const viewer = rolePermissionDefaults(SharedMemberRole.VIEWER);
  assert.deepEqual(
    [
      viewer.canViewMoney,
      viewer.canEditPlan,
      viewer.canManageTasks,
      viewer.canManageGuests,
      viewer.canManageProviders,
      viewer.canInviteMembers,
      viewer.canManageMoney,
    ],
    [false, false, false, false, false, false, false],
  );
  await assert.rejects(
    () => permissionsFor(null).assertPlanReadable(PLAN.id, { id: "stranger" } as any),
    NotFoundException,
  );
});

test("the owners read only what the view may show", async () => {
  const seen: Record<string, any> = {};
  const client = {
    weddingTask: { findMany: async (args: any) => ((seen.tasks = args), []) },
    guest: { findMany: async (args: any) => ((seen.guests = args), []) },
    booking: { findMany: async (args: any) => ((seen.bookings = args), []) },
  } as any;

  await new TasksPortService().listReadableTasks(client, PLAN.id, "reader-1");
  assert.deepEqual(seen.tasks.where.status, { not: WeddingTaskStatus.CANCELLED });
  assert.deepEqual(seen.tasks.where.OR, [
    { privateToUserId: null },
    { privateToUserId: "reader-1" },
  ]);
  assert.deepEqual(Object.keys(seen.tasks.select).sort(), [
    "assigneeUserId",
    "dueDate",
    "id",
    "responsibleName",
    "status",
    "title",
  ]);

  await new GuestsPortService().listReadableGuests(client, PLAN.id);
  assert.deepEqual(Object.keys(seen.guests.select).sort(), [
    "attendanceStatus",
    "id",
    "name",
  ]);

  await new QuoteReadService().listReadableBookings(client, PLAN.id);
  assert.deepEqual(seen.bookings.where.status, {
    in: [BookingStatus.REQUESTED, BookingStatus.CONFIRMED],
  });
  assert.deepEqual(seen.bookings.where.quoteRequest, { weddingPlanId: PLAN.id });
  assert.equal(JSON.stringify(seen.bookings.select).includes("note"), false);
  assert.equal(JSON.stringify(seen.bookings.select).includes("Phone"), false);
  assert.equal(JSON.stringify(seen.bookings.select).includes("budget"), false);
});
