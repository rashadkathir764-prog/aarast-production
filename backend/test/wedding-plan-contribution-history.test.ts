import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  ContributionScopeStatus,
  SharedMemberRole,
  WeddingPlanStatus,
} from "@prisma/client";
import { WeddingPlansService } from "../src/wedding-plans/wedding-plans.service";
import { collaborationHistory, collaborationPermissions, planningOwnerPorts } from "./support/owner-ports";

const planId = "plan-contribution-history";
const ownerUserId = "owner-user";
const contributorUserId = "contributor-user";
const originalUpdatedAt = new Date("2026-08-02T09:00:00.000Z");
const changedUpdatedAt = new Date("2026-08-02T10:00:00.000Z");

const actor = { id: contributorUserId } as any;
const planningPlan = {
  id: planId,
  ownerUserId,
  title: "Original plan",
  city: "Sanaa",
  location: { countryCode: "YE", city: "Sanaa" },
  weddingDate: new Date("2026-12-10T00:00:00.000Z"),
  priorities: ["private-priority"],
  estimatedBudget: null,
  currency: "YER",
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: null,
  status: WeddingPlanStatus.PLANNING,
  createdAt: originalUpdatedAt,
  updatedAt: originalUpdatedAt,
} as any;
const member = {
  id: "member-contributor",
  weddingPlanId: planId,
  userId: contributorUserId,
  role: SharedMemberRole.CONTRIBUTOR,
  canViewMoney: false,
  canEditPlan: true,
  canManageTasks: false,
  canManageGuests: false,
  canManageProviders: false,
  canInviteMembers: false,
  canManageMoney: false,
  receiveNotifications: true,
  authorityVersion: 4,
  createdAt: originalUpdatedAt,
  updatedAt: originalUpdatedAt,
} as any;
const context = { plan: planningPlan, isOwner: false, sharedMember: member };

test("a contributor plan update records one privacy-safe PLAN event inside the plan transaction", async () => {
  const operations: string[] = [];
  const updatedPlan = {
    ...planningPlan,
    title: "Updated plan",
    city: "Aden",
    location: { countryCode: "YE", city: "Aden", address: "private" },
    weddingDate: new Date("2026-12-20T00:00:00.000Z"),
    priorities: ["do-not-copy"],
    updatedAt: changedUpdatedAt,
  };
  let recorded: Record<string, any> | undefined;
  const tx = {
    weddingPlan: {
      update: async () => {
        operations.push("plan:update");
        return updatedPlan;
      },
    },
  };
  const service = new WeddingPlansService(
    {
      $transaction: async (work: (client: any) => Promise<unknown>) => {
        operations.push("transaction:start");
        const result = await work(tx);
        operations.push("transaction:end");
        return result;
      },
    } as any,
    collaborationPermissions({
      assertPlanManageableForUpdateInTransaction: async () => {
        operations.push("plan:locked");
        return context;
      },
      canViewMoney: () => false,
    }) as any,
    collaborationHistory({
      recordForContextInTransaction: async (
        client: unknown,
        accessContext: unknown,
        input: Record<string, any>,
      ) => {
        assert.equal(client, tx);
        assert.equal(accessContext, context);
        operations.push("history:record");
        recorded = input;
        return {};
      },
    }) as any,
    ...planningOwnerPorts,
  );

  await service.update(actor, planId, {
    title: updatedPlan.title,
    city: updatedPlan.city,
    weddingDate: updatedPlan.weddingDate.toISOString(),
  });

  assert.deepEqual(operations, [
    "transaction:start",
    "plan:locked",
    "plan:update",
    "history:record",
    "transaction:end",
  ]);
  assert.deepEqual(recorded, {
    section: ContributionSection.PLAN,
    entityType: ContributionEntityType.PLAN,
    entityId: planId,
    action: ContributionAction.UPDATED,
    snapshot: {
      planTitle: updatedPlan.title,
      weddingDate: updatedPlan.weddingDate.toISOString(),
      status: WeddingPlanStatus.PLANNING,
    },
    dedupeKey: `plan:${planId}:updated:${changedUpdatedAt.toISOString()}`,
    requiredPermission: ContributionPermission.MANAGE_PLAN,
    occurredAt: changedUpdatedAt,
  });
  assert.equal("city" in (recorded?.snapshot ?? {}), false);
  assert.equal("location" in (recorded?.snapshot ?? {}), false);
  assert.equal("priorities" in (recorded?.snapshot ?? {}), false);
});

test("a contributor archive records the frozen PLAN event and archives its history scope atomically", async () => {
  const operations: string[] = [];
  const archivedAt = new Date("2026-08-02T11:00:00.000Z");
  const archivedPlan = {
    ...planningPlan,
    status: WeddingPlanStatus.ARCHIVED,
    updatedAt: archivedAt,
  };
  let recorded: Record<string, any> | undefined;
  let scopeMutation: Record<string, any> | undefined;
  const tx = {
    weddingPlan: {
      update: async () => {
        operations.push("plan:archive");
        return archivedPlan;
      },
    },
    planInvite: {
      updateMany: async () => {
        operations.push("invites:revoke");
        return { count: 0 };
      },
    },
    contributorHistoryScope: {
      upsert: async (mutation: Record<string, any>) => {
        operations.push("scope:archive");
        scopeMutation = mutation;
        return {};
      },
    },
  };
  const service = new WeddingPlansService(
    {
      $transaction: async (work: (client: any) => Promise<unknown>) => {
        operations.push("transaction:start");
        const result = await work(tx);
        operations.push("transaction:end");
        return result;
      },
    } as any,
    collaborationPermissions({
      assertPlanManageableForUpdateInTransaction: async () => {
        operations.push("plan:locked");
        return context;
      },
      canViewMoney: () => false,
    }) as any,
    collaborationHistory({
      recordForContextInTransaction: async (
        client: unknown,
        accessContext: unknown,
        input: Record<string, any>,
      ) => {
        assert.equal(client, tx);
        assert.equal(accessContext, context);
        operations.push("history:record");
        recorded = input;
        return {};
      },
    }) as any,
    ...planningOwnerPorts,
  );

  await service.archive(actor, planId);

  assert.deepEqual(operations, [
    "transaction:start",
    "plan:locked",
    "plan:archive",
    "invites:revoke",
    "history:record",
    "scope:archive",
    "transaction:end",
  ]);
  assert.deepEqual(recorded, {
    section: ContributionSection.PLAN,
    entityType: ContributionEntityType.PLAN,
    entityId: planId,
    action: ContributionAction.STATUS_CHANGED,
    snapshot: {
      planTitle: planningPlan.title,
      weddingDate: planningPlan.weddingDate.toISOString(),
      status: WeddingPlanStatus.ARCHIVED,
    },
    dedupeKey: `plan:${planId}:status_changed:${archivedAt.toISOString()}`,
    requiredPermission: ContributionPermission.MANAGE_PLAN,
    occurredAt: archivedAt,
  });
  assert.deepEqual(scopeMutation, {
    where: { weddingPlanId: planId },
    create: {
      weddingPlanId: planId,
      status: ContributionScopeStatus.ARCHIVED,
      archivedAt,
      historyCoverageStartsAt: archivedAt,
    },
    update: {
      status: ContributionScopeStatus.ARCHIVED,
      archivedAt,
    },
  });
});
