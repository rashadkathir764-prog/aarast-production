import { ConflictException, NotFoundException } from "@nestjs/common";
import {
  ConversationEventType,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import { recordConversationEvent } from "../conversations/conversation-lifecycle";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
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
  lockWritableMarketplacePlan,
} from "./marketplace-write-locks";

export type QuoteCancellationAccess = "PLAN_OR_OWNER" | "OWNER_ONLY";

export function cancelQuoteRequestInTransaction(
  prisma: PrismaService,
  permissions: PermissionService,
  currentUser: AuthenticatedUser,
  id: string,
  access: QuoteCancellationAccess,
) {
  return runSerializableTransaction(prisma, async (tx) => {
    const seed = await tx.quoteRequest.findFirst({
      where:
        access === "OWNER_ONLY" ? { id, userId: currentUser.id } : { id },
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
    if (access === "PLAN_OR_OWNER") {
      if (seed.weddingPlanId) {
        const context =
          await permissions.assertProviderManageableInTransaction(
            tx,
            seed.weddingPlanId,
            currentUser,
          );
        if (seed.userId !== currentUser.id) {
          visibility = {
            budget: permissions.canViewMoney(context),
            contact: permissions.canManageProviders(context),
          };
        }
      } else if (seed.userId !== currentUser.id) {
        throw new NotFoundException("Quote request not found");
      }
    } else if (seed.weddingPlanId) {
      await lockWritableMarketplacePlan(tx, seed.weddingPlanId);
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
    return { quote, visibility };
  });
}
