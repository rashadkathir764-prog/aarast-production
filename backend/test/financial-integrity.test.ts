import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import {
  DebtStatus,
  ExpenseStatus,
  FinancialCommitmentSourceType,
  Prisma,
} from "@prisma/client";
import { applyDebtPaymentDelta } from "../src/common/money/debt-balance";
import {
  optionalMoneyAmount,
  requiredMoneyAmount,
} from "../src/common/validation/money";
import { DebtsService } from "../src/debts/debts.service";
import { ExpensesService } from "../src/expenses/expenses.service";
import { FinancialCommitmentsService } from "../src/financial-commitments/financial-commitments.service";
import { WeddingPlansService } from "../src/wedding-plans/wedding-plans.service";

const d = (value: string | number) => new Prisma.Decimal(value);

test("payment delta moves debt through OPEN -> PARTIALLY_PAID -> PAID", () => {
  const partial = applyDebtPaymentDelta(d("100000"), d(0), d("40000"));
  assert.equal(partial.status, DebtStatus.PARTIALLY_PAID);
  assert.equal(partial.paidAmount.toString(), "40000");

  const paid = applyDebtPaymentDelta(d("100000"), d("40000"), d("60000"));
  assert.equal(paid.status, DebtStatus.PAID);
  assert.equal(paid.paidAmount.toString(), "100000");
});

test("un-pay and delete compensation never drops the balance below zero", () => {
  const result = applyDebtPaymentDelta(d("100000"), d("30000"), d("-50000"));
  assert.equal(result.paidAmount.toString(), "0");
  assert.equal(result.status, DebtStatus.OPEN);
});

test("overpayment is clamped at the debt total", () => {
  const result = applyDebtPaymentDelta(d("100000"), d("90000"), d("40000"));
  assert.equal(result.paidAmount.toString(), "100000");
  assert.equal(result.status, DebtStatus.PAID);
});

test("decimal amounts keep exact cents — no float drift", () => {
  // 0.1 + 0.2 style drift would break this with Number arithmetic.
  const result = applyDebtPaymentDelta(d("1000.30"), d("1000.10"), d("0.20"));
  assert.equal(result.paidAmount.toString(), "1000.3");
  assert.equal(result.status, DebtStatus.PAID);
});

test("zero-total debt never reports PAID", () => {
  const result = applyDebtPaymentDelta(d(0), d(0), d("500"));
  assert.equal(result.paidAmount.toString(), "0");
  assert.equal(result.status, DebtStatus.OPEN);
});

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
    "Debt",
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

test("legacy debts and installments are linked into the financial backbone", () => {
  const schema = readFileSync(
    join(process.cwd(), "prisma/schema.prisma"),
    "utf8",
  );
  assert.match(schema, /legacyDebtId\s+String\?\s+@unique/);
  assert.match(schema, /legacyInstallmentId\s+String\?\s+@unique/);
  const migration = readFileSync(
    join(
      process.cwd(),
      "prisma/migrations/20260710090000_bridge_legacy_debts_to_financial_backbone/migration.sql",
    ),
    "utf8",
  );
  assert.match(migration, /legacy-debt-category-/);
  assert.match(migration, /ON CONFLICT \("legacyDebtId"\) DO NOTHING/);
  assert.match(migration, /ON CONFLICT \("legacyInstallmentId"\) DO NOTHING/);
});

test("debt creation clamps paid to total and mirrors into the financial backbone", async () => {
  const created: any[] = [];
  const mirroredCommitments: any[] = [];
  const mirroredPayments: any[] = [];
  const tx = {
    budgetCategory: {
      upsert: async ({ create }: any) => create,
    },
    installment: {
      aggregate: async () => ({ _sum: { amount: new Prisma.Decimal(0) } }),
    },
    financialCommitment: {
      upsert: async ({ create, update, where }: any) => {
        const data = {
          id: `commitment-${mirroredCommitments.length + 1}`,
          ...create,
        };
        mirroredCommitments.push({ where, create, update, data });
        return data;
      },
      deleteMany: async () => ({ count: 0 }),
    },
    financialPaymentRecord: {
      findMany: async ({ where }: any) =>
        mirroredPayments
          .map((entry) => entry.create)
          .filter((entry) =>
            where.legacyDebtId
              ? entry.legacyDebtId === where.legacyDebtId
              : where.legacyInstallmentId
                ? entry.legacyInstallmentId === where.legacyInstallmentId
                : true,
          )
          .map((entry) => ({
            amount: entry.amount,
            entryType: entry.entryType ?? "PAYMENT",
          })),
      create: async ({ data }: any) => {
        mirroredPayments.push({ create: data });
        return { id: `payment-${mirroredPayments.length}`, ...data };
      },
    },
  };
  const prisma = {
    $transaction: async (fn: any) => fn(tx),
    debt: {
      create: async ({ data }: any) => {
        created.push(data);
        return {
          id: `debt-${created.length}`,
          weddingPlanId: data.weddingPlanId,
          creditorName: data.creditorName,
          creditorPhone: data.creditorPhone ?? null,
          creditorNormalizedPhone: data.creditorNormalizedPhone ?? null,
          title: data.title,
          totalAmount: new Prisma.Decimal(data.totalAmount),
          paidAmount: new Prisma.Decimal(data.paidAmount),
          dueDate: data.dueDate ?? null,
          status: data.status,
          note: data.note ?? null,
          createdAt: new Date("2026-07-07T00:00:00.000Z"),
          updatedAt: new Date("2026-07-07T00:00:00.000Z"),
        };
      },
    },
  };
  (tx as any).debt = prisma.debt;
  const permissions = {
    assertFinancialManageable: async () => undefined,
  };
  const service = new DebtsService(prisma as any, permissions as any);
  const user = { id: "user-1" } as any;

  // Overpaid on create used to persist paid > total with status OPEN.
  const overpaid = await service.create(user, "plan-1", {
    creditorName: "أحمد",
    title: "دين قات",
    totalAmount: "100",
    paidAmount: "150",
  } as any);
  assert.equal(overpaid.paidAmount, "100");
  assert.equal(overpaid.status, DebtStatus.PAID);
  assert.equal(
    mirroredCommitments[0].create.sourceType,
    FinancialCommitmentSourceType.MANUAL_DEBT,
  );
  assert.equal(mirroredCommitments[0].create.legacyDebtId, "debt-1");
  assert.equal(mirroredCommitments[0].create.paidAmount.toString(), "100");
  assert.equal(mirroredPayments[0].create.legacyDebtId, "debt-1");
  assert.equal(mirroredPayments[0].create.amount.toString(), "100");

  const partial = await service.create(user, "plan-1", {
    creditorName: "أحمد",
    title: "دين ذهب",
    totalAmount: "100",
    paidAmount: "40",
    status: DebtStatus.OPEN,
  } as any);
  assert.equal(partial.status, DebtStatus.PARTIALLY_PAID);

  // Cancellation is orthogonal to the balance and must survive.
  const cancelled = await service.create(user, "plan-1", {
    creditorName: "أحمد",
    title: "ملغي",
    totalAmount: "100",
    status: DebtStatus.CANCELLED,
  } as any);
  assert.equal(cancelled.status, DebtStatus.CANCELLED);
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
    "Debt_amounts_non_negative",
    "Debt_paid_within_total",
    "Installment_amount_non_negative",
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
