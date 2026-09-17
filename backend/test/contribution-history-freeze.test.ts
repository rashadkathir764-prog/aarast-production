import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionSection,
  SharedMemberRole,
} from "@prisma/client";
import { PermissionService } from "../src/modules/collaboration/internal/permission.service";
import { PlanReadService } from "../src/modules/planning/internal/plan-read.service";
import { sharingService } from "./support/owner-ports";

function memberLockWithoutPendingInvites(query: unknown, memberId: string) {
  const sql = (query as { strings?: readonly string[] }).strings?.join(" ") ?? "";
  return sql.includes('FROM "PlanInvite"') ? [] : [{ id: memberId }];
}

test("task revocation records only an authority boundary and never rebuilds history from live assigned rows", async () => {
  const member = {
    id: "member-a",
    weddingPlanId: "plan-1",
    userId: "contributor-a",
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: true,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    authorityVersion: 4,
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  const contributionAtActionTime = {
    action: ContributionAction.CREATED,
    snapshot: { title: "عنوان المهمة وقت إنشائها" },
  };
  const contributionJson = JSON.stringify(contributionAtActionTime);
  const boundaryWrites: Array<Record<string, unknown>> = [];
  const operationOrder: string[] = [];
  const tx = {
    $queryRaw: async (query: unknown) =>
      memberLockWithoutPendingInvites(query, member.id),
    sharedMember: {
      findFirst: async () => member,
      update: async ({ data }: { data: Record<string, unknown> }) => {
        operationOrder.push("member-update");
        return {
          ...member,
          ...data,
          user: { id: member.userId, phone: null, name: "المساهم" },
        };
      },
    },
    weddingTask: {
      findMany: async () => {
        throw new Error("revocation must not read live or assignment-only tasks");
      },
    },
    contributionEvent: {
      findMany: async () => {
        throw new Error("revocation must not rebuild already frozen actions");
      },
    },
    planInvite: { updateMany: async () => ({ count: 1 }) },
  };
  const permissionService = new PermissionService({} as any, new PlanReadService());
  (permissionService as any).assertMemberManageableInTransaction =
    async () => ({
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: true,
      sharedMember: null,
    });
  const service = sharingService(
    {
      sharedMember: { findFirst: async () => member },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    permissionService,
    { purgeMoneyForMember: async () => undefined } as any,
    {} as any,
    {
      ensureTenureInTransaction: async () => undefined,
      recordInTransaction: async (
        _client: unknown,
        data: Record<string, unknown>,
      ) => {
        operationOrder.push("history-write");
        boundaryWrites.push(structuredClone(data));
        return data;
      },
      closeTenureInTransaction: async () => undefined,
    } as any,
  );

  await service.updateMemberForPlan(
    { id: "owner-1" } as any,
    "plan-1",
    member.id,
    { canManageTasks: false },
  );

  assert.equal(boundaryWrites.length, 1);
  assert.equal(
    operationOrder.indexOf("history-write") <
      operationOrder.indexOf("member-update"),
    true,
    "the authority boundary must be committed before the permission row changes",
  );
  assert.deepEqual(boundaryWrites[0], {
    weddingPlanId: "plan-1",
    actorUserId: "contributor-a",
    section: ContributionSection.TASKS,
    entityType: ContributionEntityType.SECTION,
    action: ContributionAction.SECTION_REVOKED,
    snapshot: { status: "REVOKED" },
    dedupeKey: "revoke:member-a:4:MANAGE_TASKS:section",
    provenance: ContributionProvenance.REVOCATION_SNAPSHOT,
    requiredPermission: "MANAGE_TASKS",
    authorityVersion: 4,
    occurredAt: boundaryWrites[0]?.occurredAt,
  });
  assert.equal(JSON.stringify(contributionAtActionTime), contributionJson);
});

test("changing a role never re-grants an explicitly revoked stored permission", async () => {
  const member = {
    id: "member-revoked",
    weddingPlanId: "plan-1",
    userId: "contributor-a",
    role: SharedMemberRole.VIEWER,
    canViewMoney: false,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: false,
    receiveNotifications: true,
    authorityVersion: 8,
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  let updateData: Record<string, unknown> | undefined;
  const tx = {
    $queryRaw: async (query: unknown) =>
      memberLockWithoutPendingInvites(query, member.id),
    sharedMember: {
      findFirst: async () => member,
      update: async ({ data }: { data: Record<string, unknown> }) => {
        updateData = data;
        return {
          ...member,
          ...data,
          user: { id: member.userId, phone: null, name: "مساهم" },
        };
      },
    },
    planInvite: { updateMany: async () => ({ count: 1 }) },
  };
  const permissionService = new PermissionService({} as any, new PlanReadService());
  (permissionService as any).assertMemberManageableInTransaction =
    async () => ({
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: true,
      sharedMember: null,
    });
  const service = sharingService(
    {
      sharedMember: { findFirst: async () => member },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    permissionService,
    {} as any,
    {} as any,
    {} as any,
  );

  await service.updateMemberForPlan(
    { id: "owner-1" } as any,
    "plan-1",
    member.id,
    { role: SharedMemberRole.CONTRIBUTOR },
  );

  assert.equal(updateData?.canManageTasks, false);
  assert.equal(updateData?.canManageGuests, false);
  assert.equal(updateData?.canManageProviders, false);
  assert.equal(updateData?.canViewMoney, false);
});

test("revoking money management keeps live money access and does not freeze the section", async () => {
  const member = {
    id: "member-money-editor",
    weddingPlanId: "plan-1",
    userId: "contributor-a",
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: true,
    canEditPlan: false,
    canManageTasks: false,
    canManageGuests: false,
    canManageProviders: false,
    canInviteMembers: false,
    canManageMoney: true,
    receiveNotifications: true,
    authorityVersion: 3,
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  let historyCalls = 0;
  const tx = {
    $queryRaw: async (query: unknown) =>
      memberLockWithoutPendingInvites(query, member.id),
    sharedMember: {
      findFirst: async () => member,
      update: async ({ data }: { data: Record<string, unknown> }) => ({
        ...member,
        ...data,
        user: { id: member.userId, phone: null, name: "مساهم" },
      }),
    },
    planInvite: { updateMany: async () => ({ count: 1 }) },
  };
  const permissionService = new PermissionService({} as any, new PlanReadService());
  (permissionService as any).assertMemberManageableInTransaction =
    async () => ({
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: true,
      sharedMember: null,
    });
  const service = sharingService(
    {
      sharedMember: { findFirst: async () => member },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    permissionService,
    { purgeMoneyForMember: async () => undefined } as any,
    {} as any,
    {
      ensureTenureInTransaction: async () => {
        historyCalls += 1;
      },
      recordInTransaction: async () => {
        historyCalls += 1;
      },
    } as any,
  );

  const updated = await service.updateMemberForPlan(
    { id: "owner-1" } as any,
    "plan-1",
    member.id,
    { canManageMoney: false },
  );

  assert.equal(updated.canViewMoney, true);
  assert.equal(updated.canManageMoney, false);
  assert.equal(historyCalls, 0);
});

test("revoking every permission records section boundaries without recapturing live entities", async () => {
  const member = {
    id: "member-all",
    weddingPlanId: "plan-1",
    userId: "contributor-a",
    role: SharedMemberRole.CONTRIBUTOR,
    canViewMoney: true,
    canEditPlan: true,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: true,
    canInviteMembers: true,
    canManageMoney: true,
    receiveNotifications: true,
    authorityVersion: 9,
    createdAt: new Date("2026-07-01T00:00:00.000Z"),
    updatedAt: new Date("2026-07-01T00:00:00.000Z"),
  };
  const writes: Array<Record<string, any>> = [];
  let updateData: Record<string, unknown> = {};
  const tx: any = {
    $queryRaw: async (query: unknown) =>
      memberLockWithoutPendingInvites(query, member.id),
    contributionEvent: {
      findMany: async () => {
        throw new Error("revocation must not re-read contribution events");
      },
    },
    sharedMember: {
      findFirst: async () => member,
      findMany: async () => [],
      update: async ({ data }: Record<string, any>) => {
        updateData = data;
        return {
          ...member,
          ...data,
          user: { id: member.userId, phone: null, name: "مساهم" },
        };
      },
    },
    weddingTask: {
      findMany: async () => {
        throw new Error("revocation must not read live tasks");
      },
    },
    guest: {
      findMany: async () => {
        throw new Error("revocation must not read live guests");
      },
    },
    weddingCost: {
      findMany: async () => {
        throw new Error("revocation must not read live costs");
      },
    },
    quoteRequest: {
      findMany: async () => {
        throw new Error("revocation must not read live quote requests");
      },
    },
    planProviderLink: {
      findMany: async () => {
        throw new Error("revocation must not read live provider links");
      },
    },
    planInvite: {
      findMany: async () => [],
      updateMany: async () => ({ count: 1 }),
    },
    weddingPlan: {
      findUnique: async () => {
        throw new Error("revocation must not rebuild the plan snapshot");
      },
    },
    conversation: { findMany: async () => [] },
  };
  const permissionService = new PermissionService({} as any, new PlanReadService());
  (permissionService as any).assertMemberManageableInTransaction =
    async () => ({
      plan: { id: "plan-1", ownerUserId: "owner-1" },
      isOwner: true,
      sharedMember: null,
    });
  const service = sharingService(
    {
      sharedMember: { findFirst: async () => member },
      $transaction: async (operation: (client: typeof tx) => unknown) =>
        operation(tx),
    } as any,
    permissionService,
    { purgeMoneyForMember: async () => undefined } as any,
    {} as any,
    {
      ensureTenureInTransaction: async () => undefined,
      recordInTransaction: async (_tx: unknown, data: Record<string, any>) => {
        writes.push(structuredClone(data));
        return data;
      },
    } as any,
  );

  await service.updateMemberForPlan(
    { id: "owner-1" } as any,
    "plan-1",
    member.id,
    {
      canViewMoney: false,
      canEditPlan: false,
      canManageTasks: false,
      canManageGuests: false,
      canManageProviders: false,
      canInviteMembers: false,
      canManageMoney: false,
    },
  );

  assert.equal(writes.length, 6);
  assert.deepEqual(
    new Set(writes.map(({ section }) => section)),
    new Set([
      ContributionSection.TASKS,
      ContributionSection.GUESTS,
      ContributionSection.MONEY,
      ContributionSection.PROVIDERS,
      ContributionSection.MEMBERS,
      ContributionSection.PLAN,
    ]),
  );
  for (const write of writes) {
    assert.equal(write.action, ContributionAction.SECTION_REVOKED);
    assert.equal(write.entityType, ContributionEntityType.SECTION);
    assert.equal(write.entityId, undefined);
    assert.equal(write.provenance, ContributionProvenance.REVOCATION_SNAPSHOT);
    assert.deepEqual(write.snapshot, { status: "REVOKED" });
  }
  const moneySectionEvents = writes.filter(
    ({ section }) => section === ContributionSection.MONEY,
  );
  assert.equal(moneySectionEvents.length, 1);
  assert.equal(
    moneySectionEvents[0]?.requiredPermission,
    "VIEW_MONEY",
  );
  assert.equal(updateData.authorityVersion, 10);
  assert.doesNotMatch(
    JSON.stringify(writes),
    /phone|email|token|message|note|attachment/i,
  );
});
