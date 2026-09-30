import { Prisma, ReviewStatus } from '@prisma/client';

export async function lockProviderRatingRowsInTransaction(
  tx: Prisma.TransactionClient,
  providerIds: readonly string[],
): Promise<string[]> {
  const orderedIds = [...new Set(providerIds)].sort();
  if (orderedIds.length === 0) return [];
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "Provider"
      WHERE "id" IN (${Prisma.join(orderedIds)})
      ORDER BY "id" ASC
      FOR UPDATE
    `,
  );
  return rows.map((row) => row.id);
}

export async function refreshProviderRatingInTransaction(
  tx: Prisma.TransactionClient,
  providerId: string,
): Promise<boolean> {
  const aggregate = await tx.providerReview.aggregate({
    where: { providerId, status: ReviewStatus.PUBLISHED },
    _avg: { rating: true },
    _count: { _all: true },
  });
  const ratingCount = aggregate._count._all;
  const ratingAverage = ratingCount > 0 ? (aggregate._avg.rating ?? 0) : 0;
  const updated = await tx.provider.updateMany({
    where: { id: providerId },
    data: {
      ratingAverage: ratingAverage.toFixed(2),
      ratingCount,
    },
  });
  return updated.count === 1;
}
