import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import test from "node:test";
import {
  AppRole,
  ProviderStatus,
  ReviewStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { MarketplaceService } from "../src/marketplace/marketplace.service";

const source = (relativePath: string) =>
  readFileSync(join(__dirname, "..", "src", relativePath), "utf8");
const backendFile = (...segments: string[]) =>
  readFileSync(join(__dirname, "..", ...segments), "utf8");

function deferred() {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

test("concurrent review creation cannot leave a stale provider rating cache", async () => {
  const firstAggregateObserved = deferred();
  const freshUpdateCommitted = deferred();
  const reviews: any[] = [];
  const provider = {
    id: "11111111-1111-4111-8111-111111111111",
    userId: "provider-owner",
    status: ProviderStatus.ACTIVE,
    ratingAverage: "0.00",
    ratingCount: 0,
  };
  let createCalls = 0;
  let activeTransactions = 0;
  let transactionTail = Promise.resolve();
  const updateProviderRating = async (data: any) => {
    if (activeTransactions === 0 && data.ratingCount === 1) {
      await freshUpdateCommitted.promise;
    }
    provider.ratingAverage = String(data.ratingAverage);
    provider.ratingCount = data.ratingCount;
    if (activeTransactions === 0 && data.ratingCount === 2) {
      freshUpdateCommitted.resolve();
    }
  };

  const prisma: any = {
    $transaction(operation: (tx: any) => Promise<unknown>) {
      const result = transactionTail.then(async () => {
        activeTransactions += 1;
        try {
          return await operation(prisma);
        } finally {
          activeTransactions -= 1;
        }
      });
      transactionTail = result.then(
        () => undefined,
        () => undefined,
      );
      return result;
    },
    $queryRaw: async () => [{ id: provider.id }],
    provider: {
      findFirst: async () => provider,
      findUnique: async () => provider,
      update: async ({ data }: any) => {
        await updateProviderRating(data);
        return provider;
      },
      updateMany: async ({ data }: any) => {
        await updateProviderRating(data);
        return { count: 1 };
      },
    },
    providerReview: {
      findUnique: async () => null,
      create: async ({ data }: any) => {
        createCalls += 1;
        if (activeTransactions === 0 && createCalls === 2) {
          await firstAggregateObserved.promise;
        }
        const review = {
          id: `review-${createCalls}`,
          ...data,
          status: ReviewStatus.PUBLISHED,
          createdAt: new Date(),
          updatedAt: new Date(),
          user: {
            id: data.userId,
            name: data.userId,
            appName: null,
            role: UserRole.USER,
          },
        };
        reviews.push(review);
        return review;
      },
      aggregate: async () => {
        const published = reviews.filter(
          (review) => review.status === ReviewStatus.PUBLISHED,
        );
        const average =
          published.reduce((sum, review) => sum + review.rating, 0) /
          published.length;
        if (published.length === 1) firstAggregateObserved.resolve();
        return {
          _avg: { rating: published.length === 0 ? null : average },
          _count: { _all: published.length },
        };
      },
    },
  };
  const service = new MarketplaceService(prisma, {} as any, {} as any);
  const user = (id: string) =>
    ({
      id,
      name: id,
      phone: null,
      email: null,
      role: UserRole.USER,
      adminRole: null,
      appRole: AppRole.WEDDING_USER,
      status: UserStatus.ACTIVE,
      phoneVerifiedAt: new Date(),
      lastLoginAt: null,
      avatarUrl: null,
      locale: "ar",
      activeWeddingPlanId: null,
      onboardingPath: null,
      persona: null,
      onboardingCompletedAt: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    }) as any;

  await Promise.all([
    service.createReview(user("reviewer-a"), provider.id, { rating: 1 }),
    service.createReview(user("reviewer-b"), provider.id, { rating: 5 }),
  ]);

  assert.equal(provider.ratingCount, reviews.length);
  assert.equal(Number(provider.ratingAverage), 3);
});

test("every product review mutation uses the shared locked aggregate boundary", () => {
  const marketplace = source("marketplace/marketplace.service.ts");
  const admin = source("admin/admin-mutation-executor.ts");
  const accountDeletion = source("modules/identity/internal/profile/users.service.ts");
  const aggregate = source("marketplace/provider-review-rating.ts");

  assert.equal(
    (marketplace.match(/runProviderReviewMutation\(/g) ?? []).length,
    3,
  );
  assert.equal((admin.match(/lockProviderRatingRows\(/g) ?? []).length, 2);
  assert.equal((admin.match(/refreshProviderRating\(/g) ?? []).length, 2);
  assert.equal((admin.match(/AdminPermission\.REVIEWS_WRITE/g) ?? []).length, 2);
  assert.doesNotMatch(marketplace, /recalculateProviderRating/);
  assert.doesNotMatch(admin, /recalculateProviderRating/);
  assert.match(aggregate, /runSerializableTransaction/);
  assert.match(aggregate, /ORDER BY "id" ASC\s+FOR UPDATE/);
  assert.match(accountDeletion, /providerReview\.deleteMany/);
  assert.match(accountDeletion, /refreshProviderRating/);
});

test("the upgrade migration repairs cached ratings without deleting review data", () => {
  const migration = backendFile(
    "prisma",
    "migrations",
    "20260724180500_reconcile_provider_rating_cache",
    "migration.sql",
  );

  assert.match(migration, /UPDATE "Provider"/);
  assert.match(migration, /LEFT JOIN "ProviderReview"/);
  assert.match(migration, /review\."status" = 'PUBLISHED'/);
  assert.match(migration, /COUNT\(review\."id"\)/);
  assert.doesNotMatch(migration, /\b(?:DELETE|DROP|TRUNCATE)\b/i);
});
