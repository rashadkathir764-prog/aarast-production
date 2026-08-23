import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionPermission,
  ContributionSection,
  ConversationEventType,
  PlanProviderLinkStatus,
  Prisma,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../modules/identity/public/identity-session.types";
import type { CollaborationHistoryPort as ContributionHistoryService } from "../modules/collaboration/public/collaboration-history.port";
import { buildContributionSnapshot } from "../modules/collaboration/public/contribution-snapshot.builder";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { recordConversationEvent } from "../conversations/conversation-lifecycle";
import type { NotificationsPort } from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import { assertProviderOperational } from "../provider-dashboard/provider-access-policy";
import type { CollaborationPermissionPort as PermissionService } from "../modules/collaboration/public/collaboration-permission.port";
import { weddingCostResponseInclude } from "../wedding-costs/wedding-cost.presenter";
import {
  assertQuoteRequestTransition,
  lockQuoteOfferTransitionRows,
} from "./quote-lifecycle";
import {
  assertProviderAccountUnchanged,
  lockMarketplaceMutationUsers,
} from "./marketplace-write-locks";
import {
  findLogicalBudgetCategory,
  findOtherBudgetCategory,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
} from "./quote-cost-category";
import {
  offerAcceptedProviderNotification,
  offerAcceptedRequesterNotification,
} from "./quote-notifications";

interface AcceptQuoteOfferInput {
  id: string;
  weddingPlanId: string;
  currentUser: AuthenticatedUser;
  actorUserId?: string;
}

export async function acceptQuoteOfferInTransaction(
  prisma: PrismaService,
  permissions: PermissionService,
  notifications: NotificationsPort,
  input: AcceptQuoteOfferInput,
  history?: ContributionHistoryService,
) {
  const { id, weddingPlanId } = input;
  return runSerializableTransaction(prisma, async (tx) => {
    const offerSeed = await tx.quoteOffer.findUnique({
      where: { id },
      select: {
        providerId: true,
        provider: { select: { userId: true } },
        quoteRequest: {
          select: {
            userId: true,
            weddingPlanId: true,
            weddingPlan: { select: { ownerUserId: true } },
          },
        },
      },
    });
    if (!offerSeed) {
      throw new NotFoundException("Quote offer not found");
    }
    if (offerSeed.quoteRequest.weddingPlanId !== weddingPlanId) {
      throw new BadRequestException(
        "Quote offer is not linked to this wedding plan",
      );
    }
    const lockedUserIds = await lockMarketplaceMutationUsers(
      tx,
      input.currentUser.id,
      [
        offerSeed.quoteRequest.userId,
        offerSeed.quoteRequest.weddingPlan?.ownerUserId,
        offerSeed.provider.userId,
      ],
    );
    const planContext = await permissions.assertProviderAndMoneyManageableInTransaction(
      tx,
      weddingPlanId,
      input.currentUser,
    );
    if (
      !planContext.isOwner &&
      offerSeed.quoteRequest.userId !== input.currentUser.id
    ) {
      throw new NotFoundException("Quote offer not found");
    }

    const providerLock = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "Provider"
        WHERE "id" = ${offerSeed.providerId}
        FOR SHARE
      `,
    );
    if (providerLock.length !== 1) {
      throw new NotFoundException("Provider not found");
    }

    const locked = await lockQuoteOfferTransitionRows(tx, id);
    if (!locked) {
      throw new NotFoundException("Quote offer not found");
    }

    const current = await tx.quoteOffer.findUnique({
      where: { id },
      include: {
        quoteRequest: {
          include: {
            weddingPlan: { select: { id: true, currency: true } },
            service: { include: { category: true } },
          },
        },
        provider: { select: { businessName: true, userId: true } },
        providerLinks: { where: { weddingPlanId } },
        weddingCosts: { include: weddingCostResponseInclude },
      },
    });
    if (!current) throw new NotFoundException("Quote offer not found");
    if (
      current.providerId !== offerSeed.providerId ||
      current.quoteRequest.userId !== offerSeed.quoteRequest.userId ||
      current.quoteRequest.weddingPlanId !==
        offerSeed.quoteRequest.weddingPlanId
    ) {
      throw new ConflictException(
        "Quote offer context changed concurrently; retry the request",
      );
    }
    assertProviderAccountUnchanged(
      current.provider,
      offerSeed.provider.userId,
      lockedUserIds,
    );

    const plan = current.quoteRequest.weddingPlan;
    if (!plan || plan.id !== weddingPlanId) {
      throw new BadRequestException(
        "Quote offer is not linked to this wedding plan",
      );
    }
    if (
      current.status !== QuoteOfferStatus.PENDING &&
      current.status !== QuoteOfferStatus.ACCEPTED
    ) {
      throw new ConflictException("Quote offer cannot be accepted");
    }
    if (
      current.status === QuoteOfferStatus.ACCEPTED &&
      current.quoteRequest.status !== QuoteRequestStatus.ACCEPTED
    ) {
      throw new ConflictException("Accepted quote state is inconsistent");
    }

    const acceptedNow = current.status === QuoteOfferStatus.PENDING;
    if (acceptedNow) {
      assertQuoteRequestTransition(
        current.quoteRequest.status,
        QuoteRequestStatus.ACCEPTED,
        "requester",
      );
      if (current.validUntil && current.validUntil.getTime() < Date.now()) {
        throw new ConflictException({
          code: "QUOTE_OFFER_EXPIRED",
          message: "انتهت صلاحية عرض السعر. أنشئ طلبًا جديدًا للمتابعة.",
        });
      }
    }
    if (!current.amount || !current.amount.isPositive()) {
      throw new BadRequestException(
        "Quote offer amount is required before acceptance",
      );
    }
    if (current.currency.toUpperCase() !== plan.currency.toUpperCase()) {
      throw new BadRequestException(
        "Quote offer currency must match the wedding plan currency",
      );
    }

    if (!acceptedNow) {
      const cost = current.weddingCosts[0] ?? null;
      const link = current.providerLinks[0] ?? null;
      if (
        !cost ||
        !link ||
        cost.weddingPlanId !== weddingPlanId ||
        cost.providerId !== current.providerId ||
        link.weddingPlanId !== weddingPlanId ||
        link.providerId !== current.providerId ||
        link.quoteRequestId !== current.quoteRequestId ||
        link.quoteOfferId !== current.id
      ) {
        throw new ConflictException("Accepted quote state is incomplete");
      }
      return { offer: current, cost, link, acceptedNow: false };
    }

    const provider = await tx.provider.findUnique({
      where: { id: current.providerId },
      select: { status: true },
    });
    if (!provider) {
      throw new NotFoundException("Provider not found");
    }
    assertProviderOperational(provider);

    let cost = current.weddingCosts[0] ?? null;
    if (!cost) {
      const categories = await tx.budgetCategory.findMany({
        where: { weddingPlanId },
        select: { id: true, name: true, normalizedName: true },
      });
      const providerCategoryName =
        current.quoteRequest.service?.category.nameAr ?? null;
      let category = findLogicalBudgetCategory(
        categories,
        providerCategoryName,
      );
      category ??= findOtherBudgetCategory(categories);
      if (!category) {
        category = await tx.budgetCategory.upsert({
          where: {
            weddingPlanId_normalizedName: {
              weddingPlanId,
              normalizedName: normalizeBudgetCategoryName(
                OTHER_BUDGET_CATEGORY_NAME,
              ),
            },
          },
          update: {},
          create: {
            weddingPlanId,
            name: OTHER_BUDGET_CATEGORY_NAME,
            normalizedName: normalizeBudgetCategoryName(
              OTHER_BUDGET_CATEGORY_NAME,
            ),
          },
          select: { id: true, name: true, normalizedName: true },
        });
      }

      const title =
        current.quoteRequest.service?.title.trim() ||
        current.provider.businessName.trim();
      cost = await tx.weddingCost.create({
        data: {
          weddingPlanId,
          budgetCategoryId: category.id,
          providerId: current.providerId,
          quoteOfferId: current.id,
          title,
          totalAmount: current.amount,
          paidAmount: new Prisma.Decimal(0),
        },
        include: weddingCostResponseInclude,
      });
    }

    let acceptedOffer = current;
    if (acceptedNow) {
      const acceptedAt = new Date();
      const offerTransition = await tx.quoteOffer.updateMany({
        where: { id, status: QuoteOfferStatus.PENDING },
        data: { status: QuoteOfferStatus.ACCEPTED },
      });
      if (offerTransition.count !== 1) {
        throw new ConflictException("Quote offer cannot be accepted");
      }
      acceptedOffer = await tx.quoteOffer.findUniqueOrThrow({
        where: { id },
        include: {
          quoteRequest: {
            include: {
              weddingPlan: { select: { id: true, currency: true } },
              service: { include: { category: true } },
            },
          },
          provider: { select: { businessName: true, userId: true } },
          providerLinks: { where: { weddingPlanId } },
          weddingCosts: { include: weddingCostResponseInclude },
        },
      });
      const rejectedOffers = await tx.quoteOffer.findMany({
        where: {
          quoteRequestId: current.quoteRequestId,
          id: { not: id },
          status: QuoteOfferStatus.PENDING,
        },
        select: { id: true },
      });
      await tx.quoteOffer.updateMany({
        where: {
          quoteRequestId: current.quoteRequestId,
          id: { not: id },
          status: QuoteOfferStatus.PENDING,
        },
        data: { status: QuoteOfferStatus.REJECTED },
      });
      const requestTransition = await tx.quoteRequest.updateMany({
        where: {
          id: current.quoteRequestId,
          status: current.quoteRequest.status,
        },
        data: { status: QuoteRequestStatus.ACCEPTED, acceptedAt },
      });
      if (requestTransition.count !== 1) {
        throw new ConflictException("Quote request cannot be accepted");
      }
      for (const rejectedOffer of rejectedOffers) {
        await recordConversationEvent(tx, {
          conversationId: current.quoteRequest.conversationId,
          quoteRequestId: current.quoteRequestId,
          quoteOfferId: rejectedOffer.id,
          actorUserId: input.actorUserId ?? current.quoteRequest.userId,
          type: ConversationEventType.QUOTE_OFFER_REJECTED,
          occurredAt: acceptedAt,
          dedupeKey: `quote-offer:${rejectedOffer.id}:rejected`,
          data: { status: QuoteOfferStatus.REJECTED },
        });
      }
      await recordConversationEvent(tx, {
        conversationId: current.quoteRequest.conversationId,
        quoteRequestId: current.quoteRequestId,
        quoteOfferId: current.id,
        actorUserId: input.actorUserId ?? current.quoteRequest.userId,
        type: ConversationEventType.QUOTE_OFFER_ACCEPTED,
        occurredAt: acceptedAt,
        dedupeKey: `quote-offer:${current.id}:accepted`,
        data: { status: QuoteOfferStatus.ACCEPTED },
      });
    }

    const link = await tx.planProviderLink.upsert({
      where: {
        weddingPlanId_providerId: {
          weddingPlanId,
          providerId: current.providerId,
        },
      },
      update: {
        quoteRequestId: current.quoteRequestId,
        quoteOfferId: current.id,
        status: PlanProviderLinkStatus.ACTIVE,
      },
      create: {
        weddingPlanId,
        providerId: current.providerId,
        quoteRequestId: current.quoteRequestId,
        quoteOfferId: current.id,
        status: PlanProviderLinkStatus.ACTIVE,
      },
    });

    if (history) {
      const occurredAt = new Date();
      await history.recordForContextInTransaction(tx, planContext, {
        section: ContributionSection.PROVIDERS,
        entityType: ContributionEntityType.QUOTE_REQUEST,
        entityId: current.quoteRequestId,
        action: ContributionAction.STATUS_CHANGED,
        snapshot: buildContributionSnapshot(
          ContributionEntityType.QUOTE_REQUEST,
          {
            providerDisplayLabel: current.provider.businessName,
            categoryLabel: current.quoteRequest.service?.category.nameAr,
            requestStatus: QuoteRequestStatus.ACCEPTED,
            status: QuoteRequestStatus.ACCEPTED,
          },
        ),
        dedupeKey: `provider:quote-request:${current.quoteRequestId}:accepted`,
        requiredPermission: ContributionPermission.MANAGE_PROVIDERS,
        occurredAt,
      });
      await history.recordForContextInTransaction(tx, planContext, {
        section: ContributionSection.PROVIDERS,
        entityType: ContributionEntityType.PLAN_PROVIDER_LINK,
        entityId: link.id,
        action: ContributionAction.CREATED,
        snapshot: buildContributionSnapshot(
          ContributionEntityType.PLAN_PROVIDER_LINK,
          {
            providerDisplayLabel: current.provider.businessName,
            categoryLabel: current.quoteRequest.service?.category.nameAr,
            requestStatus: QuoteRequestStatus.ACCEPTED,
            status: link.status,
          },
        ),
        dedupeKey: `provider:plan-provider-link:${link.id}:active`,
        requiredPermission: ContributionPermission.MANAGE_PROVIDERS,
        occurredAt,
      });
      await history.recordForContextInTransaction(tx, planContext, {
        section: ContributionSection.MONEY,
        entityType: ContributionEntityType.WEDDING_COST,
        entityId: cost.id,
        action: ContributionAction.CREATED,
        snapshot: buildContributionSnapshot(
          ContributionEntityType.WEDDING_COST,
          {
            title: cost.title,
            categoryLabel: cost.budgetCategory.name,
            currency: plan.currency,
            totalAmount: cost.totalAmount,
            paidAmount: cost.paidAmount,
            status: cost.status,
            relevantDate: cost.createdAt,
          },
        ),
        dedupeKey: `money:wedding-cost:${cost.id}:quote-accepted`,
        requiredPermission: ContributionPermission.MANAGE_MONEY,
        occurredAt: cost.createdAt,
      });
    }

    if (acceptedNow) {
      await notifications.createNotificationInTransaction(
        tx,
        offerAcceptedRequesterNotification({
          requesterId: current.quoteRequest.userId,
          weddingPlanId,
          quoteRequestId: current.quoteRequestId,
          quoteOfferId: current.id,
          providerId: current.providerId,
        }),
      );
      if (
        current.provider.userId &&
        current.provider.userId !== input.currentUser.id
      ) {
        await notifications.createNotificationInTransaction(
          tx,
          offerAcceptedProviderNotification({
            providerUserId: current.provider.userId,
            quoteRequestId: current.quoteRequestId,
            quoteOfferId: current.id,
            providerId: current.providerId,
          }),
        );
      }
    }

    return { offer: acceptedOffer, cost, link, acceptedNow };
  });
}
