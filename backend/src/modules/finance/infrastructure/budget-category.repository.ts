import {
  BudgetCategoryKind,
  type BudgetItemSuggestion,
  type Prisma,
} from '@prisma/client';

export function createBudgetCategory(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  name: string,
  normalizedName: string,
  allocatedAmount: Prisma.Decimal | null,
  estimatedAmount: Prisma.Decimal | null = null,
) {
  return tx.budgetCategory.create({
    data: { weddingPlanId, name, normalizedName, allocatedAmount, estimatedAmount },
    include: { _count: { select: { weddingCosts: true } } },
  });
}

export function listBudgetCategories(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  categoryIds: readonly string[] | null,
  costIds: readonly string[] | null,
) {
  return tx.budgetCategory.findMany({
    where: {
      weddingPlanId,
      ...(categoryIds ? { id: { in: [...categoryIds] } } : {}),
    },
    include: {
      _count: {
        select: {
          weddingCosts: costIds
            ? { where: { id: { in: [...costIds] } } }
            : true,
        },
      },
    },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });
}

export function findBudgetCategory(client: Prisma.TransactionClient, id: string) {
  return client.budgetCategory.findUnique({ where: { id } });
}

export function updateBudgetCategory(
  tx: Prisma.TransactionClient,
  id: string,
  name: string,
  normalizedName: string,
  allocatedAmount: Prisma.Decimal | null,
  scopedCostIds: readonly string[] | null,
  /** D109: undefined keeps it. */
  estimatedAmount?: Prisma.Decimal | null,
) {
  return tx.budgetCategory.update({
    where: { id },
    data: {
      name,
      normalizedName,
      allocatedAmount,
      ...(estimatedAmount === undefined ? {} : { estimatedAmount }),
    },
    include: {
      _count: {
        select: {
          weddingCosts: scopedCostIds
            ? { where: { id: { in: [...scopedCostIds] } } }
            : true,
        },
      },
    },
  });
}

/** The owner's answer to the home suggesting this item (or none). */
export function setBudgetCategorySuggestion(
  tx: Prisma.TransactionClient,
  id: string,
  suggestion: BudgetItemSuggestion | null,
  suggestionUntil: Date | null,
  scopedCostIds: readonly string[] | null,
) {
  return tx.budgetCategory.update({
    where: { id },
    data: { suggestion, suggestionUntil },
    include: {
      _count: {
        select: {
          weddingCosts: scopedCostIds
            ? { where: { id: { in: [...scopedCostIds] } } }
            : true,
        },
      },
    },
  });
}

export function countBudgetCategoryCosts(tx: Prisma.TransactionClient, id: string) {
  return tx.weddingCost.count({ where: { budgetCategoryId: id } });
}

export function deleteBudgetCategory(tx: Prisma.TransactionClient, id: string) {
  return tx.budgetCategory.delete({ where: { id } });
}

export async function sumOtherBudgetCategoryAllocations(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  excludeId?: string,
): Promise<Prisma.Decimal | null> {
  const result = await tx.budgetCategory.aggregate({
    where: {
      weddingPlanId,
      ...(excludeId ? { id: { not: excludeId } } : {}),
    },
    _sum: { allocatedAmount: true },
  });
  return result._sum.allocatedAmount;
}

/**
 * RA-BE-23: a plan's currency is fixed once money is recorded in it: an
 * agreement (any state), or a funding source, whose amounts (the bride's
 * mahr and the loans' included) have no currency of their own and read in
 * the plan's. Counting agreements alone let a bride with her mahr recorded
 * relabel 2,000,000 riyals as another currency. The money summary publishes
 * this one rule (`currencyLocked`), so the phone does not count it again.
 */
export async function isPlanCurrencyLocked(
  client: Prisma.TransactionClient,
  weddingPlanId: string,
): Promise<boolean> {
  const cost = await client.weddingCost.findFirst({
    where: { weddingPlanId },
    select: { id: true },
  });
  if (cost) return true;
  const source = await client.fundingSource.findFirst({
    where: { weddingPlanId },
    select: { id: true },
  });
  return source !== null;
}

/**
 * The wedding budget's items (w19 replaces them as a whole). The mahr item is
 * outside the budget (C1): it is neither replaced, nor omitted, nor listed.
 */
export function findBudgetCategoriesForReplacement(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
) {
  return tx.budgetCategory.findMany({
    where: { weddingPlanId, kind: BudgetCategoryKind.WEDDING },
    include: { _count: { select: { weddingCosts: true } } },
  });
}

export function deleteOmittedBudgetCategories(
  tx: Prisma.TransactionClient,
  ids: readonly string[],
) {
  return tx.budgetCategory.deleteMany({ where: { id: { in: [...ids] } } });
}

export function temporarilyRekeyBudgetCategory(tx: Prisma.TransactionClient, id: string) {
  return tx.budgetCategory.update({
    where: { id },
    data: { normalizedName: `__money_budget_rekey__${id}` },
  });
}

export function replaceBudgetCategoryValues(
  tx: Prisma.TransactionClient,
  id: string,
  name: string,
  normalizedName: string,
  allocatedAmount: Prisma.Decimal | null,
  /** D109: undefined keeps it (a phone that does not know it yet). */
  estimatedAmount?: Prisma.Decimal | null,
) {
  return tx.budgetCategory.update({
    where: { id },
    data: {
      name,
      normalizedName,
      allocatedAmount,
      ...(estimatedAmount === undefined ? {} : { estimatedAmount }),
    },
  });
}

export function createReplacementBudgetCategory(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  name: string,
  normalizedName: string,
  allocatedAmount: Prisma.Decimal | null,
  estimatedAmount: Prisma.Decimal | null = null,
) {
  return tx.budgetCategory.create({
    data: { weddingPlanId, name, normalizedName, allocatedAmount, estimatedAmount },
  });
}

/**
 * RA-BE-30: each item's agreements are counted as its reader reads them:
 * another account's private agreement (V1 4.10) is not theirs to count.
 */
export function listReplacedBudgetCategories(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  readerUserId: string,
) {
  return tx.budgetCategory.findMany({
    where: { weddingPlanId, kind: BudgetCategoryKind.WEDDING },
    include: {
      _count: {
        select: {
          weddingCosts: {
            where: { OR: [{ privateToUserId: null }, { privateToUserId: readerUserId }] },
          },
        },
      },
    },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });
}
