import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { Prisma, QuoteRequestStatus } from "@prisma/client";
import { MarketplaceService } from "../src/marketplace/marketplace.service";
import { createQuoteRequestInTransaction } from "../src/marketplace/quote-request-creation";
import { isQuoteOfferExpired } from "../src/marketplace/quote-offer-expiry";
import { ProviderDashboardService } from "../src/provider-dashboard/provider-dashboard.service";

const now = new Date("2026-07-22T12:00:00.000Z");
const requester = {
  id: "user-1",
  name: "Requester",
  phone: "+967711111111",
} as any;
const providerId = "11111111-1111-4111-8111-111111111111";
const quoteId = "22222222-2222-4222-8222-222222222222";

function rawSqlText(query: unknown): string {
  const strings = (query as { strings?: readonly string[] } | null)?.strings;
  return strings ? strings.join(" ") : String(query);
}

function creationHarness(
  options: {
    existingStatus?: QuoteRequestStatus;
    expiredOffer?: boolean;
  } = {},
) {
  let creates = 0;
  let matchedWhere: any;
  const notifications: any[] = [];
  const provider = {
    id: providerId,
    userId: "provider-user",
    businessName: "Provider",
    status: "ACTIVE",
  };
  const created = {
    id: quoteId,
    userId: requester.id,
    providerId,
    weddingPlanId: null,
    serviceId: null,
    eventDate: null,
    cityId: "city-1",
    contactName: requester.name,
    conversationId: "conversation-1",
    status: QuoteRequestStatus.SENT,
    createdAt: now,
    provider,
  };
  const existing = options.existingStatus
    ? {
        ...created,
        status: options.existingStatus,
        offers:
          options.existingStatus === QuoteRequestStatus.RESPONDED
            ? [
                {
                  status: "PENDING",
                  validUntil: options.expiredOffer
                    ? new Date("2026-07-21T00:00:00.000Z")
                    : new Date("2026-07-30T00:00:00.000Z"),
                },
              ]
            : [],
      }
    : null;
  const tx = {
    $queryRaw: async () => [{ id: "conversation-1" }],
    provider: {
      findFirst: async () => provider,
      findUnique: async () => ({ userId: provider.userId }),
    },
    weddingPlan: { findUnique: async () => ({ ownerUserId: requester.id }) },
    conversationParticipant: { createMany: async () => ({ count: 2 }) },
    conversation: { update: async () => ({ id: "conversation-1" }) },
    conversationEvent: {
      createMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async ({ where }: any) => ({
        id: "event-1",
        dedupeKey: where.dedupeKey,
      }),
    },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
    quoteRequest: {
      findFirst: async ({ where }: any) => {
        matchedWhere = where;
        if (
          options.existingStatus === QuoteRequestStatus.ACCEPTED ||
          options.existingStatus === QuoteRequestStatus.REJECTED ||
          options.existingStatus === QuoteRequestStatus.CANCELLED
        ) {
          return null;
        }
        return existing;
      },
      create: async ({ data }: any) => {
        creates += 1;
        return { ...created, ...data };
      },
    },
  };
  const prisma = { $transaction: async (fn: any) => fn(tx) };
  const notificationService = {
    createNotificationInTransaction: async (_tx: any, input: any) => {
      notifications.push(input);
      return input;
    },
  };
  const input = {
    requesterId: requester.id,
    contactName: requester.name,
    data: {
      userId: requester.id,
      providerId,
      weddingPlanId: null,
      serviceId: null,
      eventDate: null,
      cityId: "city-1",
      contactName: requester.name,
      message: "details do not define identity",
      budgetMin: new Prisma.Decimal("100"),
    },
  };
  return {
    run: () =>
      createQuoteRequestInTransaction(
        prisma as any,
        notificationService as any,
        input,
      ),
    get creates() {
      return creates;
    },
    get matchedWhere() {
      return matchedWhere;
    },
    notifications,
  };
}

test("an identical active quote is rejected by domain identity", async () => {
  const harness = creationHarness({ existingStatus: QuoteRequestStatus.SENT });
  await assert.rejects(harness.run(), (error: unknown) => {
    assert.ok(error instanceof ConflictException);
    assert.equal(
      (error.getResponse() as any).code,
      "ACTIVE_QUOTE_REQUEST_EXISTS",
    );
    assert.equal((error.getResponse() as any).quoteRequestId, quoteId);
    return true;
  });
  assert.equal(harness.creates, 0);
  assert.equal(harness.matchedWhere.cityId, "city-1");
  assert.equal("message" in harness.matchedWhere, false);
  assert.equal("budgetMin" in harness.matchedWhere, false);
});

test("terminal quote states allow a new logical request", async () => {
  for (const status of [
    QuoteRequestStatus.CANCELLED,
    QuoteRequestStatus.REJECTED,
    QuoteRequestStatus.ACCEPTED,
  ]) {
    const harness = creationHarness({ existingStatus: status });
    const quote = await harness.run();
    assert.equal(quote.id, quoteId);
    assert.equal(harness.creates, 1);
  }
});

test("an expired response cycle allows an explicit new request", async () => {
  const harness = creationHarness({
    existingStatus: QuoteRequestStatus.RESPONDED,
    expiredOffer: true,
  });
  await harness.run();
  assert.equal(harness.creates, 1);
});

test("quote creation and its deduplicated notifications share one transaction", async () => {
  const harness = creationHarness();
  await harness.run();
  assert.equal(harness.creates, 1);
  assert.equal(harness.notifications.length, 2);
  assert.equal(
    new Set(harness.notifications.map((item) => item.dedupeKey)).size,
    2,
  );
});

test("validUntil derives expiry without changing persisted status", () => {
  assert.equal(
    isQuoteOfferExpired(
      { status: "PENDING", validUntil: new Date("2026-07-21T00:00:00Z") },
      now,
    ),
    true,
  );
  assert.equal(
    isQuoteOfferExpired(
      { status: "PENDING", validUntil: new Date("2026-07-23T00:00:00Z") },
      now,
    ),
    false,
  );
});

test("backend rejects acceptance of an expired pending offer", async () => {
  const providerUserId = "provider-user";
  const weddingPlanId = "44444444-4444-4444-8444-444444444444";
  const offer = {
    id: "33333333-3333-4333-8333-333333333333",
    quoteRequestId: quoteId,
    providerId,
    title: null,
    message: null,
    amount: new Prisma.Decimal("100"),
    currency: "YER",
    status: "PENDING",
    validUntil: new Date("2020-01-01T00:00:00Z"),
    provider: {
      businessName: "Provider",
      userId: providerUserId,
    },
    quoteRequest: {
      id: quoteId,
      userId: requester.id,
      weddingPlanId,
      conversationId: "conversation-1",
      status: "RESPONDED",
      weddingPlan: {
        id: weddingPlanId,
        ownerUserId: requester.id,
        currency: "YER",
      },
      service: null,
    },
    weddingCosts: [],
    providerLinks: [],
  };
  const tx = {
    $queryRaw: async (query: unknown) => {
      if (rawSqlText(query).includes('FROM "User"')) {
        return [
          { id: requester.id, status: "ACTIVE" },
          { id: providerUserId, status: "ACTIVE" },
        ];
      }
      return [{ id: offer.id, quoteRequestId: quoteId }];
    },
    quoteOffer: { findUnique: async () => offer },
  };
  const service = new MarketplaceService(
    {
      quoteOffer: { findUnique: async () => offer },
      $transaction: async (operation: (client: any) => Promise<unknown>) =>
        operation(tx),
    } as any,
    {
      assertPlanReadable: async () => ({}),
      assertProviderManageable: async () => ({}),
      assertMoneyManageable: async () => ({}),
      assertProviderAndMoneyManageableInTransaction: async () => ({}),
    } as any,
    {} as any,
  );
  await assert.rejects(
    service.acceptQuoteOffer(requester, offer.id),
    (error: unknown) => {
      assert.ok(error instanceof ConflictException);
      assert.equal((error.getResponse() as any).code, "QUOTE_OFFER_EXPIRED");
      return true;
    },
  );
});

test("concurrent provider submissions create exactly one offer", async () => {
  let quoteStatus: QuoteRequestStatus = QuoteRequestStatus.SENT;
  let offerCreates = 0;
  let tail = Promise.resolve();
  const quote = () => ({
    id: quoteId,
    userId: requester.id,
    weddingPlanId: null,
    providerId,
    conversationId: "conversation-1",
    status: quoteStatus,
  });
  const provider = {
    id: providerId,
    userId: "provider-user",
    businessName: "Provider",
    status: "ACTIVE",
  };
  const tx = {
    $queryRaw: async (query: unknown) => {
      const sql = rawSqlText(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: requester.id, status: "ACTIVE" },
          { id: provider.userId, status: "ACTIVE" },
        ].sort((left, right) => left.id.localeCompare(right.id));
      }
      if (sql.includes('FROM "Provider"')) return [{ id: providerId }];
      if (sql.includes('FROM "Conversation"')) {
        return [{ id: quote().conversationId }];
      }
      if (sql.includes('FROM "QuoteRequest"')) return [{ id: quoteId }];
      return [];
    },
    provider: {
      findUnique: async () => provider,
    },
    quoteRequest: {
      findUnique: async () => quote(),
      findFirst: async () => quote(),
      update: async () => {
        quoteStatus = QuoteRequestStatus.RESPONDED;
        return quote();
      },
    },
    quoteOffer: {
      findFirst: async () =>
        offerCreates === 0 ? null : { id: "offer-created" },
      create: async ({ data }: any) => {
        await new Promise((resolve) => setTimeout(resolve, 10));
        offerCreates += 1;
        return {
          id: "offer-created",
          ...data,
          status: "PENDING",
          createdAt: now,
          updatedAt: now,
        };
      },
      findMany: async () => [],
    },
    conversationEvent: {
      createMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async ({ where }: any) => ({
        id: "event-1",
        dedupeKey: where.dedupeKey,
      }),
    },
    conversation: { update: async () => ({ id: "conversation-1" }) },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
  const prisma = {
    provider: { findUnique: async () => provider },
    $transaction: async (fn: any) => {
      let release!: () => void;
      const previous = tail;
      tail = new Promise<void>((resolve) => {
        release = resolve;
      });
      await previous;
      try {
        return await fn(tx);
      } finally {
        release();
      }
    },
  };
  const notifications = {
    createNotificationInTransaction: async (_tx: any, input: any) => input,
  };
  const service = new ProviderDashboardService(
    prisma as any,
    notifications as any,
    {} as any,
  );

  const results = await Promise.allSettled([
    service.createQuoteOffer({ id: "provider-user" } as any, quoteId, {
      message: "offer",
      amount: "100",
      currency: "YER",
    } as any),
    service.createQuoteOffer({ id: "provider-user" } as any, quoteId, {
      message: "offer",
      amount: "100",
      currency: "YER",
    } as any),
  ]);

  assert.equal(
    results.filter((result) => result.status === "fulfilled").length,
    1,
  );
  assert.equal(
    results.filter((result) => result.status === "rejected").length,
    1,
  );
  assert.equal(offerCreates, 1);
});
