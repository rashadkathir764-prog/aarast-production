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
import { recordConversationEvent } from "../conversations/conversation-lifecycle";
import { PrismaService } from "../platform/database/prisma.service";
import {
  assertWeddingPlanWritable,
  type CollaborationPermissionPort as PermissionService,
} from "../modules/collaboration/public/collaboration-permission.port";
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
  permissions: PermissionService,
  currentUser: AuthenticatedUser,
  id: string,
  access: QuoteCancellationAccess,
  history?: ContributionHistoryService,
) {
  return runSerializableTransaction(prisma, async (tx) => {
    const seed = await tx.quoteRequest.findFirst({
      where:
        access === "REQUESTER_ONLY"
          ? { id, userId: currentUser.id }
          : { id },
      select: {
        userId: true,
        weddingPlanId: true,
        providerId: true,
        conversationId: true,
        weddingPlan: { select: { ownerUserId: true } },
        provider: { select: { userId: true } },
      },
    });
    if (!seed) {
      throw new NotFoundException("Quote request not found");
    }

    const lockedUserIds = await lockMarketplaceMutationUsers(
      tx,
      currentUser.id,
      [seed.userId, seed.weddingPlan?.ownerUserId, seed.provider.userId],
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
      if (!context.isOwner) {
        const currentTenureEvent = await tx.contributionEvent.findFirst({
          where: {
            historyScope: { weddingPlanId: seed.weddingPlanId },
            contributorTenure: {
              actorUserId: currentUser.id,
            },
            entityType: ContributionEntityType.QUOTE_REQUEST,
            entityId: id,
            action: {
              in: [
                ContributionAction.CREATED,
                ContributionAction.LEGACY_CAPTURED,
              ],
            },
          },
          select: { id: true },
        });
        if (!currentTenureEvent) {
          throw new NotFoundException("Quote request not found");
        }
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
    if (!(await lockQuoteRequestTransitionRow(tx, id))) {
      throw new NotFoundException("Quote request not found");
    }

    const existing = await tx.quoteRequest.findUnique({
      where: { id },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });
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
    const transition = await tx.quoteRequest.updateMany({
      where: { id, status: existing.status },
      data: { status: QuoteRequestStatus.CANCELLED, cancelledAt },
    });
    if (transition.count !== 1) {
      throw new ConflictException("Quote request cannot be cancelled");
    }

    const quote = await tx.quoteRequest.findUniqueOrThrow({
      where: { id },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });
    await recordConversationEvent(tx, {
      conversationId: existing.conversationId,
      quoteRequestId: existing.id,
      actorUserId: currentUser.id,
      type: ConversationEventType.QUOTE_REQUEST_CANCELLED,
      occurredAt: cancelledAt,
      dedupeKey: `quote-request:${existing.id}:cancelled`,
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
