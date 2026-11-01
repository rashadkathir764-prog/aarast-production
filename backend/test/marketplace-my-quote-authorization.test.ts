import type { ConversationLifecyclePort } from "../src/modules/messaging/public/conversation-lifecycle.port";
import { findConversationProviderId, lockConversationForShare, lockConversationForUpdate, recordConversationEvent } from "../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext: async () => { throw new Error("Unexpected ensureConversationContext"); },
  recordConversationEvent,
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
  findConversationProviderId,
};
import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import {
  QuoteRequestStatus,
  SharedMemberRole,
  WeddingPlanStatus,
} from "@prisma/client";
import { marketplaceService, catalogWithoutMoneyLinks } from "./support/owner-ports";
import { FinancePortService } from "../src/modules/finance/infrastructure/finance-port.service";
import { contributorActorReference } from "../src/modules/collaboration/internal/contribution-history.service";

const contributorAId = "11111111-1111-4111-8111-111111111111";
const contributorBId = "22222222-2222-4222-8222-222222222222";
const ownerId = "33333333-3333-4333-8333-333333333333";
const providerUserId = "44444444-4444-4444-8444-444444444444";
const planId = "55555555-5555-4555-8555-555555555555";
const quoteId = "66666666-6666-4666-8666-666666666666";
const providerId = "77777777-7777-4777-8777-777777777777";
const conversationId = "88888888-8888-4888-8888-888888888888";

const currentUser = (id: string) => ({ id }) as any;
const ownedPlanId = "99999999-9999-4999-8999-999999999999";
const otherPlanId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

// The scope used to be a `weddingPlan: { is: ... }` join on planning's and
// collaboration's tables. Ownership and membership are read through their
// ports inside the same transaction and applied to the quote table by plan
// id: the owned plans, and the plans the caller still manages providers for.
const expectedMyQuoteScope = (
  userId: string,
  qualifiedQuoteIds: string[],
  ownedPlanIds: string[],
  providerManagingPlanIds: string[],
) => ({
  userId,
  OR: [
    { weddingPlanId: null },
    { weddingPlanId: { in: ownedPlanIds } },
    {
      id: { in: qualifiedQuoteIds },
      weddingPlanId: { in: providerManagingPlanIds },
    },
  ],
});

const expectedContributionScope = (userId: string) => ({
  contributorTenure: { actorReference: contributorActorReference(userId) },
  entityType: { in: ["QUOTE_REQUEST"] },
  action: { in: ["CREATED", "LEGACY_CAPTURED"] },
  entityId: { not: null },
});

test("my quote list filters plan-linked requests by the caller's current stored provider permission", async () => {
  let capturedWhere: unknown;
  let capturedContributionWhere: unknown;
  let transactionCalls = 0;
  const tx = {
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        capturedContributionWhere = where;
        return [{ entityId: quoteId }];
      },
    },
    weddingPlan: {
      findMany: async () => [{ id: ownedPlanId }],
    },
    sharedMember: {
      findMany: async () => [
        { weddingPlanId: planId, userId: contributorAId, canManageProviders: true },
        { weddingPlanId: otherPlanId, userId: contributorAId, canManageProviders: false },
      ],
    },
    quoteRequest: {
      findMany: async ({ where }: { where: unknown }) => {
        capturedWhere = where;
        return [];
      },
    },
  };
  const service = marketplaceService(
    {
      $transaction: async (operation: (client: typeof tx) => unknown) => {
        transactionCalls += 1;
        return operation(tx);
      },
    } as any,
    {} as any,
    {} as any, lifecycle, new FinancePortService(catalogWithoutMoneyLinks),
  );

  await service.findMyQuoteRequests(currentUser(contributorAId));

  assert.equal(transactionCalls, 1);
  assert.deepEqual(capturedContributionWhere, expectedContributionScope(contributorAId));
  assert.deepEqual(
    capturedWhere,
    expectedMyQuoteScope(contributorAId, [quoteId], [ownedPlanId], [planId]),
  );
});

test("my quote detail keeps contributor A and B isolated and checks current plan permission in SQL", async () => {
  let capturedWhere: unknown;
  let transactionCalls = 0;
  let capturedContributionWhere: unknown;
  const tx = {
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        capturedContributionWhere = where;
        return [];
      },
    },
    weddingPlan: { findMany: async () => [] },
    sharedMember: { findMany: async () => [] },
    quoteRequest: {
      findFirst: async ({ where }: { where: unknown }) => {
        capturedWhere = where;
        return null;
      },
    },
  };
  const service = marketplaceService(
    {
      $transaction: async (operation: (client: typeof tx) => unknown) => {
        transactionCalls += 1;
        return operation(tx);
      },
    } as any,
    {} as any,
    {} as any, lifecycle, new FinancePortService(catalogWithoutMoneyLinks),
  );

  await assert.rejects(
    () => service.findMyQuoteRequest(currentUser(contributorBId), quoteId),
    NotFoundException,
  );

  assert.equal(transactionCalls, 1);
  assert.deepEqual(capturedContributionWhere, {
    ...expectedContributionScope(contributorBId),
    entityId: quoteId,
  });
  assert.deepEqual(capturedWhere, {
    id: quoteId,
    ...expectedMyQuoteScope(contributorBId, [], [], []),
  });
  assert.notEqual((capturedWhere as any).userId, contributorAId);
});

type PlanAccess = "ACTIVE_CONTRIBUTOR" | "REVOKED" | "LEFT" | "OWNER";

function cancellationHarness(options: {
  actorUserId: string;
  quoteUserId?: string;
  weddingPlanId: string | null;
  planAccess?: PlanAccess;
  hasQualifyingContribution?: boolean;
}) {
  const quoteUserId = options.quoteUserId ?? options.actorUserId;
  let quoteStatus: QuoteRequestStatus = QuoteRequestStatus.SENT;
  let quoteWrites = 0;
  let planAuthorizationChecks = 0;
  let capturedContributionWhere: any;
  const provider = {
    id: providerId,
    userId: providerUserId,
    businessName: "Provider",
    phone: null,
    whatsapp: null,
    logoUrl: null,
    status: "ACTIVE",
    ratingAverage: 0,
    ratingCount: 0,
    cityId: "99999999-9999-4999-8999-999999999999",
    city: {
      id: "99999999-9999-4999-8999-999999999999",
      nameAr: "صنعاء",
      nameEn: "Sanaa",
      countryCode: "YE",
      isActive: true,
      sortOrder: 1,
    },
    primaryCategoryId: null,
    primaryCategory: null,
  };
  const plan = options.weddingPlanId
    ? {
        id: planId,
        ownerUserId: ownerId,
        title: "الخطة",
        city: null,
        weddingDate: null,
        status: WeddingPlanStatus.PLANNING,
      }
    : null;
  const quote = () => ({
    id: quoteId,
    userId: quoteUserId,
    weddingPlanId: options.weddingPlanId,
    providerId,
    serviceId: null,
    eventDate: null,
    location: null,
    cityId: null,
    guestCount: null,
    contactName: null,
    contactPhone: null,
    contactNormalizedPhone: null,
    message: null,
    budgetMin: null,
    budgetMax: null,
    status: quoteStatus,
    acceptedAt: null,
    rejectedAt: null,
    cancelledAt:
      quoteStatus === QuoteRequestStatus.CANCELLED ? new Date() : null,
    createdAt: new Date("2026-08-02T10:00:00.000Z"),
    updatedAt: new Date("2026-08-02T10:00:00.000Z"),
    conversationId,
    provider,
    service: null,
    city: null,
    weddingPlan: plan,
    offers: [],
    providerLinks: [],
  });
  const tx = {
    $queryRaw: async (query: unknown) => {
      const sql =
        (query as any)?.strings?.join("") ?? String(query ?? "");
      if (sql.includes('FROM "User"')) {
        return [
          options.actorUserId,
          quoteUserId,
          ownerId,
          providerUserId,
        ]
          .filter((value, index, values) => values.indexOf(value) === index)
          .sort()
          .map((id) => ({ id, status: "ACTIVE" }));
      }
      if (sql.includes('FROM "WeddingPlan"')) return [{ id: planId }];
      if (sql.includes('FROM "Provider"')) return [{ id: providerId }];
      if (sql.includes('FROM "Conversation"')) {
        return [{ id: conversationId }];
      }
      if (sql.includes('FROM "QuoteRequest"')) return [{ id: quoteId }];
      return [];
    },
    weddingPlan: {
      findUnique: async () => plan,
    },
    sharedMember: {
      findUnique: async () => null,
    },
    contributionEvent: {
      findMany: async ({ where }: { where: unknown }) => {
        capturedContributionWhere = where;
        return options.hasQualifyingContribution === false
          ? []
          : [{ entityId: quoteId }];
      },
    },
    provider: {
      findUnique: async () => provider,
    },
    quoteRequest: {
      findFirst: async () => ({
        userId: quoteUserId,
        weddingPlanId: options.weddingPlanId,
        providerId,
        conversationId,
        weddingPlan: plan ? { ownerUserId: ownerId } : null,
        provider: { userId: providerUserId },
      }),
      findUnique: async () => quote(),
      updateMany: async () => {
        quoteWrites += 1;
        quoteStatus = QuoteRequestStatus.CANCELLED;
        return { count: 1 };
      },
      findUniqueOrThrow: async () => quote(),
    },
    conversationEvent: {
      createMany: async () => ({ count: 1 }),
      findUniqueOrThrow: async () => ({ id: "event-1" }),
    },
    conversation: { update: async () => ({ id: conversationId }) },
    outboxEvent: { create: async () => ({ id: "outbox-1" }) },
  };
  const prisma = {
    $transaction: async (operation: (client: typeof tx) => unknown) =>
      operation(tx),
  };
  const permissions = {
    assertPlanReadableInTransaction: async () => {
      planAuthorizationChecks += 1;
      if (options.planAccess === "LEFT") {
        throw new NotFoundException("Wedding plan not found");
      }
      const isOwner = options.planAccess === "OWNER";
      return {
        plan,
        isOwner,
        sharedMember: isOwner
          ? null
          : {
              id: "member-1",
              weddingPlanId: planId,
              userId: options.actorUserId,
              role: SharedMemberRole.CONTRIBUTOR,
              authorityVersion: 1,
              canManageProviders:
                options.planAccess === "ACTIVE_CONTRIBUTOR",
            },
      };
    },
    canManageProviders: (context: any) =>
      context.isOwner || Boolean(context.sharedMember?.canManageProviders),
    canViewMoney: () => true,
  };
  const service = marketplaceService(
    prisma as any,
    permissions as any,
    {} as any, lifecycle, new FinancePortService(catalogWithoutMoneyLinks),
  );

  return {
    service,
    quoteWrites: () => quoteWrites,
    planAuthorizationChecks: () => planAuthorizationChecks,
    contributionWhere: () => capturedContributionWhere,
  };
}

test("my quote cancellation rejects a revoked contributor inside the transaction without writing", async () => {
  const harness = cancellationHarness({
    actorUserId: contributorAId,
    weddingPlanId: planId,
    planAccess: "REVOKED",
  });

  await assert.rejects(
    () =>
      harness.service.cancelMyQuoteRequest(
        currentUser(contributorAId),
        quoteId,
      ),
    ForbiddenException,
  );
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 0);
});

test("my quote cancellation rejects a contributor who left the plan without writing", async () => {
  const harness = cancellationHarness({
    actorUserId: contributorAId,
    weddingPlanId: planId,
    planAccess: "LEFT",
  });

  await assert.rejects(
    () =>
      harness.service.cancelMyQuoteRequest(
        currentUser(contributorAId),
        quoteId,
      ),
    NotFoundException,
  );
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 0);
});

test("my quote cancellation keeps a non-plan personal request available without a plan authorization lookup", async () => {
  const harness = cancellationHarness({
    actorUserId: contributorAId,
    weddingPlanId: null,
  });

  const result = await harness.service.cancelMyQuoteRequest(
    currentUser(contributorAId),
    quoteId,
  );

  assert.equal(result.status, QuoteRequestStatus.CANCELLED);
  assert.equal(harness.planAuthorizationChecks(), 0);
  assert.equal(harness.quoteWrites(), 1);
});

test("my quote cancellation keeps an authorized contributor's own plan request available", async () => {
  const harness = cancellationHarness({
    actorUserId: contributorAId,
    weddingPlanId: planId,
    planAccess: "ACTIVE_CONTRIBUTOR",
  });

  const result = await harness.service.cancelMyQuoteRequest(
    currentUser(contributorAId),
    quoteId,
  );

  assert.equal(result.status, QuoteRequestStatus.CANCELLED);
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 1);
});

test("my quote cancellation restores the contributor's qualified previous-tenure request after reinvitation", async () => {
  const harness = cancellationHarness({
    actorUserId: contributorAId,
    weddingPlanId: planId,
    planAccess: "ACTIVE_CONTRIBUTOR",
  });

  const result = await harness.service.cancelMyQuoteRequest(
    currentUser(contributorAId),
    quoteId,
  );

  assert.equal(result.status, QuoteRequestStatus.CANCELLED);
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 1);
  // The tenure is matched by the actor's reference (collaboration's scope)
  // and never by an end date, so a previous tenure's contribution qualifies.
  assert.deepEqual(harness.contributionWhere().contributorTenure, {
    actorReference: contributorActorReference(contributorAId),
  });
  assert.equal(
    Object.prototype.hasOwnProperty.call(
      harness.contributionWhere().contributorTenure,
      "endedAt",
    ),
    false,
  );
});

test("my quote cancellation rejects a plan quote with no contribution evidence", async () => {
  const harness = cancellationHarness({
    actorUserId: contributorAId,
    weddingPlanId: planId,
    planAccess: "ACTIVE_CONTRIBUTOR",
    hasQualifyingContribution: false,
  });

  await assert.rejects(
    () =>
      harness.service.cancelMyQuoteRequest(
        currentUser(contributorAId),
        quoteId,
      ),
    NotFoundException,
  );
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 0);
});

test("my quote cancellation keeps a plan owner's own request available with transactional authorization", async () => {
  const harness = cancellationHarness({
    actorUserId: ownerId,
    weddingPlanId: planId,
    planAccess: "OWNER",
  });

  const result = await harness.service.cancelMyQuoteRequest(
    currentUser(ownerId),
    quoteId,
  );

  assert.equal(result.status, QuoteRequestStatus.CANCELLED);
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 1);
});

test("plan-or-requester cancellation transaction prevents contributor B from cancelling contributor A's quote", async () => {
  const harness = cancellationHarness({
    actorUserId: contributorBId,
    quoteUserId: contributorAId,
    weddingPlanId: planId,
    planAccess: "ACTIVE_CONTRIBUTOR",
  });

  await assert.rejects(
    () =>
      harness.service.cancelQuoteRequestForCurrentUser(
        currentUser(contributorBId),
        quoteId,
      ),
    NotFoundException,
  );
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 0);
});

test("plan-or-requester cancellation keeps the plan owner authorized for a contributor quote", async () => {
  const harness = cancellationHarness({
    actorUserId: ownerId,
    quoteUserId: contributorAId,
    weddingPlanId: planId,
    planAccess: "OWNER",
  });

  const result = await harness.service.cancelQuoteRequestForCurrentUser(
    currentUser(ownerId),
    quoteId,
  );

  assert.equal(result.status, QuoteRequestStatus.CANCELLED);
  assert.equal(harness.planAuthorizationChecks(), 1);
  assert.equal(harness.quoteWrites(), 1);
});
