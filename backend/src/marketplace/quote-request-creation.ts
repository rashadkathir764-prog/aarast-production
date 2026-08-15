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
import { ContributionHistoryService } from "../contribution-history/contribution-history.service";
import { buildContributionSnapshot } from "../contribution-history/contribution-snapshot.builder";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import {
  ensureConversationContext,
  recordConversationEvent,
} from "../conversations/conversation-lifecycle";
import { NotificationsService } from "../notifications/notifications.service";
import { PrismaService } from "../platform/database/prisma.service";
import { PermissionService } from "../sharing/permission.service";
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
import {
  quoteSubmittedProviderNotification,
  quoteSubmittedRequesterNotification,
} from "./quote-notifications";

interface CreateQuoteRequestTransactionInput {
  data: Omit<Prisma.QuoteRequestUncheckedCreateInput, "conversationId">;
  requesterId: string;
}

export interface QuoteRequestMutationGuard {
  currentUser: AuthenticatedUser;
  permissions: PermissionService;
  history?: ContributionHistoryService;
}

export function createQuoteRequestInTransaction(
  prisma: PrismaService,
  notifications: NotificationsService,
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
      ? await tx.provider.findUnique({
          where: { id: providerId },
          select: { userId: true },
        })
      : null;
    const planSeed =
      guard && weddingPlanId
        ? await tx.weddingPlan.findUnique({
            where: { id: weddingPlanId },
            select: { ownerUserId: true },
          })
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
      if (serviceId) {
        await lockActiveProviderService(tx, serviceId, providerId);
      }
      if (cityId) {
        await lockActiveMarketplaceCity(tx, cityId);
      }
    } else {
      // Kept only for the isolated plan-less domain harness. Production calls
      // always provide the guard above and take User -> Plan -> Provider locks.
      await tx.$queryRaw(
        Prisma.sql`SELECT "id" FROM "Provider" WHERE "id" = ${providerId} FOR UPDATE`,
      );
      const activeProvider = await tx.provider.findFirst({
        where: { id: providerId, status: ProviderStatus.ACTIVE },
      });
      if (!activeProvider) throw new NotFoundException("Provider not found");
    }

    // The conversation is both the parent of the request and the row updated
    // by its first lifecycle event. It must precede QuoteRequest in the global
    // account-deletion lock order.
    const conversation = await ensureConversationContext(tx, {
      requesterUserId: input.requesterId,
      providerId,
      weddingPlanId,
    });

    // Logical identity: requester + provider + plan + service (including
    // null) + event date + city. Message, budget, contact and guest details
    // describe the same active lead and cannot bypass this domain guard.
    const existing = await tx.quoteRequest.findFirst({
      where: {
        userId: input.requesterId,
        providerId,
        weddingPlanId,
        serviceId,
        eventDate,
        cityId,
        status: {
          in: [
            QuoteRequestStatus.SENT,
            QuoteRequestStatus.VIEWED,
            QuoteRequestStatus.RESPONDED,
          ],
        },
      },
      orderBy: { createdAt: "desc" },
      include: {
        offers: {
          where: { status: QuoteOfferStatus.PENDING },
          orderBy: { createdAt: "desc" },
        },
      },
    });
    // Expiry is a derived terminal state for the response cycle, so the UI's
    // explicit "new request" action can start a new cycle without rewriting
    // historical persisted statuses.
    const expiredResponseCycle =
      existing?.status === QuoteRequestStatus.RESPONDED &&
      existing.offers.length > 0 &&
      existing.offers.every((offer) => isQuoteOfferExpired(offer));
    if (existing && !expiredResponseCycle) {
      throw new ConflictException({
        code: "ACTIVE_QUOTE_REQUEST_EXISTS",
        message:
          "يوجد طلب عرض سعر نشط مطابق. تابع الطلب الحالي بدل إنشاء نسخة جديدة.",
        quoteRequestId: existing.id,
      });
    }

    const quote = await tx.quoteRequest.create({
      data: { ...input.data, conversationId: conversation.id },
      include: MARKETPLACE_QUOTE_INCLUDE,
    });
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
    await recordConversationEvent(tx, {
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
