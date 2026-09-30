import type { ConversationLifecyclePort } from "../src/modules/messaging/public/conversation-lifecycle.port";
import { findConversationProviderId, lockConversationForShare, lockConversationForUpdate } from "../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent: async () => { throw new Error("Unexpected recordConversationEvent"); },
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
  findConversationProviderId,
};
import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionSection,
  Prisma,
  SharedMemberRole,
} from "@prisma/client";
import { BudgetCategoriesService } from "../src/budget-categories/budget-categories.service";
import { marketplaceService } from "./support/owner-ports";
import { contributorActorReference } from "../src/modules/collaboration/internal/contribution-history.service";
import { buildMoneySummaryInTransaction } from "../src/money/money-summary.service";
import { WeddingCostsService } from "../src/wedding-costs/wedding-costs.service";
import { ProviderReadService } from "../src/modules/marketplace/infrastructure/provider-read.service";
import { QuoteReadService } from "../src/modules/marketplace/infrastructure/quote-read.service";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";
import { FinancePortService } from "../src/modules/finance/infrastructure/finance-port.service";

const contributorContext = {
  plan: {
    id: "plan-1",
    ownerUserId: "owner-1",
    estimatedBudget: null,
    currency: "YER",
  },
  isOwner: false,
  sharedMember: {
    id: "member-1",
    weddingPlanId: "plan-1",
    userId: "contributor-1",
    role: SharedMemberRole.CONTRIBUTOR,
    authorityVersion: 3,
    canManageProviders: true,
    canManageTasks: true,
    canManageGuests: true,
    canViewMoney: true,
    canInviteMembers: true,
    createdAt: new Date("2026-08-02T09:00:00.000Z"),
  },
};

test("contributor cost list locks authority and carries the live permission into every final query", async () => {
  const wheres: unknown[] = [];
  const tx = {
    weddingCost: {
      findMany: ({ where }: { where: unknown }) => {
        wheres.push(where);
        return Promise.resolve([]);
      },
      count: ({ where }: { where: unknown }) => {
        wheres.push(where);
        return Promise.resolve(0);
      },
    },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  // The live re-check of stored membership and `canViewMoney` runs through
  // the collaboration port on the same transaction (the owners evaluate it);
  // its result is applied to the final own-table queries.
  const liveChecks: unknown[][] = [];
  const permissions = {
    assertMoneyReadableInTransaction: async (client: unknown) => {
      assert.equal(client, tx);
      return contributorContext;
    },
    liveAuthorizationFilter: async (...args: unknown[]) => {
      liveChecks.push(args);
      return { id: { in: [] } };
    },
  };
  const scope = {
    qualifyingEntityIdsInTransaction: async (client: unknown) => {
      assert.equal(client, tx);
      return ["cost-mine"];
    },
  };
  const service = new WeddingCostsService(
    prisma as any,
    permissions as any,
    new ProviderReadService(),
    new QuoteReadService(),
    scope as any,
    {} as any,
  );

  await service.listCosts(
    { id: "contributor-1" } as any,
    "plan-1",
    {} as any,
  );

  assert.deepEqual(liveChecks, [
    [tx, contributorContext, "contributor-1", ["canViewMoney"]],
  ]);
  assert.equal(wheres.length, 2);
  for (const where of wheres) {
    assert.equal("weddingPlan" in (where as object), false);
    assert.deepEqual((where as any).id, { in: [] });
  }
});

test("contributor cost detail rejects an id outside the actor contribution scope before returning another scoped row", async () => {
  let finalQueryCalled = false;
  const tx = {
    weddingCost: {
      findFirst: async () => {
        finalQueryCalled = true;
        return null;
      },
    },
  };
  const prisma = {
    weddingCost: {
      findUnique: async () => ({ weddingPlanId: "plan-1" }),
    },
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const permissions = {
    assertMoneyReadableInTransaction: async () => contributorContext,
  };
  const scope = {
    qualifyingEntityIdsInTransaction: async () => ["different-cost"],
  };
  const service = new WeddingCostsService(
    prisma as any,
    permissions as any,
    new ProviderReadService(),
    new QuoteReadService(),
    scope as any,
    {} as any,
  );

  await assert.rejects(
    service.getCost({ id: "contributor-1" } as any, "requested-cost"),
    /Wedding cost not found/,
  );
  assert.equal(finalQueryCalled, false);
});

// The final quote read used to join planning's table with the live
// membership predicate; the permission port is asked for the live check
// (provider + money permission) and its result spread into the quote where.
test("plan quote list restricts a contributor to requests they submitted", async () => {
  let capturedWhere: unknown;
  let capturedContributionWhere: unknown;
  const liveChecks: unknown[] = [];
  const prisma = {
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        capturedContributionWhere = where;
        return [{ entityId: "quote-mine" }];
      },
    },
    quoteRequest: {
      findMany: async ({ where }: { where: unknown }) => {
        capturedWhere = where;
        return [];
      },
    },
  };
  const permissions = {
    assertPlanReadable: async () => contributorContext,
    canManageProviders: () => true,
    canViewMoney: () => true,
    liveAuthorizationFilter: async (
      _client: unknown,
      context: unknown,
      userId: string,
      required: readonly string[],
    ) => {
      liveChecks.push({ context, userId, required });
      return {};
    },
  };
  const service = marketplaceService(
    prisma as any,
    permissions as any,
    {} as any,
    lifecycle, new FinancePortService(), {} as any,
  );

  await service.findPlanQuoteRequests(
    { id: "contributor-1" } as any,
    "plan-1",
  );

  assert.deepEqual(liveChecks, [
    {
      context: contributorContext,
      userId: "contributor-1",
      required: ["canManageProviders", "canViewMoney"],
    },
  ]);
  assert.deepEqual(capturedWhere, {
    weddingPlanId: "plan-1",
    id: { in: ["quote-mine"] },
  });
  assert.deepEqual(capturedContributionWhere, {
    historyScope: { weddingPlanId: "plan-1" },
    contributorTenure: {
      actorReference: contributorActorReference("contributor-1"),
    },
    entityType: { in: [ContributionEntityType.QUOTE_REQUEST] },
    action: {
      in: [ContributionAction.CREATED, ContributionAction.LEGACY_CAPTURED],
    },
    entityId: { not: null },
  });
});

test("creating a budget category appends a privacy-safe contribution in the same transaction", async () => {
  const category = {
    id: "category-1",
    weddingPlanId: "plan-1",
    name: "Ø§Ù„Ù‚Ø§Ø¹Ø©",
    normalizedName: "Ø§Ù„Ù‚Ø§Ø¹Ø©",
    allocatedAmount: null,
    createdAt: new Date("2026-08-02T10:00:00.000Z"),
    updatedAt: new Date("2026-08-02T10:00:00.000Z"),
    _count: { weddingCosts: 0 },
  };
  const tx = {
    budgetCategory: {
      aggregate: async () => ({ _sum: { allocatedAmount: null } }),
      create: async () => category,
    },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const permissions = {
    assertMoneyManageableForUpdateInTransaction: async () => contributorContext,
  };
  const recorded: Array<{ tx: unknown; input: any }> = [];
  const history = {
    recordForContextInTransaction: async (
      client: unknown,
      _context: unknown,
      input: any,
    ) => recorded.push({ tx: client, input }),
  };
  const service = new BudgetCategoriesService(
    prisma as any,
    permissions as any,
    {} as any,
    history as any,
  );

  await service.create(
    { id: "contributor-1" } as any,
    "plan-1",
    { name: "Ø§Ù„Ù‚Ø§Ø¹Ø©" } as any,
  );

  assert.equal(recorded.length, 1);
  assert.equal(recorded[0]?.tx, tx);
  assert.equal(recorded[0]?.input.section, ContributionSection.MONEY);
  assert.equal(
    recorded[0]?.input.entityType,
    ContributionEntityType.BUDGET_CATEGORY,
  );
  assert.equal(recorded[0]?.input.action, ContributionAction.CREATED);
  assert.equal(recorded[0]?.input.entityId, "category-1");
  assert.deepEqual(recorded[0]?.input.snapshot, { title: "Ø§Ù„Ù‚Ø§Ø¹Ø©" });
});

test("money summary applies contributor cost and category ids to every aggregate query", async () => {
  const captured: Record<string, unknown> = {};
  const tx = {
    weddingPlan: {
      findUnique: async () => ({
        estimatedBudget: new Prisma.Decimal("1000000"),
        currency: "YER",
      }),
    },
    budgetCategory: {
      findMany: async ({ where }: { where: unknown }) => {
        captured.categories = where;
        return [];
      },
    },
    weddingCost: {
      findMany: async ({ where }: { where: unknown }) => {
        captured.costs = where;
        return [];
      },
    },
    costPayment: {
      findMany: async ({ where }: { where: unknown }) => {
        captured.payments = where;
        return [];
      },
    },
    paymentSchedule: {
      findMany: async ({ where }: { where: unknown }) => {
        captured.schedules = where;
        return [];
      },
    },
  };

  const result = await buildMoneySummaryInTransaction(
    tx as any,
    { canViewMoney: () => true, canManageMoney: () => true } as any,
    new PlanReadService(),
    contributorContext as any,
    { costIds: ["cost-mine"], categoryIds: ["category-mine"] },
  );

  assert.deepEqual((captured.costs as any).id, { in: ["cost-mine"] });
  assert.deepEqual((captured.payments as any).weddingCost.id, {
    in: ["cost-mine"],
  });
  assert.deepEqual((captured.schedules as any).weddingCost.id, {
    in: ["cost-mine"],
  });
  assert.deepEqual((captured.categories as any).id, {
    in: ["category-mine"],
  });
  assert.equal((captured.categories as any).OR, undefined);
  assert.equal(result.budget.total, null);
  assert.equal(result.budget.unallocated, null);
  assert.equal(result.budget.remaining, null);
  assert.equal(
    result.warnings.some((warning) => warning.type === "BUDGET_EXCEEDED"),
    false,
  );
});

test("contributor category list exposes only actor-created categories and counts only actor-scoped costs on one transaction", async () => {
  const ownCategory = {
    id: "category-mine",
    weddingPlanId: "plan-1",
    name: "Mine",
    normalizedName: "mine",
    allocatedAmount: null,
    createdAt: new Date("2026-08-02T10:00:00.000Z"),
    updatedAt: new Date("2026-08-02T10:00:00.000Z"),
    _count: { weddingCosts: 1 },
  };
  const captured: any[] = [];
  const tx: any = {
    budgetCategory: {
      findMany: async (args: any) => {
        captured.push(args);
        return [ownCategory];
      },
    },
  };
  const prisma: any = {
    $transaction: async (operation: (client: any) => Promise<unknown>) =>
      operation(tx),
  };
  const permissions = {
    assertMoneyReadable: async () => contributorContext,
    assertMoneyReadableInTransaction: async (client: unknown) => {
      assert.equal(client, tx);
      return contributorContext;
    },
  };
  const scope = {
    qualifyingEntityIds: async (
      _planId: string,
      _actorId: string,
      entityTypes: ContributionEntityType[],
    ) =>
      entityTypes.includes(ContributionEntityType.BUDGET_CATEGORY)
        ? [ownCategory.id]
        : ["cost-mine"],
    qualifyingEntityIdsInTransaction: async (
      client: unknown,
      _planId: string,
      _actorId: string,
      entityTypes: ContributionEntityType[],
    ) => {
      assert.equal(client, tx);
      return entityTypes.includes(ContributionEntityType.BUDGET_CATEGORY)
        ? [ownCategory.id]
        : ["cost-mine"];
    },
  };
  const service = new BudgetCategoriesService(
    prisma,
    permissions as any,
    scope as any,
    {} as any,
  );

  const result = await service.findForPlan(
    { id: "contributor-1" } as any,
    "plan-1",
  );

  assert.deepEqual(result.map((category) => category.id), [ownCategory.id]);
  assert.deepEqual(captured[0].where, {
    weddingPlanId: "plan-1",
    id: { in: [ownCategory.id] },
  });
  assert.deepEqual(
    captured[0].include._count.select.weddingCosts.where.id,
    { in: ["cost-mine"] },
  );
  assert.equal(result[0]?.costsCount, 1);
});

test("an own cost linked to an owner category never grants category update authority", async () => {
  const ownerCategory = {
    id: "category-owner",
    weddingPlanId: "plan-1",
    name: "Owner only",
    normalizedName: "owner only",
    allocatedAmount: null,
    createdAt: new Date("2026-08-02T10:00:00.000Z"),
    updatedAt: new Date("2026-08-02T10:00:00.000Z"),
  };
  let transactionStarted = false;
  const prisma: any = {
    budgetCategory: {
      findUnique: async () => ownerCategory,
      findFirst: async () => ({ id: ownerCategory.id }),
    },
    $transaction: async () => {
      transactionStarted = true;
      throw new Error("must not reach mutation transaction");
    },
  };
  const service = new BudgetCategoriesService(
    prisma,
    { assertMoneyReadable: async () => contributorContext } as any,
    {
      qualifyingEntityIds: async (
        _planId: string,
        _actorId: string,
        entityTypes: ContributionEntityType[],
      ) =>
        entityTypes.includes(ContributionEntityType.BUDGET_CATEGORY)
          ? []
          : ["cost-mine"],
    } as any,
    {} as any,
  );

  await assert.rejects(
    () =>
      service.update(
        { id: "contributor-1" } as any,
        ownerCategory.id,
        { name: "Changed" },
      ),
    /Budget category not found/,
  );
  assert.equal(transactionStarted, false);
});

test("an existing own cost never authorizes reusing a foreign category for a new money write", async () => {
  const tx = {
    budgetCategory: {
      findFirst: async () => {
        throw new Error("foreign category linkage must not be consulted");
      },
    },
  };
  const scope = {
    qualifyingEntityIdsInTransaction: async (
      _client: unknown,
      _planId: string,
      _userId: string,
      entityTypes: ContributionEntityType[],
    ) =>
      entityTypes.includes(ContributionEntityType.BUDGET_CATEGORY)
        ? ["category-mine"]
        : ["cost-mine"],
  };
  const service = new WeddingCostsService(
    {} as any,
    {} as any,
    new ProviderReadService(),
    new QuoteReadService(),
    scope as any,
    {} as any,
  );

  await assert.rejects(
    (service as any).assertScopedCategoryInTransaction(
      tx,
      contributorContext,
      "category-owner",
    ),
    /Budget category not found/,
  );
});
