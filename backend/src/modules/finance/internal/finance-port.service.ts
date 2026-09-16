import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  findLogicalBudgetCategory,
  findOtherBudgetCategory,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
} from '../domain/cost-category-matching';
import type {
  CreateCostFromAcceptedOfferInput,
  FinancePort,
} from '../public/finance.port';
import {
  weddingCostResponseInclude,
  type WeddingCostWithDetails,
} from '../public/wedding-cost.presenter';

@Injectable()
export class FinancePortService implements FinancePort {
  async findCostForAcceptedOffer(
    tx: Prisma.TransactionClient,
    quoteOfferId: string,
  ): Promise<WeddingCostWithDetails | null> {
    return tx.weddingCost.findFirst({
      where: { quoteOfferId },
      include: weddingCostResponseInclude,
    });
  }

  async createCostFromAcceptedOffer(
    tx: Prisma.TransactionClient,
    input: CreateCostFromAcceptedOfferInput,
  ): Promise<WeddingCostWithDetails> {
    const categories = await tx.budgetCategory.findMany({
      where: { weddingPlanId: input.weddingPlanId },
      select: { id: true, name: true, normalizedName: true },
    });
    let category = findLogicalBudgetCategory(
      categories,
      input.providerCategoryName,
    );
    category ??= findOtherBudgetCategory(categories);
    if (!category) {
      category = await tx.budgetCategory.upsert({
        where: {
          weddingPlanId_normalizedName: {
            weddingPlanId: input.weddingPlanId,
            normalizedName: normalizeBudgetCategoryName(
              OTHER_BUDGET_CATEGORY_NAME,
            ),
          },
        },
        update: {},
        create: {
          weddingPlanId: input.weddingPlanId,
          name: OTHER_BUDGET_CATEGORY_NAME,
          normalizedName: normalizeBudgetCategoryName(
            OTHER_BUDGET_CATEGORY_NAME,
          ),
        },
        select: { id: true, name: true, normalizedName: true },
      });
    }

    return tx.weddingCost.create({
      data: {
        weddingPlanId: input.weddingPlanId,
        budgetCategoryId: category.id,
        providerId: input.providerId,
        quoteOfferId: input.quoteOfferId,
        title: input.title,
        totalAmount: input.amount,
        paidAmount: new Prisma.Decimal(0),
      },
      include: weddingCostResponseInclude,
    });
  }
}
