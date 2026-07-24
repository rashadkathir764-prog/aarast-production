import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from "@nestjs/common";
import {
  ConversationEventType,
  PlanProviderLinkStatus,
  Prisma,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { runSerializableTransaction } from "../common/prisma/serializable-transaction";
import { recordConversationEvent } from "../conversations/conversation-lifecycle";
import { PrismaService } from "../prisma/prisma.service";
import { PermissionService } from "../sharing/permission.service";
import { weddingCostResponseInclude } from "../wedding-costs/wedding-cost.presenter";
import {
  assertQuoteRequestTransition,
  lockQuoteOfferTransitionRows,
} from "./quote-lifecycle";
import {
  findLogicalBudgetCategory,
  findOtherBudgetCategory,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
} from "./quote-cost-category";

interface AcceptQuoteOfferInput {
  id: string;
  weddingPlanId: string;
  currentUser: AuthenticatedUser;
  actorUserId?: string;
}

export async function acceptQuoteOfferInTransaction(
  prisma: PrismaService,
  permissions: PermissionService,
  input: AcceptQuoteOfferInput,
) {
  const { id, weddingPlanId } = input;
  return runSerializableTransaction(prisma, async (tx) => {
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
        weddingCosts: { include: weddingCostResponseInclude },
      },
    });
    if (!current) throw new NotFoundException("Quote offer not found");

    const plan = current.quoteRequest.weddingPlan;
    if (!plan || plan.id !== weddingPlanId) {
      throw new BadRequestException(
        "Quote offer is not linked to this wedding plan",
      );
    }
    await permissions.assertProviderAndMoneyManageableInTransaction(
      tx,
      weddingPlanId,
      input.currentUser,
    );
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
        throw new ConflictException("Quote offer has expired");
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

    return { offer: acceptedOffer, cost, link, acceptedNow };
  });
}
