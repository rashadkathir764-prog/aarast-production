import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type {
  MarketplaceErasurePort,
  OwnedQuoteRequestScope,
} from '../public/marketplace-erasure.port';

@Injectable()
export class MarketplaceErasureService implements MarketplaceErasurePort {
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
    await tx.providerReview.deleteMany({ where: { userId } });
  }

  async lockOwnedQuoteRequestIdsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    scope: OwnedQuoteRequestScope,
  ): Promise<string[]> {
    // An empty id list is an empty `ANY`, i.e. that predicate matches nothing.
    const weddingPlanIds = [...scope.weddingPlanIds];
    const providerIds = [...scope.providerIds];
    const conversationIds = [...scope.conversationIds];
    const quoteRequests = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "QuoteRequest"
        WHERE "userId" = ${scope.userId}
           OR "weddingPlanId" = ANY(${weddingPlanIds}::text[])
           OR "providerId" = ANY(${providerIds}::text[])
           OR "conversationId" = ANY(${conversationIds}::text[])
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
    return quoteRequests.map((quote) => quote.id);
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

  async deleteProvidersInTransaction(
    tx: Prisma.TransactionClient,
    providerIds: readonly string[],
  ): Promise<void> {
    if (providerIds.length === 0) return;
    await tx.provider.deleteMany({ where: { id: { in: [...providerIds] } } });
  }

  async deleteUserFavoritesInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.favoriteProvider.deleteMany({ where: { userId } });
  }
}
