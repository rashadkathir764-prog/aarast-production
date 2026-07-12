import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const backendRoot = join(__dirname, "..");

test("canonical product APIs do not expose unversioned duplicate controllers", () => {
  const files = [
    "auth/auth.controller.ts",
    "budget-categories/budget-categories.controller.ts",
    "conversations/conversations.controller.ts",
    "dashboard/dashboard.controller.ts",
    "expenses/expenses.controller.ts",
    "financial-commitments/financial-commitments.controller.ts",
    "guests/guests.controller.ts",
    "marketplace/marketplace.controller.ts",
    "media/media.controller.ts",
    "money/money-summary.controller.ts",
    "me/me.controller.ts",
    "notifications/notifications.controller.ts",
    "onboarding/onboarding.controller.ts",
    "provider-dashboard/provider-dashboard.controller.ts",
    "sharing/sharing.controller.ts",
    "tasks/tasks.controller.ts",
    "timeline/timeline.controller.ts",
    "users/users.controller.ts",
    "wedding-plans/wedding-plans.controller.ts",
  ];
  const sources = files.map((file) =>
    readFileSync(join(backendRoot, "src", file), "utf8"),
  );

  const forbiddenControllerPaths = [
    "@Controller('auth')",
    "@Controller('conversations')",
    "@Controller('media/uploads')",
    '@Controller("users")',
    '@Controller("financial-commitments")',
    '@Controller("financial-installments")',
    '@Controller("financial-payment-records")',
    "@Controller('budget-categories')",
    "@Controller('dashboard')",
    "@Controller('expenses')",
    "@Controller('cities')",
    "@Controller('provider-categories')",
    "@Controller('providers')",
    "@Controller('services')",
    "@Controller('reviews')",
    "@Controller('onboarding')",
    "@Controller('provider')",
    "@Controller('provider/me')",
    "@Controller('tasks')",
    "@Controller('wedding-plans')",
    "@Controller('notifications')",
    "@Controller('shared')",
    "@Controller('shared-members')",
    "@Controller('me')",
    "@Controller('guests')",
    "@Controller('guest-groups')",
    "@Controller('wedding-plans/:weddingPlanId/guests')",
    "@Controller('wedding-plans/:weddingPlanId/guest-groups')",
    "@Controller('wedding-plans/:planId')",
    "@Controller('wedding-plans/:weddingPlanId/budget-categories')",
    "@Controller('wedding-plans/:weddingPlanId/expenses')",
    "@Controller('wedding-plans/:weddingPlanId/shared-members')",
    "@Controller('wedding-plans/:weddingPlanId/tasks')",
    "@Controller('wedding-plans/:weddingPlanId/timeline')",
  ];

  for (const path of forbiddenControllerPaths) {
    assert.equal(
      sources.some((source) => source.includes(path)),
      false,
      `Unversioned controller must stay removed: ${path}`,
    );
  }

  for (const source of sources) {
    assert.equal(
      /class ApiV1\w+Controller extends \w+Controller/.test(source),
      false,
      "Canonical controllers must not be duplicated through compatibility subclasses",
    );
  }
});

test("legacy provider-owner route aliases stay removed from code and smoke gates", () => {
  const providerController = readFileSync(
    join(
      backendRoot,
      "src/provider-dashboard/provider-dashboard.controller.ts",
    ),
    "utf8",
  );
  assert.doesNotMatch(providerController, /class ApiV1ProviderController/);

  const smokeRoot = join(backendRoot, "scripts/smoke");
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
    assert.equal(
      smokeSource.includes(legacyRoute),
      false,
      `Smoke gates must use canonical provider/me route instead of ${legacyRoute}`,
    );
  }
});
