import * as quoteRepository from "../modules/marketplace/infrastructure/marketplace-quote-mutation.repository";
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
import type { ConversationLifecyclePort } from "../modules/messaging/public/conversation-lifecycle.port";
import type { NotificationsPort } from "../modules/notifications/public/notifications.port";
import { PrismaService } from "../platform/database/prisma.service";
import { assertProviderOperational } from "../modules/marketplace/public/provider-access-policy";
import { type CollaborationPermissionPort as PermissionService, seesWholePlan } from "../modules/collaboration/public/collaboration-permission.port";
import { addressFormOf, gendered, textFor } from "../shared-kernel/voice/address-form";
import type { FinancePort } from "../modules/finance/public/finance.port";
import type { MarketplaceRelationsService } from "./marketplace-relations";
import {
  assertQuoteRequestTransition,
  lockQuoteOfferTransitionRows,
} from "./quote-lifecycle";
import {
  assertProviderAccountUnchanged,
  lockMarketplaceMutationUsers,
} from "./marketplace-write-locks";
import {
  offerAcceptedProviderNotification,
  offerAcceptedRequesterNotification,
} from "./quote-notifications";
import { quoteOfferCurrencyMismatch } from "./quote-offer-currency";

interface AcceptQuoteOfferInput {
  id: string;
  weddingPlanId: string;
  currentUser: AuthenticatedUser;
  actorUserId?: string;
  /** B-06: the version the customer read; omitted, the current one. */
  versionNo?: number;
}

export async function acceptQuoteOfferInTransaction(
  prisma: PrismaService,
  lifecycle: ConversationLifecyclePort,
  permissions: PermissionService,
  notifications: NotificationsPort,
  finance: FinancePort,
  relations: MarketplaceRelationsService,
  input: AcceptQuoteOfferInput,
  history?: ContributionHistoryService,
) {
  const { id, weddingPlanId } = input;
  return runSerializableTransaction(prisma, async (tx) => {
    const offerSeed = await quoteRepository.findOfferSeed(tx, id);
    if (!offerSeed) {
      throw new NotFoundException("Quote offer not found");
    }
    if (offerSeed.quoteRequest.weddingPlanId !== weddingPlanId) {
      throw new BadRequestException(
        "Quote offer is not linked to this wedding plan",
      );
    }
    // The plan owner is planning's row, read through its port for the
    // user lock set.
    const planSeed = await relations.plans.getPlan(tx, weddingPlanId);
    const lockedUserIds = await lockMarketplaceMutationUsers(
      tx,
      input.currentUser.id,
      [
        offerSeed.quoteRequest.userId,
        planSeed?.ownerUserId,
        offerSeed.provider.userId,
      ],
    );
    const planContext = await permissions.assertProviderAndMoneyManageableInTransaction(
      tx,
      weddingPlanId,
      input.currentUser,
    );
    if (
      !seesWholePlan(planContext) &&
      offerSeed.quoteRequest.userId !== input.currentUser.id
    ) {
      throw new NotFoundException("Quote offer not found");
    }

    const providerLock = await quoteRepository.lockProviderForOfferAcceptance(tx, offerSeed.providerId);
    if (providerLock.length !== 1) {
      throw new NotFoundException("Provider not found");
    }

    const locked = await lockQuoteOfferTransitionRows(tx, lifecycle, id);
    if (!locked) {
      throw new NotFoundException("Quote offer not found");
    }

    const currentRow = await quoteRepository.findOfferForAcceptance(tx, id, weddingPlanId);
    if (!currentRow) throw new NotFoundException("Quote offer not found");
    // The plan currency and the service category are planning's and
    // catalog's rows, attached through their ports on this transaction.
    const current = await relations.attachOfferContext(tx, currentRow);
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
    // B5: the refusals below speak to the customer in their own form.
    const form = addressFormOf({
      accountPersona: input.currentUser.persona,
      memberRole: planContext.sharedMember?.role ?? null,
      planPersona: planSeed?.persona ?? null,
    });
    if (current.status === QuoteOfferStatus.WITHDRAWN) {
      throw new ConflictException({
        code: "QUOTE_OFFER_WITHDRAWN",
        message: textFor(
          form,
          gendered(
            "سحب المزود هذا العرض، فما عاد متاح. اسأله في المحادثة أو انتظر عرضه الجديد.",
            "سحب المزود هذا العرض، فما عاد متاح. اسأليه في المحادثة أو انتظري عرضه الجديد.",
          ),
        ),
      });
    }
    if (
      current.status !== QuoteOfferStatus.PENDING &&
      current.status !== QuoteOfferStatus.ACCEPTED
    ) {
      throw new ConflictException("Quote offer cannot be accepted");
    }
    // B-06: the customer accepts the version he read, never a newer one.
    if (
      input.versionNo !== undefined &&
      input.versionNo !== current.currentVersionNo
    ) {
      throw new ConflictException({
        code: "QUOTE_OFFER_CHANGED",
        message: textFor(
          form,
          gendered(
            "تغيّر العرض قبل ما تقبله. شوف النسخة الجديدة وبعدها اقبل.",
            "تغيّر العرض قبل ما تقبليه. شوفي النسخة الجديدة وبعدها اقبلي.",
          ),
        ),
        currentVersionNo: current.currentVersionNo,
      });
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
          message: textFor(
            form,
            gendered(
              "انتهت صلاحية عرض السعر. أنشئ طلبًا جديدًا للمتابعة.",
              "انتهت صلاحية عرض السعر. أنشئي طلبًا جديدًا للمتابعة.",
            ),
          ),
        });
      }
    }
    if (!current.amount || !current.amount.isPositive()) {
      throw new BadRequestException(
        "Quote offer amount is required before acceptance",
      );
    }
    if (current.currency.toUpperCase() !== plan.currency.toUpperCase()) {
      throw quoteOfferCurrencyMismatch(plan.currency, "customer", form);
    }

    if (!acceptedNow) {
      // The cost an accepted offer is linked to is finance's row, read
      // through its port on this transaction.
      const cost = await finance.findCostForAcceptedOffer(tx, id);
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

    const provider = await quoteRepository.findProviderOperationalStatus(tx, current.providerId);
    if (!provider) {
      throw new NotFoundException("Provider not found");
    }
    assertProviderOperational(provider);

    let cost = await finance.findCostForAcceptedOffer(tx, id);
    if (!cost) {
      const title =
        current.quoteRequest.service?.title.trim() ||
        current.provider.businessName.trim();
      cost = await finance.createCostFromAcceptedOffer(tx, {
        weddingPlanId,
        providerId: current.providerId,
        quoteOfferId: current.id,
        title,
        amount: current.amount,
        providerCategoryName: await relations.offerCategoryName(tx, current),
      });
    }

    let acceptedOffer = current;
    if (acceptedNow) {
      const acceptedAt = new Date();
      const offerTransition = await quoteRepository.acceptPendingOffer(tx, id);
      if (offerTransition.count !== 1) {
        throw new ConflictException("Quote offer cannot be accepted");
      }
      acceptedOffer = await relations.attachOfferContext(
        tx,
        await quoteRepository.requireOfferForAcceptance(tx, id, weddingPlanId),
      );
      const rejectedOffers = await quoteRepository.listOtherPendingOffers(tx, current.quoteRequestId, id);
      await quoteRepository.rejectOtherPendingOffers(tx, current.quoteRequestId, id);
      const requestTransition = await quoteRepository.acceptQuoteRequest(tx, current.quoteRequestId, current.quoteRequest.status, acceptedAt);
      if (requestTransition.count !== 1) {
        throw new ConflictException("Quote request cannot be accepted");
      }
      for (const rejectedOffer of rejectedOffers) {
        await lifecycle.recordConversationEvent(tx, {
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
      await lifecycle.recordConversationEvent(tx, {
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

    const link = await quoteRepository.linkAcceptedProvider(tx, weddingPlanId, current.providerId, current.quoteRequestId, current.id);

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
          providerName: current.provider.businessName,
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
            customerName: current.quoteRequest.contactName,
          }),
        );
      }
    }

    return { offer: acceptedOffer, cost, link, acceptedNow };
  });
}
