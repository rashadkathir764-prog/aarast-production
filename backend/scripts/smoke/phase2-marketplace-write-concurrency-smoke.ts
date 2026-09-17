import type { ConversationLifecyclePort } from "../../src/modules/messaging/public/conversation-lifecycle.port";
import { ensureConversationContext, lockConversationForShare, lockConversationForUpdate, recordConversationEvent } from "../../src/conversations/conversation-lifecycle";

const lifecycle: ConversationLifecyclePort = {
  ensureConversationContext,
  recordConversationEvent,
  lockConversationForUpdateInTransaction: lockConversationForUpdate,
  lockConversationForShareInTransaction: lockConversationForShare,
};
import "reflect-metadata";

import assert from "node:assert/strict";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionProvenance,
  ContributionSection,
  PrismaClient,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
  SharedMemberRole,
  WeddingPlanStatus,
} from "@prisma/client";
import { MarketplaceService } from "../../src/marketplace/marketplace.service";
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts, contributionHistoryService } from "./support/owner-ports";
import { buildContributionSnapshot } from "../../src/modules/collaboration/public/contribution-snapshot.builder";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createPermissionRevocationFixture,
  createQuoteDecisionFixture,
  withFixture,
} = require("../../test/support/phase0-postgres-support.js") as {
  createPermissionRevocationFixture: (
    prisma: unknown,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
  createQuoteDecisionFixture: (
    prisma: unknown,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
  withFixture: (
    createFixture: (environment: NodeJS.ProcessEnv) => Promise<any>,
    callback: (fixture: any) => Promise<void>,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<void>;
};

assertManagedSmokeEnvironment(process.env);

const prisma = new PrismaClient();
const contributionHistory = contributionHistoryService(
  prisma,
  new PermissionService(prisma as any, ownerPorts.plans),
);
const notifications = {
  createNotification: async (input: unknown) => input,
  createNotificationInTransaction: async (
    _tx: unknown,
    input: unknown,
  ) => input,
};

function authenticatedUser(user: {
  id: string;
  name: string;
  phone: string | null;
}) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
  } as any;
}

function marketplaceService(): MarketplaceService {
  return new MarketplaceService(
    prisma as any,
    new PermissionService(prisma as any, ownerPorts.plans),
    notifications as any,
    lifecycle, ownerPorts.finance, contributionHistory,
  );
}

async function recordFixtureContributorQuote(fixture: any): Promise<void> {
  await prisma.$transaction(async (tx) => {
    const quoteRequest = await tx.quoteRequest.update({
      where: { id: fixture.quoteRequest.id },
      data: { userId: fixture.member.id },
    });
    assert.equal(
      quoteRequest.userId,
      fixture.member.id,
      "fixture contributor must own the quote request before history capture",
    );
    await contributionHistory.recordForContextInTransaction(
      tx as any,
      {
        plan: fixture.plan,
        isOwner: false,
        sharedMember: fixture.sharedMember,
      },
      {
        section: ContributionSection.PROVIDERS,
        entityType: ContributionEntityType.QUOTE_REQUEST,
        entityId: quoteRequest.id,
        action: ContributionAction.LEGACY_CAPTURED,
        snapshot: buildContributionSnapshot(
          ContributionEntityType.QUOTE_REQUEST,
          {
            providerDisplayLabel: fixture.provider.businessName,
            requestStatus: quoteRequest.status,
            status: quoteRequest.status,
          },
        ),
        dedupeKey: `smoke:provider:quote-request:${quoteRequest.id}:legacy`,
        provenance: ContributionProvenance.LEGACY_EXPLICIT,
        requiredPermission: ContributionPermission.MANAGE_PROVIDERS,
        occurredAt: quoteRequest.createdAt,
      },
    );
  });
}

function deferred(): {
  promise: Promise<void>;
  resolve: () => void;
  reject: (error: unknown) => void;
} {
  let resolve!: () => void;
  let reject!: (error: unknown) => void;
  const promise = new Promise<void>((done, fail) => {
    resolve = done;
    reject = fail;
  });
  return { promise, resolve, reject };
}

async function holdUncommittedMutation(
  mutate: (tx: any) => Promise<unknown>,
): Promise<{ commit: () => Promise<void> }> {
  const acquired = deferred();
  const commitRequested = deferred();
  let committed = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await mutate(tx);
      acquired.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  void transaction.catch(acquired.reject);
  await acquired.promise;

  return {
    commit: async () => {
      if (!committed) {
        committed = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function waitForBlockedMutation(
  operation: Promise<unknown>,
  label: string,
): Promise<void> {
  const state = await Promise.race([
    operation.then(
      () => "settled",
      () => "settled",
    ),
    new Promise<"blocked">((resolve) =>
      setTimeout(() => resolve("blocked"), 75),
    ),
  ]);
  assert.equal(state, "blocked", `${label} must wait for the locked row`);
}

function exceptionStatus(error: unknown): number | undefined {
  return (error as { getStatus?: () => number })?.getStatus?.();
}

function exceptionCode(error: unknown): unknown {
  const response = (
    error as { getResponse?: () => unknown }
  )?.getResponse?.();
  return typeof response === "object" && response !== null
    ? (response as { code?: unknown }).code
    : undefined;
}

async function settleRejected(
  operation: Promise<unknown>,
  label: string,
): Promise<unknown> {
  const [result] = await Promise.allSettled([operation]);
  assert.equal(result?.status, "rejected", `${label} must fail closed`);
  return result?.status === "rejected" ? result.reason : undefined;
}

async function assertPermissionRevocationBlocksQuoteCreation(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      const service = marketplaceService();
      const actor = authenticatedUser(fixture.member);
      const quoteWhere = {
        userId: fixture.member.id,
        weddingPlanId: fixture.plan.id,
        providerId: fixture.provider.id,
      };
      const quoteCountBefore = await prisma.quoteRequest.count({
        where: quoteWhere,
      });
      const eventCountBefore = await prisma.conversationEvent.count({
        where: { conversationId: fixture.conversation.id },
      });
      const blocker = await holdUncommittedMutation((tx) =>
        tx.sharedMember.update({
          where: { id: fixture.sharedMember.id },
          data: {
            role: SharedMemberRole.VIEWER,
            canManageProviders: false,
          },
        }),
      );
      const operation = service.createPlanQuoteRequest(
        actor,
        fixture.plan.id,
        {
          providerId: fixture.provider.id,
          message: "permission revocation race",
        } as any,
      );

      try {
        await waitForBlockedMutation(operation, "quote creation");
        await blocker.commit();
        const error = await settleRejected(operation, "quote creation");
        assert.equal(exceptionStatus(error), 404);
        assert.equal(
          await prisma.quoteRequest.count({ where: quoteWhere }),
          quoteCountBefore,
        );
        assert.equal(
          await prisma.conversationEvent.count({
            where: { conversationId: fixture.conversation.id },
          }),
          eventCountBefore,
        );
      } finally {
        await blocker.commit();
        await Promise.allSettled([operation]);
      }
    },
  );
}

async function assertArchiveBlocksQuoteCreation(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const service = marketplaceService();
      const actor = authenticatedUser(fixture.owner);
      const quoteCountBefore = await prisma.quoteRequest.count({
        where: {
          userId: fixture.owner.id,
          weddingPlanId: fixture.plan.id,
          providerId: fixture.provider.id,
        },
      });
      const eventCountBefore = await prisma.conversationEvent.count({
        where: { conversationId: fixture.conversation.id },
      });
      const blocker = await holdUncommittedMutation((tx) =>
        tx.weddingPlan.update({
          where: { id: fixture.plan.id },
          data: { status: WeddingPlanStatus.ARCHIVED },
        }),
      );
      const operation = service.createPlanQuoteRequest(
        actor,
        fixture.plan.id,
        {
          providerId: fixture.provider.id,
          message: "archive race",
        } as any,
      );

      try {
        await waitForBlockedMutation(operation, "archived quote creation");
        await blocker.commit();
        const error = await settleRejected(
          operation,
          "archived quote creation",
        );
        assert.equal(exceptionCode(error), "PLAN_ARCHIVED_READ_ONLY");
        assert.equal(
          await prisma.quoteRequest.count({
            where: {
              userId: fixture.owner.id,
              weddingPlanId: fixture.plan.id,
              providerId: fixture.provider.id,
            },
          }),
          quoteCountBefore,
        );
        assert.equal(
          await prisma.conversationEvent.count({
            where: { conversationId: fixture.conversation.id },
          }),
          eventCountBefore,
        );
      } finally {
        await blocker.commit();
        await Promise.allSettled([operation]);
      }
    },
  );
}

async function assertProviderSuspensionBlocksFavorite(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const service = marketplaceService();
      const actor = authenticatedUser(fixture.owner);
      const favoriteWhere = {
        userId: fixture.owner.id,
        providerId: fixture.provider.id,
      };
      const blocker = await holdUncommittedMutation((tx) =>
        tx.provider.update({
          where: { id: fixture.provider.id },
          data: { status: ProviderStatus.SUSPENDED },
        }),
      );
      const operation = service.favoriteProvider(
        actor,
        fixture.provider.id,
      );

      try {
        await waitForBlockedMutation(operation, "favorite");
        await blocker.commit();
        const error = await settleRejected(operation, "favorite");
        assert.equal(exceptionStatus(error), 404);
        assert.equal(
          await prisma.favoriteProvider.count({ where: favoriteWhere }),
          0,
        );
      } finally {
        await blocker.commit();
        await Promise.allSettled([operation]);
      }
    },
  );
}

async function assertArchiveBlocksRequesterCancellation(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      await prisma.quoteRequest.update({
        where: { id: fixture.quoteRequest.id },
        data: { status: QuoteRequestStatus.SENT },
      });
      const service = marketplaceService();
      const blocker = await holdUncommittedMutation((tx) =>
        tx.weddingPlan.update({
          where: { id: fixture.plan.id },
          data: { status: WeddingPlanStatus.ARCHIVED },
        }),
      );
      const operation = service.cancelMyQuoteRequest(
        authenticatedUser(fixture.owner),
        fixture.quoteRequest.id,
      );

      try {
        await waitForBlockedMutation(operation, "requester cancellation");
        await blocker.commit();
        const error = await settleRejected(
          operation,
          "requester cancellation",
        );
        assert.equal(exceptionCode(error), "PLAN_ARCHIVED_READ_ONLY");
        const quote = await prisma.quoteRequest.findUniqueOrThrow({
          where: { id: fixture.quoteRequest.id },
        });
        assert.equal(quote.status, QuoteRequestStatus.SENT);
      } finally {
        await blocker.commit();
        await Promise.allSettled([operation]);
      }
    },
  );
}

async function assertPermissionRevocationBlocksRejection(): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => {
      await recordFixtureContributorQuote(fixture);
      const service = marketplaceService();
      const eventCountBefore = await prisma.conversationEvent.count({
        where: { conversationId: fixture.conversation.id },
      });
      const blocker = await holdUncommittedMutation((tx) =>
        tx.sharedMember.update({
          where: { id: fixture.sharedMember.id },
          data: {
            role: SharedMemberRole.VIEWER,
            canManageProviders: false,
          },
        }),
      );
      const operation = service.rejectQuoteOffer(
        authenticatedUser(fixture.member),
        fixture.offer.id,
      );

      try {
        await waitForBlockedMutation(operation, "offer rejection");
        await blocker.commit();
        const error = await settleRejected(operation, "offer rejection");
        assert.equal(exceptionStatus(error), 404);
        const [offer, quote] = await prisma.$transaction([
          prisma.quoteOffer.findUniqueOrThrow({
            where: { id: fixture.offer.id },
          }),
          prisma.quoteRequest.findUniqueOrThrow({
            where: { id: fixture.quoteRequest.id },
          }),
        ]);
        assert.equal(offer.status, QuoteOfferStatus.PENDING);
        assert.equal(quote.status, QuoteRequestStatus.RESPONDED);
        assert.equal(
          await prisma.conversationEvent.count({
            where: { conversationId: fixture.conversation.id },
          }),
          eventCountBefore,
        );
      } finally {
        await blocker.commit();
        await Promise.allSettled([operation]);
      }
    },
  );
}

async function assertProviderSuspensionBlocksAcceptance(): Promise<void> {
  await withFixture(
    (environment) => createQuoteDecisionFixture(prisma, environment),
    async (fixture) => {
      const service = marketplaceService();
      const eventCountBefore = await prisma.conversationEvent.count({
        where: { conversationId: fixture.conversation.id },
      });
      const blocker = await holdUncommittedMutation((tx) =>
        tx.provider.update({
          where: { id: fixture.provider.id },
          data: { status: ProviderStatus.SUSPENDED },
        }),
      );
      const operation = service.acceptQuoteOffer(
        authenticatedUser(fixture.owner),
        fixture.offer.id,
      );

      try {
        await waitForBlockedMutation(operation, "offer acceptance");
        await blocker.commit();
        const error = await settleRejected(operation, "offer acceptance");
        assert.equal(exceptionCode(error), "PROVIDER_NOT_ACTIVE");
        const [offer, quote, costCount, linkCount] =
          await prisma.$transaction([
            prisma.quoteOffer.findUniqueOrThrow({
              where: { id: fixture.offer.id },
            }),
            prisma.quoteRequest.findUniqueOrThrow({
              where: { id: fixture.quoteRequest.id },
            }),
            prisma.weddingCost.count({
              where: { quoteOfferId: fixture.offer.id },
            }),
            prisma.planProviderLink.count({
              where: { quoteOfferId: fixture.offer.id },
            }),
          ]);
        assert.equal(offer.status, QuoteOfferStatus.PENDING);
        assert.equal(quote.status, QuoteRequestStatus.RESPONDED);
        assert.equal(costCount, 0);
        assert.equal(linkCount, 0);
        assert.equal(
          await prisma.conversationEvent.count({
            where: { conversationId: fixture.conversation.id },
          }),
          eventCountBefore,
        );
      } finally {
        await blocker.commit();
        await Promise.allSettled([operation]);
      }
    },
  );
}

async function main(): Promise<void> {
  try {
    await assertPermissionRevocationBlocksQuoteCreation();
    await assertArchiveBlocksQuoteCreation();
    await assertProviderSuspensionBlocksFavorite();
    await assertArchiveBlocksRequesterCancellation();
    await assertPermissionRevocationBlocksRejection();
    await assertProviderSuspensionBlocksAcceptance();
    console.log(
      "PASS - Marketplace writes wait for lifecycle locks, re-read authoritative state, and leave no partial side effects.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
