import type { ConversationLifecyclePort } from "../src/modules/messaging/public/conversation-lifecycle.port";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent: async () => { throw new Error("Unexpected recordConversationEvent"); },
};
import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { Prisma } from "@prisma/client";
import { GuestsService } from "../src/guests/guests.service";
import { MarketplaceService } from "../src/marketplace/marketplace.service";

const user = (id: string) =>
  ({ id, name: "Tester", phone: "+967700000000" }) as any;

const readerContext = {
  plan: { id: "p1" },
  isOwner: false,
  sharedMember: { id: "member-u2", userId: "u2" },
};
const contributionHistory = {
  recordForContextInTransaction: async () => undefined,
};
const contributorScope = {
  qualifyingEntityIds: async () => [],
  qualifyingEntityIdsInTransaction: async () => [],
};

function transactionalPrisma(models: Record<string, unknown>) {
  const prisma: any = { ...models };
  prisma.$transaction = async (
    operation: (tx: any) => Promise<unknown>,
  ) => operation(prisma);
  return prisma;
}

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

test("a read-only member receives no live guests, while a manager receives only their scoped guest", async () => {
  const prisma = transactionalPrisma({
    guest: { findMany: async () => [guestRow()] },
  });

  const viewer = new GuestsService(
    prisma as any,
    {
      assertPlanReadable: async () => readerContext,
      assertPlanReadableInTransaction: async () => readerContext,
      canManageGuests: () => false,
    } as any,
    contributionHistory as any,
    contributorScope as any,
  );
  const hidden = await viewer.findForPlan(user("u2"), "p1");
  assert.deepEqual(hidden, [], "revoked guest access must expose no live row");

  const manager = new GuestsService(
    prisma as any,
    {
      assertPlanReadable: async () => readerContext,
      assertPlanReadableInTransaction: async () => readerContext,
      canManageGuests: () => true,
    } as any,
    contributionHistory as any,
    {
      qualifyingEntityIds: async () => ["g1"],
      qualifyingEntityIdsInTransaction: async (
        _tx: unknown,
        _planId: string,
        _actorId: string,
        entityTypes: string[],
      ) => (entityTypes.includes("GUEST_GROUP") ? [] : ["g1"]),
    } as any,
  );
  const [full] = await manager.findForPlan(user("u2"), "p1");
  assert.equal(full.phone, "+967711111111");
  assert.equal(full.notes, "private guest note");
});

test("a read-only member receives no live guest groups, while a manager receives only their scoped group", async () => {
  const group = {
    id: "group-1",
    weddingPlanId: "p1",
    name: "Family",
    notes: "private family note",
    sortOrder: 1,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  const prisma = transactionalPrisma({
    guestGroup: { findMany: async () => [group] },
  });

  const viewer = new GuestsService(
    prisma as any,
    {
      assertPlanReadable: async () => readerContext,
      assertPlanReadableInTransaction: async () => readerContext,
      canManageGuests: () => false,
    } as any,
    contributionHistory as any,
    contributorScope as any,
  );
  const hidden = await viewer.findGroups(user("u2"), "p1");
  assert.deepEqual(hidden, []);

  const manager = new GuestsService(
    prisma as any,
    {
      assertPlanReadable: async () => readerContext,
      assertPlanReadableInTransaction: async () => readerContext,
      canManageGuests: () => true,
    } as any,
    contributionHistory as any,
    {
      qualifyingEntityIds: async (
        _planId: string,
        _actorId: string,
        entityTypes: string[],
      ) => (entityTypes.includes("GUEST_GROUP") ? ["group-1"] : []),
      qualifyingEntityIdsInTransaction: async (
        _tx: unknown,
        _planId: string,
        _actorId: string,
        entityTypes: string[],
      ) => (entityTypes.includes("GUEST_GROUP") ? ["group-1"] : []),
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

const quoteOffer = (withCost = false) => ({
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
  weddingCosts: withCost ? [{ id: "cost-from-offer" }] : [],
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
    {
      contributionEvent: {
        findMany: async () => [{ entityId: quote.id }],
      },
      quoteRequest: { findMany: async () => [quote] },
    } as any,
    {
      assertPlanReadable: async (
        _planId: string,
        currentUser: { id: string },
      ) => ({
        ...readerContext,
        sharedMember: {
          id: `member-${currentUser.id}`,
          userId: currentUser.id,
        },
      }),
      ...perms,
    } as any,
    {} as any,
    lifecycle, contributionHistory as any,
  );

test("plan quote live data is denied after provider permission revocation", async () => {
  const svc = marketplace(quoteRow("owner"), {
    canViewMoney: () => false,
    canManageProviders: () => false,
  });
  await assert.rejects(
    () => svc.findPlanQuoteRequests(user("viewer"), "p1"),
    (error: any) => error?.getResponse?.().code === "PROVIDER_PERMISSION_REVOKED",
  );
});

test("plan quote offers are denied after provider permission revocation", async () => {
  const svc = marketplace(
    quoteRow("owner", { status: "ACCEPTED", offers: [quoteOffer(true)] }),
    {
      canViewMoney: () => false,
      canManageProviders: () => false,
    },
  );
  await assert.rejects(
    () => svc.findPlanQuoteRequests(user("viewer"), "p1"),
    (error: any) => error?.getResponse?.().code === "PROVIDER_PERMISSION_REVOKED",
  );
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

test("plan owner sees the full plan quote context", async () => {
  const quote = quoteRow("requester");
  const svc = new MarketplaceService(
    { quoteRequest: { findMany: async () => [quote] } } as any,
    {
      assertPlanReadable: async () => ({ isOwner: true, sharedMember: null }),
      canViewMoney: (context: any) => context.isOwner,
      canManageProviders: (context: any) => context.isOwner,
    } as any,
    {} as any, lifecycle,
  );
  const [q] = await svc.findPlanQuoteRequests(user("owner"), "p1");
  assert.equal(q.contactPhone, "+967733333333");
  assert.equal(q.budgetMin, "1000");
  assert.equal(q.guestCount, 100);
});

test("quote offer amounts and financial suggestion are visible to a budget manager", async () => {
  const svc = marketplace(
    quoteRow("owner", { status: "ACCEPTED", offers: [quoteOffer(true)] }),
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
  assert.equal(q.costSuggestion.suggestedAction, "VIEW_COST");
  assert.deepEqual(q.costSuggestion.availableActions, ["VIEW_COST"]);
  assert.equal(q.costSuggestion.costId, "cost-from-offer");
  assert.equal(q.costSuggestion.automaticCostCreated, true);
});

test("the member who submitted a request loses live quote access when provider permission is revoked", async () => {
  const svc = marketplace(quoteRow("self"), {
    canViewMoney: () => false,
    canManageProviders: () => false,
  });
  await assert.rejects(
    () => svc.findPlanQuoteRequests(user("self"), "p1"),
    (error: any) => error?.getResponse?.().code === "PROVIDER_PERMISSION_REVOKED",
  );
});
