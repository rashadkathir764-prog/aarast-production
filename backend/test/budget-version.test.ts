import assert from "node:assert/strict";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { validate } from "class-validator";
import { Prisma } from "@prisma/client";
import { ReplaceMoneyBudgetDto } from "../src/money/dto/replace-money-budget.dto";
import { MoneyBudgetService } from "../src/money/money-budget.service";
import { budgetVersionOf } from "../src/modules/finance/public/budget-version";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";

// D112 (Q-4), the owner's word: a budget saved from what a phone read a
// while ago is refused when the budget changed since. The whole budget is
// saved at once, so the old save brought back names and amounts changed on
// another phone and deleted the items added there. The version is what the
// budget holds (its total, its currency, its items), so it changes exactly
// when the budget does, with no column to keep in step.

const hall = {
  id: "b-hall",
  name: "القاعة",
  allocatedAmount: "500000",
  estimatedAmount: null,
};
const dress = {
  id: "a-dress",
  name: "الفستان",
  allocatedAmount: "200000",
  estimatedAmount: "250000",
};

test("the version is the budget's content: the same budget, the same version", () => {
  const read = budgetVersionOf({
    totalBudget: "1000000",
    currency: "YER",
    categories: [hall, dress],
  });
  assert.match(read, /^[0-9a-f]{24}$/u);
  // The order rows come back in does not matter.
  assert.equal(
    budgetVersionOf({ totalBudget: "1000000", currency: "yer", categories: [dress, hall] }),
    read,
  );
});

test("any change to the budget changes its version", () => {
  const base = { totalBudget: "1000000", currency: "YER", categories: [hall, dress] };
  const read = budgetVersionOf(base);
  const changed = [
    { ...base, totalBudget: "1200000" },
    { ...base, totalBudget: null },
    { ...base, currency: "SAR" },
    { ...base, categories: [hall] },
    { ...base, categories: [hall, { ...dress, name: "فستان العروسة" }] },
    { ...base, categories: [hall, { ...dress, allocatedAmount: "300000" }] },
    { ...base, categories: [hall, { ...dress, estimatedAmount: null }] },
    { ...base, categories: [hall, dress, { id: "c-new", name: "الصالون", allocatedAmount: null, estimatedAmount: null }] },
  ];
  for (const budget of changed) {
    assert.notEqual(budgetVersionOf(budget), read);
  }
});

function harness() {
  const now = new Date("2026-11-13T00:00:00.000Z");
  const stored = [
    {
      ...hall,
      weddingPlanId: "plan-1",
      normalizedName: "القاعة",
      allocatedAmount: new Prisma.Decimal(hall.allocatedAmount),
      estimatedAmount: null,
      createdAt: now,
      updatedAt: now,
      _count: { weddingCosts: 0 },
    },
  ];
  let writes = 0;
  const tx = {
    $queryRaw: async () => [{ id: "plan-1" }],
    weddingCost: { count: async () => 0, findFirst: async () => null, findMany: async () => [] },
    fundingSource: { findFirst: async () => null, findMany: async () => [] },
    budgetCategory: {
      findMany: async () => stored,
      deleteMany: async () => {
        writes += 1;
        return { count: 0 };
      },
      update: async () => {
        writes += 1;
        return stored[0];
      },
      create: async () => {
        writes += 1;
        return stored[0];
      },
    },
  };
  const service = new MoneyBudgetService(
    { $transaction: async (operation: (client: any) => unknown) => operation(tx) } as any,
    {
      assertMoneyManageableForUpdateInTransaction: async () => ({
        plan: {
          id: "plan-1",
          currency: "YER",
          estimatedBudget: new Prisma.Decimal("1000000"),
        },
        isOwner: true,
        sharedMember: null,
      }),
      canViewMoney: () => true,
      canManageMoney: () => true,
    } as any,
    {
      updateBudgetInTransaction: async () => {
        writes += 1;
      },
    },
    new PlanReadService(),
    { listActiveCategories: async () => [], listMoneyCatalogItems: async () => [] } as any,
  );
  const current = budgetVersionOf({
    totalBudget: "1000000",
    currency: "YER",
    categories: [{ ...hall, estimatedAmount: null }],
  });
  return { service, current, writes: () => writes };
}

test("a save made from an older read of the budget is refused, and writes nothing", async () => {
  const { service, writes } = harness();
  const dto = Object.assign(new ReplaceMoneyBudgetDto(), {
    totalBudget: "1000000",
    currency: "YER",
    categories: [],
    expectedBudgetVersion: "0".repeat(24),
  });
  assert.deepEqual(await validate(dto), []);

  await assert.rejects(
    () => service.replace({ id: "owner-1" } as any, "plan-1", dto),
    (error: unknown) => {
      assert.ok(error instanceof ConflictException);
      assert.deepEqual(error.getResponse(), {
        statusCode: 409,
        code: "BUDGET_CHANGED_ELSEWHERE",
        message: "الميزانية تغيّرت من جهاز ثاني. حدّث الشاشة وعدّل من جديد.",
      });
      return true;
    },
  );
  assert.equal(writes(), 0);
});

test("the version a phone read is carried in the save as text only", async () => {
  const dto = Object.assign(new ReplaceMoneyBudgetDto(), {
    totalBudget: "1000",
    currency: "YER",
    categories: [],
    expectedBudgetVersion: 42,
  });
  assert.equal((await validate(dto)).length, 1);
});

test("a save from the budget as it is now passes the version check", async () => {
  const { service, current, writes } = harness();
  const dto = Object.assign(new ReplaceMoneyBudgetDto(), {
    totalBudget: "1000000",
    currency: "YER",
    categories: [{ id: hall.id, name: hall.name, allocatedAmount: "600000" }],
    expectedBudgetVersion: current,
  });
  // The harness has no money summary to build after the write; reaching the
  // write is what this proves.
  await service.replace({ id: "owner-1" } as any, "plan-1", dto).catch(() => null);
  assert.ok(writes() > 0);
});
