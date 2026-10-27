import { Injectable } from '@nestjs/common';
import {
  type BudgetCategory,
  BudgetCategoryKind,
  CostPaymentType,
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
  PaymentScheduleStatus,
  Prisma,
  WeddingCostStatus,
} from '@prisma/client';
import {
  budgetItemForProviderCategory,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
} from '../domain/cost-category-matching';
import { listPlanItemsForProviderSearch } from './budget-item-search.repository';
import { isVenueBudgetCategoryName } from '../domain/cost-category-matching';
import { deriveCostStatus } from '../domain/wedding-cost-aggregate';
import { parseMahrAgreement } from '../public/mahr-agreement';
import { deletePlanFundingSources } from './funding-sources.repository';
import { recordPlanMahrInTransaction } from './mahr.repository';
import { excludeOthersPrivateCosts } from './cost-privacy.repository';
import {
  deleteReceipts,
  listPlanReceiptIds,
  listPrivateCostReceiptIds,
  listReceiptIdsUploadedBy,
} from './cost-receipts.repository';
import { type MoneyPicture, type MoneyPictureQuery, readMoneyPicture } from './money-picture';
import type {
  CreateCostFromAcceptedOfferInput,
  DueExpectedFunding,
  DueLoanRepayment,
  DuePaymentSchedule,
  DuePaymentScheduleQuery,
  ExceededBudgetCategory,
  FinancePort,
  ImportedCostInput,
  MahrAgreementRequest,
  OfferCost,
  PendingPaymentSchedule,
  PlanImportCounts,
  RecordedCostCounts,
  SpendingSample,
} from '../public/finance.port';
import {
  weddingCostResponseInclude,
  type WeddingCostWithDetails,
} from '../public/wedding-cost.presenter';

@Injectable()
export class FinancePortService implements FinancePort {
  excludeOthersPrivateCosts(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    readerUserId: string,
    costIds: readonly string[] | null,
  ): Promise<string[] | null> {
    return excludeOthersPrivateCosts(client, weddingPlanId, readerUserId, costIds);
  }

  async listErasedReceiptIdsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    userId: string,
  ): Promise<string[]> {
    const [inPlans, uploaded, onPrivateCosts] = await Promise.all([
      listPlanReceiptIds(tx, weddingPlanIds),
      listReceiptIdsUploadedBy(tx, userId),
      listPrivateCostReceiptIds(tx, userId),
    ]);
    return [...new Set([...inPlans, ...uploaded, ...onPrivateCosts])].sort();
  }

  async lockPrivateCostsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingCost"
        WHERE "privateToUserId" = ${userId}
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
  }

  async purgePrivateCostsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void> {
    const costs = await tx.weddingCost.findMany({
      where: { privateToUserId: userId },
      select: { id: true },
    });
    if (costs.length === 0) return;
    const ofCosts = { weddingCostId: { in: costs.map((cost) => cost.id) } };
    // The same transaction-local ledger purge as the plan erasure below.
    await tx.$executeRaw`
      SELECT set_config('aarast.allow_ledger_purge', 'on', true)
    `;
    await tx.costPayment.deleteMany({ where: ofCosts });
    await tx.paymentSchedule.deleteMany({ where: ofCosts });
    await tx.weddingCost.deleteMany({ where: { privateToUserId: userId } });
  }

  async deleteReceiptsInTransaction(
    tx: Prisma.TransactionClient,
    receiptIds: readonly string[],
  ): Promise<void> {
    await deleteReceipts(tx, receiptIds);
  }

  async countRecordedCosts(client: Prisma.TransactionClient): Promise<RecordedCostCounts> {
    const [costs, plans] = await Promise.all([
      client.weddingCost.count(),
      client.weddingCost.groupBy({ by: ['weddingPlanId'] }),
    ]);
    return { costs, plans: plans.length };
  }

  async listSpendingSamples(client: Prisma.TransactionClient): Promise<SpendingSample[]> {
    const groups = await client.weddingCost.groupBy({
      by: ['weddingPlanId', 'budgetCategoryId'],
      where: {
        status: { not: WeddingCostStatus.CANCELLED },
        privateToUserId: null,
        budgetCategory: { kind: BudgetCategoryKind.WEDDING },
      },
      _sum: { totalAmount: true },
    });
    if (groups.length === 0) return [];
    const categories = await client.budgetCategory.findMany({
      where: { id: { in: [...new Set(groups.map((group) => group.budgetCategoryId))] } },
      select: { id: true, normalizedName: true },
    });
    const names = new Map(categories.map((category) => [category.id, category.normalizedName]));
    return groups.flatMap((group) => {
      const itemName = names.get(group.budgetCategoryId);
      const total = group._sum.totalAmount;
      return itemName && total && total.gt(0)
        ? [{ weddingPlanId: group.weddingPlanId, itemName, total }]
        : [];
    });
  }

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
    // The import validated paid <= total before calling the port.
    const status = deriveCostStatus(cost.totalAmount, cost.paidAmount);
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

  async lockPlanCostsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    if (weddingPlanIds.length === 0) return;
    await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingCost"
        WHERE "weddingPlanId" IN (${Prisma.join([...weddingPlanIds])})
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
  }

  async purgePlanLedgerInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    const inPlans = { weddingPlanId: { in: [...weddingPlanIds] } };
    // CostPayment is append-only during normal product work. Account
    // erasure is the one explicit, transaction-local purge path.
    await tx.$executeRaw`
      SELECT set_config('aarast.allow_ledger_purge', 'on', true)
    `;
    await tx.costPayment.deleteMany({ where: { weddingCost: inPlans } });
    await tx.paymentSchedule.deleteMany({ where: { weddingCost: inPlans } });
    await tx.weddingCost.deleteMany({ where: inPlans });
    // Funding sources reference the plan (Restrict); their repayments cascade.
    await deletePlanFundingSources(tx, weddingPlanIds);
  }

  async deletePlanBudgetCategoriesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    await tx.budgetCategory.deleteMany({
      where: { weddingPlanId: { in: [...weddingPlanIds] } },
    });
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

  readMoneyPicture(
    client: Prisma.TransactionClient,
    query: MoneyPictureQuery,
  ): Promise<MoneyPicture> {
    return readMoneyPicture(client, query);
  }

  async recordMahrInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    persona: string | null,
    request: MahrAgreementRequest,
    recordedAt: Date,
  ): Promise<void> {
    await recordPlanMahrInTransaction(
      tx,
      weddingPlanId,
      persona,
      parseMahrAgreement(request),
      recordedAt,
    );
  }

  async hasVenueCost(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    costIds?: readonly string[] | null,
  ): Promise<boolean> {
    const costs = await client.weddingCost.findMany({
      where: {
        weddingPlanId,
        ...(costIds ? { id: { in: [...costIds] } } : {}),
        status: { not: WeddingCostStatus.CANCELLED },
      },
      select: { budgetCategory: { select: { name: true } } },
    });
    return costs.some((cost) => isVenueBudgetCategoryName(cost.budgetCategory.name));
  }

  async listPendingPaymentSchedules(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    costIds?: readonly string[] | null,
  ): Promise<PendingPaymentSchedule[]> {
    return client.paymentSchedule.findMany({
      where: {
        status: PaymentScheduleStatus.PENDING,
        weddingCost: {
          weddingPlanId,
          ...(costIds ? { id: { in: [...costIds] } } : {}),
          status: { not: WeddingCostStatus.CANCELLED },
        },
      },
      include: { weddingCost: { select: { title: true } } },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    });
  }

  async listDuePaymentSchedules(
    client: Prisma.TransactionClient,
    query: DuePaymentScheduleQuery,
  ): Promise<DuePaymentSchedule[]> {
    if (query.weddingPlanIds.length === 0 || query.scheduleIds?.length === 0) {
      return [];
    }
    return client.paymentSchedule.findMany({
      where: {
        ...(query.scheduleIds ? { id: { in: [...query.scheduleIds] } } : {}),
        dueDate: { lte: query.dueBefore },
        status: PaymentScheduleStatus.PENDING,
        weddingCost: {
          weddingPlanId: { in: [...query.weddingPlanIds] },
          status: { not: WeddingCostStatus.CANCELLED },
        },
      },
      include: {
        weddingCost: {
          select: {
            weddingPlanId: true,
            title: true,
            partyName: true,
            providerId: true,
            privateToUserId: true,
          },
        },
      },
    });
  }

  async listExceededBudgetCategories(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<ExceededBudgetCategory[]> {
    if (weddingPlanIds.length === 0) return [];
    const categories = await client.budgetCategory.findMany({
      where: {
        weddingPlanId: { in: [...weddingPlanIds] },
        allocatedAmount: { not: null },
      },
      select: { id: true, weddingPlanId: true, name: true, allocatedAmount: true },
    });
    if (categories.length === 0) return [];
    // The same committed total the money summary uses: non-cancelled costs.
    const totals = await client.weddingCost.groupBy({
      by: ['budgetCategoryId'],
      where: {
        budgetCategoryId: { in: categories.map((category) => category.id) },
        status: { not: WeddingCostStatus.CANCELLED },
        // V1 checklist 4.10: a private cost never feeds the owner's
        // plan-wide alert (it would reveal the cost indirectly).
        privateToUserId: null,
      },
      _sum: { totalAmount: true },
    });
    const committedByCategory = new Map(
      totals.map((total) => [total.budgetCategoryId, total._sum.totalAmount]),
    );
    return categories.flatMap((category) => {
      const committed = committedByCategory.get(category.id);
      if (!committed || !category.allocatedAmount) return [];
      if (!committed.gt(category.allocatedAmount)) return [];
      return [
        {
          id: category.id,
          weddingPlanId: category.weddingPlanId,
          name: category.name,
          allocatedAmount: category.allocatedAmount,
          committedAmount: committed,
        },
      ];
    });
  }

  async listDueLoanRepayments(
    client: Prisma.TransactionClient,
    query: { weddingPlanIds: readonly string[]; dueBefore: Date },
  ): Promise<DueLoanRepayment[]> {
    if (query.weddingPlanIds.length === 0) return [];
    const repayments = await client.loanRepayment.findMany({
      where: {
        status: LoanRepaymentStatus.PLANNED,
        dueDate: { lte: query.dueBefore },
        fundingSource: {
          weddingPlanId: { in: [...query.weddingPlanIds] },
          kind: FundingSourceKind.LOAN,
          // G33: a promised loan is no debt until it arrives.
          status: FundingSourceStatus.RECEIVED,
        },
      },
      include: {
        fundingSource: { select: { weddingPlanId: true, sourceName: true } },
      },
    });
    return repayments.flatMap((repayment) =>
      repayment.dueDate
        ? [
            {
              id: repayment.id,
              weddingPlanId: repayment.fundingSource.weddingPlanId,
              sourceName: repayment.fundingSource.sourceName,
              amount: repayment.amount,
              dueDate: repayment.dueDate,
            },
          ]
        : [],
    );
  }

  async listDueExpectedFunding(
    client: Prisma.TransactionClient,
    query: { weddingPlanIds: readonly string[]; dueBefore: Date },
  ): Promise<DueExpectedFunding[]> {
    if (query.weddingPlanIds.length === 0) return [];
    const sources = await client.fundingSource.findMany({
      where: {
        weddingPlanId: { in: [...query.weddingPlanIds] },
        status: FundingSourceStatus.PLEDGED,
        expectedAt: { not: null, lte: query.dueBefore },
      },
      select: {
        id: true,
        weddingPlanId: true,
        kind: true,
        sourceName: true,
        amount: true,
        expectedAt: true,
      },
      orderBy: [{ expectedAt: 'asc' }, { id: 'asc' }],
    });
    return sources.flatMap((source) =>
      source.expectedAt ? [{ ...source, expectedAt: source.expectedAt }] : [],
    );
  }

  async listPaymentScheduleIdsForCosts(
    client: Prisma.TransactionClient,
    scopes: ReadonlyArray<{ weddingPlanId: string; costIds: readonly string[] }>,
  ): Promise<Array<{ id: string; weddingPlanId: string }>> {
    const clauses = scopes.flatMap((scope) =>
      scope.costIds.length === 0
        ? []
        : [{ weddingCost: { weddingPlanId: scope.weddingPlanId, id: { in: [...scope.costIds] } } }],
    );
    if (clauses.length === 0) return [];
    const schedules = await client.paymentSchedule.findMany({
      where: { OR: clauses },
      select: { id: true, weddingCost: { select: { weddingPlanId: true } } },
    });
    return schedules.map((schedule) => ({
      id: schedule.id,
      weddingPlanId: schedule.weddingCost.weddingPlanId,
    }));
  }

  async isPaymentScheduleOfCosts(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scheduleId: string,
    costIds: readonly string[],
  ): Promise<boolean> {
    if (costIds.length === 0) return false;
    const schedule = await client.paymentSchedule.findFirst({
      where: {
        id: scheduleId,
        weddingCost: { weddingPlanId, id: { in: [...costIds] } },
      },
      select: { id: true },
    });
    return schedule !== null;
  }

  async lockCostRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    costIds: readonly string[],
  ): Promise<void> {
    const sortedIds = [...new Set(costIds)].sort();
    if (sortedIds.length === 0) return;
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingCost"
        WHERE "id" = ANY(${sortedIds}::text[])
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
  }

  async lockPaymentScheduleRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    scheduleIds: readonly string[],
  ): Promise<void> {
    const sortedIds = [...new Set(scheduleIds)].sort();
    if (sortedIds.length === 0) return;
    await tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "PaymentSchedule"
        WHERE "id" = ANY(${sortedIds}::text[])
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
  }

  async listCostsForOffers(
    client: Prisma.TransactionClient,
    quoteOfferIds: readonly string[],
  ): Promise<OfferCost[]> {
    if (quoteOfferIds.length === 0) return [];
    const costs = await client.weddingCost.findMany({
      where: { quoteOfferId: { in: [...quoteOfferIds] } },
      select: {
        id: true,
        quoteOfferId: true,
        budgetCategoryId: true,
        totalAmount: true,
        paidAmount: true,
        status: true,
        // B-18: when money last reached him (a reversal is not a payment).
        payments: {
          where: { entryType: CostPaymentType.PAYMENT, reversedBy: null },
          orderBy: { paidAt: 'desc' },
          take: 1,
          select: { paidAt: true },
        },
      },
    });
    return costs.flatMap((cost) =>
      cost.quoteOfferId
        ? [
            {
              id: cost.id,
              quoteOfferId: cost.quoteOfferId,
              budgetCategoryId: cost.budgetCategoryId,
              totalAmount: cost.totalAmount,
              paidAmount: cost.paidAmount,
              status: cost.status,
              lastPaidAt: cost.payments[0]?.paidAt ?? null,
            },
          ]
        : [],
    );
  }

  async listOutsidePartyItemIds(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    costIds: readonly string[] | null,
  ): Promise<string[]> {
    const costs = await client.weddingCost.findMany({
      where: {
        weddingPlanId,
        providerId: null,
        quoteOfferId: null,
        status: { not: WeddingCostStatus.CANCELLED },
        partyName: { not: null },
        NOT: { partyName: '' },
        budgetCategory: { kind: { not: BudgetCategoryKind.MAHR } },
        ...(costIds ? { id: { in: [...costIds] } } : {}),
      },
      select: { budgetCategoryId: true, partyName: true },
      orderBy: { budgetCategoryId: 'asc' },
    });
    return [
      ...new Set(
        costs
          .filter((cost) => (cost.partyName ?? '').trim() !== '')
          .map((cost) => cost.budgetCategoryId),
      ),
    ];
  }

  async createCostFromAcceptedOffer(
    tx: Prisma.TransactionClient,
    input: CreateCostFromAcceptedOfferInput,
  ): Promise<WeddingCostWithDetails> {
    // A provider's offer is wedding money, never the mahr (C1). The matcher
    // takes the first item that fits: the plan's own order. The money
    // summary reads the same items and rule for «ابحث» (G40).
    const categories = await listPlanItemsForProviderSearch(
      tx,
      input.weddingPlanId,
    );
    let category = budgetItemForProviderCategory(
      categories,
      input.providerCategoryName,
    );
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
