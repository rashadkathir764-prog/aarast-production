import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { HttpException } from "@nestjs/common";
import {
  PlanInviteDeliveryStatus,
  SharedMemberRole,
  UserStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import { SharingService } from "../src/sharing/sharing.service";

const plan = {
  id: "plan-1",
  ownerUserId: "owner-1",
  title: "خطة الاختبار",
  city: "صنعاء",
  weddingDate: new Date("2026-12-01T00:00:00.000Z"),
  estimatedBudget: null,
  currency: "YER",
  status: WeddingPlanStatus.PLANNING,
  createdAt: new Date("2026-07-01T00:00:00.000Z"),
  updatedAt: new Date("2026-07-01T00:00:00.000Z"),
};

function authenticatedUser(id: string, phone: string) {
  const now = new Date("2026-08-02T00:00:00.000Z");
  return {
    id,
    name: id,
    phone,
    email: null,
    role: "USER",
    adminRole: null,
    appRole: "WEDDING_USER",
    status: UserStatus.ACTIVE,
    phoneVerifiedAt: now,
    lastLoginAt: now,
    avatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: now,
    createdAt: now,
    updatedAt: now,
  } as any;
}

function permissionMember(
  userId: string,
  overrides: Record<string, boolean> = {},
) {
  const now = new Date("2026-08-01T00:00:00.000Z");
  return {
    id: `member-${userId}`,
    weddingPlanId: plan.id,
    userId,
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: true,
    canManageMoney: false,
    receiveNotifications: true,
    authorityVersion: 2,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function sqlText(query: unknown): string {
  const candidate = query as { strings?: readonly string[] };
  return candidate.strings?.join(" ") ?? String(query);
}

function inviteAcceptanceHarness(options: {
  ownerInvite?: boolean;
  inviterMember: ReturnType<typeof permissionMember> | null;
  invitePermissions?: Record<string, boolean>;
  ownerStatus?: UserStatus;
  inviterStatus?: UserStatus;
}) {
  const owner = {
    ...authenticatedUser(plan.ownerUserId, "+967777000001"),
    status: options.ownerStatus ?? UserStatus.ACTIVE,
  };
  const inviter = options.ownerInvite
    ? owner
    : {
        ...authenticatedUser("delegated-inviter", "+967777000002"),
        status: options.inviterStatus ?? UserStatus.ACTIVE,
      };
  const invitee = authenticatedUser("invitee-1", "+967777000003");
  const createdAt = new Date("2026-08-02T00:00:00.000Z");
  const invite = {
    id: "invite-1",
    weddingPlanId: plan.id,
    inviterUserId: inviter.id,
    inviteeUserId: invitee.id,
    name: invitee.name,
    phone: invitee.phone,
    normalizedPhone: invitee.phone,
    email: null,
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    expiresAt: new Date("2026-09-02T00:00:00.000Z"),
    acceptedAt: null as Date | null,
    declinedAt: null,
    revokedAt: null,
    createdAt,
    updatedAt: createdAt,
    tokenHash: createHash("sha256").update("raw-token").digest("hex"),
    deliveryStatus: PlanInviteDeliveryStatus.DELIVERED,
    deliveryAttemptedAt: createdAt,
    weddingPlan: {
      id: plan.id,
      title: plan.title,
      city: plan.city,
      weddingDate: plan.weddingDate,
      status: plan.status,
    },
    inviter: {
      id: inviter.id,
      name: inviter.name,
      phone: inviter.phone,
    },
    invitee: {
      id: invitee.id,
      name: invitee.name,
      phone: invitee.phone,
    },
    ...options.invitePermissions,
  };
  const createdMember = {
    ...permissionMember(invitee.id, {
      canManageTasks: invite.canManageTasks,
    }),
    id: "member-invitee",
    role: invite.role,
    user: { id: invitee.id, name: invitee.name, phone: invitee.phone },
  };
  const writes = {
    inviteClaims: 0,
    memberUpserts: 0,
    history: 0,
    notifications: 0,
  };
  const lockOrder: string[] = [];

  const tx: any = {
    __transaction: true,
    $queryRaw: async (query: unknown) => {
      const sql = sqlText(query);
      if (sql.includes('FROM "User"')) {
        lockOrder.push("users");
        return [
          ...new Map(
            [owner, inviter, invitee].map(({ id, status }: any) => [
              id,
              { id, status },
            ]),
          ).values(),
        ];
      }
      if (sql.includes('FROM "WeddingPlan"')) {
        lockOrder.push("plan");
        return [{ id: plan.id }];
      }
      if (sql.includes('FROM "SharedMember"')) {
        lockOrder.push("inviter-member");
        return options.inviterMember
          ? [{ id: options.inviterMember.id }]
          : [];
      }
      if (sql.includes('FROM "PlanInvite"')) {
        lockOrder.push("invite");
        return [{ id: invite.id }];
      }
      return [];
    },
    weddingPlan: {
      findUnique: async () => plan,
    },
    planInvite: {
      findUnique: async () => invite,
      updateMany: async () => {
        writes.inviteClaims += 1;
        invite.acceptedAt = new Date();
        return { count: 1 };
      },
    },
    sharedMember: {
      findUnique: async ({ where }: any) => {
        const userId = where.weddingPlanId_userId?.userId;
        if (userId === inviter.id) return options.inviterMember;
        if (userId === invitee.id && invite.acceptedAt) return createdMember;
        return null;
      },
      upsert: async () => {
        writes.memberUpserts += 1;
        return createdMember;
      },
    },
  };
  const prisma = {
    planInvite: {
      findUnique: async ({ where }: any) =>
        where.id === invite.id ? invite : null,
    },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const permissions = {
    canViewMoney: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canViewMoney),
    canManagePlan: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canEditPlan),
    canManageTasks: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canManageTasks),
    canManageGuests: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canManageGuests),
    canManageProviders: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canManageProviders),
    canManageMembers: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canInviteMembers),
    canManageMoney: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canManageMoney),
  };
  const history = {
    ensureTenureInTransaction: async () => {
      writes.history += 1;
    },
    recordInTransaction: async () => {
      writes.history += 1;
    },
  };
  const notifications = {
    createNotificationInTransaction: async () => {
      writes.notifications += 1;
    },
  };
  const service = new SharingService(
    prisma as any,
    permissions as any,
    notifications as any,
    {} as any,
    history as any,
  );
  return { service, invitee, writes, lockOrder };
}

const revokedAuthorityScenarios: Array<{
  name: string;
  inviterMember: ReturnType<typeof permissionMember> | null;
  invitePermissions: Record<string, boolean>;
}> = [
  {
    name: "delegated inviter left the plan",
    inviterMember: null,
    invitePermissions: {},
  },
  {
    name: "delegated inviter no longer holds a permission in the invite",
    inviterMember: permissionMember("delegated-inviter", {
      canManageTasks: false,
    }),
    invitePermissions: { canManageTasks: true },
  },
  {
    name: "delegated inviter lost member-invitation authority",
    inviterMember: permissionMember("delegated-inviter", {
      canInviteMembers: false,
    }),
    invitePermissions: {},
  },
];

for (const scenario of revokedAuthorityScenarios) {
  test(`pending acceptance fails atomically when ${scenario.name}`, async () => {
    const harness = inviteAcceptanceHarness(scenario);

    await assert.rejects(
      () => harness.service.acceptInvite(harness.invitee, "invite-1"),
      (error: unknown) => {
        assert.ok(error instanceof HttpException);
        assert.equal(error.getStatus(), 409);
        assert.equal(
          (error.getResponse() as any).code,
          "INVITE_AUTHORITY_REVOKED",
        );
        return true;
      },
    );

    assert.deepEqual(harness.writes, {
      inviteClaims: 0,
      memberUpserts: 0,
      history: 0,
      notifications: 0,
    });
    assert.ok(harness.lockOrder.includes("inviter-member"));
    assert.ok(
      harness.lockOrder.indexOf("inviter-member") <
        harness.lockOrder.indexOf("invite"),
      "the inviter membership lock must precede the invite lock",
    );
  });
}

test("an owner invitation remains acceptable without a SharedMember authority row", async () => {
  const harness = inviteAcceptanceHarness({
    ownerInvite: true,
    inviterMember: null,
  });

  const accepted = await harness.service.acceptInvite(
    harness.invitee,
    "invite-1",
  );

  assert.equal(accepted.invite.status, "ACCEPTED");
  assert.equal(accepted.member.userId, harness.invitee.id);
  assert.equal(harness.writes.inviteClaims, 1);
  assert.equal(harness.writes.memberUpserts, 1);
  assert.equal(harness.writes.notifications, 1);
  assert.equal(harness.lockOrder.includes("inviter-member"), false);
});

for (const scenario of [
  {
    name: "the delegated inviter is disabled",
    options: {
      inviterMember: permissionMember("delegated-inviter"),
      inviterStatus: UserStatus.DISABLED,
    },
  },
  {
    name: "the plan owner is disabled",
    options: {
      ownerInvite: true,
      inviterMember: null,
      ownerStatus: UserStatus.DISABLED,
    },
  },
] as const) {
  test(`pending acceptance fails atomically when ${scenario.name}`, async () => {
    const harness = inviteAcceptanceHarness(scenario.options);

    await assert.rejects(
      () => harness.service.acceptInvite(harness.invitee, "invite-1"),
      (error: unknown) => {
        assert.ok(error instanceof HttpException);
        assert.equal(error.getStatus(), 409);
        assert.equal(
          (error.getResponse() as any).code,
          "INVITE_AUTHORITY_INACTIVE",
        );
        return true;
      },
    );

    assert.deepEqual(harness.writes, {
      inviteClaims: 0,
      memberUpserts: 0,
      history: 0,
      notifications: 0,
    });
    assert.deepEqual(harness.lockOrder, ["users"]);
  });
}

test("narrowing a delegated inviter permission revokes only pending grants above the new stored ceiling", async () => {
  const member = permissionMember("delegated-inviter", {
    canManageTasks: true,
    canManageGuests: true,
  });
  const pendingTaskInvite = {
    ...permissionMember("invitee-task", { canManageTasks: true }),
    id: "invite-task",
    role: SharedMemberRole.CONTRIBUTOR,
  };
  const pendingGuestInvite = {
    ...permissionMember("invitee-guest", { canManageGuests: true }),
    id: "invite-guest",
    role: SharedMemberRole.CONTRIBUTOR,
  };
  const revokedIdBatches: string[][] = [];
  const revokedAtBatches: Date[] = [];
  let currentMember = { ...member };
  let inviteLockCount = 0;
  const tx: any = {
    $queryRaw: async (query: unknown) => {
      const sql = sqlText(query);
      if (sql.includes('FROM "SharedMember"')) return [{ id: member.id }];
      if (sql.includes('FROM "PlanInvite"')) {
        inviteLockCount += 1;
        assert.match(sql, /ORDER BY "id"/);
        assert.match(sql, /FOR UPDATE/);
        return [pendingGuestInvite, pendingTaskInvite];
      }
      return [];
    },
    sharedMember: {
      findFirst: async () => currentMember,
      update: async ({ data }: any) => {
        currentMember = { ...currentMember, ...data };
        return {
          ...currentMember,
          user: { id: member.userId, name: "Inviter", phone: null },
        };
      },
    },
    planInvite: {
      updateMany: async ({ where, data }: any) => {
        const ids = [...(where.id?.in ?? [])];
        revokedIdBatches.push(ids);
        assert.equal(where.acceptedAt, null);
        assert.equal(where.declinedAt, null);
        assert.equal(where.revokedAt, null);
        assert.ok(data.revokedAt instanceof Date);
        revokedAtBatches.push(data.revokedAt);
        return { count: ids.length };
      },
    },
  };
  const access = { plan, isOwner: true, sharedMember: null };
  const service = new SharingService(
    {
      sharedMember: { findFirst: async () => currentMember },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {
      assertMemberManageableInTransaction: async () => access,
      canViewMoney: () => false,
    } as any,
    {} as any,
    {} as any,
    {
      ensureTenureInTransaction: async () => undefined,
      recordInTransaction: async () => undefined,
    } as any,
  );

  await service.updateMemberForPlan(
    authenticatedUser(plan.ownerUserId, "+967777000001"),
    plan.id,
    member.id,
    { canManageTasks: false },
  );
  await service.updateMemberForPlan(
    authenticatedUser(plan.ownerUserId, "+967777000001"),
    plan.id,
    member.id,
    { canManageTasks: false },
  );

  assert.equal(currentMember.canInviteMembers, true);
  assert.equal(inviteLockCount, 1, "repeating the same state is idempotent");
  assert.deepEqual(revokedIdBatches, [[pendingTaskInvite.id]]);
  assert.equal(revokedAtBatches.length, 1);
});

test("direct member creation cannot reopen a tenure that ended with MEMBER_LEFT", async () => {
  const owner = authenticatedUser(plan.ownerUserId, "+967777000001");
  const target = authenticatedUser("former-contributor", "+967777000004");
  let memberCreates = 0;
  let notificationWrites = 0;
  let historyWrites = 0;
  let additionalLifecycleIds: readonly string[] = [];
  const access = { plan, isOwner: true, sharedMember: null };
  const tx: any = {
    user: {
      findUnique: async () => ({ status: UserStatus.ACTIVE }),
    },
    sharedMember: {
      findUnique: async () => null,
      create: async () => {
        memberCreates += 1;
        throw new Error("direct membership must not be created");
      },
    },
    contributorHistoryScope: {
      findUnique: async () => ({ id: "history-scope-1" }),
    },
    contributorTenure: {
      findFirst: async () => ({ id: "left-tenure-1" }),
    },
  };
  const prisma = {
    user: {
      findUnique: async () => target,
    },
    sharedMember: {
      findUnique: async () => null,
    },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const service = new SharingService(
    prisma as any,
    {
      assertMemberManageable: async () => access,
      assertMemberManageableInTransaction: async (
        _tx: unknown,
        _planId: string,
        _actor: unknown,
        ids: readonly string[],
      ) => {
        additionalLifecycleIds = ids;
        return access;
      },
      canViewMoney: () => true,
      canManagePlan: () => true,
      canManageTasks: () => true,
      canManageGuests: () => true,
      canManageProviders: () => true,
      canManageMembers: () => true,
      canManageMoney: () => true,
    } as any,
    {
      createNotificationInTransaction: async () => {
        notificationWrites += 1;
      },
    } as any,
    {} as any,
    {
      ensureTenureInTransaction: async () => {
        historyWrites += 1;
      },
      recordForContextInTransaction: async () => {
        historyWrites += 1;
      },
    } as any,
  );

  await assert.rejects(
    () =>
      service.create(owner, plan.id, {
        userId: target.id,
        role: SharedMemberRole.CONTRIBUTOR,
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpException);
      assert.equal(error.getStatus(), 409);
      assert.equal(
        (error.getResponse() as any).code,
        "MEMBER_REENTRY_REQUIRES_INVITE",
      );
      return true;
    },
  );

  assert.deepEqual(additionalLifecycleIds, [target.id]);
  assert.equal(memberCreates, 0);
  assert.equal(historyWrites, 0);
  assert.equal(notificationWrites, 0);
});
