import type { ConversationLifecyclePort } from "../../src/modules/messaging/public/conversation-lifecycle.port";
import { findConversationProviderId, lockConversationForShare, lockConversationForUpdate } from "../../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent: async () => { throw new Error("Unexpected recordConversationEvent"); },
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
  findConversationProviderId,
};
import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  AdminRole,
  BookingStatus,
  ConversationScope,
  PrismaClient,
  ProviderStatus,
  QuoteRequestStatus,
  ReviewStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { MarketplaceService } from "../../src/marketplace/marketplace.service";
import { UsersService } from "../../src/modules/identity/internal/profile/users.service";
import { identityErasurePorts, ownerPorts, marketplaceService, adminService } from "./support/owner-ports";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const labelPrefix = `Rating atomicity ${runId}`;

function passwordHash(label: string): string {
  return createHash("sha256").update(`${runId}:${label}`).digest("hex");
}

async function assertExactAggregate(providerId: string): Promise<void> {
  const [provider, aggregate] = await Promise.all([
    prisma.provider.findUniqueOrThrow({
      where: { id: providerId },
      select: { ratingAverage: true, ratingCount: true },
    }),
    prisma.providerReview.aggregate({
      where: { providerId, status: ReviewStatus.PUBLISHED },
      _avg: { rating: true },
      _count: { _all: true },
    }),
  ]);
  const expectedCount = aggregate._count._all;
  const expectedAverage =
    expectedCount === 0 ? 0 : Number((aggregate._avg.rating ?? 0).toFixed(2));
  assert.equal(provider.ratingCount, expectedCount);
  assert.equal(Number(provider.ratingAverage), expectedAverage);
}

/** F10: a reviewer needs a confirmed booking with the provider whose day has passed. */
async function seedCompletedBookings(
  userIds: string[],
  providerId: string,
): Promise<void> {
  for (const [index, userId] of userIds.entries()) {
    const conversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.ACCOUNT,
        accountRequesterUserId: userId,
        providerId,
        createdByUserId: userId,
      },
    });
    const quote = await prisma.quoteRequest.create({
      data: {
        userId,
        providerId,
        conversationId: conversation.id,
        status: QuoteRequestStatus.ACCEPTED,
        acceptedAt: new Date(),
      },
    });
    await prisma.booking.create({
      data: {
        quoteRequestId: quote.id,
        providerId,
        // One confirmed booking per provider per day (partial unique index).
        eventDate: new Date(Date.UTC(2026, 0, index + 1)),
        status: BookingStatus.CONFIRMED,
        requestedByUserId: userId,
        confirmedAt: new Date(),
      },
    });
  }
}

async function main(): Promise<void> {
  const city = await prisma.city.create({
    data: {
      nameAr: labelPrefix,
      countryCode: "ZZ",
      isActive: true,
    },
  });
  const users = await Promise.all(
    ["owner", "reviewer-a", "reviewer-b", "reviewer-c", "reviewer-d"].map(
      (label) =>
        prisma.user.create({
          data: {
            name: `${labelPrefix} ${label}`,
            passwordHash: passwordHash(label),
          },
        }),
    ),
  );
  const [owner, ...reviewers] = users;
  const adminActor = await prisma.user.create({
    data: {
      name: `${labelPrefix} moderator`,
      passwordHash: passwordHash("moderator"),
      role: UserRole.ADMIN,
      status: UserStatus.ACTIVE,
      adminRole: AdminRole.MODERATOR,
    },
  });
  // B-09: a new review tells the provider in the same transaction; this
  // passed no notifications, so every review here threw once the notice
  // came (the smoke had not run since: it did not compile, see deleteMe).
  const marketplace = marketplaceService(
    prisma,
    new PermissionService(prisma as any, ownerPorts.plans),
    { createNotificationInTransaction: async () => null },
    lifecycle,
  );
  const admin = adminService(prisma as any, {} as any, {
    createNotificationInTransaction: async () => null,
  } as any);

  try {
    const migrationProvider = await prisma.provider.create({
      data: {
        cityId: city.id,
        businessName: `${labelPrefix} migration-provider`,
        phone: "rating-migration",
        status: ProviderStatus.ACTIVE,
        ratingAverage: "1.00",
        ratingCount: 99,
        reviews: {
          create: [
            { userId: reviewers[0].id, rating: 5 },
            { userId: reviewers[1].id, rating: 3 },
          ],
        },
      },
    });
    const migrationSql = readFileSync(
      join(
        __dirname,
        "..",
        "..",
        "prisma",
        "migrations",
        "20260724180500_reconcile_provider_rating_cache",
        "migration.sql",
      ),
      "utf8",
    );
    await prisma.$executeRawUnsafe(migrationSql);
    await assertExactAggregate(migrationProvider.id);
    let repairedProvider = await prisma.provider.findUniqueOrThrow({
      where: { id: migrationProvider.id },
      select: { ratingAverage: true, ratingCount: true },
    });
    assert.equal(Number(repairedProvider.ratingAverage), 4);
    assert.equal(repairedProvider.ratingCount, 2);
    await prisma.$executeRawUnsafe(migrationSql);
    repairedProvider = await prisma.provider.findUniqueOrThrow({
      where: { id: migrationProvider.id },
      select: { ratingAverage: true, ratingCount: true },
    });
    assert.equal(Number(repairedProvider.ratingAverage), 4);
    assert.equal(repairedProvider.ratingCount, 2);

    for (let iteration = 0; iteration < 40; iteration += 1) {
      const provider = await prisma.provider.create({
        data: {
          userId: iteration === 0 ? owner.id : null,
          cityId: city.id,
          businessName: `${labelPrefix} provider ${iteration}`,
          phone: `rating-${iteration}`,
          status: ProviderStatus.ACTIVE,
        },
      });
      await seedCompletedBookings(
        reviewers.map((reviewer) => reviewer.id),
        provider.id,
      );

      await Promise.all(
        reviewers.map((reviewer, index) =>
          marketplace.createReview(reviewer as any, provider.id, {
            rating: [1, 2, 4, 5][index],
          }),
        ),
      );
      await assertExactAggregate(provider.id);

      const reviews = await prisma.providerReview.findMany({
        where: { providerId: provider.id },
        orderBy: { userId: "asc" },
      });
      const byUserId = new Map(reviews.map((review) => [review.userId, review]));
      await Promise.all(
        reviewers.map((reviewer, index) =>
          marketplace.updateReview(
            reviewer as any,
            byUserId.get(reviewer.id)!.id,
            { rating: [5, 4, 2, 1][index] },
          ),
        ),
      );
      await assertExactAggregate(provider.id);

      await Promise.all([
        admin.hideReview(
          adminActor as any,
          byUserId.get(reviewers[0].id)!.id,
        ),
        marketplace.updateReview(
          reviewers[1] as any,
          byUserId.get(reviewers[1].id)!.id,
          { rating: 5 },
        ),
        marketplace.deleteReview(
          reviewers[2] as any,
          byUserId.get(reviewers[2].id)!.id,
        ),
        marketplace.updateReview(
          reviewers[3] as any,
          byUserId.get(reviewers[3].id)!.id,
          { rating: 1 },
        ),
      ]);
      await assertExactAggregate(provider.id);

      await Promise.all([
        admin.updateReviewStatus(
          adminActor as any,
          byUserId.get(reviewers[0].id)!.id,
          {
            status: ReviewStatus.PUBLISHED,
          },
        ),
        marketplace.updateReview(
          reviewers[1] as any,
          byUserId.get(reviewers[1].id)!.id,
          { rating: 2 },
        ),
      ]);
      await assertExactAggregate(provider.id);
    }

    const deletionReviewer = await prisma.user.create({
      data: {
        name: `${labelPrefix} deletion-reviewer`,
        passwordHash: passwordHash("deletion-reviewer"),
      },
    });
    const deletionProvider = await prisma.provider.create({
      data: {
        cityId: city.id,
        businessName: `${labelPrefix} deletion-provider`,
        phone: "rating-deletion",
        status: ProviderStatus.ACTIVE,
      },
    });
    await seedCompletedBookings(
      [reviewers[0].id, deletionReviewer.id],
      deletionProvider.id,
    );
    await Promise.all([
      marketplace.createReview(reviewers[0] as any, deletionProvider.id, {
        rating: 2,
      }),
      marketplace.createReview(deletionReviewer as any, deletionProvider.id, {
        rating: 4,
      }),
    ]);
    await assertExactAggregate(deletionProvider.id);

    // The erasure tells each plan's members (D63), so it needs the real
    // permission service, as the account-deletion smoke builds it.
    const usersService = new UsersService(
      prisma as any,
      new PermissionService(prisma as any, ownerPorts.plans),
      {
        lockAccountDeletionBoundary: async () => undefined,
        scheduleAllOwnedMediaDeletion: async () => [],
        scheduleChatAttachmentDeletion: async () => undefined,
        // Receipt files go with the account (V1 4.4); this reviewer has none.
        scheduleCostReceiptDeletion: async () => undefined,
      } as any,
      ...identityErasurePorts,
    );
    // D63: an account is erased once its 30 days are up; `deleteMe`, which
    // erased at once, is gone, so this smoke no longer compiled. The
    // reviewer's request is made due, then erased as the purge job does.
    await prisma.user.update({
      where: { id: deletionReviewer.id },
      data: {
        deletionRequestedAt: new Date(Date.now() - 31 * 24 * 60 * 60_000),
        deletionScheduledFor: new Date(Date.now() - 60_000),
      },
    });
    assert.equal(
      await usersService.eraseDueAccount(deletionReviewer.id, new Date()),
      "ERASED",
    );
    assert.equal(
      await prisma.providerReview.count({
        where: { userId: deletionReviewer.id },
      }),
      0,
    );
    await assertExactAggregate(deletionProvider.id);

    console.log(
      "PASS - rating migration repaired stale data idempotently; cache stayed exact across 40 concurrent create/update/hide/delete cycles and account deletion.",
    );
  } finally {
    await prisma.provider.deleteMany({
      where: { businessName: { startsWith: labelPrefix } },
    });
    await prisma.user.deleteMany({
      where: { name: { startsWith: labelPrefix } },
    });
    await prisma.city.deleteMany({ where: { id: city.id } });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
