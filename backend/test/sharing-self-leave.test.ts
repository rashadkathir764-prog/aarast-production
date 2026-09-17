import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpException, RequestMethod } from "@nestjs/common";
import { METHOD_METADATA, PATH_METADATA } from "@nestjs/common/constants";
import { SharedMemberRole } from "@prisma/client";
import { ApiV1WeddingPlanMembersController } from "../src/modules/collaboration/api/sharing.controller";
import { SharingService } from "../src/modules/collaboration/internal/sharing.service";
import { sharingService } from "./support/owner-ports";

test("the members controller exposes DELETE me and forwards the authenticated membership precondition", async () => {
  const prototype = ApiV1WeddingPlanMembersController.prototype;
  const handler = Object.getOwnPropertyNames(prototype)
    .filter((name) => name !== "constructor")
    .map((name) => ({
      name,
      value: (prototype as unknown as Record<string, unknown>)[
        name
      ] as Function,
    }))
    .find(
      ({ value }) =>
        Reflect.getMetadata(METHOD_METADATA, value) === RequestMethod.DELETE &&
        Reflect.getMetadata(PATH_METADATA, value) === "me",
    );

  assert.ok(handler, "DELETE /members/me must be registered");

  const calls: unknown[][] = [];
  const terminal = { deleted: true };
  const sharingService = new Proxy(
    {},
    {
      get:
        () =>
        async (...args: unknown[]) => {
          calls.push(args);
          return terminal;
        },
    },
  );
  const controller = new ApiV1WeddingPlanMembersController(
    sharingService as SharingService,
  );
  const currentUser = { id: "contributor-a" } as any;
  const expectedMembership = {
    expectedMemberId: "member-a",
    expectedAuthorityVersion: 3,
  };
  const result = await handler.value.call(
    controller,
    currentUser,
    "plan-1",
    expectedMembership,
  );

  assert.deepEqual(result, terminal);
  assert.deepEqual(calls, [[currentUser, "plan-1", expectedMembership]]);
});

test("a contributor leaves one plan transactionally while history remains retained", async () => {
  const member = {
    id: "member-a",
    weddingPlanId: "plan-1",
    userId: "contributor-a",
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    authorityVersion: 3,
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  const calls: string[] = [];
  let revokedInviteWhere: Record<string, unknown> | undefined;
  let lockCall = 0;
  const tx = {
    $queryRaw: async () => {
      lockCall += 1;
      if (lockCall === 1) return [{ id: member.userId }];
      if (lockCall === 2) return [{ id: member.id }];
      if (lockCall === 3) return [{ id: "pending-invite" }];
      return [];
    },
    weddingPlan: {
      findUnique: async () => ({ ownerUserId: "owner-a" }),
    },
    user: {
      findUnique: async () => ({
        phone: "+967777000001",
        activeWeddingPlanId: "plan-1",
      }),
      updateMany: async () => {
        calls.push("active-plan-cleared");
        return { count: 1 };
      },
    },
    sharedMember: {
      findUnique: async () => member,
      findFirst: async () => member,
      delete: async () => {
        calls.push("member-deleted");
        return member;
      },
    },
    planInvite: {
      updateMany: async ({ where }: { where: Record<string, unknown> }) => {
        revokedInviteWhere = where;
        calls.push("invites-revoked");
        return { count: 1 };
      },
    },
    conversation: { findMany: async () => [] },
  };
  const history = {
    ensureTenureInTransaction: async () => calls.push("tenure-ensured"),
    recordInTransaction: async () => calls.push("membership-end-recorded"),
    closeTenureInTransaction: async () => calls.push("tenure-closed"),
  };
  const service = sharingService(
    {
      weddingPlan: { findUnique: async () => ({ ownerUserId: "owner-a" }) },
      sharedMember: { findUnique: async () => member },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    { purgeMoneyForMember: async () => calls.push("money-purged") } as any,
    {} as any,
    history as any,
  );

  const result = await service.leaveCurrentMemberFromPlan(
    { id: member.userId } as any,
    "plan-1",
    {
      expectedMemberId: member.id,
      expectedAuthorityVersion: member.authorityVersion,
    },
  );

  assert.deepEqual(result, {
    weddingPlanId: "plan-1",
    deleted: true,
    alreadyLeft: false,
  });
  assert.ok(calls.indexOf("tenure-closed") < calls.indexOf("member-deleted"));
  assert.ok(calls.includes("invites-revoked"));
  assert.deepEqual((revokedInviteWhere as any)?.OR, [
    { inviterUserId: member.userId },
    { inviteeUserId: member.userId },
    { normalizedPhone: "+967777000001" },
  ]);
  assert.ok(calls.includes("active-plan-cleared"));
  assert.ok(calls.includes("money-purged"));
  assert.equal(
    "contributionEvent" in tx,
    false,
    "leave must not delete immutable contribution history",
  );
});

test("a delayed leave request cannot delete a newly accepted membership", async () => {
  const currentMembership = {
    id: "member-new-tenure",
    weddingPlanId: "plan-1",
    userId: "contributor-a",
    role: SharedMemberRole.CONTRIBUTOR,
    authorityVersion: 1,
  };
  let lockCall = 0;
  const tx = {
    $queryRaw: async () => {
      lockCall += 1;
      return lockCall === 1
        ? [{ id: currentMembership.userId }]
        : [{ id: currentMembership.id }];
    },
    weddingPlan: {
      findUnique: async () => ({ ownerUserId: "owner-a" }),
    },
    sharedMember: {
      findUnique: async () => currentMembership,
    },
    user: {
      findUnique: async () => {
        throw new Error("stale leave reached membership side effects");
      },
    },
  };
  const service = sharingService(
    {
      weddingPlan: { findUnique: async () => ({ ownerUserId: "owner-a" }) },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );
  const leave = service.leaveCurrentMemberFromPlan.bind(service) as unknown as (
    currentUser: { id: string },
    weddingPlanId: string,
    expectedMembership: {
      expectedMemberId: string;
      expectedAuthorityVersion: number;
    },
  ) => Promise<unknown>;

  await assert.rejects(
    leave({ id: currentMembership.userId }, "plan-1", {
      expectedMemberId: "member-old-tenure",
      expectedAuthorityVersion: 7,
    }),
    (error: unknown) => {
      assert.ok(error instanceof HttpException);
      assert.equal(error.getStatus(), 409);
      assert.deepEqual(error.getResponse(), {
        statusCode: 409,
        code: "MEMBERSHIP_CHANGED_SINCE_LEAVE_REQUEST",
        message: "تغيّرت عضويتك في الخطة. حدّث المسارات ثم أعد محاولة المغادرة.",
      });
      return true;
    },
  );
});

test("self-leave is idempotent only for a previously completed MEMBER_LEFT tenure", async () => {
  let lockCall = 0;
  const tx = {
    $queryRaw: async () => {
      lockCall += 1;
      return lockCall === 1 ? [{ id: "contributor-a" }] : [];
    },
    weddingPlan: { findUnique: async () => ({ ownerUserId: "owner-a" }) },
    user: {
      findUnique: async () => ({ phone: null, activeWeddingPlanId: null }),
    },
    sharedMember: { findUnique: async () => null },
    contributorHistoryScope: {
      findUnique: async () => ({ id: "scope-1" }),
    },
    contributorTenure: {
      findFirst: async () => ({ id: "old-tenure", endReason: "MEMBER_LEFT" }),
    },
  };
  const service = sharingService(
    {
      weddingPlan: { findUnique: async () => ({ ownerUserId: "owner-a" }) },
      sharedMember: { findUnique: async () => null },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );

  assert.deepEqual(
    await service.leaveCurrentMemberFromPlan(
      { id: "contributor-a" } as any,
      "plan-1",
      {
        expectedMemberId: "member-from-completed-leave",
        expectedAuthorityVersion: 1,
      },
    ),
    { weddingPlanId: "plan-1", deleted: true, alreadyLeft: true },
  );
});

test("revoking member-management authority atomically revokes invitations created by that contributor", async () => {
  const member = {
    id: "member-inviter",
    weddingPlanId: "plan-1",
    userId: "contributor-inviter",
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
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  let revokedWhere: Record<string, unknown> | undefined;
  const tx: any = {
    $queryRaw: async (query: unknown) =>
      String((query as { strings?: readonly string[] }).strings?.join(" ")).includes(
        'FROM "PlanInvite"',
      )
        ? [{ id: "invite-a" }, { id: "invite-b" }]
        : [{ id: member.id }],
    sharedMember: {
      findFirst: async () => member,
      findMany: async () => [],
      update: async ({ data }: any) => ({
        ...member,
        ...data,
        user: { id: member.userId, phone: null, name: "Contributor" },
      }),
    },
    contributionEvent: { findMany: async () => [] },
    planInvite: {
      findMany: async () => [],
      updateMany: async ({ where }: { where: Record<string, unknown> }) => {
        revokedWhere = where;
        return { count: 2 };
      },
    },
  };
  const permissions = {
    assertMemberManageableInTransaction: async () => ({
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: true,
      sharedMember: null,
    }),
    canViewMoney: () => false,
  };
  const service = sharingService(
    {
      sharedMember: { findFirst: async () => member },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    permissions as any,
    {} as any,
    {} as any,
    {
      ensureTenureInTransaction: async () => undefined,
      recordInTransaction: async () => undefined,
    } as any,
  );

  await service.updateMemberForPlan(
    { id: "owner-1" } as any,
    "plan-1",
    member.id,
    { canInviteMembers: false },
  );

  assert.equal((revokedWhere as any)?.inviterUserId, member.userId);
  assert.equal((revokedWhere as any)?.weddingPlanId, member.weddingPlanId);
  assert.deepEqual((revokedWhere as any)?.id?.in, ["invite-a", "invite-b"]);
  assert.equal((revokedWhere as any)?.acceptedAt, null);
  assert.equal((revokedWhere as any)?.revokedAt, null);
});

test("the plan owner cannot use the contributor self-leave operation", async () => {
  const service = sharingService(
    {
      weddingPlan: { findUnique: async () => ({ ownerUserId: "owner-a" }) },
    } as any,
    {} as any,
    {} as any,
    {} as any,
    {} as any,
  );

  await assert.rejects(
    service.leaveCurrentMemberFromPlan(
      { id: "owner-a" } as any,
      "plan-1",
      {
        expectedMemberId: "owner-membership-does-not-exist",
        expectedAuthorityVersion: 1,
      },
    ),
    (error: unknown) => {
      assert.ok(error instanceof HttpException);
      assert.equal(error.getStatus(), 403);
      assert.equal(
        (error.getResponse() as any).code,
        "PLAN_OWNER_CANNOT_LEAVE",
      );
      return true;
    },
  );
});
