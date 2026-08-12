import { NotFoundException } from "@nestjs/common";
import { Prisma, ReviewStatus } from "@prisma/client";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";

export async function lockProviderRatingRows(
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

export async function refreshProviderRating(
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

export async function runProviderReviewMutation<T>(
  prisma: PrismaService,
  providerId: string,
  mutation: (tx: Prisma.TransactionClient) => Promise<T>,
): Promise<T> {
  return runSerializableTransaction(prisma, async (tx) => {
    const locked = await lockProviderRatingRows(tx, [providerId]);
    if (locked.length !== 1) {
      throw new NotFoundException("Provider not found");
    }
    const result = await mutation(tx);
    if (!(await refreshProviderRating(tx, providerId))) {
      throw new NotFoundException("Provider not found");
    }
    return result;
  });
}
