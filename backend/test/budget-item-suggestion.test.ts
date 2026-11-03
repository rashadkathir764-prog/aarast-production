import assert from "node:assert/strict";
import { test } from "node:test";
import { BudgetCategoriesService } from "../src/budget-categories/budget-categories.service";
import { planEssentials } from "../src/dashboard/plan-essentials";
import {
  budgetItemSuggestionAnswer,
  isBudgetItemSuggestionHidden,
  LATER_DAYS,
} from "../src/modules/finance/domain/budget-item-suggestion-policy";

// The home suggests the plan's own open items. «ما أحتاجها» keeps one off
// this plan; «بعدين» keeps it off for a week; no answer suggests it.

const now = new Date("2026-11-02T09:00:00Z");
const day = 24 * 60 * 60 * 1000;

test("«ما أحتاجها» hides the item until it is taken back", () => {
  const answer = budgetItemSuggestionAnswer("NOT_NEEDED", now);
  assert.deepEqual(answer, { suggestion: "NOT_NEEDED", suggestionUntil: null });
  assert.equal(isBudgetItemSuggestionHidden(answer, now), true);
  assert.equal(
    isBudgetItemSuggestionHidden(answer, new Date(now.getTime() + 365 * day)),
    true,
  );
});

test("«بعدين» hides it for a week, then it is suggested again", () => {
  const answer = budgetItemSuggestionAnswer("LATER", now);
  assert.equal(answer.suggestion, "LATER");
  assert.equal(
    answer.suggestionUntil?.getTime(),
    now.getTime() + LATER_DAYS * day,
  );
  assert.equal(LATER_DAYS, 7);
  assert.equal(
    isBudgetItemSuggestionHidden(answer, new Date(now.getTime() + 6 * day)),
    true,
  );
  assert.equal(
    isBudgetItemSuggestionHidden(answer, new Date(now.getTime() + 8 * day)),
    false,
  );
});

test("no answer, or a cleared one, is suggested", () => {
  const cleared = budgetItemSuggestionAnswer(null, now);
  assert.deepEqual(cleared, { suggestion: null, suggestionUntil: null });
  assert.equal(isBudgetItemSuggestionHidden(cleared, now), false);
});

test("«ايش ناقص» carries the item's answer as hidden", () => {
  const result = planEssentials({
    persona: "GROOM",
    categories: [
      {
        categoryId: "venue",
        name: "قاعة أو مخدرة الرجال",
        kind: "WEDDING",
        costsCount: 0,
        suggestionHidden: true,
      },
      {
        categoryId: "photo",
        name: "التصوير والفيديو",
        kind: "WEDDING",
        costsCount: 0,
      },
    ],
    bookedCategoryIds: [],
    venueSecured: false,
  });
  const byKey = Object.fromEntries(result.map((item) => [item.key, item]));
  assert.equal(byKey.VENUE.status, "MISSING");
  assert.equal(byKey.VENUE.hidden, true);
  assert.equal(byKey.PHOTO.hidden, false);
  // An essential with no item is not an answered suggestion.
  assert.equal(byKey.HONEYMOON.hidden, false);
});

test("the owner's answer is stored on the item, and only the answer", async () => {
  const writes: unknown[] = [];
  const category = {
    id: "venue",
    weddingPlanId: "plan-1",
    name: "قاعة",
    normalizedName: "قاعة",
    kind: "WEDDING",
    allocatedAmount: null,
    suggestion: null,
    suggestionUntil: null,
    createdAt: now,
    updatedAt: now,
  };
  const tx = {
    budgetCategory: {
      findUnique: async () => category,
      update: async ({ data }: { data: Record<string, unknown> }) => {
        writes.push(data);
        return { ...category, ...data, _count: { weddingCosts: 0 } };
      },
    },
    weddingCost: { findMany: async () => [] },
  };
  const prisma = {
    ...tx,
    $transaction: async (operation: (client: unknown) => unknown) =>
      operation(tx),
  };
  const owner = { isOwner: true, sharedMember: null, plan: { id: "plan-1" } };
  const permissions = {
    assertMoneyReadable: async () => owner,
    assertMoneyManageableForUpdateInTransaction: async () => owner,
  };
  const service = new BudgetCategoriesService(
    prisma as never,
    permissions as never,
  );

  const later = await service.setSuggestion(
    { id: "owner-1" } as never,
    "venue",
    { choice: "LATER" },
    now,
  );
  assert.equal(later.suggestion, "LATER");
  assert.deepEqual(writes[writes.length - 1], {
    suggestion: "LATER",
    suggestionUntil: new Date(now.getTime() + 7 * day),
  });

  const back = await service.setSuggestion(
    { id: "owner-1" } as never,
    "venue",
    { choice: null },
    now,
  );
  assert.equal(back.suggestion, null);
  assert.deepEqual(writes[writes.length - 1], { suggestion: null, suggestionUntil: null });
});

test("a partner's answer enters the plan's history, as an edit of the item does", async () => {
  const category = {
    id: "venue",
    weddingPlanId: "plan-1",
    name: "قاعة",
    normalizedName: "قاعة",
    kind: "WEDDING",
    allocatedAmount: null,
    suggestion: null,
    suggestionUntil: null,
    createdAt: now,
    updatedAt: now,
  };
  const tx = {
    budgetCategory: {
      findUnique: async () => category,
      update: async ({ data }: { data: Record<string, unknown> }) => ({
        ...category,
        ...data,
        _count: { weddingCosts: 0 },
      }),
    },
    weddingCost: { findMany: async () => [] },
  };
  const prisma = {
    ...tx,
    $transaction: async (operation: (client: unknown) => unknown) =>
      operation(tx),
  };
  const partner = {
    isOwner: false,
    sharedMember: { role: "BRIDE" },
    plan: { id: "plan-1" },
  };
  const recorded: Array<{ entityId: string; action: string }> = [];
  const service = new BudgetCategoriesService(
    prisma as never,
    {
      assertMoneyReadable: async () => partner,
      assertMoneyManageableForUpdateInTransaction: async () => partner,
    } as never,
    undefined,
    {
      recordForContextInTransaction: async (
        _tx: unknown,
        _context: unknown,
        event: { entityId: string; action: string },
      ) => {
        recorded.push(event);
      },
    } as never,
  );

  await service.setSuggestion(
    { id: "partner-1" } as never,
    "venue",
    { choice: "NOT_NEEDED" },
    now,
  );
  assert.deepEqual(
    recorded.map(({ entityId, action }) => ({ entityId, action })),
    [{ entityId: "venue", action: "UPDATED" }],
  );
});

test("whoever may not manage the money cannot answer", async () => {
  const category = { id: "venue", weddingPlanId: "plan-1" };
  const tx = { budgetCategory: { findUnique: async () => category } };
  const prisma = {
    ...tx,
    $transaction: async (operation: (client: unknown) => unknown) =>
      operation(tx),
  };
  const permissions = {
    assertMoneyReadable: async () => ({ isOwner: true, sharedMember: null }),
    assertMoneyManageableForUpdateInTransaction: async () => {
      const error = new Error("forbidden");
      error.name = "ForbiddenException";
      throw error;
    },
  };
  const service = new BudgetCategoriesService(
    prisma as never,
    permissions as never,
  );
  await assert.rejects(
    service.setSuggestion(
      { id: "viewer-1" } as never,
      "venue",
      { choice: "NOT_NEEDED" },
      now,
    ),
  );
});
