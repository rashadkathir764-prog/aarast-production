import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from "@nestjs/common";
import {
  PaymentScheduleStatus,
  Prisma,
  WeddingCostStatus,
} from "@prisma/client";
import { validate } from "class-validator";
import { BudgetCategoriesService } from "../src/budget-categories/budget-categories.service";
import {
  optionalMoneyAmount,
  requiredMoneyAmount,
} from "../src/shared-kernel/money/money";
import { MoneyBudgetService } from "../src/money/money-budget.service";
import { MoneySummaryController } from "../src/money/money-summary.controller";
import { MoneySummaryService } from "../src/money/money-summary.service";
import { ReplaceMoneyBudgetDto } from "../src/money/dto/replace-money-budget.dto";
import {
  findLogicalBudgetCategory,
  findOtherBudgetCategory,
  normalizeBudgetCategoryName,
} from "../src/modules/finance/domain/cost-category-matching";
import { WeddingCostsService } from "../src/wedding-costs/wedding-costs.service";
import { ProviderReadService } from "../src/modules/marketplace/infrastructure/provider-read.service";
import { QuoteReadService } from "../src/modules/marketplace/infrastructure/quote-read.service";
import { PlanReadService } from "../src/modules/planning/infrastructure/plan-read.service";

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
  for (const invalidType of [["1000"], { amount: "1000" }, true, null]) {
    assert.throws(
      () => requiredMoneyAmount(invalidType, "amount"),
      BadRequestException,
    );
  }

  const budget = new MoneyBudgetService({} as any, {} as any, {
    updateBudgetInTransaction: async () => {
      throw new Error("validation-only fixture must not write a plan");
    },
  }, new PlanReadService());
  assert.throws(() => (budget as any).totalBudget([]), BadRequestException);
  assert.throws(
    () =>
      (budget as any).category({
        name: "Hall",
        allocatedAmount: [],
      }),
    BadRequestException,
  );
  assert.throws(
    () =>
      (new WeddingCostsService({} as any, {} as any, new ProviderReadService(), new QuoteReadService()) as any).optionalAmount(
        [],
        "initialPaymentAmount",
      ),
    BadRequestException,
  );
  assert.throws(
    () =>
      (
        new BudgetCategoriesService({} as any, {} as any) as any
      ).optionalAllocation([]),
    BadRequestException,
  );
});

test("money-budget rejects ambiguous categories and impossible allocations before writing", async () => {
  let transactions = 0;
  const prisma = {
    $transaction: async () => {
      transactions += 1;
      throw new Error("must not run");
    },
  };
  const permissions = {
    assertMoneyManageableForUpdateInTransaction: async () => ({
      plan: { currency: "YER" },
    }),
  };
  const service = new MoneyBudgetService(prisma as any, permissions as any, {
    updateBudgetInTransaction: async () => {
      throw new Error("invalid input must not write a plan");
    },
  }, new PlanReadService());
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

test("money budget accepts an empty category list but still protects categories used by costs", async () => {
  const dto = Object.assign(new ReplaceMoneyBudgetDto(), {
    totalBudget: "1000",
    currency: "YER",
    categories: [],
  });
  assert.deepEqual(await validate(dto), []);

  const now = new Date("2026-07-15T00:00:00.000Z");
  const unusedCategory = {
    id: "cat-unused",
    weddingPlanId: "plan-1",
    name: "Unused",
    normalizedName: "unused",
    allocatedAmount: null,
    createdAt: now,
    updatedAt: now,
    _count: { weddingCosts: 0 },
  };
  const deletedIds: string[][] = [];
  let categoryReads = 0;
  const transactionEvents: string[] = [];
  const tx = {
    $queryRaw: async () => [{ id: "plan-1" }],
    weddingPlan: {
      findUnique: async () => {
        transactionEvents.push("summary-plan");
        return {
          id: "plan-1",
          estimatedBudget: new Prisma.Decimal("1000"),
          currency: "YER",
        };
      },
      findUniqueOrThrow: async () => ({ id: "plan-1", currency: "YER" }),
      update: async () => {
        throw new Error("Finance must not write WeddingPlan directly");
      },
    },
    weddingCost: { count: async () => 0, findMany: async () => [] },
    fundingSource: { findMany: async () => [] },
    costPayment: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
    budgetCategory: {
      findMany: async () => {
        categoryReads += 1;
        return categoryReads === 1 ? [unusedCategory] : [];
      },
      deleteMany: async ({ where }: any) => {
        deletedIds.push(where.id.in);
        return { count: where.id.in.length };
      },
      update: async () => {
        throw new Error("empty replacement must not update categories");
      },
      create: async () => {
        throw new Error("empty replacement must not create categories");
      },
    },
  };
  const prisma = {
    $transaction: async (operation: (client: any) => unknown) => operation(tx),
  };
  const permissions = {
    assertMoneyManageableForUpdateInTransaction: async () => ({
      plan: { id: "plan-1", currency: "YER" },
      isOwner: true,
      sharedMember: null,
    }),
    canViewMoney: () => true,
    canManageMoney: () => true,
  };
  const planningBudgetWriter = {
    updateBudgetInTransaction: async (receivedTx: unknown, input: any) => {
      assert.equal(receivedTx, tx);
      assert.equal(input.weddingPlanId, "plan-1");
      assert.equal(input.estimatedBudget?.toString() ?? null, "1000");
      assert.equal(input.currency, "YER");
      transactionEvents.push("budget-update");
    },
  };
  const service = new MoneyBudgetService(
    prisma as any,
    permissions as any,
    planningBudgetWriter,
    new PlanReadService(),
  );
  const cleared = await service.replace(
    { id: "owner-1" } as any,
    "plan-1",
    dto,
  );
  assert.deepEqual(cleared.categories, []);
  assert.equal(cleared.summary.budget.total, "1000");
  assert.ok(
    transactionEvents.indexOf("budget-update") <
      transactionEvents.indexOf("summary-plan"),
  );
  assert.deepEqual(deletedIds, [["cat-unused"]]);

  const usedTx = {
    ...tx,
    budgetCategory: {
      ...tx.budgetCategory,
      findMany: async () => [
        { ...unusedCategory, id: "cat-used", _count: { weddingCosts: 1 } },
      ],
      deleteMany: async () => {
        throw new Error("used category deletion must be rejected first");
      },
    },
  };
  const usedService = new MoneyBudgetService(
    {
      $transaction: async (operation: (client: any) => unknown) =>
        operation(usedTx),
    } as any,
    permissions as any,
    planningBudgetWriter,
    new PlanReadService(),
  );
  await assert.rejects(
    () => usedService.replace({ id: "owner-1" } as any, "plan-1", dto),
    ConflictException,
  );
});

test("money budget delegates the Planning write through the same serializable transaction", async () => {
  const transactionEvents: string[] = [];
  const tx = {
    weddingPlan: {
      update: async () => {
        throw new Error("Finance must not write WeddingPlan directly");
      },
      findUnique: async () => ({
        estimatedBudget: new Prisma.Decimal("1000"),
        currency: "YER",
      }),
    },
    weddingCost: { count: async () => 0, findMany: async () => [] },
    fundingSource: { findMany: async () => [] },
    costPayment: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
    budgetCategory: {
      findMany: async () => [],
      deleteMany: async () => ({ count: 0 }),
      update: async () => {
        throw new Error("empty replacement must not update categories");
      },
      create: async () => {
        throw new Error("empty replacement must not create categories");
      },
    },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const permissions = {
    assertMoneyManageableForUpdateInTransaction: async () => ({
      plan: { id: "plan-1", currency: "YER" },
      isOwner: true,
      sharedMember: null,
    }),
    canViewMoney: () => true,
    canManageMoney: () => true,
  };
  const planningBudgetWriter = {
    updateBudgetInTransaction: async (receivedTx: unknown, input: any) => {
      assert.equal(receivedTx, tx);
      assert.equal(input.weddingPlanId, "plan-1");
      assert.equal(input.estimatedBudget.toString(), "1000");
      assert.equal(input.currency, "YER");
      transactionEvents.push("budget-update");
    },
  };
  const service = new (MoneyBudgetService as any)(
    prisma,
    permissions,
    planningBudgetWriter,
    new PlanReadService(),
  ) as MoneyBudgetService;

  const result = await service.replace(
    { id: "owner-1" } as any,
    "plan-1",
    { totalBudget: "1000", currency: "YER", categories: [] },
  );

  assert.deepEqual(transactionEvents, ["budget-update"]);
  assert.equal(result.summary.budget.total, "1000");
});

test("strict finance dates reject impossible and ambiguous calendar input", () => {
  const service = new WeddingCostsService({} as any, {} as any, new ProviderReadService(), new QuoteReadService());
  const requiredDate = (value: string) =>
    (service as any).requiredDate(value, "dueDate") as Date;
  assert.equal(
    requiredDate("2026-02-28").toISOString(),
    "2026-02-28T00:00:00.000Z",
  );
  assert.throws(() => requiredDate("2026-02-30"), BadRequestException);
  assert.throws(() => requiredDate("01/02/2026"), BadRequestException);
});

test("quote service categories match budget categories logically and preserve the canonical fallback", () => {
  const categories = [
    { id: "hall", name: "قاعات الأفراح", normalizedName: "قاعات الأفراح" },
    { id: "photo", name: "التصوير", normalizedName: "التصوير" },
    { id: "qat", name: "القات والمقيل", normalizedName: "القات والمقيل" },
    { id: "other", name: "اخرى", normalizedName: "اخرى" },
  ];
  assert.equal(
    findLogicalBudgetCategory(categories, "الصالات وقاعات المناسبات")?.id,
    "hall",
  );
  assert.equal(
    findLogicalBudgetCategory(categories, "Photography")?.id,
    "photo",
  );
  // A مقوّت's offer files under the qat item, not «أخرى».
  assert.equal(findLogicalBudgetCategory(categories, "مقوّتين")?.id, "qat");
  assert.equal(findLogicalBudgetCategory(categories, "خدمة خاصة"), null);
  assert.equal(findOtherBudgetCategory(categories)?.id, "other");
  assert.equal(normalizeBudgetCategoryName("  أخرى  "), "أخرى");
});

test("an accepted quote offer cannot be linked to a second cost", async () => {
  const service = new WeddingCostsService({} as any, {} as any, new ProviderReadService(), new QuoteReadService());
  const tx = {
    $queryRaw: async () => [{ id: "locked-reference" }],
    quoteOffer: {
      findUnique: async () => ({
        id: "offer-1",
        providerId: "provider-1",
        status: "ACCEPTED",
        currency: "YER",
        amount: new Prisma.Decimal("250000"),
        quoteRequest: { weddingPlanId: "plan-1" },
      }),
    },
    weddingCost: {
      findMany: async () => [{ id: "cost-existing" }],
    },
    provider: {
      findUnique: async () => ({ id: "provider-1", status: "ACTIVE" }),
    },
  };

  await assert.rejects(
    () =>
      (service as any).normalizeCounterparty(tx, {
        weddingPlanId: "plan-1",
        planCurrency: "YER",
        totalAmount: new Prisma.Decimal("250000"),
        providerId: "provider-1",
        quoteOfferId: "offer-1",
      }),
    ConflictException,
  );
});

test("a direct payment ignores reminder totals and cancels pending reminders when it settles the cost", async () => {
  const now = new Date("2026-07-14T12:00:00.000Z");
  const cost = {
    id: "cost-1",
    weddingPlanId: "plan-1",
    budgetCategoryId: "cat-1",
    providerId: null,
    quoteOfferId: null,
    title: "Hall",
    partyName: null,
    partyPhone: null,
    totalAmount: new Prisma.Decimal("500"),
    paidAmount: new Prisma.Decimal("300"),
    agreementDate: null,
    status: WeddingCostStatus.PARTIALLY_PAID,
    note: null,
    createdAt: now,
    updatedAt: now,
    budgetCategory: { name: "Hall" },
    provider: null,
    _count: { payments: 1, paymentSchedules: 2 },
  };
  const payment = {
    id: "payment-1",
    weddingCostId: cost.id,
    amount: new Prisma.Decimal("200"),
    entryType: "PAYMENT",
    paymentScheduleId: null,
    reversalOfId: null,
    reversedBy: null,
    paidAt: now,
    method: null,
    note: null,
    createdAt: now,
    weddingCost: cost,
  };
  const costUpdates: any[] = [];
  const reminderUpdates: any[] = [];
  const tx = {
    $queryRaw: async () => [{ id: cost.id }],
    weddingCost: {
      // V1 checklist 4.10: the cost is the shared plan's.
      findUnique: async () => ({ privateToUserId: null }),
      findUniqueOrThrow: async () => cost,
      update: async (args: any) => {
        costUpdates.push(args);
        return cost;
      },
    },
    costPayment: { create: async () => payment },
    paymentSchedule: {
      aggregate: async () => {
        throw new Error("pending reminder totals must not be queried");
      },
      updateMany: async (args: any) => {
        reminderUpdates.push(args);
        return { count: 2 };
      },
    },
  };
  const prisma = {
    weddingCost: { findUnique: async () => cost },
    $transaction: async (operation: (client: any) => unknown) => operation(tx),
  };
  const permissions = {
    assertMoneyManageableInTransaction: async () => ({
      isOwner: true,
      sharedMember: null,
      plan: { id: "plan-1", currency: "YER" },
    }),
  };

  const result = await new WeddingCostsService(
    prisma as any,
    permissions as any,
    new ProviderReadService(),
    new QuoteReadService(),
  ).createPayment({ id: "owner-1" } as any, cost.id, { amount: "200" });

  assert.equal(result.id, payment.id);
  assert.equal(costUpdates[0]?.data?.paidAmount.toString(), "500");
  assert.equal(costUpdates[0]?.data?.status, WeddingCostStatus.PAID);
  assert.deepEqual(reminderUpdates, [
    {
      where: {
        weddingCostId: cost.id,
        status: PaymentScheduleStatus.PENDING,
      },
      data: { status: PaymentScheduleStatus.CANCELLED, paidAt: null },
    },
  ]);
});

test("each payment reminder is bounded by the current remaining cost without reserving other reminders", async () => {
  const now = new Date("2026-07-14T12:00:00.000Z");
  const cost = {
    id: "cost-1",
    weddingPlanId: "plan-1",
    budgetCategoryId: "cat-1",
    providerId: null,
    quoteOfferId: null,
    title: "Hall",
    partyName: null,
    partyPhone: null,
    totalAmount: new Prisma.Decimal("500"),
    paidAmount: new Prisma.Decimal("300"),
    agreementDate: null,
    status: WeddingCostStatus.PARTIALLY_PAID,
    note: null,
    createdAt: now,
    updatedAt: now,
    budgetCategory: { name: "Hall" },
    provider: null,
    _count: { payments: 1, paymentSchedules: 2 },
  };
  let aggregateCalls = 0;
  let createCalls = 0;
  const tx = {
    $queryRaw: async () => [{ id: cost.id }],
    weddingCost: {
      // V1 checklist 4.10: the cost is the shared plan's.
      findUnique: async () => ({ privateToUserId: null }),
      findUniqueOrThrow: async () => cost,
    },
    paymentSchedule: {
      aggregate: async () => {
        aggregateCalls += 1;
        return { _sum: { amount: new Prisma.Decimal("1000") } };
      },
      create: async ({ data }: any) => {
        createCalls += 1;
        return {
          id: `schedule-${createCalls}`,
          ...data,
          paidAt: null,
          status: PaymentScheduleStatus.PENDING,
          createdAt: now,
          updatedAt: now,
          weddingCost: cost,
        };
      },
    },
  };
  const prisma = {
    weddingCost: { findUnique: async () => cost },
    $transaction: async (operation: (client: any) => unknown) => operation(tx),
  };
  const permissions = {
    assertMoneyManageableInTransaction: async () => ({
      isOwner: true,
      sharedMember: null,
      plan: { id: "plan-1", currency: "YER" },
    }),
  };
  const service = new WeddingCostsService(prisma as any, permissions as any, new ProviderReadService(), new QuoteReadService());

  const created = await service.createSchedule(
    { id: "owner-1" } as any,
    cost.id,
    { amount: "200", dueDate: "2026-08-01" },
  );
  assert.equal(created.amount, "200");
  assert.equal(aggregateCalls, 0);
  assert.equal(createCalls, 1);

  await assert.rejects(
    () =>
      service.createSchedule({ id: "owner-1" } as any, cost.id, {
        amount: "200.01",
        dueDate: "2026-08-02",
      }),
    BadRequestException,
  );
  assert.equal(createCalls, 1);
});

test("money summary uses cost totals and the net append-only ledger exactly once", async () => {
  const transactionCalls: unknown[] = [];
  const snapshot = {
    weddingPlan: {
      findUnique: async () => ({
        estimatedBudget: new Prisma.Decimal("1000"),
        currency: "YER",
      }),
    },
    fundingSource: { findMany: async () => [] },
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
      // V1 checklist 4.10: the private-cost pre-filter finds none.
      findMany: async ({ where }: any) =>
        where?.privateToUserId
          ? []
          : [
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
  const prisma = {
    $transaction: async (
      operation: (tx: typeof snapshot) => unknown,
      options: unknown,
    ) => {
      transactionCalls.push(options);
      return operation(snapshot);
    },
  };
  const permissions = {
    assertMoneyReadableInTransaction: async (tx: unknown) => {
      assert.equal(tx, snapshot);
      return {
      plan: {
        id: "plan-1",
        estimatedBudget: new Prisma.Decimal("9999"),
        currency: "USD",
      },
      isOwner: true,
      sharedMember: null,
      };
    },
    canViewMoney: () => true,
    canManageMoney: () => true,
  };
  const summary = await new MoneySummaryService(
    prisma as any,
    permissions as any,
    new PlanReadService(),
  ).getSummary({ id: "user-1" } as any, "plan-1");

  assert.equal(summary.budget.total, "1000");
  assert.equal(summary.currency, "YER");
  assert.equal(summary.budget.confirmedCost, "600");
  assert.equal(summary.budget.remaining, "400");
  assert.equal(summary.costs.paid, "200");
  assert.equal(summary.costs.outstanding, "400");
  assert.equal(summary.categories[0].paid, "200");
  assert.deepEqual(transactionCalls, [
    { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
  ]);
});

test("payment schedule warnings expose counts without adding overlapping reminder amounts", async () => {
  const snapshot = {
    weddingPlan: {
      findUnique: async () => ({ estimatedBudget: null, currency: "YER" }),
    },
    fundingSource: { findMany: async () => [] },
    budgetCategory: { findMany: async () => [] },
    weddingCost: { findMany: async () => [] },
    costPayment: { findMany: async () => [] },
    paymentSchedule: {
      findMany: async () => [
        {
          id: "overdue",
          weddingCostId: "cost-1",
          amount: new Prisma.Decimal("700"),
          dueDate: new Date("2020-01-01T00:00:00.000Z"),
          status: PaymentScheduleStatus.PENDING,
          weddingCost: { budgetCategoryId: "cat-1" },
        },
        {
          id: "due-soon",
          weddingCostId: "cost-1",
          amount: new Prisma.Decimal("700"),
          dueDate: new Date(Date.now() + 24 * 60 * 60 * 1000),
          status: PaymentScheduleStatus.PENDING,
          weddingCost: { budgetCategoryId: "cat-1" },
        },
      ],
    },
  };
  const prisma = {
    $transaction: async (operation: (tx: typeof snapshot) => unknown) =>
      operation(snapshot),
  };
  const permissions = {
    assertMoneyReadableInTransaction: async (tx: unknown) => {
      assert.equal(tx, snapshot);
      return {
      plan: { id: "plan-1", estimatedBudget: null, currency: "YER" },
      isOwner: true,
      sharedMember: null,
      };
    },
    canViewMoney: () => true,
    canManageMoney: () => true,
  };

  const summary = await new MoneySummaryService(
    prisma as any,
    permissions as any,
    new PlanReadService(),
  ).getSummary({ id: "owner-1" } as any, "plan-1");
  const scheduleWarnings = summary.warnings.filter((warning) =>
    warning.type.startsWith("PAYMENT_SCHEDULE_"),
  );
  assert.deepEqual(
    scheduleWarnings.map((warning) => ({
      type: warning.type,
      count: warning.count,
      amount: warning.amount,
    })),
    [
      { type: "PAYMENT_SCHEDULE_OVERDUE", count: 1, amount: null },
      { type: "PAYMENT_SCHEDULE_DUE_SOON", count: 1, amount: null },
    ],
  );
});

test("money access remains fail-closed when the plan is not visible", async () => {
  let transactions = 0;
  let moneyReads = 0;
  const permissions = {
    assertMoneyReadableInTransaction: async () => {
      throw new NotFoundException("Wedding plan not found");
    },
  };
  const service = new MoneySummaryService(
    {
      $transaction: async (operation: (tx: unknown) => unknown) => {
        transactions += 1;
        return operation({
          weddingPlan: {
            findUnique: async () => {
              moneyReads += 1;
              return null;
            },
          },
        });
      },
    } as any,
    permissions as any,
    new PlanReadService(),
  );
  await assert.rejects(
    () => service.getSummary({ id: "outsider" } as any, "plan-1"),
    NotFoundException,
  );
  assert.equal(transactions, 1);
  assert.equal(moneyReads, 0);
});

test("money summary fails closed if the plan disappears before its snapshot is read", async () => {
  const snapshot = {
    weddingPlan: { findUnique: async () => null },
    fundingSource: { findMany: async () => [] },
    budgetCategory: { findMany: async () => [] },
    weddingCost: { findMany: async () => [] },
    costPayment: { findMany: async () => [] },
    paymentSchedule: { findMany: async () => [] },
  };
  const permissions = {
    assertMoneyReadableInTransaction: async () => ({
      plan: {
        id: "plan-1",
        estimatedBudget: new Prisma.Decimal("1000"),
        currency: "YER",
      },
      isOwner: true,
      sharedMember: null,
    }),
  };
  const service = new MoneySummaryService(
    {
      $transaction: async (operation: (tx: typeof snapshot) => unknown) =>
        operation(snapshot),
    } as any,
    permissions as any,
    new PlanReadService(),
  );

  await assert.rejects(
    () => service.getSummary({ id: "owner-1" } as any, "plan-1"),
    NotFoundException,
  );
});

test("money-budget returns the summary committed by its own transaction without a second read", async () => {
  let secondSummaryReads = 0;
  const committedSummary = { weddingPlanId: "plan-1", budget: { total: "1000" } };
  const controller = new MoneySummaryController(
    {
      getSummary: async () => {
        secondSummaryReads += 1;
        throw new Error("PUT must not perform a post-commit summary read");
      },
    } as any,
    {
      replace: async () => ({
        summary: committedSummary,
        categories: [],
        idMap: {},
      }),
    } as any,
  );

  const response = await controller.replaceMoneyBudget(
    { id: "owner-1" } as any,
    "plan-1",
    {
      totalBudget: "1000",
      currency: "YER",
      categories: [],
    },
  );

  assert.equal(response.summary, committedSummary);
  assert.equal(secondSummaryReads, 0);
});
