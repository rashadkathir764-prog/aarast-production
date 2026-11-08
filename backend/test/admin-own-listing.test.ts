import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { AdminPortfolioReview } from "../src/admin/admin-portfolio-review";

// RA-BE-101: a team member who also has a provider account decided on his
// own business's photos and hid the reviews written about it. As with his
// own application and his listing's featured period, he cannot.

test("RA-BE-101: a team member does not decide on his own business's photos", async () => {
  let decided = false;
  const review = new AdminPortfolioReview({
    prisma: { $transaction: async (operation: any) => operation({}) } as any,
    owners: {
      marketplace: {
        lockPortfolioItemInTransaction: async () => ({
          id: "photo-1",
          status: "PENDING",
          forWomen: false,
          provider: { id: "provider-1", businessName: "استوديو", userId: "admin-1", status: "ACTIVE" },
        }),
        decidePortfolioItemInTransaction: async () => {
          decided = true;
          return null;
        },
      },
    } as any,
    notifications: {} as any,
  });

  await assert.rejects(
    review.decide({ id: "admin-1" } as any, "photo-1", { decision: "APPROVE" } as any),
    /cannot review their own portfolio/,
  );
  assert.equal(decided, false);
});

test("RA-BE-101: every review moderation asks whose listing it is first", () => {
  const admin = readFileSync(join(__dirname, "../src/admin/admin-mutation-executor.ts"), "utf8");
  // The status change and the hide run moderateReview; the reply's status
  // runs its own lock. Each refuses the reviews of the member's own listing.
  assert.match(
    admin,
    /private async moderateReview\([\s\S]*?findReviewProviderId[\s\S]*?this\.assertNotOwnListing\(tx, currentUser, providerId\)[\s\S]*?setReviewStatusInTransaction/,
  );
  assert.match(
    admin,
    /async updateReviewReplyStatus\([\s\S]*?lockReviewForUpdateInTransaction[\s\S]*?this\.assertNotOwnListing\(tx, currentUser, providerId\)[\s\S]*?setReviewReplyStatusInTransaction/,
  );
  assert.match(
    admin,
    /private async assertNotOwnListing\([\s\S]*?findProviderAccount\(tx, providerId\)[\s\S]*?account\?\.userId === currentUser\.id/,
  );
});
