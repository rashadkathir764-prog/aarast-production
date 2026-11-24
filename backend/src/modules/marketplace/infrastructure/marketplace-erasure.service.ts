import { Injectable } from '@nestjs/common';
import {
  BookingStatus,
  Prisma,
  ProviderStatus,
  QuoteOfferStatus,
  QuoteRequestStatus,
} from '@prisma/client';
import type { CreateNotificationInput } from '../../notifications/public/notifications.port';
import {
  customerClosedProviderNotification,
  providerClosedCustomerNotification,
} from '../../../marketplace/booking-notifications';
import { bookingToday } from '../../../marketplace/booking-policy';
import type {
  MarketplaceErasurePort,
  OwnedQuoteRequestScope,
  QuoteRequestHeir,
} from '../public/marketplace-erasure.port';

/** RA-BE-178: what an erased provider is called wherever his customers read him. */
export const ERASED_PROVIDER_NAME = 'مزود محذوف';

@Injectable()
export class MarketplaceErasureService implements MarketplaceErasurePort {
  async lockUpcomingConfirmedBookingIdsInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    now: Date,
  ): Promise<string[]> {
    const today = bookingToday(now);
    const ids = [...new Set(providerIds)].sort();
    if (ids.length === 0) return [];
    // The provider row is what every booking confirmation locks first.
    await tx.$queryRaw(
      Prisma.sql`SELECT "id" FROM "Provider" WHERE "id" = ANY(${ids}::text[]) ORDER BY "id" ASC FOR UPDATE`,
    );
    const bookings = await tx.booking.findMany({
      where: {
        providerId: { in: ids },
        status: BookingStatus.CONFIRMED,
        eventDate: { gte: today },
      },
      orderBy: [{ eventDate: 'asc' }, { id: 'asc' }],
      select: { id: true },
    });
    return bookings.map((booking) => booking.id);
  }

  async closedProviderNoticesInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    closedAt: Date,
  ): Promise<CreateNotificationInput[]> {
    if (providerIds.length === 0) return [];
    const open = await tx.quoteRequest.findMany({
      where: {
        providerId: { in: [...providerIds] },
        status: {
          in: [
            QuoteRequestStatus.SENT,
            QuoteRequestStatus.VIEWED,
            QuoteRequestStatus.RESPONDED,
            QuoteRequestStatus.ACCEPTED,
          ],
        },
        // A wedding the provider already did is no open request.
        NOT: { booking: { status: BookingStatus.CONFIRMED } },
      },
      orderBy: { id: 'asc' },
      select: {
        id: true,
        userId: true,
        weddingPlanId: true,
        provider: { select: { businessName: true } },
      },
    });
    return open.map((quote) =>
      providerClosedCustomerNotification({
        quoteRequestId: quote.id,
        customerUserId: quote.userId,
        weddingPlanId: quote.weddingPlanId,
        providerName: quote.provider.businessName,
        at: closedAt,
      }),
    );
  }

  async closedCustomerNoticesInTransaction(
    tx: Prisma.TransactionClient,
    scope: { userId: string; weddingPlanIds: readonly string[] },
    customerName: string | null,
    closedAt: Date,
    closed: 'ACCOUNT' | 'PLAN',
  ): Promise<CreateNotificationInput[]> {
    const today = bookingToday(closedAt);
    const open = await tx.quoteRequest.findMany({
      where: {
        OR: [
          // D112 (Q-22): a request the account sent from inside another
          // person's plan stays that plan's and is not closed, so its
          // provider is not told the customer left.
          ...(scope.userId !== null
            ? [{ userId: scope.userId, weddingPlanId: null }]
            : []),
          ...(scope.weddingPlanIds.length > 0
            ? [{ weddingPlanId: { in: [...scope.weddingPlanIds] } }]
            : []),
        ],
        status: {
          in: [
            QuoteRequestStatus.SENT,
            QuoteRequestStatus.VIEWED,
            QuoteRequestStatus.RESPONDED,
            QuoteRequestStatus.ACCEPTED,
          ],
        },
        // A wedding the provider already did is no open request.
        NOT: { booking: { status: BookingStatus.CONFIRMED, eventDate: { lt: today } } },
        provider: { userId: { not: null } },
      },
      orderBy: { id: 'asc' },
      select: {
        id: true,
        provider: { select: { userId: true } },
        booking: { select: { status: true, eventDate: true } },
      },
    });
    return open.map((quote) =>
      customerClosedProviderNotification({
        quoteRequestId: quote.id,
        providerUserId: quote.provider.userId!,
        customerName,
        confirmedDay:
          quote.booking?.status === BookingStatus.CONFIRMED
            ? quote.booking.eventDate
            : null,
        at: closedAt,
        closed,
      }),
    );
  }

  async countUpcomingPlanBookings(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    now: Date,
  ): Promise<number> {
    if (weddingPlanIds.length === 0) return 0;
    return client.booking.count({
      where: {
        status: BookingStatus.CONFIRMED,
        eventDate: { gte: bookingToday(now) },
        quoteRequest: { weddingPlanId: { in: [...weddingPlanIds] } },
      },
    });
  }

  async listOwnedProviderIds(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]> {
    const ownedProviders = await tx.provider.findMany({
      where: { userId },
      orderBy: { id: 'asc' },
      select: { id: true },
    });
    return ownedProviders.map((provider) => provider.id);
  }

  async markOwnerLeavingInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    at: Date | null,
  ): Promise<void> {
    if (providerIds.length === 0) return;
    await tx.provider.updateMany({
      where: { id: { in: [...providerIds] } },
      data: { ownerLeavingAt: at },
    });
  }

  async listReviewedProviderIds(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]> {
    const reviewedProviders = await tx.providerReview.findMany({
      where: { userId },
      distinct: ['providerId'],
      orderBy: { providerId: 'asc' },
      select: { providerId: true },
    });
    return reviewedProviders.map((review) => review.providerId);
  }

  async deleteUserReviewsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    // RA-ST-05: the reports this account made are its words too; reports
    // on its own reviews go with them (cascade).
    await tx.reviewReport.deleteMany({ where: { reporterUserId: userId } });
    await tx.providerReview.deleteMany({ where: { userId } });
  }

  async lockOwnedQuoteRequestIdsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    scope: OwnedQuoteRequestScope,
  ): Promise<string[]> {
    // An empty id list is an empty `ANY`, and a null account an unknown
    // `=`: that predicate matches nothing. RA-BE-178: the requests sent to
    // the account's listings stay with the customers who sent them.
    const weddingPlanIds = [...scope.weddingPlanIds];
    const conversationIds = [...scope.conversationIds];
    const quoteRequests = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "QuoteRequest"
        WHERE ("userId" = ${scope.userId}
               AND ("weddingPlanId" IS NULL
                    OR "weddingPlanId" = ANY(${weddingPlanIds}::text[])))
           OR "weddingPlanId" = ANY(${weddingPlanIds}::text[])
           OR "conversationId" = ANY(${conversationIds}::text[])
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
    return quoteRequests.map((quote) => quote.id);
  }

  async lockMemberPlanQuoteRequestsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    scope: OwnedQuoteRequestScope & { userId: string },
  ): Promise<Array<{ weddingPlanId: string; quoteRequestIds: string[] }>> {
    const weddingPlanIds = [...scope.weddingPlanIds];
    const conversationIds = [...scope.conversationIds];
    // Exactly the account's requests the lock above leaves out: sent from a
    // plan it does not own, in a thread that stays.
    const rows = await tx.$queryRaw<Array<{ id: string; weddingPlanId: string }>>(
      Prisma.sql`
        SELECT "id", "weddingPlanId"
        FROM "QuoteRequest"
        WHERE "userId" = ${scope.userId}
          AND "weddingPlanId" IS NOT NULL
          AND NOT ("weddingPlanId" = ANY(${weddingPlanIds}::text[]))
          AND ("conversationId" IS NULL
               OR NOT ("conversationId" = ANY(${conversationIds}::text[])))
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
    const byPlan = new Map<string, string[]>();
    for (const row of rows) {
      byPlan.set(row.weddingPlanId, [
        ...(byPlan.get(row.weddingPlanId) ?? []),
        row.id,
      ]);
    }
    return [...byPlan.entries()]
      .sort(([first], [second]) => (first < second ? -1 : first > second ? 1 : 0))
      .map(([weddingPlanId, quoteRequestIds]) => ({
        weddingPlanId,
        quoteRequestIds,
      }));
  }

  async handOverQuoteRequestsInTransaction(
    tx: Prisma.TransactionClient,
    erasedUserId: string,
    heirs: readonly QuoteRequestHeir[],
  ): Promise<void> {
    for (const heir of heirs) {
      const ids = [...heir.quoteRequestIds];
      if (ids.length === 0) continue;
      await tx.quoteRequest.updateMany({
        where: { id: { in: ids }, userId: erasedUserId },
        data: {
          userId: heir.ownerUserId,
          contactName: heir.contactName,
          contactPhone: heir.contactPhone,
          contactNormalizedPhone: heir.contactPhone,
        },
      });
      await tx.booking.updateMany({
        where: { quoteRequestId: { in: ids }, requestedByUserId: erasedUserId },
        data: { requestedByUserId: heir.ownerUserId },
      });
      await tx.bookingChange.updateMany({
        where: {
          booking: { quoteRequestId: { in: ids } },
          requestedByUserId: erasedUserId,
        },
        data: { requestedByUserId: heir.ownerUserId },
      });
    }
  }

  async deleteQuoteRequestsInTransaction(
    tx: Prisma.TransactionClient,
    quoteRequestIds: readonly string[],
  ): Promise<void> {
    if (quoteRequestIds.length === 0) return;
    await tx.quoteRequest.deleteMany({
      where: { id: { in: [...quoteRequestIds] } },
    });
  }

  async deletePlanProviderLinksInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    await tx.planProviderLink.deleteMany({
      where: { weddingPlanId: { in: [...weddingPlanIds] } },
    });
  }

  async eraseProvidersInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
    erasedAt: Date,
  ): Promise<void> {
    if (providerIds.length === 0) return;
    const ofProviders = { providerId: { in: [...providerIds] } };
    // What was open ends, as when a listing is suspended (B-42, B-04).
    await tx.quoteRequest.updateMany({
      where: {
        ...ofProviders,
        status: {
          in: [
            QuoteRequestStatus.SENT,
            QuoteRequestStatus.VIEWED,
            QuoteRequestStatus.RESPONDED,
          ],
        },
      },
      data: { status: QuoteRequestStatus.EXPIRED, expiredAt: erasedAt },
    });
    await tx.quoteOffer.updateMany({
      where: { ...ofProviders, status: QuoteOfferStatus.PENDING },
      data: {
        status: QuoteOfferStatus.WITHDRAWN,
        withdrawnAt: erasedAt,
        withdrawnReason: null,
      },
    });
    await tx.booking.updateMany({
      where: { ...ofProviders, status: BookingStatus.REQUESTED },
      data: { status: BookingStatus.EXPIRED, expiredAt: erasedAt },
    });
    // The listing's own data. A request keeps its service as none (SetNull).
    await tx.providerService.deleteMany({ where: ofProviders });
    await tx.providerPackage.deleteMany({ where: ofProviders });
    await tx.portfolioItem.deleteMany({ where: ofProviders });
    await tx.favoriteProvider.deleteMany({ where: ofProviders });
    await tx.providerReview.deleteMany({ where: ofProviders });
    await tx.providerBlockedDate.deleteMany({ where: ofProviders });
    await tx.providerProfileViewDay.deleteMany({ where: ofProviders });
    await tx.providerFeaturedPeriod.deleteMany({ where: ofProviders });
    await tx.providerClaimRequest.deleteMany({ where: ofProviders });
    await tx.providerReviewEvent.deleteMany({ where: ofProviders });
    // RA-BE-152: the name and images he asked for (the images go with his
    // account's media).
    await tx.providerProfileChange.deleteMany({ where: ofProviders });
    await tx.provider.updateMany({
      where: { id: { in: [...providerIds] } },
      data: {
        businessName: ERASED_PROVIDER_NAME,
        ownerName: null,
        phone: '',
        whatsapp: null,
        email: null,
        description: null,
        address: null,
        latitude: null,
        longitude: null,
        logoUrl: null,
        coverUrl: null,
        logoThumbUrl: null,
        logoMediumUrl: null,
        coverThumbUrl: null,
        coverMediumUrl: null,
        socialLinks: Prisma.DbNull,
        ratingAverage: 0,
        ratingCount: 0,
        status: ProviderStatus.SUSPENDED,
        erasedAt,
      },
    });
  }

  async deleteUserFavoritesInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.favoriteProvider.deleteMany({ where: { userId } });
  }

  async deleteUserClaimRequestsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.providerClaimRequest.deleteMany({ where: { userId } });
  }
}
