import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { readLivePrismaSchema } from './support/live-prisma-schema';

const backendRoot = join(__dirname, "..");
const read = (path: string) =>
  readFileSync(join(backendRoot, path), "utf8");

test("only the unified money domain remains in the live schema and modules", () => {
  const schema = readLivePrismaSchema();
  const appModule = read("src/app.module.ts");

  for (const required of [
    "model BudgetCategory {",
    "model WeddingCost {",
    "model CostPayment {",
    "model PaymentSchedule {",
    "canViewMoney",
    "canManageMoney",
  ]) {
    assert.equal(schema.includes(required), true, required);
  }

  for (const forbidden of [
    "model Debt ",
    "model Installment ",
    "model Expense ",
    "model FinancialCommitment ",
    "model FinancialPaymentRecord ",
    "model FinancialInstallment ",
    "legacyDebtId",
    "legacyInstallmentId",
    "legacyExpenseId",
    "canViewBudget",
    "canViewExpenses",
    "canViewFinancialRecords",
    "canManageFinancialRecords",
  ]) {
    assert.equal(schema.includes(forbidden), false, forbidden);
  }

  for (const removed of [
    "src/expenses/expenses.controller.ts",
    "src/expenses/expenses.service.ts",
    "src/financial-commitments/financial-commitments.controller.ts",
    "src/financial-commitments/financial-commitments.service.ts",
    "src/common/finance/legacy-finance-bridge.ts",
    "src/common/money/debt-balance.ts",
  ]) {
    assert.equal(existsSync(join(backendRoot, removed)), false, removed);
  }

  assert.doesNotMatch(appModule, /ExpensesModule|FinancialCommitmentsModule|DebtsModule|InstallmentsModule/);
  assert.match(appModule, /WeddingCostsModule/);
  assert.match(appModule, /MoneyModule/);
});

test("operational seed, load, and smoke tools cannot restore old money paths", () => {
  const seed = read("prisma/seed.ts");
  const load = read("scripts/load/load-test.js");
  const packageJson = read("package.json");
  const allSmoke = read("scripts/smoke/all-smoke.js");

  for (const [name, source] of [
    ["seed", seed],
    ["load", load],
    ["package", packageJson],
    ["all-smoke", allSmoke],
  ] as const) {
    assert.doesNotMatch(
      source,
      /targetAmount|\/expenses|FinancialCommitment|FinancialInstallment|ExpenseStatus|InstallmentStatus|budget-expense/,
      name,
    );
  }

  assert.equal(
    existsSync(join(backendRoot, "scripts/smoke/money-budget-smoke.js")),
    true,
  );
  assert.equal(
    existsSync(join(backendRoot, "scripts/smoke/budget-expense-smoke.js")),
    false,
  );
});

test("the terminal prelaunch migration deletes old finance and fails closed", () => {
  const migration = read(
    "prisma/migrations/20260714190000_unify_money_domain/migration.sql",
  );

  for (const required of [
    'DROP TABLE "Expense"',
    'DROP TABLE "FinancialCommitment"',
    'DROP TABLE "FinancialPaymentRecord"',
    'DROP TABLE "FinancialInstallment"',
    'DROP TYPE "ExpenseStatus"',
    'DROP TYPE "FinancialCommitmentStatus"',
    'DROP TYPE "FinancialPaymentRecordType"',
    "prelaunch finance reset must create empty money tables",
    "old finance tables or enum types remain after reset",
    "old finance notifications remain after reset",
    'CREATE TEMP TABLE "aarast_removed_finance_notification"',
    'DELETE FROM "OutboxEvent"',
    "old finance notification outbox events remain after reset",
    `SET "name" = 'غير مصنف'`,
    `WHERE trim("name") = ''`,
  ]) {
    assert.equal(migration.includes(required), true, required);
  }

  assert.match(migration, /^-- PRELAUNCH DESTRUCTIVE RESET/);
  assert.match(migration, /BEGIN;[\s\S]*COMMIT;\s*$/);
  assert.doesNotMatch(migration, /(?:Ø|Ù)[^\s']*/);
});
