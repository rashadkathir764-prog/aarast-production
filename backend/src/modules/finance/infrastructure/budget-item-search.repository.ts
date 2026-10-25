import { BudgetCategoryKind, Prisma } from '@prisma/client';

/**
 * G40: every wedding item of the plan, in the order acceptance reads them
 * (`createCostFromAcceptedOffer`), whoever asks: a contributor sees only
 * some rows, but a category lands in the same item for everyone. The mahr
 * item is not wedding money, so no offer lands there (C1).
 */
export function listPlanItemsForProviderSearch(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
): Promise<Array<{ id: string; name: string; normalizedName: string }>> {
  return tx.budgetCategory.findMany({
    where: { weddingPlanId, kind: BudgetCategoryKind.WEDDING },
    select: { id: true, name: true, normalizedName: true },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });
}
