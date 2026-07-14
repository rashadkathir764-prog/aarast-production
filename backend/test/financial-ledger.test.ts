import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const read = (path: string) =>
  readFileSync(join(process.cwd(), path), "utf8");

test("the payment ledger is append-only and reversals stay in the same cost", () => {
  const schema = read("prisma/schema.prisma");
  const payment = schema.match(/model CostPayment \{[\s\S]*?\n\}/)?.[0] ?? "";
  assert.match(payment, /entryType\s+CostPaymentType/);
  assert.match(payment, /reversalOfId\s+String\?\s+@unique/);
  assert.match(payment, /@@unique\(\[reversalOfId, weddingCostId\]\)/);
  assert.match(payment, /paymentSchedule\s+PaymentSchedule\?\s+@relation\(fields: \[paymentScheduleId, weddingCostId\]/);

  const migration = read(
    "prisma/migrations/20260714190000_unify_money_domain/migration.sql",
  );
  for (const required of [
    "CostPayment_append_only",
    "CostPayment_reversal_same_cost_fkey",
    "CostPayment_reversal_type",
    "CostPayment_ledger_integrity",
    "CostPayment_entry_integrity",
    "active_schedule_paid_at IS DISTINCT FROM linked_schedule",
  ]) {
    assert.equal(migration.includes(required), true, required);
  }
});

test("cost and schedule balance changes lock rows and retry serialization failures", () => {
  const service = read("src/wedding-costs/wedding-costs.service.ts");
  const retry = read("src/common/prisma/serializable-transaction.ts");
  for (const method of [
    "createCost",
    "updateCost",
    "createPayment",
    "reversePayment",
    "createSchedule",
    "updateSchedule",
    "cancelSchedule",
    "paySchedule",
  ]) {
    const start = service.indexOf("async " + method + "(");
    assert.ok(start >= 0, method);
    const end = service.indexOf("\n  async ", start + 8);
    const body = service.slice(start, end < 0 ? undefined : end);
    assert.match(body, /runSerializableTransaction|\$transaction/);
  }
  assert.match(service, /lockCost\(tx, current\.weddingCostId\)[\s\S]*lockSchedule\(tx, id\)/);
  assert.match(retry, /P2034/);
  assert.match(retry, /40001/);
  assert.match(retry, /40P01/);
  assert.match(retry, /DEFAULT_ATTEMPTS = 4/);
});

test("database constraints protect budgets and pending schedule capacity", () => {
  const migration = read(
    "prisma/migrations/20260714190000_unify_money_domain/migration.sql",
  );
  for (const required of [
    "BudgetCategory_allocation_non_negative",
    "BudgetCategory_money_budget_integrity",
    "WeddingPlan_money_budget_integrity",
    "PaymentSchedule_capacity_integrity",
    "WeddingCost_schedule_capacity_integrity",
    "payment schedules exceed the remaining cost",
  ]) {
    assert.equal(migration.includes(required), true, required);
  }
});

test("a reversed schedule can be cancelled and generic plan updates cannot bypass money-budget", () => {
  const controller = read("src/wedding-costs/wedding-costs.controller.ts");
  const service = read("src/wedding-costs/wedding-costs.service.ts");
  const updatePlanDto = read("src/wedding-plans/dto/update-wedding-plan.dto.ts");
  assert.match(controller, /@Post\(":id\/cancel"\)/);
  assert.match(service, /async cancelSchedule\(/);
  assert.match(service, /Reverse the payment before cancelling this payment schedule/);
  assert.doesNotMatch(updatePlanDto, /estimatedBudget|currency/);
});
