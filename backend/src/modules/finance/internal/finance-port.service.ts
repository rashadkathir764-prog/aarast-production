import { Injectable } from '@nestjs/common';
import { type BudgetCategory, Prisma, WeddingCostStatus } from '@prisma/client';
import {
  findLogicalBudgetCategory,
  findOtherBudgetCategory,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
} from '../domain/cost-category-matching';
import type {
  CreateCostFromAcceptedOfferInput,
  FinancePort,
  ImportedCostInput,
  PlanImportCounts,
} from '../public/finance.port';
import {
  weddingCostResponseInclude,
  type WeddingCostWithDetails,
} from '../public/wedding-cost.presenter';

@Injectable()
export class FinancePortService implements FinancePort {
  async createBudgetCategoriesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    names: readonly string[],
  ): Promise<BudgetCategory[]> {
    if (names.length > 0) {
      await tx.budgetCategory.createMany({
        data: names.map((name) => ({
          weddingPlanId,
          name,
          normalizedName: normalizeBudgetCategoryName(name),
        })),
      });
    }
    return this.listBudgetCategories(tx, weddingPlanId);
  }

  async listBudgetCategories(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<BudgetCategory[]> {
    return client.budgetCategory.findMany({
      where: { weddingPlanId },
      orderBy: { createdAt: 'asc' },
    });
  }

  async createImportedCostInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    cost: ImportedCostInput,
  ): Promise<void> {
    const status = cost.paidAmount.isZero()
      ? WeddingCostStatus.OPEN
      : cost.paidAmount.eq(cost.totalAmount)
        ? WeddingCostStatus.PAID
        : WeddingCostStatus.PARTIALLY_PAID;
    await tx.weddingCost.create({
      data: {
        weddingPlanId,
        budgetCategoryId: cost.budgetCategoryId,
        title: cost.title,
        partyName: cost.partyName,
        partyPhone: cost.partyPhone,
        totalAmount: cost.totalAmount,
        paidAmount: cost.paidAmount,
        agreementDate: cost.agreementDate,
        status,
        note: cost.note,
        payments: {
          create: cost.payments.map((payment) => ({
            amount: payment.amount,
            paidAt: payment.paidAt,
            method: payment.method,
            note: payment.note,
          })),
        },
        paymentSchedules: {
          create: cost.paymentSchedules.map((schedule) => ({
            amount: schedule.amount,
            dueDate: schedule.dueDate,
            note: schedule.note,
          })),
        },
      },
    });
  }

  async getPlanImportCounts(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<PlanImportCounts> {
    const [costs, payments, paymentSchedules] = await Promise.all([
      client.weddingCost.count({ where: { weddingPlanId } }),
      client.costPayment.count({
        where: { weddingCost: { weddingPlanId } },
      }),
      client.paymentSchedule.count({
        where: { weddingCost: { weddingPlanId } },
      }),
    ]);
    return { costs, payments, paymentSchedules };
  }

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
