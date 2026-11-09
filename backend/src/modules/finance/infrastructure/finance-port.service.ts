import { randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import {
  BudgetItemSuggestion,
  type BudgetCategory,
  BudgetCategoryKind,
  type CostPayer,
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
  budgetItemForService,
  normalizeBudgetCategoryName,
  OTHER_BUDGET_CATEGORY_NAME,
} from '../domain/cost-category-matching';
import { listPlanItemsForProviderSearch } from './budget-item-search.repository';
import {
  CATALOG_READ_PORT,
  type CatalogReadPort,
} from '../../catalog/public/catalog-read.port';
import { isVenueBudgetCategoryName } from '../domain/cost-category-matching';
import { deriveCostStatus } from '../domain/wedding-cost-aggregate';
import { estimateCoverOf, expectedItem } from '../domain/expected-cost-policy';
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
  ImportedFundingSourceInput,
  ImportedItemAmountInput,
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
import { scheduleAmountDue } from '../domain/payment-schedule-policy';

// RA-BE-53: a pending schedule leaves finance asking for what its cost still
// owes, at most, so the dashboard, its money items and the reminders name the
// payment that is actually due.
function amountDueOf(
  amount: Prisma.Decimal,
  cost: { totalAmount: Prisma.Decimal; paidAmount: Prisma.Decimal },
): Prisma.Decimal {
  return scheduleAmountDue(amount, cost.totalAmount, cost.paidAmount);
}

/** A row id made before its write, in the schema's own form (a cuid). */
function newRowId(): string {
  return `c${randomUUID().replaceAll('-', '').slice(0, 24)}`;
}

@Injectable()
export class FinancePortService implements FinancePort {
  constructor(
    // D73: the money catalog's explicit item-to-category links.
    @Inject(CATALOG_READ_PORT) private readonly catalog: CatalogReadPort,
  ) {}

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

  async createImportedCostsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    costs: readonly ImportedCostInput[],
  ): Promise<void> {
    if (costs.length === 0) return;
    // The import validated paid <= total before calling the port.
    //
    // RA-BE-63: each agreement is written as it happened. A reminder is
    // checked against what is left when it is written (the database's
    // `PaymentSchedule_amount_at_write_integrity`), and on the phone it was
    // written before the payments that came after it. So the agreements are
    // made unpaid with their reminders, then their payments are recorded and
    // their paid totals set; the ledger's own checks run at the end of the
    // transaction, on every agreement.
    //
    // RA-BE-113: four statements whatever the size of the plan, with the ids
    // made here so a payment finds its date (D106). One statement per row
    // ran past the transaction's time on a plan at the caps (RA-BE-64).
    const rows = costs.map((cost) => {
      const entryKind = cost.entryKind ?? 'AGREEMENT';
      return {
        id: newRowId(),
        cost,
        entryKind,
        cover: estimateCoverOf({
          entryKind,
          totalAmount: cost.totalAmount,
          estimateCover: cost.estimateCover ?? null,
          estimatePart: cost.estimatePart ?? null,
        }),
        scheduleIds: cost.paymentSchedules.map(() => newRowId()),
      };
    });
    const unpaid = new Prisma.Decimal(0);
    await tx.weddingCost.createMany({
      data: rows.map(({ id, cost, entryKind, cover }) => ({
        id,
        weddingPlanId,
        budgetCategoryId: cost.budgetCategoryId,
        title: cost.title,
        partyName: cost.partyName,
        partyPhone: cost.partyPhone,
        totalAmount: cost.totalAmount,
        paidAmount: unpaid,
        agreementDate: cost.agreementDate,
        status: deriveCostStatus(cost.totalAmount, unpaid),
        note: cost.note,
        payer: (cost.payer as CostPayer | null | undefined) ?? null,
        payerName: cost.payerName ?? null,
        entryKind,
        estimateCover: cover.estimateCover,
        estimatePart: cover.estimatePart,
      })),
    });
    const schedules = rows.flatMap(({ id, cost, scheduleIds }) =>
      cost.paymentSchedules.map((schedule, index) => ({
        id: scheduleIds[index],
        weddingCostId: id,
        amount: schedule.amount,
        dueDate: schedule.dueDate,
        note: schedule.note,
        remindAt: schedule.remindAt ?? null,
        rescheduledFrom: schedule.rescheduledFrom ?? null,
      })),
    );
    if (schedules.length > 0) {
      await tx.paymentSchedule.createMany({ data: schedules });
    }
    const payments = rows.flatMap(({ id, cost, scheduleIds }) =>
      cost.payments.map((payment) => ({
        weddingCostId: id,
        amount: payment.amount,
        paidAt: payment.paidAt,
        method: payment.method,
        note: payment.note,
        lowersScheduleId:
          payment.lowersScheduleIndex === null || payment.lowersScheduleIndex === undefined
            ? null
            : (scheduleIds[payment.lowersScheduleIndex] ?? null),
      })),
    );
    if (payments.length === 0) return;
    await tx.costPayment.createMany({ data: payments });
    const paid = rows.filter(({ cost }) => cost.payments.length > 0);
    await tx.$executeRaw`
      UPDATE "WeddingCost" AS cost
      SET "paidAmount" = paid.amount,
          "status" = paid.status::"WeddingCostStatus",
          "updatedAt" = NOW()
      FROM (
        SELECT
          unnest(${paid.map((row) => row.id)}::text[]) AS id,
          unnest(${paid.map((row) => row.cost.paidAmount.toString())}::numeric[]) AS amount,
          unnest(${paid.map((row) => deriveCostStatus(row.cost.totalAmount, row.cost.paidAmount))}::text[]) AS status
      ) AS paid
      WHERE cost.id = paid.id
    `;
  }

  async setImportedItemAmountsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    budget: Prisma.Decimal | null,
    items: readonly ImportedItemAmountInput[],
  ): Promise<void> {
    if (items.length === 0) return;
    const kinds = new Map(
      (
        await tx.budgetCategory.findMany({
          where: { weddingPlanId, id: { in: items.map((item) => item.budgetCategoryId) } },
          select: { id: true, kind: true },
        })
      ).map((row) => [row.id, row.kind]),
    );
    // C1: the mahr carries no allocation. The allocations come over only
    // while they fit the budget (the account's own rule, enforced by the
    // database): a phone's plan is never refused for them.
    const allocations = items.filter(
      // RA-BE-29: «0» is no allocation.
      (item) =>
        item.allocatedAmount !== null &&
        item.allocatedAmount.gt(0) &&
        kinds.get(item.budgetCategoryId) === BudgetCategoryKind.WEDDING,
    );
    const allocated = allocations.reduce(
      (sum, item) => sum.plus(item.allocatedAmount as Prisma.Decimal),
      new Prisma.Decimal(0),
    );
    const keepAllocations =
      budget !== null && allocated.gt(0) && !allocated.gt(budget);
    const writes = items.flatMap((item) => {
      if (!kinds.has(item.budgetCategoryId)) return [];
      const allocation =
        keepAllocations && allocations.includes(item) ? item.allocatedAmount : null;
      if (allocation === null && item.estimatedAmount === null) return [];
      return [{ id: item.budgetCategoryId, allocation, estimate: item.estimatedAmount }];
    });
    if (writes.length === 0) return;
    // RA-BE-113: one statement for every item; a value not given is kept.
    // An array parameter cannot carry a null beside values (the driver
    // refuses it, 08P01), so «not given» travels as '' and is read as null.
    await tx.$executeRaw`
      UPDATE "BudgetCategory" AS item
      SET "allocatedAmount" = COALESCE(NULLIF(next.allocation, '')::numeric, item."allocatedAmount"),
          "estimatedAmount" = COALESCE(NULLIF(next.estimate, '')::numeric, item."estimatedAmount"),
          "updatedAt" = NOW()
      FROM (
        SELECT
          unnest(${writes.map((write) => write.id)}::text[]) AS id,
          unnest(${writes.map((write) => write.allocation?.toString() ?? '')}::text[]) AS allocation,
          unnest(${writes.map((write) => write.estimate?.toString() ?? '')}::text[]) AS estimate
      ) AS next
      WHERE item.id = next.id
    `;
  }

  async createImportedFundingSourcesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    persona: string | null,
    sources: readonly ImportedFundingSourceInput[],
  ): Promise<void> {
    // RA-BE-113: two statements whatever their number, the ids made here.
    const rows = sources.map((source) => {
      // The mahr is money coming in on the bride's plan only; on another
      // plan the money is kept, as «other».
      const kind =
        source.kind === FundingSourceKind.MAHR && persona !== 'BRIDE'
          ? FundingSourceKind.OTHER
          : (source.kind as FundingSourceKind);
      // Repayments go with a loan, and never more than it (in order).
      let room = source.amount;
      const repayments =
        kind === FundingSourceKind.LOAN
          ? source.repayments.filter((repayment) => {
              if (repayment.amount.gt(room)) return false;
              room = room.minus(repayment.amount);
              return true;
            })
          : [];
      return { id: newRowId(), kind, source, repayments };
    });
    if (rows.length === 0) return;
    await tx.fundingSource.createMany({
      data: rows.map(({ id, kind, source }) => ({
        id,
        weddingPlanId,
        kind,
        sourceName: source.sourceName,
        sourcePhone: source.sourcePhone,
        contributorName: source.contributorName,
        amount: source.amount,
        status: source.status,
        receivedAt: source.status === FundingSourceStatus.RECEIVED ? source.receivedAt : null,
        expectedAt: source.status === FundingSourceStatus.PLEDGED ? source.expectedAt : null,
        note: source.note,
      })),
    });
    const repayments = rows.flatMap(({ id, repayments: own }) =>
      own.map((repayment) => ({
        fundingSourceId: id,
        amount: repayment.amount,
        dueDate: repayment.dueDate,
        status: repayment.status,
        paidAt:
          repayment.status === LoanRepaymentStatus.PAID
            ? (repayment.paidAt ?? new Date())
            : null,
        note: repayment.note,
      })),
    );
    if (repayments.length > 0) {
      await tx.loanRepayment.createMany({ data: repayments });
    }
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
    const schedules = await client.paymentSchedule.findMany({
      where: {
        status: PaymentScheduleStatus.PENDING,
        weddingCost: {
          weddingPlanId,
          ...(costIds ? { id: { in: [...costIds] } } : {}),
          status: { not: WeddingCostStatus.CANCELLED },
        },
      },
      include: {
        weddingCost: {
          select: { title: true, totalAmount: true, paidAmount: true },
        },
      },
      orderBy: [{ dueDate: 'asc' }, { createdAt: 'asc' }],
    });
    return schedules.map(({ weddingCost, ...schedule }) => ({
      ...schedule,
      amount: amountDueOf(schedule.amount, weddingCost),
      weddingCost: { title: weddingCost.title },
    }));
  }

  async listDuePaymentSchedules(
    client: Prisma.TransactionClient,
    query: DuePaymentScheduleQuery,
  ): Promise<DuePaymentSchedule[]> {
    if (query.weddingPlanIds.length === 0 || query.scheduleIds?.length === 0) {
      return [];
    }
    const schedules = await client.paymentSchedule.findMany({
      where: {
        ...(query.scheduleIds ? { id: { in: [...query.scheduleIds] } } : {}),
        // D106: a reminder day of its own may be further out than the window.
        ...(query.remindBefore
          ? {
              OR: [
                { dueDate: { lte: query.dueBefore } },
                { remindAt: { lte: query.remindBefore } },
              ],
            }
          : { dueDate: { lte: query.dueBefore } }),
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
            totalAmount: true,
            paidAmount: true,
          },
        },
      },
    });
    return schedules.map(({ weddingCost, ...schedule }) => {
      const { totalAmount, paidAmount, ...cost } = weddingCost;
      return {
        ...schedule,
        amount: amountDueOf(schedule.amount, { totalAmount, paidAmount }),
        weddingCost: cost,
      };
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
      select: {
        id: true,
        weddingPlanId: true,
        name: true,
        allocatedAmount: true,
        estimatedAmount: true,
        suggestion: true,
      },
    });
    if (categories.length === 0) return [];
    // The money summary's rule (D105): non-cancelled agreements, and the
    // estimate they have not settled.
    const costs = await client.weddingCost.findMany({
      where: {
        budgetCategoryId: { in: categories.map((category) => category.id) },
        status: { not: WeddingCostStatus.CANCELLED },
        // V1 checklist 4.10: a private cost never feeds the owner's
        // plan-wide alert (it would reveal the cost indirectly).
        privateToUserId: null,
      },
      select: {
        budgetCategoryId: true,
        totalAmount: true,
        estimateCover: true,
        estimatePart: true,
      },
    });
    const zero = new Prisma.Decimal(0);
    // RA-BE-117: each item's agreements in one pass, not one scan of every
    // agreement per item (the hourly due scan reads all planning plans).
    const costsByItem = new Map<string, typeof costs>();
    for (const cost of costs) {
      const list = costsByItem.get(cost.budgetCategoryId);
      if (list) list.push(cost);
      else costsByItem.set(cost.budgetCategoryId, [cost]);
    }
    return categories.flatMap((category) => {
      if (!category.allocatedAmount) return [];
      const expected = expectedItem(
        {
          allocatedAmount: category.allocatedAmount,
          estimatedAmount: category.estimatedAmount,
          notNeeded: category.suggestion === BudgetItemSuggestion.NOT_NEEDED,
        },
        costsByItem.get(category.id) ?? [],
        zero,
      );
      if (!expected.expected.gt(category.allocatedAmount)) return [];
      return [
        {
          id: category.id,
          weddingPlanId: category.weddingPlanId,
          name: category.name,
          allocatedAmount: category.allocatedAmount,
          committedAmount: expected.agreed,
          expectedAmount: expected.expected,
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

  async findItemForService(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    serviceName: string,
    planPersona: string | null,
  ): Promise<string | null> {
    const [items, providerCategories, catalogItems] = await Promise.all([
      listPlanItemsForProviderSearch(client, weddingPlanId),
      this.catalog.listActiveCategories(client),
      this.catalog.listMoneyCatalogItems(client),
    ]);
    return (
      budgetItemForService(items, serviceName, providerCategories, {
        planPersona,
        items: catalogItems,
      })?.id ?? null
    );
  }

  async isPlanItem(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    budgetCategoryId: string,
  ): Promise<boolean> {
    const item = await client.budgetCategory.findFirst({
      where: { id: budgetCategoryId, weddingPlanId },
      select: { id: true },
    });
    return item !== null;
  }

  async findPlanSchedule(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scheduleId: string,
  ): Promise<{ costId: string; settled: boolean } | null> {
    const schedule = await client.paymentSchedule.findFirst({
      where: { id: scheduleId, weddingCost: { weddingPlanId } },
      select: { weddingCostId: true, status: true },
    });
    if (!schedule) return null;
    return {
      costId: schedule.weddingCostId,
      settled: schedule.status === PaymentScheduleStatus.PAID,
    };
  }

  async createCostFromAcceptedOffer(
    tx: Prisma.TransactionClient,
    input: CreateCostFromAcceptedOfferInput,
  ): Promise<WeddingCostWithDetails> {
    // A provider's offer is wedding money, never the mahr (C1). The matcher
    // takes the first item that fits: the plan's own order. The money
    // summary reads the same items and rule for «ابحث» (G40), and the same
    // money catalog links (D73).
    const [categories, catalogItems] = await Promise.all([
      listPlanItemsForProviderSearch(tx, input.weddingPlanId),
      this.catalog.listMoneyCatalogItems(tx),
    ]);
    let category = budgetItemForProviderCategory(
      categories,
      input.providerCategoryName,
      {
        providerCategorySlug: input.providerCategorySlug,
        catalog: { planPersona: input.planPersona, items: catalogItems },
      },
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
