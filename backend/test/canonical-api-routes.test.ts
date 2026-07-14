import assert from "node:assert/strict";
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const backendRoot = join(__dirname, "..");
const read = (path: string) =>
  readFileSync(join(backendRoot, path), "utf8");

function controllerSources(root: string): string[] {
  const result: string[] = [];
  for (const entry of readdirSync(root)) {
    const path = join(root, entry);
    if (statSync(path).isDirectory()) result.push(...controllerSources(path));
    else if (entry.endsWith(".controller.ts")) result.push(readFileSync(path, "utf8"));
  }
  return result;
}

test("old money endpoints are gone and canonical v1 endpoints are present", () => {
  const sources = controllerSources(join(backendRoot, "src"));
  const all = sources.join("\n");
  for (const forbidden of [
    "/expenses",
    "/financial-commitments",
    "/financial-installments",
    "/financial-payment-records",
    '@Controller("expenses")',
    '@Controller("financial-commitments")',
  ]) {
    assert.equal(all.includes(forbidden), false, forbidden);
  }

  const weddingCosts = read("src/wedding-costs/wedding-costs.controller.ts");
  const money = read("src/money/money-summary.controller.ts");
  for (const required of [
    '@Controller("api/v1/wedding-plans/:weddingPlanId/costs")',
    '@Controller("api/v1/costs")',
    '@Controller("api/v1/wedding-plans/:weddingPlanId/cost-payments")',
    '@Controller("api/v1/cost-payments")',
    '@Controller("api/v1/wedding-plans/:weddingPlanId/payment-schedules")',
    '@Controller("api/v1/payment-schedules")',
  ]) {
    assert.equal(weddingCosts.includes(required), true, required);
  }
  assert.match(money, /@Get\("money-summary"\)/);
  assert.match(money, /@Put\("money-budget"\)/);
});

test("canonical controllers are not duplicated through compatibility subclasses", () => {
  const all = controllerSources(join(backendRoot, "src")).join("\n");
  assert.doesNotMatch(all, /class ApiV1\w+Controller extends \w+Controller/);
  assert.doesNotMatch(all, /ApiV1ExpensesController|ApiV1FinancialCommitmentsController/);
});

test("legacy provider-owner aliases stay absent from smoke gates", () => {
  const smokeRoot = join(backendRoot, "scripts", "smoke");
  const smokeSource = readdirSync(smokeRoot)
    .filter((file) => file.endsWith(".js") || file.endsWith(".ts"))
    .map((file) => readFileSync(join(smokeRoot, file), "utf8"))
    .join("\n");
  for (const legacyRoute of [
    "/api/v1/provider/profile",
    "/api/v1/provider/services",
    "/api/v1/provider/quote-requests",
    "/api/v1/provider/quote-offers",
  ]) {
    assert.equal(smokeSource.includes(legacyRoute), false, legacyRoute);
  }
});
