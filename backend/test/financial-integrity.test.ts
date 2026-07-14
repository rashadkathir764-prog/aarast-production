import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException, NotFoundException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import {
  optionalMoneyAmount,
  requiredMoneyAmount,
} from "../src/common/validation/money";
import { MoneyBudgetService } from "../src/money/money-budget.service";
import { MoneySummaryService } from "../src/money/money-summary.service";
import { WeddingCostsService } from "../src/wedding-costs/wedding-costs.service";

test("money validation accepts bounded amounts and rejects unsafe values", () => {
  assert.equal(requiredMoneyAmount("1500000", "amount"), "1500000");
  assert.equal(requiredMoneyAmount("99.25", "amount"), "99.25");
  assert.equal(optionalMoneyAmount(undefined, "amount"), null);
  for (const invalid of ["9999999999999", "10.999", "-5", "abc", ""]) {
    assert.throws(
      () => requiredMoneyAmount(invalid, "amount"),
      BadRequestException,
      invalid,
    );
  }
});

test("money-budget rejects ambiguous categories and impossible allocations before writing", async () => {
  let transactions = 0;
  const prisma = {
    $transaction: async () => {
      transactions += 1;
      throw new Error("must not run");
    },
  };
  const permissions = { assertMoneyManageable: async () => ({}) };
  const service = new MoneyBudgetService(prisma as any, permissions as any);
  const user = { id: "user-1" } as any;

  await assert.rejects(
    () =>
      service.replace(user, "plan-1", {
        totalBudget: null,
        currency: "YER",
        categories: [
          {
            clientId: "00000000-0000-4000-8000-000000000001",
            name: "القاعة",
            allocatedAmount: "100",
          },
        ],
      }),
    BadRequestException,
  );
  await assert.rejects(
    () =>
      service.replace(user, "plan-1", {
        totalBudget: "1000",
        currency: "YER",
        categories: [{ name: "القاعة" }],
      } as any),
    BadRequestException,
  );
  await assert.rejects(
    () =>
      service.replace(user, "plan-1", {
        totalBudget: "1000",
        currency: "YER",
        categories: [
          { id: "cat-1", name: " القاعة " },
          { id: "cat-2", name: "القاعة" },
        ],
      }),
    BadRequestException,
  );
  assert.equal(transactions, 0);
});

test("strict finance dates reject impossible and ambiguous calendar input", () => {
  const service = new WeddingCostsService({} as any, {} as any);
  const requiredDate = (value: string) =>
    (service as any).requiredDate(value, "dueDate") as Date;
  assert.equal(
    requiredDate("2026-02-28").toISOString(),
    "2026-02-28T00:00:00.000Z",
  );
  assert.throws(() => requiredDate("2026-02-30"), BadRequestException);
  assert.throws(() => requiredDate("01/02/2026"), BadRequestException);
});

test("money summary uses cost totals and the net append-only ledger exactly once", async () => {
  const prisma = {
    budgetCategory: {
      findMany: async () => [
        {
          id: "cat-1",
          name: "القاعة",
          allocatedAmount: new Prisma.Decimal("800"),
        },
      ],
    },
    weddingCost: {
      findMany: async () => [
        {
          id: "cost-1",
          budgetCategoryId: "cat-1",
          totalAmount: new Prisma.Decimal("600"),
          title: "القاعة",
        },
      ],
    },
    costPayment: {
      findMany: async () => [
        {
          weddingCostId: "cost-1",
          amount: new Prisma.Decimal("250"),
          entryType: "PAYMENT",
        },
        {
          weddingCostId: "cost-1",
          amount: new Prisma.Decimal("50"),
          entryType: "REVERSAL",
        },
      ],
    },
    paymentSchedule: { findMany: async () => [] },
  };
  const permissions = {
    assertMoneyReadable: async () => ({
      plan: {
        id: "plan-1",
        estimatedBudget: new Prisma.Decimal("1000"),
        currency: "YER",
      },
      isOwner: true,
      sharedMember: null,
    }),
    canViewMoney: () => true,
    canManageMoney: () => true,
  };
  const summary = await new MoneySummaryService(
    prisma as any,
    permissions as any,
  ).getSummary({ id: "user-1" } as any, "plan-1");

  assert.equal(summary.budget.total, "1000");
  assert.equal(summary.budget.confirmedCost, "600");
  assert.equal(summary.budget.remaining, "400");
  assert.equal(summary.costs.paid, "200");
  assert.equal(summary.costs.outstanding, "400");
  assert.equal(summary.categories[0].paid, "200");
});

test("money access remains fail-closed when the plan is not visible", async () => {
  const permissions = {
    assertMoneyReadable: async () => {
      throw new NotFoundException("Wedding plan not found");
    },
  };
  const service = new MoneySummaryService({} as any, permissions as any);
  await assert.rejects(
    () => service.getSummary({ id: "outsider" } as any, "plan-1"),
    NotFoundException,
  );
});
