import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { GuestsService } from "../src/guests/guests.service";
import { MarketplaceService } from "../src/marketplace/marketplace.service";

const user = (id: string) =>
  ({ id, name: "Tester", phone: "+967700000000" }) as any;

const readerContext = { isOwner: false, sharedMember: {} };

// --- Guests: phone is PII, gated behind canManageGuests -------------------

const guestRow = () => ({
  id: "g1",
  weddingPlanId: "p1",
  groupId: null,
  name: "ضيف",
  phone: "+967711111111",
  side: "OTHER",
  status: "INVITED",
  invitationStatus: "NOT_SENT",
  attendanceStatus: "PENDING",
  seatsCount: 1,
  companionsCount: 0,
  notes: "private guest note",
  createdAt: new Date(),
  updatedAt: new Date(),
});

test("guest phone is hidden from a read-only member, shown to a guest manager", async () => {
  const prisma = { guest: { findMany: async () => [guestRow()] } };

  const viewer = new GuestsService(
    prisma as any,
    { assertPlanReadable: async () => readerContext, canManageGuests: () => false } as any,
  );
  const [redacted] = await viewer.findForPlan(user("u2"), "p1");
  assert.equal(redacted.phone, null, "viewer must not see the phone");
  assert.equal(redacted.notes, null, "viewer must not see private guest notes");
  assert.equal(redacted.name, "ضيف", "non-PII stays visible");

  const manager = new GuestsService(
    prisma as any,
    { assertPlanReadable: async () => readerContext, canManageGuests: () => true } as any,
  );
  const [full] = await manager.findForPlan(user("u2"), "p1");
  assert.equal(full.phone, "+967711111111");
  assert.equal(full.notes, "private guest note");
});

test("guest-group notes are hidden from a read-only member", async () => {
  const group = {
    id: "group-1",
    weddingPlanId: "p1",
    name: "Family",
    notes: "private family note",
    sortOrder: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  const prisma = { guestGroup: { findMany: async () => [group] } };

  const viewer = new GuestsService(
    prisma as any,
    {
      assertPlanReadable: async () => readerContext,
      canManageGuests: () => false,
    } as any,
  );
  const [redacted] = await viewer.findGroups(user("u2"), "p1");
  assert.equal(redacted.notes, null);

  const manager = new GuestsService(
    prisma as any,
    {
      assertPlanReadable: async () => readerContext,
      canManageGuests: () => true,
    } as any,
  );
  const [full] = await manager.findGroups(user("u2"), "p1");
  assert.equal(full.notes, "private family note");
});

// --- Quotes: contact phone + budget gated per permission ------------------

const provider = () => ({
  id: "prov1",
  businessName: "قاعة",
  phone: "+967722222222",
  whatsapp: null,
  logoUrl: null,
  status: "ACTIVE",
  ratingAverage: new Prisma.Decimal("4.5"),
  ratingCount: 10,
  city: {
    id: "c1",
    nameAr: "صنعاء",
    nameEn: "Sanaa",
    countryCode: "YE",
    isActive: true,
    sortOrder: 1,
  },
  primaryCategory: null,
});

const quoteOffer = () => ({
  id: "offer1",
  quoteRequestId: "q1",
  providerId: "prov1",
  title: "Offer",
  message: "Detailed pricing",
  amount: new Prisma.Decimal("250000"),
  currency: "YER",
  validUntil: null,
  status: "ACCEPTED",
  createdAt: new Date(),
  updatedAt: new Date(),
  weddingCosts: [],
});

const quoteRow = (
  userId: string,
  options: { status?: string; offers?: ReturnType<typeof quoteOffer>[] } = {},
) => ({
  id: "q1",
  userId,
  weddingPlanId: "p1",
  weddingPlan: null,
  providerId: "prov1",
  provider: provider(),
  serviceId: null,
  service: null,
  eventDate: null,
  location: null,
  cityId: null,
  city: null,
  guestCount: 100,
  contactName: "العريس",
  contactPhone: "+967733333333",
  contactNormalizedPhone: "967733333333",
  message: "msg",
  budgetMin: new Prisma.Decimal("1000"),
  budgetMax: new Prisma.Decimal("5000"),
  status: options.status ?? "SENT",
  offers: options.offers ?? [],
  providerLinks: [],
  acceptedAt: null,
  rejectedAt: null,
  cancelledAt: null,
  createdAt: new Date(),
  updatedAt: new Date(),
});

const marketplace = (
  quote: ReturnType<typeof quoteRow>,
  perms: Record<string, unknown>,
) =>
  new MarketplaceService(
    { quoteRequest: { findMany: async () => [quote] } } as any,
    { assertPlanReadable: async () => readerContext, ...perms } as any,
    {} as any,
  );

test("quote budget and contact phone are hidden from a read-only member", async () => {
  const svc = marketplace(quoteRow("owner"), {
    canViewMoney: () => false,
    canManageProviders: () => false,
  });
  const [q] = await svc.findPlanQuoteRequests(user("viewer"), "p1");
  assert.equal(q.contactPhone, null);
  assert.equal(q.contactNormalizedPhone, null);
  assert.equal(q.budgetMin, null);
  assert.equal(q.budgetMax, null);
  assert.equal(q.guestCount, 100, "non-sensitive fields stay visible");
});

test("quote offer amounts and financial suggestion are hidden from a read-only member", async () => {
  const svc = marketplace(
    quoteRow("owner", { status: "ACCEPTED", offers: [quoteOffer()] }),
    {
      canViewMoney: () => false,
      canManageProviders: () => false,
    },
  );
  const [q] = await svc.findPlanQuoteRequests(user("viewer"), "p1");
  assert.equal(q.offers.length, 1, "offer context can remain visible");
  assert.equal(q.offers[0].amount, null);
  assert.equal(q.offers[0].currency, null);
  assert.equal(q.costSuggestion.quotedAmount, null);
  assert.equal(q.costSuggestion.currency, null);
  assert.equal(q.costSuggestion.suggestedAction, "NONE");
  assert.deepEqual(q.costSuggestion.availableActions, []);
  assert.equal(q.costSuggestion.automaticCostCreated, false);
});

test("quote budget and contact phone are visible to a provider+budget manager", async () => {
  const svc = marketplace(quoteRow("owner"), {
    canViewMoney: () => true,
    canManageProviders: () => true,
  });
  const [q] = await svc.findPlanQuoteRequests(user("mgr"), "p1");
  assert.equal(q.contactPhone, "+967733333333");
  assert.equal(q.budgetMin, "1000");
  assert.equal(q.budgetMax, "5000");
});

test("quote offer amounts and financial suggestion are visible to a budget manager", async () => {
  const svc = marketplace(
    quoteRow("owner", { status: "ACCEPTED", offers: [quoteOffer()] }),
    {
      canViewMoney: () => true,
      canManageProviders: () => true,
    },
  );
  const [q] = await svc.findPlanQuoteRequests(user("mgr"), "p1");
  assert.equal(q.offers[0].amount, "250000");
  assert.equal(q.offers[0].currency, "YER");
  assert.equal(q.costSuggestion.quotedAmount, "250000");
  assert.equal(q.costSuggestion.currency, "YER");
  assert.equal(q.costSuggestion.suggestedAction, "CREATE_COST");
  assert.deepEqual(q.costSuggestion.availableActions, ["CREATE_COST"]);
  assert.equal(q.costSuggestion.automaticCostCreated, false);
});

test("the member who submitted the request always sees their own contact and budget", async () => {
  const svc = marketplace(quoteRow("self"), {
    canViewMoney: () => false,
    canManageProviders: () => false,
  });
  const [q] = await svc.findPlanQuoteRequests(user("self"), "p1");
  assert.equal(q.contactPhone, "+967733333333");
  assert.equal(q.budgetMin, "1000");
});
