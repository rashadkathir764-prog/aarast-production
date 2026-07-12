import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { ExpenseStatus, Prisma } from "@prisma/client";
import {
  optionalMoneyAmount,
  requiredMoneyAmount,
} from "../src/common/validation/money";
import { ExpensesService } from "../src/expenses/expenses.service";
import { FinancialCommitmentsService } from "../src/financial-commitments/financial-commitments.service";
import {
  combineVisibleMoney,
  financialExposure,
} from "../src/money/money-summary.math";
import { WeddingPlansService } from "../src/wedding-plans/wedding-plans.service";

test("money validation accepts sane amounts", () => {
  assert.equal(requiredMoneyAmount("1500000", "amount"), "1500000");
  assert.equal(requiredMoneyAmount("99.25", "amount"), "99.25");
  assert.equal(requiredMoneyAmount(250, "amount"), "250");
  assert.equal(optionalMoneyAmount(undefined, "amount"), null);
});

test("money validation rejects overflow, extra decimals and garbage", () => {
  // 13+ integer digits used to overflow numeric(14,2) into a raw 500.
  assert.throws(
    () => requiredMoneyAmount("9999999999999", "amount"),
    BadRequestException,
  );
  // >2 decimals used to be silently rounded by Postgres.
  assert.throws(
    () => requiredMoneyAmount("10.999", "amount"),
    BadRequestException,
  );
  assert.throws(() => requiredMoneyAmount("-5", "amount"), BadRequestException);
  assert.throws(
    () => requiredMoneyAmount("abc", "amount"),
    BadRequestException,
  );
  assert.throws(() => requiredMoneyAmount("", "amount"), BadRequestException);
});

test("expenses are actual paid money-out records with required category", async () => {
  const created: any[] = [];
  const prisma = {
    budgetCategory: {
      findFirst: async ({ where }: any) =>
        where.id === "cat-1" && where.weddingPlanId === "plan-1"
          ? { id: "cat-1" }
          : null,
    },
    expense: {
      create: async ({ data }: any) => {
        created.push(data);
        return {
          id: "expense-1",
          ...data,
          amount: new Prisma.Decimal(data.amount),
          expenseDate: data.expenseDate ?? null,
          note: data.note ?? null,
          createdAt: new Date("2026-07-07T00:00:00.000Z"),
          updatedAt: new Date("2026-07-07T00:00:00.000Z"),
        };
      },
    },
  };
  const permissions = {
    assertFinancialManageable: async () => undefined,
  };
  const service = new ExpensesService(prisma as any, permissions as any);
  const user = { id: "user-1" } as any;

  await assert.rejects(
    () =>
      service.create(user, "plan-1", {
        title: "Missing category",
        amount: "100",
      } as any),
    BadRequestException,
  );
  await assert.rejects(
    () =>
      service.create(user, "plan-1", {
        title: "Planned expense",
        amount: "100",
        budgetCategoryId: "cat-1",
        status: ExpenseStatus.PLANNED,
      }),
    BadRequestException,
  );
  await assert.rejects(
    () =>
      service.create(user, "plan-1", {
        title: "Zero expense",
        amount: "0",
        budgetCategoryId: "cat-1",
      }),
    BadRequestException,
  );

  const response = await service.create(user, "plan-1", {
    title: "Paid expense",
    amount: "100.00",
    budgetCategoryId: "cat-1",
  });

  assert.equal(response.status, ExpenseStatus.PAID);
  assert.equal(response.budgetCategoryId, "cat-1");
  assert.equal(created[0].status, ExpenseStatus.PAID);
});

function createLocalPlanImportHarness() {
  const now = new Date("2026-07-10T00:00:00.000Z");
  const categories: any[] = [];
  const expenses: any[] = [];
  let transactions = 0;
  const plan = {
    id: "plan-1",
    ownerUserId: "user-1",
    title: "Local plan",
    city: null,
    location: null,
    weddingDate: null,
    priorities: [],
    estimatedBudget: null,
    currency: "YER",
    onboardingPath: "USER",
    persona: null,
    onboardingCompletedAt: now,
    importMigrationId: "migration-1",
    status: "PLANNING",
    createdAt: now,
    updatedAt: now,
  };
  const user = {
    id: "user-1",
    name: "User",
    phone: "+967777123456",
    email: null,
    role: "USER",
    adminRole: null,
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: now,
    lastLoginAt: now,
    avatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: "plan-1",
    onboardingPath: "USER",
    persona: null,
    onboardingCompletedAt: now,
    createdAt: now,
    updatedAt: now,
  };

  const prisma: any = {
    weddingPlan: {
      findFirst: async () => null,
      create: async () => plan,
    },
    budgetCategory: {
      createMany: async ({ data }: any) => {
        for (const [index, category] of data.entries()) {
          categories.push({
            id: `category-${index + 1}`,
            targetAmount: null,
            createdAt: now,
            updatedAt: now,
            ...category,
          });
        }
        return { count: data.length };
      },
      findMany: async () => categories,
    },
    expense: {
      createMany: async ({ data }: any) => {
        expenses.push(...data);
        return { count: data.length };
      },
      count: async () => expenses.length,
    },
    weddingTask: {
      createMany: async () => ({ count: 0 }),
      count: async () => 0,
    },
    guest: {
      createMany: async () => ({ count: 0 }),
      count: async () => 0,
    },
    user: {
      update: async () => user,
      findUniqueOrThrow: async () => user,
    },
    $transaction: async (action: any) => {
      transactions += 1;
      return action(prisma);
    },
  };

  return {
    service: new WeddingPlansService(prisma, {} as any),
    categories,
    expenses,
    get transactions() {
      return transactions;
    },
  };
}

test("local-plan import rejects zero and non-paid expenses before writing", async () => {
  for (const expense of [
    { title: "Zero", amount: "0" },
    { title: "Planned", amount: "100", status: ExpenseStatus.PLANNED },
  ]) {
    const harness = createLocalPlanImportHarness();
    await assert.rejects(
      () =>
        harness.service.importLocalPlan(
          { id: "user-1" } as any,
          {
            clientMigrationId: "migration-1",
            title: "Local plan",
            expenses: [expense],
          } as any,
        ),
      BadRequestException,
    );
    assert.equal(
      harness.transactions,
      0,
      "invalid imported expenses must fail before the transaction",
    );
  }
});

test("local-plan import keeps categoryName optional but never writes an uncategorized expense", async () => {
  const harness = createLocalPlanImportHarness();
  await harness.service.importLocalPlan(
    { id: "user-1" } as any,
    {
      clientMigrationId: "migration-1",
      title: "Local plan",
      selectedCategories: ["التصوير"],
      expenses: [
        {
          title: "Camera",
          amount: "100.00",
          categoryName: "التصوير",
          status: ExpenseStatus.PAID,
        },
        { title: "Legacy uncategorized", amount: "50" },
      ],
    } as any,
  );

  const categoryById = new Map(
    harness.categories.map((category) => [category.id, category.name]),
  );
  assert.equal(harness.expenses.length, 2);
  assert.ok(
    harness.expenses.every(
      (expense) =>
        expense.status === ExpenseStatus.PAID &&
        typeof expense.budgetCategoryId === "string" &&
        expense.budgetCategoryId.length > 0,
    ),
  );
  assert.equal(
    categoryById.get(harness.expenses[0].budgetCategoryId),
    "التصوير",
  );
  assert.equal(
    categoryById.get(harness.expenses[1].budgetCategoryId),
    "مصروفات أخرى",
  );
});

test("local-plan import does not add a fallback category when every expense maps explicitly", async () => {
  const harness = createLocalPlanImportHarness();
  await harness.service.importLocalPlan(
    { id: "user-1" } as any,
    {
      clientMigrationId: "migration-1",
      selectedCategories: ["التصوير"],
      expenses: [
        {
          title: "Camera",
          amount: "100",
          categoryName: "التصوير",
        },
      ],
    } as any,
  );

  assert.deepEqual(
    harness.categories.map((category) => category.name),
    ["التصوير"],
  );
  assert.equal(
    harness.expenses[0].budgetCategoryId,
    harness.categories[0].id,
  );
});

test("financial commitments require a real positive cost and valid paid amount", async () => {
  const prisma = {
    budgetCategory: {
      findFirst: async ({ where }: any) =>
        where.id === "cat-1" && where.weddingPlanId === "plan-1"
          ? { id: "cat-1" }
          : null,
    },
  };
  const permissions = {
    assertFinancialManageable: async () => undefined,
  };
  const service = new FinancialCommitmentsService(
    prisma as any,
    permissions as any,
  );
  const user = { id: "user-1" } as any;

  await assert.rejects(
    () =>
      service.create(user, "plan-1", {
        budgetCategoryId: "cat-1",
        title: "Zero commitment",
        totalAmount: "0",
      }),
    BadRequestException,
  );
  await assert.rejects(
    () =>
      service.create(user, "plan-1", {
        budgetCategoryId: "cat-1",
        title: "Overpaid commitment",
        totalAmount: "100",
        paidAmount: "150",
      }),
    BadRequestException,
  );
});

test("wedding plan financial children cannot cascade-delete private data", () => {
  const schema = readFileSync(
    join(process.cwd(), "prisma/schema.prisma"),
    "utf8",
  );
  for (const model of [
    "BudgetCategory",
    "Expense",
    "FinancialCommitment",
    "FinancialPaymentRecord",
    "FinancialInstallment",
    "WeddingTask",
    "SharedMember",
    "PlanInvite",
    "Guest",
    "GuestGroup",
    "PlanProviderLink",
  ]) {
    const block = schema.match(
      new RegExp(`model ${model} \\{[\\s\\S]*?\\n\\}`),
    )?.[0];
    assert.ok(block, `missing ${model} model`);
    assert.match(
      block,
      /weddingPlan\s+WeddingPlan\??\s+@relation\([^\n]*onDelete: Restrict\)/,
    );
  }
  const notification = schema.match(/model Notification \{[\s\S]*?\n\}/)?.[0];
  assert.ok(notification);
  assert.match(
    notification,
    /weddingPlan\s+WeddingPlan\?\s+@relation\([^\n]*onDelete: SetNull\)/,
  );
});

test("database CHECK constraints guard every financial amount column", () => {
  const migration = readFileSync(
    join(
      process.cwd(),
      "prisma/migrations/20260707120000_add_financial_check_constraints/migration.sql",
    ),
    "utf8",
  );
  for (const constraint of [
    "Expense_amount_non_negative",
    "FinancialCommitment_amounts_non_negative",
    "FinancialCommitment_paid_within_total",
    "FinancialInstallment_amount_non_negative",
    "FinancialPaymentRecord_amount_positive",
  ]) {
    assert.match(migration, new RegExp(`ADD CONSTRAINT "${constraint}"`));
  }
});

test("money summary reports manage permission through PermissionService", () => {
  const service = readFileSync(
    join(process.cwd(), "src/money/money-summary.service.ts"),
    "utf8",
  );
  assert.match(
    service,
    /const canManageFinancialRecords =\s*this\.permissions\.canManageFinancialRecords\(context\);/,
  );
  assert.doesNotMatch(
    service,
    /context\.sharedMember\?\.canManageFinancialRecords/,
  );
});

test("money summary combines standalone expenses and commitments once", () => {
  assert.equal(
    financialExposure({
      standaloneExpenses: 2_000_000,
      commitments: 3_000_000,
    }),
    5_000_000,
  );
  assert.equal(combineVisibleMoney(2_000_000, null), 2_000_000);
  assert.equal(combineVisibleMoney(null, 3_000_000), 3_000_000);
  assert.equal(combineVisibleMoney(null, null), null);
});
