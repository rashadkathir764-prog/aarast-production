import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { MarketplaceService } from "../src/marketplace/marketplace.service";
import { ProviderDashboardService } from "../src/provider-dashboard/provider-dashboard.service";

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

function capture() {
  const sent: any[] = [];
  const notifications = {
    createNotification: async (input: any) => {
      sent.push(input);
      return input;
    },
  };
  return { sent, notifications };
}

test("a new quote request notifies the provider account too", async () => {
  const { sent, notifications } = capture();
  const prisma = {
    provider: { findFirst: async () => providerRow(PROVIDER_USER_ID) },
    quoteRequest: { create: async () => quoteRow(PROVIDER_USER_ID) },
  };
  const service = new MarketplaceService(
    prisma as any,
    {} as any,
    notifications as any,
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
    quoteRequest: { create: async () => quoteRow(null) },
  };
  const service = new MarketplaceService(
    prisma as any,
    {} as any,
    notifications as any,
  );

  await service.createQuoteRequest(requester, PROVIDER_ID, {} as any);

  assert.equal(sent.length, 1);
  assert.equal(sent[0].userId, requester.id);
});

test("accepting an offer notifies the provider account", async () => {
  const { sent, notifications } = capture();
  const offerRow = {
    id: OFFER_ID,
    quoteRequestId: QUOTE_ID,
    providerId: PROVIDER_ID,
    title: null,
    message: null,
    amount: null,
    currency: null,
    validUntil: null,
    status: "PENDING",
    createdAt: new Date(),
    updatedAt: new Date(),
    quoteRequest: {
      id: QUOTE_ID,
      userId: requester.id,
      weddingPlanId: PLAN_ID,
      status: "RESPONDED",
    },
  };
  const link = {
    id: "66666666-6666-4666-8666-666666666666",
    weddingPlanId: PLAN_ID,
    providerId: PROVIDER_ID,
    quoteRequestId: QUOTE_ID,
    quoteOfferId: OFFER_ID,
    status: "ACTIVE",
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  const tx = {
    quoteOffer: {
      update: async () => ({ ...offerRow, status: "ACCEPTED" }),
      updateMany: async () => ({ count: 0 }),
    },
    quoteRequest: { update: async () => ({}) },
    planProviderLink: { upsert: async () => link },
  };
  const prisma = {
    quoteOffer: { findUnique: async () => offerRow },
    provider: { findUnique: async () => ({ userId: PROVIDER_USER_ID }) },
    $transaction: async (fn: any) => fn(tx),
  };
  const permissions = {
    assertPlanReadable: async () => ({}),
    assertProviderManageable: async () => ({}),
  };
  const service = new MarketplaceService(
    prisma as any,
    permissions as any,
    notifications as any,
  );

  const result = await service.acceptQuoteOffer(requester, OFFER_ID);

  assert.equal(result.automaticCostCreated, false);
  const toRequester = sent.find((n) => n.userId === requester.id);
  const toProvider = sent.find((n) => n.userId === PROVIDER_USER_ID);
  assert.ok(toRequester, "requester still gets the acceptance summary");
  assert.ok(toProvider, "provider must know their offer was accepted");
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

test("rejecting an offer keeps the requester in the marketplace", async () => {
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
    quoteRequest: {
      id: QUOTE_ID,
      userId: requester.id,
      weddingPlanId: PLAN_ID,
      status: "RESPONDED",
    },
  };
  const tx = {
    quoteOffer: {
      update: async () => ({ ...offerRow, status: "REJECTED" }),
    },
    quoteRequest: { update: async () => ({}) },
  };
  const prisma = {
    quoteOffer: { findUnique: async () => offerRow },
    $transaction: async (fn: any) => fn(tx),
  };
  const permissions = {
    assertPlanReadable: async () => ({}),
    assertProviderManageable: async () => ({}),
  };
  const service = new MarketplaceService(
    prisma as any,
    permissions as any,
    notifications as any,
  );

  await service.rejectQuoteOffer(requester, OFFER_ID);

  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, "QUOTE_REJECTED");
  assert.equal(sent[0].routeTarget, `/providers?quoteId=${QUOTE_ID}`);
});

test("a received provider offer opens its exact marketplace quote", async () => {
  const { sent, notifications } = capture();
  const provider = providerRow(PROVIDER_USER_ID);
  const quote = {
    id: QUOTE_ID,
    userId: requester.id,
    providerId: PROVIDER_ID,
    weddingPlanId: PLAN_ID,
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
    quoteOffer: { create: async () => createdOffer },
    quoteRequest: { update: async () => ({}) },
  };
  const prisma = {
    provider: { findUnique: async () => provider },
    quoteRequest: { findFirst: async () => quote },
    $transaction: async (fn: any) => fn(tx),
  };
  const service = new ProviderDashboardService(
    prisma as any,
    notifications as any,
    {} as any,
  );

  await service.createQuoteOffer(
    { id: PROVIDER_USER_ID } as any,
    QUOTE_ID,
    { message: "offer" } as any,
  );

  assert.equal(sent.length, 1);
  assert.equal(sent[0].type, "QUOTE_OFFER_RECEIVED");
  assert.equal(sent[0].routeTarget, `/providers?quoteId=${QUOTE_ID}`);
});
