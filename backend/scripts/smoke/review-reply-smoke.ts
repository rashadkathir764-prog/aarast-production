import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import {
  AdminRole,
  BookingStatus,
  ConversationScope,
  PrismaClient,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  ReviewStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { OutboxService } from "../../src/platform/outbox/outbox.service";
import {
  adminService,
  marketplaceService,
  notificationsService,
  ownerPorts,
  providerDashboardService,
} from "./support/owner-ports";

// B-09 on a real database: a new review tells the provider (p42, opening
// p27); he replies once, two replies at once land once; the reviewer is told
// and reads the reply on his page; a replied review keeps its words; the
// moderation team hides and shows the reply (a10).

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (environment: NodeJS.ProcessEnv) => unknown;
};

assertManagedSmokeEnvironment(process.env);
const runId = process.env.AARAST_SMOKE_RUN_ID!;
const prisma = new PrismaClient();
const label = `Review reply ${runId}`;

function passwordHash(value: string): string {
  return createHash("sha256").update(`${runId}:review-reply:${value}`).digest("hex");
}

function code(error: any): string | undefined {
  return error?.response?.code;
}

async function main(): Promise<void> {
  const city = await prisma.city.create({ data: { nameAr: label, countryCode: "ZZ", isActive: true } });
  const [providerUser, otherProviderUser, customerA, customerB, moderator] = await Promise.all(
    [
      ["provider", UserRole.PROVIDER, null],
      ["other-provider", UserRole.PROVIDER, null],
      ["customer-a", UserRole.USER, null],
      ["customer-b", UserRole.USER, null],
      ["moderator", UserRole.ADMIN, AdminRole.MODERATOR],
    ].map(([name, role, adminRole]) =>
      prisma.user.create({
        data: {
          // The reviewer's first name is what the provider reads (p42).
          name: name === "customer-a" ? "خالد القاضي" : `${label} ${name}`,
          passwordHash: passwordHash(name as string),
          role: role as UserRole,
          adminRole: adminRole as AdminRole | null,
          status: UserStatus.ACTIVE,
        },
      }),
    ),
  );
  const [provider, otherProvider] = await Promise.all(
    [providerUser, otherProviderUser].map((user, index) =>
      prisma.provider.create({
        data: {
          userId: user.id,
          cityId: city.id,
          businessName: `${label} مزود ${index + 1}`,
          phone: `review-${index}-${runId}`.slice(0, 30),
          status: ProviderStatus.ACTIVE,
        },
      }),
    ),
  );

  /** A confirmed booking whose day has passed: the customer may review (F10). */
  async function completedBooking(userId: string, day: string) {
    const eventDate = new Date(`${day}T00:00:00Z`);
    const conversation = await prisma.conversation.create({
      data: {
        scope: ConversationScope.ACCOUNT,
        accountRequesterUserId: userId,
        providerId: provider.id,
        createdByUserId: userId,
      },
    });
    const quote = await prisma.quoteRequest.create({
      data: {
        userId,
        providerId: provider.id,
        conversationId: conversation.id,
        status: QuoteRequestStatus.ACCEPTED,
        acceptedAt: new Date(),
        eventDate,
        contactName: "خالد القاضي",
      },
    });
    const offer = await prisma.quoteOffer.create({
      data: {
        quoteRequestId: quote.id,
        providerId: provider.id,
        amount: "300000",
        status: QuoteOfferStatus.ACCEPTED,
      },
    });
    await prisma.booking.create({
      data: {
        quoteRequestId: quote.id,
        quoteOfferId: offer.id,
        providerId: provider.id,
        eventDate,
        status: BookingStatus.CONFIRMED,
        requestedByUserId: userId,
        confirmedAt: new Date(),
      },
    });
  }

  const permissions = new PermissionService(prisma as any, ownerPorts.plans);
  const notifications = notificationsService(prisma, permissions, new OutboxService());
  const market = marketplaceService(prisma, permissions, notifications, {});
  const dashboard = providerDashboardService(prisma, notifications, {}, {});
  const admins = adminService(prisma, { revokeConversationAccess: () => {} }, notifications);
  const asUser = (user: typeof customerA) => ({ ...user, sessionScope: "application" }) as any;
  const asAdmin = { ...moderator, adminMfa: true, sessionScope: "admin" } as any;

  try {
    // One confirmed booking per provider per day (the partial unique index).
    await completedBooking(customerA.id, "2026-01-15");
    await completedBooking(customerB.id, "2026-01-16");

    const review = await market.createReview(asUser(customerA), provider.id, { rating: 4, comment: "تأخر الفيلم" } as any);
    const received = await prisma.notification.findFirstOrThrow({
      where: { userId: providerUser.id, type: "REVIEW_RECEIVED", entityId: review.id },
    });
    assert.equal(received.routeTarget, `/provider/reviews/${review.id}`);
    assert.equal(received.title, "تقييم جديد");
    assert.equal(received.body, "4 نجوم من خالد");
    assert.equal((received.data as any).recipientAudience, "PROVIDER");
    console.log("PASS - a new review tells the provider «4 نجوم من …», opening p27");

    await assert.rejects(
      dashboard.replyToReview(asUser(otherProviderUser), review.id, { body: "ليس لي" }),
      /not found/i,
    );
    const replied = await dashboard.replyToReview(asUser(providerUser), review.id, { body: "  نعتذر عن التأخير، وعدّلنا التسليم.  " });
    assert.equal(replied.reply?.body, "نعتذر عن التأخير، وعدّلنا التسليم.");
    assert.equal(replied.reply?.status, ReviewStatus.PUBLISHED);
    await assert.rejects(
      dashboard.replyToReview(asUser(providerUser), review.id, { body: "مرة ثانية" }),
      (error: any) => code(error) === "REVIEW_ALREADY_REPLIED",
    );
    console.log("PASS - only his own review, once; a second reply is 409 REVIEW_ALREADY_REPLIED");

    const toReviewer = await prisma.notification.findFirstOrThrow({
      where: { userId: customerA.id, type: "REVIEW_REPLIED", entityId: review.id },
    });
    assert.equal(toReviewer.routeTarget, `/providers/${provider.id}`);
    assert.match(toReviewer.title, /^رد .+ على تقييمك$/u);
    console.log("PASS - the reviewer is told and the notice opens the provider's page");

    const publicReviews = await market.findProviderReviews(provider.id);
    assert.equal(publicReviews[0]?.reply?.body, "نعتذر عن التأخير، وعدّلنا التسليم.");
    await assert.rejects(
      market.updateReview(asUser(customerA), review.id, { comment: "غيّرت رأيي" } as any),
      (error: any) => code(error) === "REVIEW_HAS_REPLY",
    );
    console.log("PASS - customers read the reply; a replied review keeps its words (409 REVIEW_HAS_REPLY)");

    // Two replies at once to another review: exactly one lands.
    const second = await market.createReview(asUser(customerB), provider.id, { rating: 5 } as any);
    const race = await Promise.allSettled([
      dashboard.replyToReview(asUser(providerUser), second.id, { body: "شكرًا أ" }),
      dashboard.replyToReview(asUser(providerUser), second.id, { body: "شكرًا ب" }),
    ]);
    assert.equal(race.filter((outcome) => outcome.status === "fulfilled").length, 1);
    const stored = await prisma.providerReview.findUniqueOrThrow({ where: { id: second.id } });
    assert.ok(["شكرًا أ", "شكرًا ب"].includes(stored.replyBody ?? ""));
    console.log("PASS - two replies at once: one lands, one is refused");

    const hidden = await admins.updateReviewReplyStatus(asAdmin, review.id, { status: "HIDDEN" });
    assert.equal(hidden.reply?.status, ReviewStatus.HIDDEN);
    assert.equal((await market.findProviderReviews(provider.id)).find((item) => item.id === review.id)?.reply, null);
    const own = (await dashboard.findReviews(asUser(providerUser))).find((item) => item.id === review.id);
    assert.equal(own?.reply?.status, ReviewStatus.HIDDEN);
    const listed = await admins.listReviews({ providerId: provider.id } as any);
    assert.equal(listed.items.find((item: any) => item.id === review.id)?.reply?.status, ReviewStatus.HIDDEN);
    await admins.updateReviewReplyStatus(asAdmin, review.id, { status: "PUBLISHED" });
    assert.ok((await market.findProviderReviews(provider.id)).find((item) => item.id === review.id)?.reply);
    await assert.rejects(
      admins.updateReviewReplyStatus(asAdmin, review.id, { status: "PENDING" }),
      /PUBLISHED or HIDDEN/u,
    );
    console.log("PASS - the moderation team hides and shows a reply; customers stop and start reading it");

    const plain = await prisma.providerReview.create({
      data: { userId: otherProviderUser.id, providerId: provider.id, rating: 3, status: ReviewStatus.PUBLISHED },
    });
    await assert.rejects(
      admins.updateReviewReplyStatus(asAdmin, plain.id, { status: "HIDDEN" }),
      (error: any) => code(error) === "REVIEW_REPLY_NOT_FOUND",
    );
    console.log("PASS - a review without a reply has no reply to hide");
  } finally {
    await prisma.notification.deleteMany({
      where: { userId: { in: [providerUser.id, otherProviderUser.id, customerA.id, customerB.id] } },
    });
    await prisma.provider.deleteMany({ where: { id: { in: [provider.id, otherProvider.id] } } });
    await prisma.conversation.deleteMany({ where: { accountRequesterUserId: { in: [customerA.id, customerB.id] } } });
    await prisma.city.deleteMany({ where: { id: city.id } });
    await prisma.user.deleteMany({
      where: { id: { in: [providerUser.id, otherProviderUser.id, customerA.id, customerB.id, moderator.id] } },
    });
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
