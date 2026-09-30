import type { Prisma } from '@prisma/client';

export function createBudgetCategory(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  name: string,
  normalizedName: string,
  allocatedAmount: Prisma.Decimal | null,
) {
  return tx.budgetCategory.create({
    data: { weddingPlanId, name, normalizedName, allocatedAmount },
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
) {
  return tx.budgetCategory.update({
    where: { id },
    data: { name, normalizedName, allocatedAmount },
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

export function countWeddingPlanCosts(tx: Prisma.TransactionClient, weddingPlanId: string) {
  return tx.weddingCost.count({ where: { weddingPlanId } });
}

export function findBudgetCategoriesForReplacement(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
) {
  return tx.budgetCategory.findMany({
    where: { weddingPlanId },
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
) {
  return tx.budgetCategory.update({
    where: { id },
    data: { name, normalizedName, allocatedAmount },
  });
}

export function createReplacementBudgetCategory(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  name: string,
  normalizedName: string,
  allocatedAmount: Prisma.Decimal | null,
) {
  return tx.budgetCategory.create({
    data: { weddingPlanId, name, normalizedName, allocatedAmount },
  });
}

export function listReplacedBudgetCategories(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
) {
  return tx.budgetCategory.findMany({
    where: { weddingPlanId },
    include: { _count: { select: { weddingCosts: true } } },
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });
}
