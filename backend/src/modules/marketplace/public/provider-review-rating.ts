import { NotFoundException } from "@nestjs/common";
import { Prisma } from "@prisma/client";
import { runSerializableTransaction } from "../../../platform/database/serializable-transaction";
import { PrismaService } from "../../../platform/database/prisma.service";
import {
  lockProviderRatingRowsInTransaction,
  refreshProviderRatingInTransaction,
} from "../infrastructure/provider-review-rating.repository";

export async function lockProviderRatingRows(
  tx: Prisma.TransactionClient,
  providerIds: readonly string[],
): Promise<string[]> {
  return lockProviderRatingRowsInTransaction(tx, providerIds);
}

export async function refreshProviderRating(
  tx: Prisma.TransactionClient,
  providerId: string,
): Promise<boolean> {
  return refreshProviderRatingInTransaction(tx, providerId);
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
