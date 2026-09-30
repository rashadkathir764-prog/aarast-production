import * as quoteRepository from "../modules/marketplace/infrastructure/marketplace-quote-mutation.repository";
import {
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  ConversationEventType,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import type { CollaborationHistoryPort as ContributionHistoryService } from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import type { ConversationLifecyclePort } from "../modules/messaging/public/conversation-lifecycle.port";
import { PrismaService } from "../platform/database/prisma.service";
import {
  assertWeddingPlanWritable,
  type CollaborationPermissionPort as PermissionService,
} from "../modules/collaboration/public/collaboration-permission.port";
import type { CollaborationScopePort } from "../modules/collaboration/public/collaboration-scope.port";
import { findContributorProviderQuoteIds } from "./marketplace-contributor-quote-scope";
import type { MarketplaceRelationsService } from "./marketplace-relations";
import {
  assertQuoteRequestTransition,
  lockQuoteRequestTransitionRow,
} from "./quote-lifecycle";
import {
  FULL_QUOTE_VISIBILITY,
  MARKETPLACE_QUOTE_INCLUDE,
  QuoteVisibility,
} from "./marketplace.contracts";
import {
  assertProviderAccountUnchanged,
  lockMarketplaceMutationUsers,
  lockMarketplaceProvider,
} from "./marketplace-write-locks";

export type QuoteCancellationAccess =
  | "PLAN_OR_REQUESTER"
  | "REQUESTER_ONLY";

export function cancelQuoteRequestInTransaction(
  prisma: PrismaService,
  lifecycle: ConversationLifecyclePort,
  permissions: PermissionService,
  scope: CollaborationScopePort,
  relations: MarketplaceRelationsService,
  currentUser: AuthenticatedUser,
  id: string,
  access: QuoteCancellationAccess,
  history?: ContributionHistoryService,
) {
  return runSerializableTransaction(prisma, async (tx) => {
    const seed = await quoteRepository.findRequestCancellationSeed(tx, id, access === "REQUESTER_ONLY" ? currentUser.id : undefined);
    if (!seed) {
      throw new NotFoundException("Quote request not found");
    }
    // The plan owner is planning's row, read through its port for the
    // user lock set.
    const planSeed = seed.weddingPlanId
      ? await relations.plans.getPlan(tx, seed.weddingPlanId)
      : null;

    const lockedUserIds = await lockMarketplaceMutationUsers(
      tx,
      currentUser.id,
      [seed.userId, planSeed?.ownerUserId, seed.provider.userId],
    );
    let visibility: QuoteVisibility = FULL_QUOTE_VISIBILITY;
    let planContext: Awaited<
      ReturnType<PermissionService["assertPlanReadableInTransaction"]>
    > | null = null;
    if (seed.weddingPlanId) {
      const context = await permissions.assertPlanReadableInTransaction(
        tx,
        seed.weddingPlanId,
        currentUser,
      );
      if (!permissions.canManageProviders(context)) {
        throw new ForbiddenException({
          statusCode: 403,
          code: "PROVIDER_PERMISSION_REVOKED",
          message: "Provider access has been revoked",
        });
      }
      assertWeddingPlanWritable(context.plan);
      planContext = context;
      if (
        access === "PLAN_OR_REQUESTER" &&
        !context.isOwner &&
        seed.userId !== currentUser.id
      ) {
        throw new NotFoundException("Quote request not found");
      }
      if (
        !context.isOwner &&
        !(await findContributorProviderQuoteIds(
          tx,
          scope,
          seed.weddingPlanId,
          currentUser.id,
        )).includes(id)
      ) {
        throw new NotFoundException("Quote request not found");
      }
      if (seed.userId !== currentUser.id) {
        visibility = {
          budget: permissions.canViewMoney(context),
          contact: permissions.canManageProviders(context),
        };
      }
    } else if (
      access === "PLAN_OR_REQUESTER" &&
      seed.userId !== currentUser.id
    ) {
      throw new NotFoundException("Quote request not found");
    }

    const provider = await lockMarketplaceProvider(tx, seed.providerId);
    assertProviderAccountUnchanged(
      provider,
      seed.provider.userId,
      lockedUserIds,
    );
    if (!(await lockQuoteRequestTransitionRow(tx, lifecycle, id))) {
      throw new NotFoundException("Quote request not found");
    }

    const existing = await quoteRepository.findRequestCancellationState(tx, id);
    if (!existing) {
      throw new NotFoundException("Quote request not found");
    }
    if (
      existing.userId !== seed.userId ||
      existing.weddingPlanId !== seed.weddingPlanId ||
      existing.providerId !== seed.providerId ||
      existing.conversationId !== seed.conversationId
    ) {
      throw new ConflictException(
        "Quote request context changed concurrently; retry the request",
      );
    }

    assertQuoteRequestTransition(
      existing.status,
      QuoteRequestStatus.CANCELLED,
      "requester",
    );
    const cancelledAt = new Date();
    const transition = await quoteRepository.cancelQuoteRequest(tx, id, existing.status, cancelledAt);
    if (transition.count !== 1) {
      throw new ConflictException("Quote request cannot be cancelled");
    }

    const quote = await relations.attachQuoteRelation(
      tx,
      await quoteRepository.requireCancelledQuoteRequest(tx, id),
    );
    await lifecycle.recordConversationEvent(tx, {
      conversationId: existing.conversationId,
      quoteRequestId: quote.id,
      actorUserId: currentUser.id,
      type: ConversationEventType.QUOTE_REQUEST_CANCELLED,
      occurredAt: cancelledAt,
      dedupeKey: `quote-request:${quote.id}:cancelled`,
      data: { status: QuoteRequestStatus.CANCELLED },
    });
    if (planContext && history) {
      await history.recordForContextInTransaction(tx, planContext, {
        section: ContributionSection.PROVIDERS,
        entityType: ContributionEntityType.QUOTE_REQUEST,
        entityId: quote.id,
        action: ContributionAction.STATUS_CHANGED,
        snapshot: buildContributionSnapshot(
          ContributionEntityType.QUOTE_REQUEST,
          {
            providerDisplayLabel: quote.provider.businessName,
            categoryLabel: quote.service?.category.nameAr,
            requestStatus: quote.status,
            status: quote.status,
          },
        ),
        dedupeKey: `provider:quote-request:${quote.id}:cancelled`,
        requiredPermission: ContributionPermission.MANAGE_PROVIDERS,
        occurredAt: cancelledAt,
      });
    }
    return { quote, visibility };
  });
}
