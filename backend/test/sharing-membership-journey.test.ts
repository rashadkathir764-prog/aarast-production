import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpException } from "@nestjs/common";
import {
  NotificationType,
  SharedMemberRole,
  UserRole,
  WeddingPersona,
  WeddingTaskStatus,
} from "@prisma/client";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { rolePermissionDefaults } from "../src/modules/collaboration/internal/plan-permissions";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";
import { TasksPortService } from "../src/modules/tasks/infrastructure/tasks-port.service";
import { textFor } from "../src/shared-kernel/voice/address-form";
import { sharingService } from "./support/owner-ports";

// The participation journey after the invite: the owner re-scopes or removes
// a member, or the member leaves. Each change is told to the member it is
// about (J2-07), never leaves a task waiting on someone who can no longer act
// on it (J2-08), and «يشوف بس» never holds an editing right (J2-05, D52).

const plan = {
  id: "plan-1",
  ownerUserId: "owner-1",
  title: "عرس سلمى",
  persona: WeddingPersona.BRIDE,
  status: "PLANNING",
  city: null,
  weddingDate: null,
  currency: "YER",
  createdAt: new Date("2026-07-01T00:00:00.000Z"),
  updatedAt: new Date("2026-07-01T00:00:00.000Z"),
};

function account(id: string, name: string, persona: WeddingPersona | null) {
  const now = new Date("2026-07-01T00:00:00.000Z");
  return {
    id,
    name,
    appName: null,
    role: UserRole.USER,
    phone: `+96777700${id.length}${id.charCodeAt(0)}`,
    email: null,
    adminRole: null,
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: now,
    lastLoginAt: now,
    avatarUrl: null,
    appAvatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: plan.id,
    onboardingPath: null,
    persona,
    onboardingCompletedAt: now,
    reviewFirstNameOnly: false,
    createdAt: now,
    updatedAt: now,
  } as any;
}

type Task = {
  id: string;
  weddingPlanId: string;
  assigneeUserId: string | null;
  status: WeddingTaskStatus;
};

function journey(memberRole: SharedMemberRole = SharedMemberRole.HELPER) {
  const owner = account("owner-1", "سلمى أحمد", WeddingPersona.BRIDE);
  const helper = account("helper-1", "صالح علي", null);
  const users = new Map([owner, helper].map((user) => [user.id, user]));
  const members = new Map<string, Record<string, any>>();
  members.set("member-1", {
    id: "member-1",
    weddingPlanId: plan.id,
    userId: helper.id,
    role: memberRole,
    ...rolePermissionDefaults(memberRole),
    authorityVersion: 1,
    createdAt: new Date("2026-07-02T00:00:00.000Z"),
    updatedAt: new Date("2026-07-02T00:00:00.000Z"),
  });
  const tasks: Task[] = [
    { id: "open-todo", weddingPlanId: plan.id, assigneeUserId: helper.id, status: WeddingTaskStatus.TODO },
    { id: "open-doing", weddingPlanId: plan.id, assigneeUserId: helper.id, status: WeddingTaskStatus.IN_PROGRESS },
    { id: "done", weddingPlanId: plan.id, assigneeUserId: helper.id, status: WeddingTaskStatus.DONE },
    { id: "cancelled", weddingPlanId: plan.id, assigneeUserId: helper.id, status: WeddingTaskStatus.CANCELLED },
    { id: "owners", weddingPlanId: plan.id, assigneeUserId: owner.id, status: WeddingTaskStatus.TODO },
    { id: "other-plan", weddingPlanId: "plan-2", assigneeUserId: helper.id, status: WeddingTaskStatus.TODO },
  ];
  const notices: Array<Record<string, any>> = [];

  // A read returns a fresh row, as Prisma does.
  const memberWhere = (where: Record<string, any>) => {
    const found = [...members.values()].find((member) =>
      where.weddingPlanId_userId
        ? member.weddingPlanId === where.weddingPlanId_userId.weddingPlanId &&
          member.userId === where.weddingPlanId_userId.userId
        : (where.id === undefined || member.id === where.id) &&
          (where.weddingPlanId === undefined || member.weddingPlanId === where.weddingPlanId) &&
          (where.userId === undefined || member.userId === where.userId),
    );
    return found ? { ...found } : null;
  };

  const tx: Record<string, any> = {
    __transaction: true,
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings) ? query.strings.join(" ") : String(query);
      const values: unknown[] = query?.values ?? [];
      if (sql.includes('FROM "User"')) {
        return values
          .filter((value): value is string => typeof value === "string" && users.has(value))
          .map((id) => ({ id, status: "ACTIVE", deletionPending: false }));
      }
      if (sql.includes('FROM "SharedMember"')) {
        const byId = [...members.values()].find((member) => values.includes(member.id));
        const byUser = [...members.values()].find(
          (member) => values.includes(member.weddingPlanId) && values.includes(member.userId),
        );
        const found = byId ?? byUser;
        return found ? [{ id: found.id }] : [];
      }
      return [];
    },
    weddingPlan: {
      findUnique: async ({ where }: any) => (where.id === plan.id ? plan : null),
      findMany: async () => [plan],
    },
    user: {
      findUnique: async ({ where }: any) => users.get(where.id) ?? null,
      findMany: async ({ where }: any) =>
        [...users.values()].filter((user) => (where?.id?.in ?? []).includes(user.id)),
      updateMany: async () => ({ count: 1 }),
    },
    sharedMember: {
      findFirst: async ({ where }: any) => memberWhere(where),
      findUnique: async ({ where }: any) => memberWhere(where),
      update: async ({ where, data }: any) => {
        const member = members.get(where.id)!;
        Object.assign(member, data, { updatedAt: new Date() });
        return { ...member };
      },
      delete: async ({ where }: any) => {
        const member = members.get(where.id)!;
        members.delete(where.id);
        return member;
      },
    },
    planInvite: { updateMany: async () => ({ count: 0 }) },
    conversation: { findMany: async () => [] },
    weddingTask: {
      updateMany: async ({ where, data }: any) => {
        const matching = tasks.filter(
          (task) =>
            (where.weddingPlanId === undefined || task.weddingPlanId === where.weddingPlanId) &&
            task.assigneeUserId === where.assigneeUserId &&
            (where.status?.in === undefined || where.status.in.includes(task.status)),
        );
        for (const task of matching) Object.assign(task, data);
        return { count: matching.length };
      },
    },
  };
  const prisma = {
    ...tx,
    $transaction: async (operation: (client: Record<string, any>) => unknown) => operation(tx),
  };
  const permissions = new PermissionService({} as any, new PlanReadService());
  (permissions as any).assertMemberManageableInTransaction = async () => ({
    plan,
    isOwner: true,
    sharedMember: null,
  });
  const notifications = {
    createNotificationInTransaction: async (client: Record<string, any>, input: Record<string, any>) => {
      assert.equal(client.__transaction, true, "the notice is written in the change's transaction");
      notices.push(input);
      return { id: `notice-${notices.length}` };
    },
    purgeMoneyForMember: async () => undefined,
  };
  const history = {
    ensureTenureInTransaction: async () => undefined,
    recordInTransaction: async () => undefined,
    recordForContextInTransaction: async () => undefined,
    closeTenureInTransaction: async () => undefined,
  };
  const service = sharingService(
    prisma as any,
    permissions,
    notifications as any,
    {} as any,
    history as any,
    undefined,
    new TasksPortService(),
  );
  return { service, owner, helper, members, tasks, notices };
}

function taskAssignees(tasks: Task[]) {
  return Object.fromEntries(tasks.map((task) => [task.id, [task.assigneeUserId, task.status]]));
}

function assertViewerCannotEdit(error: unknown): true {
  assert.ok(error instanceof HttpException);
  assert.equal(error.getStatus(), 400);
  const response = error.getResponse() as Record<string, unknown>;
  assert.equal(response.code, "VIEWER_CANNOT_EDIT");
  assert.match(String(response.message), /[؀-ۿ]/u);
  assert.doesNotMatch(String(response.message), /[A-Za-z]/u);
  return true;
}

test("J2-05: making a member «يشوف بس» while asking for a manage right is refused with VIEWER_CANNOT_EDIT", async () => {
  for (const flag of ["canManageTasks", "canManageGuests", "canManageProviders", "canManageMoney", "canEditPlan"]) {
    const { service, owner, members } = journey();
    await assert.rejects(
      () =>
        service.updateMemberForPlan(owner, plan.id, "member-1", {
          role: SharedMemberRole.VIEWER,
          [flag]: true,
        }),
      assertViewerCannotEdit,
      flag,
    );
    assert.equal(members.get("member-1")!.role, SharedMemberRole.HELPER, flag);
  }
});

test("J2-05: a member made «يشوف بس» keeps no editing right, and may keep reading the money", async () => {
  const { service, owner, members } = journey();
  members.get("member-1")!.canViewMoney = true;

  const updated = await service.updateMemberForPlan(owner, plan.id, "member-1", {
    role: SharedMemberRole.VIEWER,
  });

  for (const response of [updated, members.get("member-1")!]) {
    assert.equal(response.role, SharedMemberRole.VIEWER);
    assert.equal(response.canManageTasks, false);
    assert.equal(response.canManageGuests, false);
    assert.equal(response.canManageProviders, false);
    assert.equal(response.canManageMoney, false);
    assert.equal(response.canEditPlan, false);
    assert.equal(response.canViewMoney, true);
  }
});

test("J2-05: a HELPER keeps the rights the owner gives it", async () => {
  const { service, owner, members } = journey();

  const updated = await service.updateMemberForPlan(owner, plan.id, "member-1", {
    canManageMoney: true,
  });

  assert.equal(updated.role, SharedMemberRole.HELPER);
  assert.equal(updated.canManageTasks, true);
  assert.equal(updated.canManageGuests, true);
  assert.equal(updated.canManageProviders, true);
  assert.equal(updated.canManageMoney, true);
  assert.equal(members.get("member-1")!.canManageMoney, true);
});

test("J2-07: a rights change tells the member once, in their form, and opens the plan", async () => {
  const { service, owner, helper, notices } = journey();

  await service.updateMemberForPlan(owner, plan.id, "member-1", {
    canManageGuests: false,
  });

  assert.equal(notices.length, 1);
  const [notice] = notices;
  assert.equal(notice.userId, helper.id);
  assert.equal(notice.type, NotificationType.SHARING_UPDATED);
  assert.equal(notice.weddingPlanId, plan.id);
  assert.equal(notice.routeTarget, `/wedding-plans/${plan.id}/dashboard`);
  assert.equal(notice.data.change, "RIGHTS");
  // The owner is a bride: she «غيّرت»; the reader is spoken to in their form.
  assert.equal(textFor("MASCULINE", notice.title), "سلمى غيّرت اللي تشوفه في عرس سلمى");
  assert.equal(textFor("FEMININE", notice.title), "سلمى غيّرت اللي تشوفيه في عرس سلمى");
  for (const form of ["MASCULINE", "FEMININE"] as const) {
    assert.doesNotMatch(textFor(form, notice.title), /[A-Za-z]/u);
    assert.doesNotMatch(textFor(form, notice.body), /[A-Za-z]/u);
  }
});

test("J2-07: an update that changes no right tells no one", async () => {
  const { service, owner, notices } = journey();

  await service.updateMemberForPlan(owner, plan.id, "member-1", {
    canManageTasks: true,
    receiveNotifications: false,
  });

  assert.equal(notices.length, 0);
});

test("J2-07 + J2-08: removal releases the member's open tasks in that plan and tells them once", async () => {
  const { service, owner, helper, tasks, notices } = journey();

  await service.removeMemberFromPlan(owner, plan.id, "member-1");

  assert.deepEqual(taskAssignees(tasks), {
    "open-todo": [null, WeddingTaskStatus.TODO],
    "open-doing": [null, WeddingTaskStatus.IN_PROGRESS],
    done: [helper.id, WeddingTaskStatus.DONE],
    cancelled: [helper.id, WeddingTaskStatus.CANCELLED],
    owners: [owner.id, WeddingTaskStatus.TODO],
    "other-plan": [helper.id, WeddingTaskStatus.TODO],
  });
  assert.equal(notices.length, 1);
  const [notice] = notices;
  assert.equal(notice.userId, helper.id);
  assert.equal(notice.type, NotificationType.SHARING_UPDATED);
  // The plan is closed to them now, so the notice carries no plan (as D63's).
  assert.equal(notice.weddingPlanId, null);
  assert.equal(notice.routeTarget, `/shared/wedding-plans/${plan.id}`);
  assert.deepEqual(notice.data, {
    weddingPlanId: plan.id,
    sharedMemberId: "member-1",
    change: "REMOVED",
  });
  assert.equal(textFor("MASCULINE", notice.title), "سلمى شالتك من عرس سلمى");
  assert.equal(textFor("FEMININE", notice.title), "سلمى شالتِك من عرس سلمى");
});

test("J2-08: leaving releases your open tasks in that plan and tells no one", async () => {
  const { service, helper, owner, tasks, notices } = journey();

  await service.leaveCurrentMemberFromPlan(helper, plan.id, {
    expectedMemberId: "member-1",
    expectedAuthorityVersion: 1,
  });

  assert.deepEqual(taskAssignees(tasks), {
    "open-todo": [null, WeddingTaskStatus.TODO],
    "open-doing": [null, WeddingTaskStatus.IN_PROGRESS],
    done: [helper.id, WeddingTaskStatus.DONE],
    cancelled: [helper.id, WeddingTaskStatus.CANCELLED],
    owners: [owner.id, WeddingTaskStatus.TODO],
    "other-plan": [helper.id, WeddingTaskStatus.TODO],
  });
  assert.equal(notices.length, 0);
});

test("J2-08: losing task management releases the member's open tasks in that plan", async () => {
  const { service, owner, helper, tasks } = journey();

  await service.updateMemberForPlan(owner, plan.id, "member-1", {
    canManageTasks: false,
  });

  assert.deepEqual(taskAssignees(tasks), {
    "open-todo": [null, WeddingTaskStatus.TODO],
    "open-doing": [null, WeddingTaskStatus.IN_PROGRESS],
    done: [helper.id, WeddingTaskStatus.DONE],
    cancelled: [helper.id, WeddingTaskStatus.CANCELLED],
    owners: [owner.id, WeddingTaskStatus.TODO],
    "other-plan": [helper.id, WeddingTaskStatus.TODO],
  });
});

test("J2-08: a rights change that keeps task management keeps the tasks", async () => {
  const { service, owner, helper, tasks } = journey();

  await service.updateMemberForPlan(owner, plan.id, "member-1", {
    canManageGuests: false,
  });

  assert.equal(tasks.find((task) => task.id === "open-todo")!.assigneeUserId, helper.id);
});
