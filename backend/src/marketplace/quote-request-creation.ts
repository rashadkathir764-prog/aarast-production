import * as quoteRepository from "../modules/marketplace/infrastructure/marketplace-quote-mutation.repository";
import type { QuoteRequestCreateData } from "../modules/marketplace/infrastructure/marketplace-quote-mutation.repository";
import { ConflictException, NotFoundException } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  ConversationEventType,
  Prisma,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import type { CollaborationHistoryPort as ContributionHistoryService } from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import type { ConversationLifecyclePort } from "../modules/messaging/public/conversation-lifecycle.port";
import type { NotificationsPort } from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import type { CollaborationPermissionPort as PermissionService } from "../modules/collaboration/public/collaboration-permission.port";
import type { CatalogReadPort } from "../modules/catalog/public/catalog-read.port";
import type { MarketplaceRelationsService } from "./marketplace-relations";
import { MARKETPLACE_QUOTE_INCLUDE } from "./marketplace.contracts";
import {
  assertMarketplaceProviderActive,
  assertProviderAccountUnchanged,
  lockActiveMarketplaceCity,
  lockActiveProviderService,
  lockMarketplaceMutationUsers,
  lockMarketplaceProvider,
} from "./marketplace-write-locks";
import { isQuoteOfferExpired } from "./quote-offer-expiry";
import { isQuoteRequestOverdue, quoteRequestAnswerDeadline } from "./quote-lifecycle";
import {
  quoteSubmittedProviderNotification,
  quoteSubmittedRequesterNotification,
} from "./quote-notifications";

// The request is created with its own columns only. The generated
// `QuoteRequestUncheckedCreateInput` also admits nested writes to the
// offers, links and conversation events, so the ownership scan cannot prove
// a write typed by it; the columns the service sets are declared exactly.
interface CreateQuoteRequestTransactionInput {
  data: QuoteRequestCreateData;
  requesterId: string;
}

export interface QuoteRequestMutationGuard {
  currentUser: AuthenticatedUser;
  permissions: PermissionService;
  /** Catalog locks the requested city; planning's owner is read for the user locks. */
  catalog: CatalogReadPort;
  history?: ContributionHistoryService;
}

export function createQuoteRequestInTransaction(
  prisma: PrismaService,
  lifecycle: ConversationLifecyclePort,
  notifications: NotificationsPort,
  relations: MarketplaceRelationsService,
  input: CreateQuoteRequestTransactionInput,
  guard?: QuoteRequestMutationGuard,
) {
  const providerId = input.data.providerId;
  const weddingPlanId = input.data.weddingPlanId ?? null;
  const serviceId = input.data.serviceId ?? null;
  const eventDate = input.data.eventDate ?? null;
  const cityId = input.data.cityId ?? null;

  return runSerializableTransaction(prisma, async (tx) => {
    let planContext: Awaited<
      ReturnType<PermissionService["assertProviderManageableInTransaction"]>
    > | null = null;
    const providerSeed = guard
      ? await quoteRepository.findProviderAccountForRequest(tx, providerId)
      : null;
    const planSeed =
      guard && weddingPlanId
        ? await relations.plans.getPlan(tx, weddingPlanId)
        : null;

    if (weddingPlanId && !guard) {
      throw new Error("QuoteRequestMutationGuardRequired");
    }

    if (guard) {
      const lockedUserIds = await lockMarketplaceMutationUsers(
        tx,
        guard.currentUser.id,
        [providerSeed?.userId, planSeed?.ownerUserId],
      );
      if (weddingPlanId) {
        planContext = await guard.permissions.assertProviderManageableInTransaction(
          tx,
          weddingPlanId,
          guard.currentUser,
        );
      }
      const provider = await lockMarketplaceProvider(tx, providerId, "UPDATE");
      assertProviderAccountUnchanged(
        provider,
        providerSeed?.userId ?? null,
        lockedUserIds,
      );
      assertMarketplaceProviderActive(provider);
      // A listing the back office made that its owner has not claimed yet
      // (V1 checklist 4.18): nobody would read the request.
      if (!provider.userId) {
        throw new ConflictException({
          statusCode: 409,
          code: "PROVIDER_NOT_CLAIMED",
          message: "This provider has not activated their account yet",
        });
      }
      if (serviceId) {
        await lockActiveProviderService(tx, serviceId, providerId);
      }
      if (cityId) {
        await lockActiveMarketplaceCity(tx, guard.catalog, cityId);
      }
    } else {
      // Kept only for the isolated plan-less domain harness. Production calls
      // always provide the guard above and take User -> Plan -> Provider locks.
      await quoteRepository.lockProviderForRequestCreation(tx, providerId);
      const activeProvider = await quoteRepository.findActiveProviderForRequest(tx, providerId);
      if (!activeProvider) throw new NotFoundException("Provider not found");
    }

    // The conversation is both the parent of the request and the row updated
    // by its first lifecycle event. It must precede QuoteRequest in the global
    // account-deletion lock order.
    const conversation = await lifecycle.ensureConversationContext(tx, {
      requesterUserId: input.requesterId,
      providerId,
      weddingPlanId,
    });

    // Logical identity: requester + provider + plan + service (including
    // null) + event date + city. Message, budget, contact and guest details
    // describe the same active lead and cannot bypass this domain guard.
    const existing = await quoteRepository.findActiveRequestCycle(tx, input.requesterId, providerId, weddingPlanId, serviceId, eventDate, cityId);
    // Expiry is a derived terminal state for the response cycle, so the UI's
    // explicit "new request" action can start a new cycle without rewriting
    // historical persisted statuses.
    const expiredResponseCycle =
      existing?.status === QuoteRequestStatus.RESPONDED &&
      existing.offers.length > 0 &&
      existing.offers.every((offer) => isQuoteOfferExpired(offer));
    // B-04: a request past its answer deadline is over even before the
    // hourly job marks it EXPIRED.
    const unansweredInTime = existing ? isQuoteRequestOverdue(existing) : false;
    if (existing && !expiredResponseCycle && !unansweredInTime) {
      throw new ConflictException({
        code: "ACTIVE_QUOTE_REQUEST_EXISTS",
        message:
          "يوجد طلب عرض سعر نشط مطابق. تابع الطلب الحالي بدل إنشاء نسخة جديدة.",
        quoteRequestId: existing.id,
      });
    }

    // B-04: the answer deadline is seven days from this very instant.
    const requestedAt = new Date();
    const quote = await relations.attachQuoteRelation(
      tx,
      await quoteRepository.createQuoteRequest(
        tx,
        {
          ...input.data,
          createdAt: requestedAt,
          expiresAt: quoteRequestAnswerDeadline(requestedAt),
        },
        conversation.id,
      ),
    );
    if (planContext && guard?.history) {
      await guard.history.recordForContextInTransaction(tx, planContext, {
        section: ContributionSection.PROVIDERS,
        entityType: ContributionEntityType.QUOTE_REQUEST,
        entityId: quote.id,
        action: ContributionAction.CREATED,
        snapshot: buildContributionSnapshot(
          ContributionEntityType.QUOTE_REQUEST,
          {
            providerDisplayLabel: quote.provider.businessName,
            categoryLabel: quote.service?.category.nameAr,
            requestStatus: quote.status,
            status: quote.status,
          },
        ),
        dedupeKey: `provider:quote-request:${quote.id}:created`,
        requiredPermission: ContributionPermission.MANAGE_PROVIDERS,
        occurredAt: quote.createdAt,
      });
    }
    await lifecycle.recordConversationEvent(tx, {
      conversationId: conversation.id,
      quoteRequestId: quote.id,
      actorUserId: input.requesterId,
      type: ConversationEventType.QUOTE_REQUEST_CREATED,
      occurredAt: quote.createdAt,
      dedupeKey: `quote-request:${quote.id}:created`,
      data: { status: QuoteRequestStatus.SENT },
    });
    await notifications.createNotificationInTransaction(
      tx,
      quoteSubmittedRequesterNotification({
        requesterId: input.requesterId,
        weddingPlanId: quote.weddingPlanId,
        quoteId: quote.id,
        providerId: quote.providerId,
        providerName: quote.provider.businessName,
      }),
    );
    const providerUserId = quote.provider.userId;
    if (providerUserId && providerUserId !== input.requesterId) {
      await notifications.createNotificationInTransaction(
        tx,
        quoteSubmittedProviderNotification({
          providerUserId,
          quoteId: quote.id,
          providerId: quote.providerId,
        }),
      );
    }
    return quote;
  });
}
