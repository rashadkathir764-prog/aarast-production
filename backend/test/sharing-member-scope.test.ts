import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  PlanInviteDeliveryStatus,
  SharedMemberRole,
  UserRole,
} from "@prisma/client";
import { SharingService } from "../src/sharing/sharing.service";

function member(id: string, userId: string, phone: string) {
  return {
    id,
    weddingPlanId: "plan-1",
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
    authorityVersion: 1,
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
    user: {
      id: userId,
      name: userId,
      appName: null,
      role: UserRole.USER,
      phone,
    },
  };
}

test("a contributor member list contains only self and members created by that contributor", async () => {
  const self = member("member-self", "contributor-a", "+967700000001");
  const created = member("member-created", "contributor-b", "+967700000002");
  const unrelated = member(
    "member-unrelated",
    "contributor-c",
    "+967700000003",
  );
  let capturedWhere: unknown;
  let contributionWhere: unknown;
  const service = new SharingService(
    {
      sharedMember: {
        findMany: async ({ where }: { where: unknown }) => {
          capturedWhere = where;
          // Deliberately return an over-broad mock result. The service must
          // still prevent a phone leak at its backend response boundary.
          return [self, created, unrelated];
        },
      },
      contributionEvent: {
        findMany: async ({ where }: { where: unknown }) => {
          contributionWhere = where;
          return [{ entityId: created.id }];
        },
      },
    } as any,
    {
      assertPlanReadable: async () => ({
        plan: { id: "plan-1", ownerUserId: "owner-a" },
        isOwner: false,
        sharedMember: self,
      }),
      canManageMembers: () => true,
    } as any,
    {} as any,
    {} as any,
    {} as any,
  );

  const result = await service.findMembersForPlan(
    { id: self.userId } as any,
    "plan-1",
  );

  assert.deepEqual(
    result.map(({ id }) => id),
    [self.id, created.id],
  );
  assert.doesNotMatch(JSON.stringify(result), /\+967700000003/);
  assert.deepEqual(capturedWhere, {
    weddingPlanId: "plan-1",
    weddingPlan: {
      is: {
        sharedMembers: {
          some: { id: self.id, userId: self.userId },
        },
      },
    },
    OR: [
      { userId: self.userId },
      {
        id: { in: [created.id] },
        weddingPlan: {
          is: {
            sharedMembers: {
              some: {
                id: self.id,
                userId: self.userId,
                canInviteMembers: true,
              },
            },
          },
        },
      },
    ],
  });
  assert.deepEqual((contributionWhere as any).contributorTenure, {
    actorUserId: self.userId,
  });
});

test("a contributor without member permission receives only their own member row", async () => {
  const self = member("member-self", "contributor-a", "+967700000001");
  self.canInviteMembers = false;
  const unrelated = member(
    "member-unrelated",
    "contributor-c",
    "+967700000003",
  );
  const service = new SharingService(
    {
      sharedMember: { findMany: async () => [self, unrelated] },
      contributionEvent: {
        findMany: async () => {
          throw new Error(
            "history scope must not be expanded after revocation",
          );
        },
      },
    } as any,
    {
      assertPlanReadable: async () => ({
        plan: { id: "plan-1", ownerUserId: "owner-a" },
        isOwner: false,
        sharedMember: self,
      }),
      canManageMembers: () => false,
    } as any,
    {} as any,
    {} as any,
    {} as any,
  );

  const result = await service.findMembersForPlan(
    { id: self.userId } as any,
    "plan-1",
  );
  assert.deepEqual(
    result.map(({ id }) => id),
    [self.id],
  );
  assert.doesNotMatch(JSON.stringify(result), /\+967700000003/);
});

test("a contributor invite list cannot leak invites created by another contributor", async () => {
  const now = new Date("2026-07-01T00:00:00.000Z");
  const invite = (id: string, inviterUserId: string, phone: string) => ({
    id,
    weddingPlanId: "plan-1",
    inviterUserId,
    inviteeUserId: null,
    name: id,
    phone,
    normalizedPhone: phone,
    email: null,
    tokenHash: `${id}-hash`,
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    expiresAt: new Date("2026-09-01T00:00:00.000Z"),
    acceptedAt: null,
    declinedAt: null,
    revokedAt: null,
    deliveryStatus: PlanInviteDeliveryStatus.PENDING,
    deliveryAttemptedAt: now,
    createdAt: now,
    updatedAt: now,
  });
  const own = invite("invite-own", "contributor-a", "+967700000010");
  const unrelated = invite(
    "invite-unrelated",
    "contributor-b",
    "+967700000099",
  );
  let capturedWhere: unknown;
  const service = new SharingService(
    {
      planInvite: {
        findMany: async ({ where }: { where: unknown }) => {
          capturedWhere = where;
          return [own, unrelated];
        },
      },
    } as any,
    {
      assertPlanReadable: async () => ({
        plan: { id: "plan-1", ownerUserId: "owner-a" },
        isOwner: false,
        sharedMember: {
          id: "member-a",
          userId: "contributor-a",
          canInviteMembers: true,
        },
      }),
      canManageMembers: () => true,
    } as any,
    {} as any,
    {} as any,
    {} as any,
  );

  const result = await service.findInvitesForPlan(
    { id: "contributor-a" } as any,
    "plan-1",
  );
  assert.deepEqual(
    result.map(({ id }) => id),
    [own.id],
  );
  assert.doesNotMatch(JSON.stringify(result), /\+967700000099/);
  assert.deepEqual(capturedWhere, {
    weddingPlanId: "plan-1",
    weddingPlan: {
      is: {
        sharedMembers: {
          some: {
            id: "member-a",
            userId: "contributor-a",
            canInviteMembers: true,
          },
        },
      },
    },
    inviterUserId: "contributor-a",
  });
});

test("a delegated contributor cannot mutate a member created by somebody else", async () => {
  const actor = member("member-actor", "contributor-a", "+967700000001");
  const target = member("member-target", "contributor-b", "+967700000002");
  let updateCalled = false;
  const access = {
    plan: { id: "plan-1", ownerUserId: "owner-a" },
    isOwner: false,
    sharedMember: actor,
  };
  const tx = {
    $queryRaw: async () => [{ id: target.id }],
    sharedMember: {
      findFirst: async () => target,
      update: async () => {
        updateCalled = true;
        return target;
      },
    },
    contributionEvent: { findFirst: async () => null },
  };
  const service = new SharingService(
    {
      sharedMember: { findFirst: async () => target },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {
      assertMemberManageableInTransaction: async () => access,
    } as any,
    {} as any,
    {} as any,
    {} as any,
  );

  await assert.rejects(
    service.updateMemberForPlan(
      { id: actor.userId } as any,
      "plan-1",
      target.id,
      { canManageTasks: false },
    ),
    (error: any) => error?.getStatus?.() === 404,
  );
  assert.equal(updateCalled, false);
});
