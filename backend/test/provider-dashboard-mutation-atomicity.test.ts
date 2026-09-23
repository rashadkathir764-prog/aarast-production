import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

function methodBlock(source: string, method: string, nextMethod: string): string {
  const start = source.indexOf(`  async ${method}(`);
  const end = source.indexOf(`  async ${nextMethod}(`, start + 1);
  assert.notEqual(start, -1, `${method} must exist`);
  assert.notEqual(end, -1, `${nextMethod} must exist after ${method}`);
  return source.slice(start, end);
}

test("every provider-dashboard write reauthorizes inside a serializable transaction", () => {
  const source = readFileSync(
    "src/provider-dashboard/provider-dashboard.service.ts",
    "utf8",
  );
  const writes = [
    ["apply", "getProfile"],
    ["updateProfile", "getSummary"],
    ["createService", "findService"],
    ["updateService", "deactivateService"],
    ["deactivateService", "createServiceImage"],
    ["createServiceImage", "updateServiceImage"],
    ["updateServiceImage", "deleteServiceImage"],
    ["deleteServiceImage", "findPackages"],
    ["createPackage", "updatePackage"],
    ["updatePackage", "deactivatePackage"],
    ["deactivatePackage", "findQuoteRequests"],
    ["updateQuoteRequestStatus", "createQuoteOffer"],
    ["createQuoteOffer", "updateQuoteOffer"],
    ["updateQuoteOffer", "findReviews"],
  ] as const;

  for (const [method, nextMethod] of writes) {
    const block = methodBlock(source, method, nextMethod);
    assert.match(
      block,
      /runSerializableTransaction\(\s*this\.prisma/,
      `${method} must own one serializable authorization+write boundary`,
    );
  }
});

test("provider quote writes lock users, plan, provider and conversation before quote rows", () => {
  const source = readFileSync(
    "src/provider-dashboard/provider-dashboard.service.ts",
    "utf8",
  );
  for (const [method, nextMethod] of [
    ["updateQuoteRequestStatus", "createQuoteOffer"],
    ["createQuoteOffer", "updateQuoteOffer"],
    ["updateQuoteOffer", "findReviews"],
  ] as const) {
    const block = methodBlock(source, method, nextMethod);
    const users = block.indexOf("lockQuoteMutationContext");
    const quote =
      method === "updateQuoteOffer"
        ? block.indexOf("lockQuoteOfferTransitionRows")
        : block.indexOf("lockQuoteRequestTransitionRow");
    assert.ok(users >= 0, `${method} must lock the live mutation context`);
    assert.ok(
      quote > users,
      `${method} must lock the mutation context before quote lifecycle rows`,
    );
  }
});

test("service image update and delete lock the image before media target state", () => {
  const source = readFileSync(
    "src/provider-dashboard/provider-dashboard.service.ts",
    "utf8",
  );
  for (const [method, nextMethod] of [
    ["updateServiceImage", "deleteServiceImage"],
    ["deleteServiceImage", "findPackages"],
  ] as const) {
    const block = methodBlock(source, method, nextMethod);
    const image = block.indexOf("lockOwnedServiceImageInTransaction");
    const media = block.indexOf("scheduleTargetDeletion");
    assert.ok(image >= 0, `${method} must lock the image row`);
    assert.ok(
      media > image,
      `${method} must use Image -> media-target lock order`,
    );
  }
});

test("admin provider review locks actor and owner users before the provider", () => {
  const source = readFileSync("src/admin/admin.service.ts", "utf8");
  const block = source.slice(
    source.indexOf("  private async reviewProvider("),
    source.indexOf(
      "  private async lockProviderReviewUsersInTransaction(",
      source.indexOf("  private async reviewProvider("),
    ),
  );
  // The provider row lock is marketplace's statement now, taken through
  // its admin port after identity locked the actor and owner accounts.
  const users = block.indexOf("lockProviderReviewUsersInTransaction");
  const provider = block.indexOf("lockProviderForUpdateInTransaction");
  assert.ok(users >= 0, "reviewProvider must lock the actor and owner users");
  assert.ok(
    provider > users,
    "reviewProvider must use User(s) -> Provider lock order",
  );
});
