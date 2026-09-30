import type { ConversationLifecyclePort } from "../src/modules/messaging/public/conversation-lifecycle.port";
import { ensureConversationContext, findConversationProviderId, lockConversationForShare, lockConversationForUpdate, recordConversationEvent } from "../src/conversations/conversation-lifecycle";
import { marketplaceRelations, marketplaceService, ownerPorts, providerDashboardService, withOwnerTables } from "./support/owner-ports";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: (tx, input) => ensureConversationContext(tx, input, { plans: ownerPorts.plans, providers: ownerPorts.providers }),
  recordConversationEvent,
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
  findConversationProviderId,
};
import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { FinancePortService } from "../src/modules/finance/infrastructure/finance-port.service";
import { acceptQuoteOfferInTransaction } from "../src/marketplace/quote-offer-acceptance";

// عقد المرحلة الأولى: المورد طرف في الصفقة ويجب أن يُنبَّه عند وصول طلب جديد
// وعند قبول عرضه — لا طلبات صامتة ولا قبول لا يعلم به المورد.

const PROVIDER_ID = "11111111-1111-4111-8111-111111111111";
const OFFER_ID = "22222222-2222-4222-8222-222222222222";
const QUOTE_ID = "33333333-3333-4333-8333-333333333333";
const PLAN_ID = "44444444-4444-4444-8444-444444444444";
const PROVIDER_USER_ID = "provider-user-1";

const requester = {
  id: "user-1",
  name: "رشاد",
  phone: "+967711111111",
} as any;

const city = {
  id: "55555555-5555-4555-8555-555555555555",
  nameAr: "صنعاء",
  nameEn: "Sanaa",
  countryCode: "YE",
  isActive: true,
  sortOrder: 1,
  createdAt: new Date(),
  updatedAt: new Date(),
};

const providerRow = (userId: string | null) => ({
  id: PROVIDER_ID,
  userId,
  cityId: city.id,
  primaryCategoryId: null,
  businessName: "قاعة الثريا",
  ownerName: null,
  phone: "+967722222222",
  whatsapp: null,
  email: null,
  description: null,
  address: null,
  latitude: null,
  longitude: null,
  logoUrl: null,
  coverUrl: null,
  status: "ACTIVE",
  reviewNote: null,
  reviewedAt: null,
  reviewedById: null,
  isFeatured: false,
  ratingAverage: 0,
  ratingCount: 0,
  createdAt: new Date(),
  updatedAt: new Date(),
  city,
  primaryCategory: null,
});

const quoteRow = (providerUserId: string | null) => ({
  id: QUOTE_ID,
  userId: requester.id,
  providerId: PROVIDER_ID,
  weddingPlanId: null,
  conversationId: "conversation-1",
  serviceId: null,
  eventDate: null,
  location: null,
  cityId: null,
  guestCount: null,
  contactName: "رشاد",
  contactPhone: "+967711111111",
  contactNormalizedPhone: "+967711111111",
  message: null,
  budgetMin: null,
  budgetMax: null,
  status: "SENT",
  respondedAt: null,
  acceptedAt: null,
  cancelledAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
  provider: providerRow(providerUserId),
  service: null,
  city: null,
  weddingPlan: null,
  offers: [],
  providerLinks: [],
});

function rawSqlText(query: unknown): string {
  const strings = (query as { strings?: readonly string[] } | null)?.strings;
  return strings ? strings.join(" ") : String(query);
}

function marketplaceUserLockRows(
  query: unknown,
  providerUserId: string | null = PROVIDER_USER_ID,
) {
  if (!rawSqlText(query).includes('FROM "User"')) return null;
  return [
    { id: requester.id, status: "ACTIVE" },
    ...(providerUserId
      ? [{ id: providerUserId, status: "ACTIVE" }]
      : []),
  ];
}

function capture() {
  const sent: any[] = [];
  const notifications = {
    resolveProviderUpdateRecipientInTransaction: async (
      _tx: any,
      _weddingPlanId: string | null,
      requestedUserId: string,
    ) => requestedUserId,
    createNotification: async (input: any) => {
      sent.push(input);
      return input;
    },
    createNotificationInTransaction: async (_tx: any, input: any) => {
      sent.push(input);
      return input;
    },
  };
  return { sent, notifications };
}

function eventTxFields() {
  return {
    conversationEvent: {
      createMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async ({ where }: any) => ({
        id: `event-${where.dedupeKey}`,
        dedupeKey: where.dedupeKey,
      }),
    },
    conversation: { update: async () => ({ id: "conversation-1" }) },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
}

test("a new quote request notifies the provider account too", async () => {
  const { sent, notifications } = capture();
  const prisma = {
    provider: { findFirst: async () => providerRow(PROVIDER_USER_ID) },
    $transaction: async (fn: any) =>
      fn({
        $queryRaw: async (query: unknown) =>
          marketplaceUserLockRows(query) ?? [{ id: "conversation-1" }],
        provider: {
          findFirst: async () => providerRow(PROVIDER_USER_ID),
          findUnique: async () => providerRow(PROVIDER_USER_ID),
        },
        conversationParticipant: { createMany: async () => ({ count: 2 }) },
        ...eventTxFields(),
        quoteRequest: {
          findFirst: async () => null,
          create: async () => quoteRow(PROVIDER_USER_ID),
        },
      }),
  };
  const service = marketplaceService(
    prisma as any,
    {} as any,
    notifications as any, lifecycle, new FinancePortService(),
  );

  await service.createQuoteRequest(requester, PROVIDER_ID, {} as any);

  assert.equal(sent.length, 2, "requester confirmation + provider alert");
  const toRequester = sent.find((n) => n.userId === requester.id);
  const toProvider = sent.find((n) => n.userId === PROVIDER_USER_ID);
  assert.ok(toRequester, "requester keeps their confirmation");
  assert.ok(toProvider, "provider must be notified of the new request");
  assert.equal(
    toRequester.routeTarget,
    `/providers?quoteId=${QUOTE_ID}`,
    "requester returns to the exact quote in the marketplace, never plan center",
  );
  assert.equal(toProvider.type, "QUOTE_REQUEST_SUBMITTED");
  assert.equal(toProvider.priority, "HIGH");
  assert.equal(toProvider.routeTarget, "/provider/dashboard");
  assert.equal(
    toProvider.body.includes(quoteRow(PROVIDER_USER_ID).contactName),
    false,
    "provider alerts must not persist requester PII outside the protected quote",
  );
  assert.equal(
    toProvider.body.includes(quoteRow(PROVIDER_USER_ID).contactPhone),
    false,
    "provider alerts must not persist requester phone data",
  );
  assert.equal(
    toProvider.weddingPlanId,
    undefined,
    "provider is not a plan member — no plan scoping leaks",
  );
  assert.ok(
    toProvider.dedupeKey.includes(QUOTE_ID),
    "dedupe is per quote request",
  );
});

test("a provider without a linked user account is skipped silently", async () => {
  const { sent, notifications } = capture();
  const prisma = {
    provider: { findFirst: async () => providerRow(null) },
    $transaction: async (fn: any) =>
      fn({
        $queryRaw: async (query: unknown) =>
          marketplaceUserLockRows(query, null) ?? [{ id: "conversation-1" }],
        provider: {
          findFirst: async () => providerRow(null),
          findUnique: async () => providerRow(null),
        },
        conversationParticipant: { createMany: async () => ({ count: 1 }) },
        ...eventTxFields(),
        quoteRequest: {
          findFirst: async () => null,
          create: async () => quoteRow(null),
        },
      }),
  };
  const service = marketplaceService(
    prisma as any,
    {} as any,
    notifications as any, lifecycle, new FinancePortService(),
  );

  await service.createQuoteRequest(requester, PROVIDER_ID, {} as any);

  assert.equal(sent.length, 1);
  assert.equal(sent[0].userId, requester.id);
});

test("provider rejection notifies the requester with the exact quote route", async () => {
  const { sent, notifications } = capture();
  const existing = quoteRow(PROVIDER_USER_ID);
  const updated = {
    ...existing,
    status: "REJECTED",
    rejectedAt: new Date(),
    user: {
      id: requester.id,
      name: requester.name,
      appName: requester.name,
      phone: requester.phone,
      role: "CUSTOMER",
    },
  };
  const tx = {
    ...eventTxFields(),
    $queryRaw: async (query: unknown) => {
      const sql = rawSqlText(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: PROVIDER_USER_ID, status: "ACTIVE" },
          { id: requester.id, status: "ACTIVE" },
        ].sort((left, right) => left.id.localeCompare(right.id));
      }
      if (sql.includes('FROM "Provider"')) return [{ id: PROVIDER_ID }];
      if (sql.includes('FROM "Conversation"')) {
        return [{ id: existing.conversationId }];
      }
      if (sql.includes('FROM "QuoteRequest"')) return [{ id: QUOTE_ID }];
      return [];
    },
    provider: {
      findUnique: async () => providerRow(PROVIDER_USER_ID),
    },
    quoteRequest: {
      findUnique: async () => existing,
      findFirst: async () => existing,
      updateMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async () => updated,
    },
  };
  const prisma = {
    provider: { findUnique: async () => providerRow(PROVIDER_USER_ID) },
    $transaction: async (fn: any) => fn(tx),
  };
  const service = providerDashboardService(
    prisma as any,
    notifications as any,
    {} as any, lifecycle,
  );

  await service.updateQuoteRequestStatus(
    { id: PROVIDER_USER_ID } as any,
    QUOTE_ID,
    { status: "REJECTED" } as any,
  );

  assert.equal(sent.length, 1);
  assert.equal(sent[0].userId, requester.id);
  assert.equal(sent[0].type, "QUOTE_REJECTED");
  assert.equal(sent[0].routeTarget, `/providers?quoteId=${QUOTE_ID}`);
  assert.equal(sent[0].data.providerId, PROVIDER_ID);
  assert.equal(sent[0].data.status, "REJECTED");
});

function acceptanceHarness({
  categories,
  providerCategoryName,
  failNotifications = false,
}: {
  categories: Array<{ id: string; name: string; normalizedName: string }>;
  providerCategoryName: string;
  failNotifications?: boolean;
}) {
  const { sent, notifications } = capture();
  if (failNotifications) {
    notifications.createNotification = async () => {
      throw new Error("notification write failed");
    };
    notifications.createNotificationInTransaction = async () => {
      throw new Error("notification write failed");
    };
  }
  let offerStatus = "PENDING";
  let quoteStatus = "RESPONDED";
  let createdCost: any = null;
  let costCreates = 0;
  let fallbackCreates = 0;
  let linkWrites = 0;
  let providerStatus = "ACTIVE";
  let providerStatusReads = 0;
  let providerPermissionChecks = 0;
  let moneyPermissionChecks = 0;
  const now = new Date("2026-07-20T00:00:00.000Z");
  const offerBase = {
    id: OFFER_ID,
    quoteRequestId: QUOTE_ID,
    providerId: PROVIDER_ID,
    title: null,
    message: null,
    amount: new Prisma.Decimal("250000"),
    currency: "YER",
    validUntil: null,
    createdAt: now,
    updatedAt: now,
  };
  const quoteRequest = () => ({
    id: QUOTE_ID,
    userId: requester.id,
    weddingPlanId: PLAN_ID,
    conversationId: "conversation-1",
    status: quoteStatus,
    weddingPlan: { id: PLAN_ID, currency: "YER" },
    service: {
      title: "خدمة القاعة",
      categoryId: "category-1",
      category: { id: "category-1", nameAr: providerCategoryName },
    },
  });
  const accessibleOffer = () => ({
    ...offerBase,
    status: offerStatus,
    quoteRequest: {
      id: QUOTE_ID,
      userId: requester.id,
      weddingPlanId: PLAN_ID,
      conversationId: "conversation-1",
      status: quoteStatus,
    },
  });
  const richOffer = () => ({
    ...offerBase,
    status: offerStatus,
    quoteRequest: quoteRequest(),
    provider: {
      businessName: "قاعة الثريا",
      userId: PROVIDER_USER_ID,
    },
    weddingCosts: createdCost == null ? [] : [createdCost],
    providerLinks: linkWrites === 0 ? [] : [link],
  });
  const link = {
    id: "66666666-6666-4666-8666-666666666666",
    weddingPlanId: PLAN_ID,
    providerId: PROVIDER_ID,
    quoteRequestId: QUOTE_ID,
    quoteOfferId: OFFER_ID,
    status: "ACTIVE",
    createdAt: now,
    updatedAt: now,
  };
  const tx = {
    $queryRaw: async (query: unknown) =>
      marketplaceUserLockRows(query) ?? [
        { id: OFFER_ID, quoteRequestId: QUOTE_ID },
      ],
    quoteOffer: {
      findUnique: async () => richOffer(),
      findUniqueOrThrow: async () => richOffer(),
      updateMany: async ({ where, data }: any) => {
        if (where.id === OFFER_ID && where.status === "PENDING") {
          offerStatus = data.status;
          return { count: 1 };
        }
        return { count: 0 };
      },
      findMany: async () => [],
    },
    quoteRequest: {
      updateMany: async ({ where, data }: any) => {
        if (where.id === QUOTE_ID && where.status === quoteStatus) {
          quoteStatus = data.status;
          return { count: 1 };
        }
        return { count: 0 };
      },
    },
    provider: {
      findUnique: async () => {
        providerStatusReads += 1;
        return { status: providerStatus };
      },
    },
    budgetCategory: {
      findMany: async () => categories,
      upsert: async ({ create }: any) => {
        fallbackCreates += 1;
        return {
          id: "category-other",
          name: create.name,
          normalizedName: create.normalizedName,
        };
      },
    },
    weddingCost: {
      findFirst: async () => createdCost ?? null,
      create: async ({ data }: any) => {
        costCreates += 1;
        const category =
          categories.find((item) => item.id === data.budgetCategoryId) ??
          ({ id: "category-other", name: "أخرى" } as const);
        createdCost = {
          id: "cost-from-offer",
          ...data,
          agreementDate: null,
          status: "OPEN",
          note: null,
          createdAt: now,
          updatedAt: now,
          budgetCategory: { name: category.name },
          provider: { businessName: "قاعة الثريا" },
          _count: { payments: 0, paymentSchedules: 0 },
        };
        return createdCost;
      },
    },
    planProviderLink: {
      upsert: async () => {
        linkWrites += 1;
        return link;
      },
    },
    ...eventTxFields(),
  };
  const prisma = {
    quoteOffer: { findUnique: async () => accessibleOffer() },
    provider: { findUnique: async () => ({ userId: PROVIDER_USER_ID }) },
    $transaction: async (fn: any) => {
      const before = {
        offerStatus,
        quoteStatus,
        createdCost,
        costCreates,
        fallbackCreates,
        sentLength: sent.length,
      };
      try {
        return await fn(tx);
      } catch (error) {
        offerStatus = before.offerStatus;
        quoteStatus = before.quoteStatus;
        createdCost = before.createdCost;
        costCreates = before.costCreates;
        fallbackCreates = before.fallbackCreates;
        sent.splice(before.sentLength);
        throw error;
      }
    },
  };
  const permissions = {
    assertPlanReadable: async () => ({ isOwner: true, sharedMember: null }),
    canManageProviders: () => true,
    assertProviderManageable: async () => {
      providerPermissionChecks += 1;
      return {};
    },
    assertMoneyManageable: async () => {
      moneyPermissionChecks += 1;
      return {};
    },
    assertProviderAndMoneyManageableInTransaction: async () => {
      providerPermissionChecks += 1;
      moneyPermissionChecks += 1;
      return {};
    },
  };
  const service = marketplaceService(
    prisma as any,
    permissions as any,
    notifications as any, lifecycle, new FinancePortService(),
  );

  return {
    service,
    sent,
    get createdCost() {
      return createdCost;
    },
    get costCreates() {
      return costCreates;
    },
    get fallbackCreates() {
      return fallbackCreates;
    },
    get linkWrites() {
      return linkWrites;
    },
    get providerStatusReads() {
      return providerStatusReads;
    },
    setProviderStatus(status: string) {
      providerStatus = status;
    },
    get providerPermissionChecks() {
      return providerPermissionChecks;
    },
    get moneyPermissionChecks() {
      return moneyPermissionChecks;
    },
    get offerStatus() {
      return offerStatus;
    },
    get quoteStatus() {
      return quoteStatus;
    },
  };
}

const acceptedReplayCost = {
  id: "accepted-cost",
  weddingPlanId: PLAN_ID,
  providerId: PROVIDER_ID,
  quoteOfferId: OFFER_ID,
};

const acceptedReplayLink = {
  id: "accepted-link",
  weddingPlanId: PLAN_ID,
  providerId: PROVIDER_ID,
  quoteRequestId: QUOTE_ID,
  quoteOfferId: OFFER_ID,
  status: "ACTIVE",
};

function acceptedReplayIntegrityHarness({
  weddingCosts,
  providerLinks,
}: {
  weddingCosts: any[];
  providerLinks: any[];
}) {
  let businessWrites = 0;
  let providerStatusReads = 0;
  let lockCalls = 0;
  const writeAttempt = async () => {
    businessWrites += 1;
    throw new Error("accepted replay attempted a business write");
  };
  const currentOffer = {
    id: OFFER_ID,
    quoteRequestId: QUOTE_ID,
    providerId: PROVIDER_ID,
    title: null,
    message: null,
    amount: new Prisma.Decimal("250000"),
    currency: "YER",
    validUntil: null,
    status: "ACCEPTED",
    createdAt: new Date("2026-07-20T00:00:00.000Z"),
    updatedAt: new Date("2026-07-20T00:00:00.000Z"),
    quoteRequest: {
      id: QUOTE_ID,
      userId: requester.id,
      weddingPlanId: PLAN_ID,
      conversationId: "conversation-1",
      status: "ACCEPTED",
      weddingPlan: { id: PLAN_ID, currency: "YER" },
      service: null,
    },
    provider: {
      businessName: "Accepted Provider",
      userId: PROVIDER_USER_ID,
    },
    weddingCosts,
    providerLinks,
  };
  const tx = {
    $queryRaw: async (query: unknown) => {
      const userRows = marketplaceUserLockRows(query);
      if (userRows) return userRows;
      lockCalls += 1;
      return [{ id: OFFER_ID, quoteRequestId: QUOTE_ID }];
    },
    quoteOffer: {
      findUnique: async () => currentOffer,
      findUniqueOrThrow: async () => currentOffer,
      findMany: async () => [],
      updateMany: writeAttempt,
    },
    quoteRequest: { updateMany: writeAttempt },
    provider: {
      findUnique: async () => {
        providerStatusReads += 1;
        return { status: "ACTIVE" };
      },
    },
    budgetCategory: {
      findMany: async () => [],
      upsert: writeAttempt,
    },
    weddingCost: {
      findFirst: async () => weddingCosts[0] ?? null,
      create: writeAttempt,
    },
    planProviderLink: { upsert: writeAttempt },
    conversationEvent: {
      createMany: writeAttempt,
      findUniqueOrThrow: async () => ({ id: "event-1" }),
    },
    conversation: { update: writeAttempt },
    outboxEvent: { create: writeAttempt },
  };
  const execute = () =>
    acceptQuoteOfferInTransaction(
      withOwnerTables({
        $transaction: async (operation: (client: any) => Promise<unknown>) =>
          operation(tx),
      } as any),
      lifecycle, {
        assertProviderAndMoneyManageableInTransaction: async () => ({}),
      } as any,
      {
        createNotificationInTransaction: writeAttempt,
      } as any,
      new FinancePortService(),
      marketplaceRelations(),
      {
        id: OFFER_ID,
        weddingPlanId: PLAN_ID,
        currentUser: requester,
      },
    );

  return {
    execute,
    get businessWrites() {
      return businessWrites;
    },
    get providerStatusReads() {
      return providerStatusReads;
    },
    get lockCalls() {
      return lockCalls;
    },
  };
}

async function expectCorruptAcceptedReplayRejected(
  label: string,
  harness: ReturnType<typeof acceptedReplayIntegrityHarness>,
) {
  await assert.rejects(harness.execute(), (error: unknown) => {
    const responseError = error as {
      getStatus?: () => number;
      message?: string;
    };
    assert.equal(responseError.getStatus?.(), 409, label);
    assert.match(
      responseError.message ?? "",
      /Accepted quote state is incomplete/,
      label,
    );
    return true;
  });
  assert.equal(harness.businessWrites, 0, `${label}: business writes`);
  assert.equal(
    harness.providerStatusReads,
    0,
    `${label}: provider status reads`,
  );
  assert.equal(
    harness.lockCalls,
    4,
    `${label}: provider, conversation, request, and offer row locks`,
  );
}

test("accepting an offer atomically creates one linked cost and is idempotent", async () => {
  const harness = acceptanceHarness({
    categories: [
      {
        id: "category-hall",
        name: "قاعات الأفراح",
        normalizedName: "قاعات الأفراح",
      },
    ],
    providerCategoryName: "الصالات وقاعات المناسبات",
  });

  const result = await harness.service.acceptQuoteOffer(requester, OFFER_ID);
  harness.setProviderStatus("SUSPENDED");
  const replay = await harness.service.acceptQuoteOffer(requester, OFFER_ID);

  assert.equal(result.automaticCostCreated, true);
  assert.equal(result.weddingCost.id, "cost-from-offer");
  assert.equal(replay.weddingCost.id, "cost-from-offer");
  assert.equal(
    harness.costCreates,
    1,
    "network replay must not duplicate cost",
  );
  assert.equal(
    harness.linkWrites,
    1,
    "historical replay must not rewrite the provider link",
  );
  assert.equal(
    harness.providerStatusReads,
    1,
    "historical replay must not become a new provider operation",
  );
  assert.equal(
    harness.fallbackCreates,
    0,
    "logical match uses existing category",
  );
  assert.equal(harness.createdCost.budgetCategoryId, "category-hall");
  assert.equal(harness.createdCost.providerId, PROVIDER_ID);
  assert.equal(harness.createdCost.quoteOfferId, OFFER_ID);
  assert.equal(harness.createdCost.totalAmount.toString(), "250000");
  assert.equal(harness.createdCost.paidAmount.toString(), "0");
  assert.equal(harness.createdCost.title, "خدمة القاعة");
  assert.equal(result.costSuggestion.suggestedAction, "VIEW_COST");
  assert.deepEqual(result.nextActions, ["viewCost", "viewAcceptedProvider"]);
  assert.equal(harness.providerPermissionChecks, 4);
  assert.equal(harness.moneyPermissionChecks, 4);

  const toRequester = harness.sent.find((n) => n.userId === requester.id);
  const toProvider = harness.sent.find((n) => n.userId === PROVIDER_USER_ID);
  assert.ok(toRequester, "requester still gets the acceptance summary");
  assert.ok(toProvider, "provider must know their offer was accepted");
  assert.equal(
    harness.sent.length,
    2,
    "idempotent replay sends no duplicate alerts",
  );
  assert.equal(
    toRequester.routeTarget,
    `/providers?quoteId=${QUOTE_ID}`,
    "accepted-offer notification returns to the exact marketplace quote",
  );
  assert.equal(toProvider.type, "QUOTE_ACCEPTED");
  assert.equal(toProvider.priority, "HIGH");
  assert.equal(toProvider.routeTarget, "/provider/dashboard");
  assert.ok(
    toProvider.dedupeKey.includes(OFFER_ID),
    "dedupe is per accepted offer",
  );
});

test("accepted-offer replay rejects missing or mismatched wedding cost without writes", async () => {
  const cases = [
    { label: "missing cost", weddingCosts: [] },
    {
      label: "cost from another wedding plan",
      weddingCosts: [
        { ...acceptedReplayCost, weddingPlanId: "another-plan-id" },
      ],
    },
    {
      label: "cost from another provider",
      weddingCosts: [
        { ...acceptedReplayCost, providerId: "another-provider-id" },
      ],
    },
  ];

  for (const scenario of cases) {
    await expectCorruptAcceptedReplayRejected(
      scenario.label,
      acceptedReplayIntegrityHarness({
        weddingCosts: scenario.weddingCosts,
        providerLinks: [acceptedReplayLink],
      }),
    );
  }
});

test("accepted-offer replay rejects missing or mismatched provider link without writes", async () => {
  const cases = [
    { label: "missing link", providerLinks: [] },
    {
      label: "link from another wedding plan",
      providerLinks: [
        { ...acceptedReplayLink, weddingPlanId: "another-plan-id" },
      ],
    },
    {
      label: "link from another provider",
      providerLinks: [
        { ...acceptedReplayLink, providerId: "another-provider-id" },
      ],
    },
    {
      label: "link from another quote request",
      providerLinks: [
        { ...acceptedReplayLink, quoteRequestId: "another-quote-id" },
      ],
    },
    {
      label: "link from another quote offer",
      providerLinks: [
        { ...acceptedReplayLink, quoteOfferId: "another-offer-id" },
      ],
    },
  ];

  for (const scenario of cases) {
    await expectCorruptAcceptedReplayRejected(
      scenario.label,
      acceptedReplayIntegrityHarness({
        weddingCosts: [acceptedReplayCost],
        providerLinks: scenario.providerLinks,
      }),
    );
  }
});

test("accepting an unmatched provider service creates and uses the other category", async () => {
  const harness = acceptanceHarness({
    categories: [],
    providerCategoryName: "خدمة خاصة غير مصنفة",
  });

  const result = await harness.service.acceptQuoteOffer(requester, OFFER_ID);

  assert.equal(result.automaticCostCreated, true);
  assert.equal(harness.fallbackCreates, 1);
  assert.equal(harness.createdCost.budgetCategoryId, "category-other");
  assert.equal(result.weddingCost.categoryName, "أخرى");
});

test("an accepted offer rolls back when its durable notification cannot be written", async () => {
  const harness = acceptanceHarness({
    categories: [
      {
        id: "category-hall",
        name: "قاعات الأفراح",
        normalizedName: "قاعات الأفراح",
      },
    ],
    providerCategoryName: "الصالات وقاعات المناسبات",
    failNotifications: true,
  });

  await assert.rejects(
    harness.service.acceptQuoteOffer(requester, OFFER_ID),
    /notification write failed/,
  );
  assert.equal(harness.offerStatus, "PENDING");
  assert.equal(harness.quoteStatus, "RESPONDED");
  assert.equal(harness.createdCost, null);
  assert.equal(harness.costCreates, 0);
});

test("rejecting an offer notifies the provider rather than the requester", async () => {
  const { sent, notifications } = capture();
  const offerRow = {
    id: OFFER_ID,
    quoteRequestId: QUOTE_ID,
    providerId: PROVIDER_ID,
    title: null,
    message: "offer",
    amount: null,
    currency: "YER",
    validUntil: null,
    status: "PENDING",
    createdAt: new Date(),
    updatedAt: new Date(),
    provider: providerRow(PROVIDER_USER_ID),
    quoteRequest: {
      id: QUOTE_ID,
      userId: requester.id,
      weddingPlanId: PLAN_ID,
      conversationId: "conversation-1",
      status: "RESPONDED",
      weddingPlan: { ownerUserId: requester.id },
    },
  };
  const tx = {
    ...eventTxFields(),
    $queryRaw: async (query: unknown) =>
      marketplaceUserLockRows(query) ?? [
        { id: OFFER_ID, quoteRequestId: QUOTE_ID },
      ],
    quoteOffer: {
      findUnique: async () => offerRow,
      updateMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async () => ({
        ...offerRow,
        status: "REJECTED",
      }),
    },
    quoteRequest: { updateMany: async () => ({ count: 1 }) },
    provider: {
      findUnique: async () => providerRow(PROVIDER_USER_ID),
    },
  };
  const prisma = {
    quoteOffer: { findUnique: async () => offerRow },
    $transaction: async (fn: any) => fn(tx),
  };
  const permissions = {
    assertPlanReadable: async () => ({ isOwner: true, sharedMember: null }),
    canManageProviders: () => true,
    assertProviderManageable: async () => ({}),
    assertProviderManageableInTransaction: async () => ({}),
  };
  const service = marketplaceService(
    prisma as any,
    permissions as any,
    notifications as any, lifecycle, new FinancePortService(),
  );

  await service.rejectQuoteOffer(requester, OFFER_ID);

  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, "QUOTE_REJECTED");
  assert.equal(sent[0].userId, PROVIDER_USER_ID);
  assert.notEqual(sent[0].userId, requester.id);
  assert.equal(sent[0].routeTarget, "/provider/dashboard");
});

test("rejecting an offer succeeds when the provider has no linked user", async () => {
  const { sent, notifications } = capture();
  const offerRow = {
    id: OFFER_ID,
    quoteRequestId: QUOTE_ID,
    providerId: PROVIDER_ID,
    status: "PENDING",
    validUntil: null,
    provider: providerRow(null),
    quoteRequest: {
      id: QUOTE_ID,
      userId: requester.id,
      weddingPlanId: PLAN_ID,
      conversationId: "conversation-1",
      status: "RESPONDED",
      weddingPlan: { ownerUserId: requester.id },
    },
  };
  const tx = {
    ...eventTxFields(),
    $queryRaw: async (query: unknown) =>
      marketplaceUserLockRows(query, null) ?? [
        { id: OFFER_ID, quoteRequestId: QUOTE_ID },
      ],
    quoteOffer: {
      findUnique: async () => offerRow,
      updateMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async () => ({
        ...offerRow,
        status: "REJECTED",
      }),
    },
    quoteRequest: { updateMany: async () => ({ count: 1 }) },
    provider: { findUnique: async () => providerRow(null) },
  };
  const service = marketplaceService(
    {
      quoteOffer: { findUnique: async () => offerRow },
      $transaction: async (fn: any) => fn(tx),
    } as any,
    {
      assertPlanReadable: async () => ({ isOwner: true, sharedMember: null }),
      canManageProviders: () => true,
      assertProviderManageable: async () => ({}),
      assertProviderManageableInTransaction: async () => ({}),
    } as any,
    notifications as any, lifecycle, new FinancePortService(),
  );

  const result = await service.rejectQuoteOffer(requester, OFFER_ID);
  assert.equal(result.status, "REJECTED");
  assert.equal(sent.length, 0);
});

test("a received provider offer opens its exact marketplace quote", async () => {
  const { sent, notifications } = capture();
  const provider = providerRow(PROVIDER_USER_ID);
  const quote = {
    id: QUOTE_ID,
    userId: requester.id,
    providerId: PROVIDER_ID,
    weddingPlanId: PLAN_ID,
    conversationId: "conversation-1",
    status: "SENT",
  };
  const createdOffer = {
    id: OFFER_ID,
    quoteRequestId: QUOTE_ID,
    providerId: PROVIDER_ID,
    title: null,
    message: "offer",
    amount: null,
    currency: "YER",
    validUntil: null,
    status: "PENDING",
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  const tx = {
    ...eventTxFields(),
    $queryRaw: async (query: unknown) => {
      const sql = rawSqlText(query);
      if (sql.includes('FROM "User"')) {
        return [
          { id: PROVIDER_USER_ID, status: "ACTIVE" },
          { id: requester.id, status: "ACTIVE" },
        ].sort((left, right) => left.id.localeCompare(right.id));
      }
      if (sql.includes('FROM "WeddingPlan"')) return [{ id: PLAN_ID }];
      if (sql.includes('FROM "Provider"')) return [{ id: PROVIDER_ID }];
      if (sql.includes('FROM "Conversation"')) {
        return [{ id: quote.conversationId }];
      }
      if (sql.includes('FROM "QuoteRequest"')) return [{ id: QUOTE_ID }];
      return [];
    },
    provider: {
      findUnique: async () => provider,
    },
    weddingPlan: {
      findUnique: async () => ({ status: "PLANNING" }),
    },
    quoteOffer: {
      findFirst: async () => null,
      create: async () => createdOffer,
    },
    quoteRequest: {
      findUnique: async () => quote,
      findFirst: async () => quote,
      update: async () => ({}),
    },
  };
  const prisma = {
    provider: { findUnique: async () => provider },
    quoteRequest: { findFirst: async () => quote },
    $transaction: async (fn: any) => fn(tx),
  };
  const service = providerDashboardService(
    prisma as any,
    notifications as any,
    {} as any, lifecycle,
  );

  await service.createQuoteOffer({ id: PROVIDER_USER_ID } as any, QUOTE_ID, {
    message: "offer",
    amount: "1000",
    currency: "YER",
  } as any);

  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, "QUOTE_OFFER_RECEIVED");
  assert.equal(sent[0].routeTarget, `/providers?quoteId=${QUOTE_ID}`);
});
