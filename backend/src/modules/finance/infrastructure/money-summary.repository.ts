import { Prisma, WeddingCostStatus } from '@prisma/client';

/** Finance's own rows for one money-summary snapshot on the caller's transaction. */
export function loadMoneySummaryRows(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  contributionScope: {
    costIds: readonly string[];
    categoryIds: readonly string[];
  } | null,
) {
  return Promise.all([
    tx.budgetCategory.findMany({
      where: {
        weddingPlanId,
        ...(contributionScope
          ? { id: { in: [...contributionScope.categoryIds] } }
          : {}),
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    }),
    tx.weddingCost.findMany({
      where: {
        weddingPlanId,
        ...(contributionScope
          ? { id: { in: [...contributionScope.costIds] } }
          : {}),
        status: { not: WeddingCostStatus.CANCELLED },
      },
      select: {
        id: true,
        budgetCategoryId: true,
        totalAmount: true,
        title: true,
        partyName: true,
        payer: true,
        payerName: true,
        entryKind: true,
        estimateCover: true,
        estimatePart: true,
      },
    }),
    tx.costPayment.findMany({
      where: {
        weddingCost: {
          weddingPlanId,
          ...(contributionScope
            ? { id: { in: [...contributionScope.costIds] } }
            : {}),
          status: { not: WeddingCostStatus.CANCELLED },
        },
      },
      select: {
        id: true,
        weddingCostId: true,
        amount: true,
        entryType: true,
        // D106: a partial payment of a date, and whether it was reversed.
        lowersScheduleId: true,
        reversalOfId: true,
      },
    }),
    tx.paymentSchedule.findMany({
      where: {
        weddingCost: {
          weddingPlanId,
          ...(contributionScope
            ? { id: { in: [...contributionScope.costIds] } }
            : {}),
          status: { not: WeddingCostStatus.CANCELLED },
        },
      },
      include: {
        weddingCost: { select: { budgetCategoryId: true } },
      },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    }),
  ]);
}
