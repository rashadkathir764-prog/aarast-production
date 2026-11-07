import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { readLivePrismaSchema } from './support/live-prisma-schema';

const read = (path: string) =>
  readFileSync(join(process.cwd(), path), "utf8");

test("the payment ledger is append-only and reversals stay in the same cost", () => {
  const schema = readLivePrismaSchema();
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
  const retry = read("src/platform/database/serializable-transaction.ts");
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

test("database constraints protect budgets while payment schedules remain non-reserving reminders", () => {
  const migration = read(
    "prisma/migrations/20260714190000_unify_money_domain/migration.sql",
  );
  for (const required of [
    "BudgetCategory_allocation_non_negative",
    "BudgetCategory_money_budget_integrity",
    "WeddingPlan_money_budget_integrity",
    "PaymentSchedule_amount_positive",
    "aarast_validate_payment_schedule_cost_status",
    "PaymentSchedule_cost_status_integrity",
    "WeddingCost_pending_schedule_integrity",
    "paid or cancelled wedding cost % cannot retain pending payment schedules",
    "payment schedule database integrity triggers are missing",
  ]) {
    assert.equal(migration.includes(required), true, required);
  }
  for (const removed of [
    "aarast_validate_cost_schedule_capacity",
    "PaymentSchedule_capacity_integrity",
    "WeddingCost_schedule_capacity_integrity",
    "payment schedules exceed the remaining cost",
  ]) {
    assert.equal(migration.includes(removed), false, removed);
  }

  const statusInvariant =
    migration.match(
      /CREATE FUNCTION "aarast_validate_payment_schedule_cost_status"\(\)[\s\S]*?END \$\$;/,
    )?.[0] ?? "";
  assert.match(statusInvariant, /cost\."status" IN \('PAID', 'CANCELLED'\)/);
  assert.match(statusInvariant, /schedule\."status" = 'PENDING'/);
  assert.doesNotMatch(statusInvariant, /SUM\s*\(|"amount"/);

  const amountAtWriteInvariant =
    migration.match(
      /CREATE FUNCTION "aarast_validate_payment_schedule_amount_at_write"\(\)[\s\S]*?END \$\$;/,
    )?.[0] ?? "";
  assert.match(amountAtWriteInvariant, /NEW\."status" <> 'PENDING'/);
  assert.match(
    amountAtWriteInvariant,
    /NEW\."amount" > remaining_amount/,
  );
  assert.match(amountAtWriteInvariant, /FOR SHARE/);
  assert.doesNotMatch(amountAtWriteInvariant, /SUM\s*\(/);
  const amountAtWriteTrigger =
    migration.match(
      /CREATE TRIGGER "PaymentSchedule_amount_at_write_integrity"[\s\S]*?aarast_validate_payment_schedule_amount_at_write"\(\);/,
    )?.[0] ?? "";
  assert.match(amountAtWriteTrigger, /BEFORE INSERT OR UPDATE/);
  assert.doesNotMatch(amountAtWriteTrigger, /DEFERRABLE|CONSTRAINT/);

  for (const trigger of [
    "PaymentSchedule_cost_status_integrity",
    "WeddingCost_pending_schedule_integrity",
  ]) {
    const definition =
      migration.match(
        new RegExp(
          `CREATE CONSTRAINT TRIGGER "${trigger}"[\\s\\S]*?aarast_validate_payment_schedule_cost_status\\"\\(\\);`,
        ),
      )?.[0] ?? "";
    assert.match(definition, /DEFERRABLE INITIALLY DEFERRED/, trigger);
  }

  const service = read("src/wedding-costs/wedding-costs.service.ts");
  assert.doesNotMatch(service, /pendingScheduleTotal|reserved by pending payment schedules/);
  // The schedule cap is Finance's pure domain policy (O3): the service
  // applies it; the policy caps each schedule by the outstanding amount alone.
  const schedulePolicy = read("src/modules/finance/domain/payment-schedule-policy.ts");
  assert.match(service, /scheduleAmountViolation\(/);
  assert.match(schedulePolicy, /Payment schedule amount cannot exceed the remaining cost/);
  assert.match(schedulePolicy, /amount\.gt\(totalAmount\.minus\(paidAmount\)\)/);
  assert.doesNotMatch(schedulePolicy, /pendingScheduleTotal|reserved by pending payment schedules/);
  assert.match(service, /cancelPendingSchedulesWhenPaid/);
  for (const method of ["updateCost", "createPayment", "paySchedule"]) {
    const start = service.indexOf("async " + method + "(");
    const end = service.indexOf("\n  async ", start + 8);
    const body = service.slice(start, end < 0 ? undefined : end);
    assert.match(body, /cancelPendingSchedulesWhenPaid/, method);
  }

  const reverseStart = service.indexOf("async reversePayment(");
  const reverseEnd = service.indexOf("\n  async ", reverseStart + 8);
  const reverseBody = service.slice(
    reverseStart,
    reverseEnd < 0 ? undefined : reverseEnd,
  );
  const costUpdate = reverseBody.indexOf("await updateWeddingCost(tx");
  const scheduleUpdate = reverseBody.indexOf("await updatePaymentSchedule(tx");
  assert.ok(
    costUpdate >= 0 && scheduleUpdate > costUpdate,
    "reversal must reopen the cost balance before writing a pending schedule",
  );
});

test("the only payment due date belongs to PaymentSchedule", () => {
  const schema = readLivePrismaSchema();
  const cost = schema.match(/model WeddingCost \{[\s\S]*?\n\}/)?.[0] ?? "";
  const schedule = schema.match(/model PaymentSchedule \{[\s\S]*?\n\}/)?.[0] ?? "";
  assert.doesNotMatch(cost, /\bdueDate\b/);
  assert.match(schedule, /dueDate\s+DateTime/);

  const migration = read(
    "prisma/migrations/20260714190000_unify_money_domain/migration.sql",
  );
  const costTable =
    migration.match(/CREATE TABLE "WeddingCost" \([\s\S]*?\n\);/)?.[0] ?? "";
  assert.doesNotMatch(costTable, /"dueDate"/);

  const createDto = read("src/wedding-costs/dto/create-wedding-cost.dto.ts");
  const updateDto = read("src/wedding-costs/dto/update-wedding-cost.dto.ts");
  const importDto = read("src/onboarding/dto/import-local-plan.dto.ts");
  const importCost =
    importDto.match(/export class ImportLocalCostDto \{[\s\S]*?\n\}/)?.[0] ?? "";
  const importSchedule =
    importDto.match(/export class ImportLocalPaymentScheduleDto \{[\s\S]*?\n\}/)?.[0] ?? "";
  assert.doesNotMatch(createDto, /\bdueDate\b/);
  assert.doesNotMatch(updateDto, /\bdueDate\b/);
  assert.doesNotMatch(importCost, /\bdueDate\b/);
  assert.match(importSchedule, /\bdueDate\b/);

  const importService = read("src/wedding-plans/wedding-plans.service.ts");
  assert.doesNotMatch(importService, /cost\.dueDate|scheduledAmount/);
  // RA-BE-63 (changed with its reason): this line pinned the import refusing
  // a reminder above what is left, which refused a phone's plan for ever
  // once a payment came after the reminder (a state the account itself
  // keeps, RA-BE-53). The rule it guarded still holds where it belongs, in
  // the database, at the reminder's write: the import writes an agreement as
  // it happened (unpaid with its reminders, then its payments), and a
  // reminder is never above the whole agreement nor kept on one paid in full.
  assert.doesNotMatch(importService, /exceeds the remaining cost/);
  assert.match(importService, /written\.gt\(totalAmount\) \? totalAmount : written/);
  assert.match(importService, /\.filter\(\(\) => remainingAmount\.gt\(0\)\)/);
  const financePort = read("src/modules/finance/infrastructure/finance-port.service.ts");
  const importedCost =
    financePort.match(/async createImportedCostInTransaction\([\s\S]*?\n  \}/)?.[0] ?? "";
  assert.ok(
    importedCost.indexOf("paymentSchedules:") >= 0 &&
      importedCost.indexOf("paymentSchedules:") < importedCost.indexOf("costPayment.createMany"),
    "an imported agreement's reminders are written before its payments",
  );
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
