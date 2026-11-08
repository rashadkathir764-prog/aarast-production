import {
  BudgetCategoryKind,
  BudgetItemSuggestion,
  CostPayer,
  CostPaymentType,
  FundingSourceKind,
  FundingSourceStatus,
  LoanRepaymentStatus,
  PaymentScheduleStatus,
  Prisma,
} from '@prisma/client';
import {
  type MahrPicture,
  type MahrSide,
  mahrPicture,
  mahrSideOf,
} from '../domain/mahr-policy';
import { paidFromOwnerMoney } from '../domain/payer-policy';
import { scheduleAmountDue } from '../domain/payment-schedule-policy';
import { listOthersPrivateCostIds } from './cost-privacy.repository';
import {
  type FundingSourceWithRepayments,
  listFundingSources,
} from './funding-sources.repository';
import { loadMoneySummaryRows } from './money-summary.repository';
import type {
  MoneyPicture,
  MoneyPictureQuery,
  MoneyWarningType as WarningType,
} from '../public/money-picture';
import { isBudgetItemSuggestionHidden } from '../domain/budget-item-suggestion-policy';
import {
  type ExpectedItem,
  type ExpectedTotals,
  expectedItem,
  sumExpected,
} from '../domain/expected-cost-policy';
import {
  type Coverage,
  type CoverageRun,
  type DuesByMonth,
  type Obligation,
  type TimelineSource,
  coverageOf,
  coverageVerdict,
  listObligations,
  weddingDuesByMonth,
} from '../domain/money-timeline-policy';
import {
  type Contributor,
  familyContributions,
} from '../domain/family-contributions-policy';

/**
 * The plan's money in one read (C1, C2, D59): the wedding budget (WEDDING
 * items only), every agreement, the mahr on its own, who paid what, and the
 * owner's money in and in hand. `money-summary`, the dashboards and the
 * assistant all read it, so no screen or prompt works the money out again.
 */
export async function readMoneyPicture(
  tx: Prisma.TransactionClient,
  query: MoneyPictureQuery,
): Promise<MoneyPicture> {
  const { weddingPlanId } = query;
  const [[categories, scopedCosts, scopedPayments, scopedSchedules], fundingSources, hidden] =
    await Promise.all([
      loadMoneySummaryRows(tx, weddingPlanId, query.scope),
      query.fundingVisible ? listFundingSources(tx, weddingPlanId, true) : null,
      listOthersPrivateCostIds(tx, weddingPlanId, query.readerUserId),
    ]);
  const costs = scopedCosts.filter((cost) => !hidden.has(cost.id));
  const payments = scopedPayments.filter(
    (payment) => !hidden.has(payment.weddingCostId),
  );
  const schedules = scopedSchedules.filter(
    (schedule) => !hidden.has(schedule.weddingCostId),
  );

  const zero = () => new Prisma.Decimal(0);
  const sum = <T>(rows: readonly T[], of: (row: T) => Prisma.Decimal) =>
    rows.reduce((total, row) => total.plus(of(row)), zero());
  // C1: the groom's mahr item is outside the wedding budget. Its costs count
  // in what he agreed, paid and owes, never against the budget.
  const mahrCategoryIds = new Set(
    categories
      .filter((category) => category.kind === BudgetCategoryKind.MAHR)
      .map((category) => category.id),
  );
  const weddingCosts = costs.filter(
    (cost) => !mahrCategoryIds.has(cost.budgetCategoryId),
  );
  const netPaidByCost = new Map<string, Prisma.Decimal>();
  for (const payment of payments) {
    const signed =
      payment.entryType === CostPaymentType.REVERSAL
        ? payment.amount.negated()
        : payment.amount;
    netPaidByCost.set(
      payment.weddingCostId,
      (netPaidByCost.get(payment.weddingCostId) ?? zero()).plus(signed),
    );
  }
  const paidOf = (cost: { id: string }) => netPaidByCost.get(cost.id) ?? zero();
  // D59: whose money paid it, from the agreement's payer.
  const ownerMoney = (cost: { payer: CostPayer | null }) =>
    paidFromOwnerMoney(cost.payer, query.persona);
  const paidSplit = (rows: typeof costs) => {
    const paid = sum(rows, paidOf);
    const byOwner = sum(rows.filter(ownerMoney), paidOf);
    return { paid, byOwner, byOthers: paid.minus(byOwner) };
  };

  // D106: what live partial payments took off each date (a reversal of one
  // gives it back, and its row stays in the ledger).
  const reversedIds = new Set(
    payments
      .filter((payment) => payment.entryType === CostPaymentType.REVERSAL)
      .map((payment) => payment.reversalOfId),
  );
  const partlyPaid = new Map<string, Prisma.Decimal>();
  for (const payment of payments) {
    if (
      payment.entryType !== CostPaymentType.PAYMENT ||
      !payment.lowersScheduleId ||
      reversedIds.has(payment.id)
    ) {
      continue;
    }
    partlyPaid.set(
      payment.lowersScheduleId,
      (partlyPaid.get(payment.lowersScheduleId) ?? zero()).plus(payment.amount),
    );
  }

  // D105, D109: what each item is expected to cost. A cost whose item this
  // reader does not see (a contributor's own cost in the owner's item) counts
  // as agreed.
  const costsByCategory = new Map<string, typeof costs>();
  for (const cost of costs) {
    costsByCategory.set(cost.budgetCategoryId, [
      ...(costsByCategory.get(cost.budgetCategoryId) ?? []),
      cost,
    ]);
  }
  const expectedByCategory = new Map<string, ExpectedItem>(
    categories.map((category) => [
      category.id,
      expectedItem(
        {
          allocatedAmount: category.allocatedAmount,
          estimatedAmount: category.estimatedAmount,
          notNeeded: category.suggestion === BudgetItemSuggestion.NOT_NEEDED,
        },
        costsByCategory.get(category.id) ?? [],
        zero(),
      ),
    ]),
  );
  const shownCategoryIds = new Set(categories.map((category) => category.id));
  const expectedOutside = costs
    .filter((cost) => !shownCategoryIds.has(cost.budgetCategoryId))
    .map((cost) =>
      expectedItem(
        { allocatedAmount: null, estimatedAmount: null, notNeeded: false },
        [cost],
        zero(),
      ),
    );
  const expectedOfKind = (kind: BudgetCategoryKind) =>
    categories
      .filter((category) => category.kind === kind)
      .map((category) => expectedByCategory.get(category.id) as ExpectedItem);
  const weddingExpected = sumExpected(
    [...expectedOfKind(BudgetCategoryKind.WEDDING), ...expectedOutside],
    zero(),
  );
  const mahrExpected = sumExpected(expectedOfKind(BudgetCategoryKind.MAHR), zero());

  const totalCost = sum(costs, (cost) => cost.totalAmount);
  const weddingCost = sum(weddingCosts, (cost) => cost.totalAmount);
  const allPaid = paidSplit(costs);
  const weddingPaid = paidSplit(weddingCosts);
  const allocated = sum(categories, (category) => category.allocatedAmount ?? zero());
  const totalBudget = query.totalBudget;
  const clock = query.now ?? new Date();
  const today = startOfTodayInRiyadh(clock);
  const dueSoonEnd = new Date(today.getTime() + 7 * 24 * 60 * 60 * 1000);
  const pendingSchedules = schedules.filter(
    (schedule) => schedule.status === PaymentScheduleStatus.PENDING,
  );
  const overdueSchedules = pendingSchedules.filter(
    (schedule) => schedule.dueDate < today,
  );
  const upcomingSchedules = pendingSchedules.filter(
    (schedule) => schedule.dueDate >= today,
  );
  const dueSoonSchedules = upcomingSchedules.filter(
    (schedule) => schedule.dueDate <= dueSoonEnd,
  );

  const categoryRows = categories.map((category) => {
    const categoryCosts = costs.filter(
      (cost) => cost.budgetCategoryId === category.id,
    );
    const confirmedCost = sum(categoryCosts, (cost) => cost.totalAmount);
    const categoryPaid = sum(categoryCosts, paidOf);
    const categorySchedules = schedules.filter(
      (schedule) => schedule.weddingCost.budgetCategoryId === category.id,
    );
    const expected = expectedByCategory.get(category.id) as ExpectedItem;
    return {
      categoryId: category.id,
      name: category.name,
      kind: category.kind,
      allocatedAmount: category.allocatedAmount?.toString() ?? null,
      confirmedCost: confirmedCost.toString(),
      paid: categoryPaid.toString(),
      outstanding: confirmedCost.minus(categoryPaid).toString(),
      remainingAllocation:
        category.allocatedAmount?.minus(confirmedCost).toString() ?? null,
      // D109: the owner's own estimate; `estimate` is the one the rule uses
      // (his, else the allocation).
      estimatedAmount: category.estimatedAmount?.toString() ?? null,
      estimate: expected.estimate?.toString() ?? null,
      estimateSource: expected.estimateSource,
      // D105: agreements plus the estimate no agreement settled yet.
      expectedCost: expected.expected.toString(),
      estimateLeft: expected.estimateLeft.toString(),
      costKnown: expected.costKnown,
      costsCount: categoryCosts.length,
      paymentSchedulesCount: categorySchedules.length,
      // D105: over its allocation by what it is expected to cost.
      overBudget:
        category.allocatedAmount === null
          ? null
          : expected.expected.gt(category.allocatedAmount),
      suggestion: category.suggestion,
      suggestionUntil: category.suggestionUntil,
      suggestionHidden: isBudgetItemSuggestionHidden(category, clock),
    };
  });

  const warnings: Array<{
    type: WarningType;
    severity: 'WARNING' | 'DANGER';
    categoryId?: string;
    count: number | null;
    amount: string | null;
  }> = [];
  // D105: the early warning is the expected cost, not the agreements alone.
  if (totalBudget !== null && weddingExpected.expected.gt(totalBudget)) {
    warnings.push({
      type: 'BUDGET_EXCEEDED',
      severity: 'DANGER',
      count: null,
      amount: weddingExpected.expected.minus(totalBudget).toString(),
    });
  }
  for (const category of categoryRows) {
    if (category.overBudget && category.allocatedAmount !== null) {
      warnings.push({
        type: 'CATEGORY_EXCEEDED',
        severity: 'DANGER',
        categoryId: category.categoryId,
        count: category.costsCount,
        amount: new Prisma.Decimal(category.expectedCost)
          .minus(category.allocatedAmount)
          .toString(),
      });
    }
  }
  if (overdueSchedules.length > 0) {
    warnings.push({
      type: 'PAYMENT_SCHEDULE_OVERDUE',
      severity: 'DANGER',
      count: overdueSchedules.length,
      amount: null,
    });
  }
  if (dueSoonSchedules.length > 0) {
    warnings.push({
      type: 'PAYMENT_SCHEDULE_DUE_SOON',
      severity: 'WARNING',
      count: dueSoonSchedules.length,
      amount: null,
    });
  }
  // D102: everything still to pay, and the wedding's dues by month.
  const timelineCosts = costs.map((cost) => ({
    id: cost.id,
    budgetCategoryId: cost.budgetCategoryId,
    title: cost.title,
    totalAmount: cost.totalAmount,
    paid: paidOf(cost),
    payer: cost.payer,
    payerName: cost.payerName,
    ownerMoney: ownerMoney(cost),
    mahr: mahrCategoryIds.has(cost.budgetCategoryId),
  }));
  const timelineSources: TimelineSource[] | null =
    fundingSources?.map((source) => ({
      id: source.id,
      kind: source.kind,
      sourceName: source.sourceName,
      amount: source.amount,
      status: source.status,
      expectedAt: source.expectedAt,
      repayments: source.repayments.map((repayment) => ({
        id: repayment.id,
        amount: repayment.amount,
        dueDate: repayment.dueDate,
        status: repayment.status,
        note: repayment.note,
      })),
    })) ?? null;
  const obligations = listObligations({
    costs: timelineCosts,
    schedules: schedules.map((schedule) => ({
      id: schedule.id,
      weddingCostId: schedule.weddingCostId,
      amount: schedule.amount,
      dueDate: schedule.dueDate,
      status: schedule.status,
      note: schedule.note,
      remindAt: schedule.remindAt,
      rescheduledFrom: schedule.rescheduledFrom,
      partlyPaid: partlyPaid.get(schedule.id) ?? zero(),
      createdAt: schedule.createdAt,
    })),
    sources: timelineSources,
    today,
    zero: zero(),
  });
  const dues = weddingDuesByMonth(obligations, zero());

  // D103, D104: the owner's money against what is on him, on its days.
  const fundingTotals = fundingSources
    ? summarizeFunding(fundingSources, { paidByOwner: allPaid.byOwner, today })
    : null;
  const coverage =
    fundingTotals && timelineSources && timelineSources.length > 0
      ? coverageOf({
          cash: new Prisma.Decimal(fundingTotals.availableCash),
          obligations,
          sources: timelineSources,
          today,
        })
      : null;
  const funding = fundingTotals
    ? {
        ...fundingTotals,
        shortfall: coverage?.withPledges.deepest?.amount.toString() ?? null,
      }
    : null;
  if (funding && funding.shortfall !== null) {
    warnings.push({
      type: 'FUNDING_SHORTFALL',
      severity: 'WARNING',
      count: null,
      amount: funding.shortfall,
    });
  }
  if (funding && funding.overdueLoanRepayments > 0) {
    warnings.push({
      type: 'LOAN_REPAYMENT_OVERDUE',
      severity: 'DANGER',
      count: funding.overdueLoanRepayments,
      amount: null,
    });
  }

  const next = pendingSchedules[0] ?? null;
  // RA-BE-53: «the next payment» asks for what its cost still owes, at most.
  const costById = new Map(costs.map((cost) => [cost.id, cost]));
  const nextCost = next ? costById.get(next.weddingCostId) : undefined;
  const nextAmountDue =
    next && nextCost
      ? scheduleAmountDue(next.amount, nextCost.totalAmount, paidOf(nextCost))
      : (next?.amount ?? null);
  const mahr = summarizeMahr({
    side: mahrSideOf(query.persona),
    costs: costs.filter((cost) => mahrCategoryIds.has(cost.budgetCategoryId)),
    netPaidByCost,
    pendingSchedules: pendingSchedules.filter((schedule) =>
      mahrCategoryIds.has(schedule.weddingCost.budgetCategoryId),
    ),
    fundingSources,
  });
  return {
    // The wedding budget (C1): the mahr item is not in it.
    budget: {
      total: totalBudget?.toString() ?? null,
      allocated: allocated.toString(),
      unallocated: totalBudget?.minus(allocated).toString() ?? null,
      confirmedCost: weddingCost.toString(),
      paid: weddingPaid.paid.toString(),
      paidByOwner: weddingPaid.byOwner.toString(),
      paidByOthers: weddingPaid.byOthers.toString(),
      outstanding: weddingCost.minus(weddingPaid.paid).toString(),
      count: weddingCosts.length,
      remaining: totalBudget?.minus(weddingCost).toString() ?? null,
    },
    // Every agreement, the mahr's included.
    costs: {
      total: totalCost.toString(),
      paid: allPaid.paid.toString(),
      paidByOwner: allPaid.byOwner.toString(),
      paidByOthers: allPaid.byOthers.toString(),
      outstanding: totalCost.minus(allPaid.paid).toString(),
      count: costs.length,
    },
    paymentSchedules: {
      totalCount: schedules.length,
      upcomingCount: upcomingSchedules.length,
      overdueCount: overdueSchedules.length,
      paidCount: schedules.filter(
        (schedule) => schedule.status === PaymentScheduleStatus.PAID,
      ).length,
      next: next
        ? {
            id: next.id,
            weddingCostId: next.weddingCostId,
            // RA-MO-38: «الدفعة الجاية» names its agreement («القاعة: ...»),
            // not «دفعة».
            costTitle: nextCost?.title ?? null,
            amount: (nextAmountDue ?? next.amount).toString(),
            dueDate: next.dueDate,
            status: next.status,
            isOverdue: next.dueDate < today,
          }
        : null,
    },
    categories: categoryRows,
    /**
     * D105, D109: what the wedding is expected to cost: agreements plus the
     * estimates no agreement settled. The budget is the wedding items' (C1);
     * the mahr is apart. «المسجّلة»: never final while `unknownCount` > 0.
     */
    expected: {
      wedding: presentExpected(weddingExpected),
      mahr: presentExpected(mahrExpected),
      total: weddingExpected.expected.plus(mahrExpected.expected).toString(),
      budgetLeft: totalBudget?.minus(weddingExpected.expected).toString() ?? null,
    },
    /** D102: what is left to pay, and on whom: the owner (mahr with it) or others. */
    outstanding: {
      total: sum(timelineCosts, (cost) => positive(cost.totalAmount.minus(cost.paid))).toString(),
      owner: sum(
        timelineCosts.filter((cost) => cost.ownerMoney),
        (cost) => positive(cost.totalAmount.minus(cost.paid)),
      ).toString(),
      ownerMahr: sum(
        timelineCosts.filter((cost) => cost.ownerMoney && cost.mahr),
        (cost) => positive(cost.totalAmount.minus(cost.paid)),
      ).toString(),
      others: sum(
        timelineCosts.filter((cost) => !cost.ownerMoney),
        (cost) => positive(cost.totalAmount.minus(cost.paid)),
      ).toString(),
    },
    /** D102, D106: everything still to pay, one line each (loans: the owner's only). */
    obligations: obligations.map(presentObligation),
    /** D102: the wedding's dues by month (loans apart). */
    duesByMonth: presentDues(dues),
    /**
     * D103: will the owner's money cover what is on him, in time. Null for
     * anyone but the owner, and before any source of money is recorded.
     */
    coverage: coverage
      ? presentCoverage(
          coverage,
          // The estimates' «if»: items not agreed yet are his until an
          // agreement names someone else; the mahr's when he pays it.
          weddingExpected.estimateLeft.plus(
            mahrSideOf(query.persona) === 'PAYS' ? mahrExpected.estimateLeft : zero(),
          ),
        )
      : null,
    /** D108: the family, person by person (the owner's only). */
    family: fundingSources
      ? familyContributions({
          costs: timelineCosts,
          sources: fundingSources.map((source) => ({
            contributorName: source.contributorName,
            amount: source.amount,
            status: source.status,
            kind: source.kind,
          })),
          zero: zero(),
        }).map(presentContributor)
      : null,
    /**
     * The plan's mahr (a06): the groom's agreement with the bride's family
     * (PAYS, from his MAHR item) or the bride's mahr coming in (RECEIVES,
     * from her MAHR funding sources, so the owner's only). Null before it is
     * recorded, on a plan without a persona, or for a reader who may not see it.
     */
    mahr,
    /** G14: who pays what, by each agreement's payer; D59: whose money it is. */
    payers: summarizePayers(costs, netPaidByCost, query.persona),
    /** Owner only; null for anyone else. */
    funding,
    warnings,
  };
}

export type { MoneyPicture, MoneyPictureQuery };

function positive(amount: Prisma.Decimal): Prisma.Decimal {
  return amount.gt(0) ? amount : amount.mul(0);
}

function presentExpected(total: ExpectedTotals) {
  return {
    agreed: total.agreed.toString(),
    estimateLeft: total.estimateLeft.toString(),
    expected: total.expected.toString(),
    unknownCount: total.unknownCount,
  };
}

function presentObligation(line: Obligation) {
  return {
    kind: line.kind,
    id: line.id,
    weddingCostId: line.weddingCostId,
    budgetCategoryId: line.budgetCategoryId,
    fundingSourceId: line.fundingSourceId,
    title: line.title,
    note: line.note,
    amount: line.amount.toString(),
    scheduledAmount: line.scheduledAmount.toString(),
    paidTowards: line.paidTowards.toString(),
    dueDate: line.dueDate,
    isOverdue: line.isOverdue,
    remindAt: line.remindAt,
    rescheduledFrom: line.rescheduledFrom,
    payer: line.payer as CostPayer | null,
    payerName: line.payerName,
    ownerMoney: line.ownerMoney,
    mahr: line.mahr,
  };
}

function presentDues(dues: DuesByMonth) {
  const bucket = (value: { amount: Prisma.Decimal; ownerAmount: Prisma.Decimal; count: number }) => ({
    amount: value.amount.toString(),
    ownerAmount: value.ownerAmount.toString(),
    count: value.count,
  });
  return {
    months: dues.months.map((month) => ({ month: month.month, ...bucket(month) })),
    overdue: bucket(dues.overdue),
    undated: bucket(dues.undated),
  };
}

function presentRun(run: CoverageRun) {
  const short = (value: CoverageRun['firstShort']) =>
    value
      ? { date: value.date, amount: value.amount.toString(), title: value.title, id: value.id }
      : null;
  return {
    firstShort: short(run.firstShort),
    deepest: short(run.deepest),
    end: run.end.toString(),
  };
}

function presentCoverage(coverage: Coverage, estimateLeft: Prisma.Decimal) {
  const pledge = (value: Coverage['pledgesCounted'][number]) => ({
    id: value.id,
    sourceName: value.sourceName,
    amount: value.amount.toString(),
    expectedAt: value.expectedAt,
  });
  return {
    /** The one verdict every screen and the assistant say. */
    verdict: coverageVerdict(coverage),
    cash: coverage.cash.toString(),
    total: coverage.total.toString(),
    undated: coverage.undated.toString(),
    lastDate: coverage.lastDate,
    hasLoan: coverage.hasLoan,
    withoutPledges: presentRun(coverage.withoutPledges),
    withPledges: presentRun(coverage.withPledges),
    /** «كيف حسبناها؟»: the account with the promised money that counts. */
    steps: coverage.withPledges.steps.map((step) => ({
      kind: step.kind,
      id: step.id,
      date: step.date,
      late: step.late,
      title: step.title,
      note: step.note,
      amount: step.amount.toString(),
      inflow: step.inflow,
      balance: step.balance.toString(),
    })),
    pledgesCounted: coverage.pledgesCounted.map(pledge),
    pledgesIgnored: coverage.pledgesIgnored.map((value) => ({
      ...pledge(value),
      reason: value.reason,
    })),
    /** An «if», not a commitment: the estimates still expected, and what would be left. */
    estimates: {
      left: estimateLeft.toString(),
      endAfter: coverage.withPledges.end.minus(estimateLeft).toString(),
    },
  };
}

function presentContributor(person: Contributor) {
  return {
    name: person.name,
    payer: person.payer as CostPayer | null,
    gave: person.gave.toString(),
    promised: person.promised.toString(),
    paid: person.paid.toString(),
    left: person.left.toString(),
    costsCount: person.costsCount,
  };
}

function summarizeMahr(input: {
  side: MahrSide | null;
  costs: ReadonlyArray<{ id: string; totalAmount: Prisma.Decimal }>;
  netPaidByCost: ReadonlyMap<string, Prisma.Decimal>;
  pendingSchedules: ReadonlyArray<{ dueDate: Date }>;
  fundingSources: readonly FundingSourceWithRepayments[] | null;
}): MahrPicture | null {
  const zero = new Prisma.Decimal(0);
  if (input.side === 'PAYS') {
    if (input.costs.length === 0) return null;
    const total = input.costs.reduce(
      (sum, cost) => sum.plus(cost.totalAmount),
      zero,
    );
    const settled = input.costs.reduce(
      (sum, cost) => sum.plus(input.netPaidByCost.get(cost.id) ?? zero),
      zero,
    );
    return mahrPicture(
      'PAYS',
      total,
      settled,
      input.pendingSchedules[0]?.dueDate ?? null,
    );
  }
  if (input.side === 'RECEIVES' && input.fundingSources) {
    const sources = input.fundingSources.filter(
      (source) => source.kind === FundingSourceKind.MAHR,
    );
    if (sources.length === 0) return null;
    const total = sources.reduce((sum, source) => sum.plus(source.amount), zero);
    const received = sources
      .filter((source) => source.status === FundingSourceStatus.RECEIVED)
      .reduce((sum, source) => sum.plus(source.amount), zero);
    const expected = sources
      .filter(
        (source) =>
          source.status === FundingSourceStatus.PLEDGED &&
          source.expectedAt !== null,
      )
      .map((source) => source.expectedAt as Date)
      .sort((a, b) => a.getTime() - b.getTime());
    return mahrPicture('RECEIVES', total, received, expected[0] ?? null);
  }
  return null;
}

const PAYER_ORDER: ReadonlyArray<CostPayer | null> = [
  CostPayer.GROOM,
  CostPayer.BRIDE,
  CostPayer.FAMILY,
  CostPayer.SHARED,
  CostPayer.OTHER,
  null,
];

/**
 * G14: what each payer agreed to and paid, grouped by the agreement's payer
 * and the name written with it («الوالد», «خالي أحمد»); agreements without
 * a payer are one group with `payer: null`. D59: `ownerMoney` says whether
 * the group's payments came out of the owner's own money.
 */
function summarizePayers(
  costs: ReadonlyArray<{
    id: string;
    totalAmount: Prisma.Decimal;
    payer: CostPayer | null;
    payerName: string | null;
  }>,
  netPaidByCost: ReadonlyMap<string, Prisma.Decimal>,
  persona: string | null,
) {
  const groups = new Map<
    string,
    {
      payer: CostPayer | null;
      payerName: string | null;
      agreed: Prisma.Decimal;
      paid: Prisma.Decimal;
      costsCount: number;
    }
  >();
  for (const cost of costs) {
    const payerName = cost.payerName?.trim() || null;
    const key = `${cost.payer ?? ''}|${payerName ?? ''}`;
    const group = groups.get(key) ?? {
      payer: cost.payer,
      payerName,
      agreed: new Prisma.Decimal(0),
      paid: new Prisma.Decimal(0),
      costsCount: 0,
    };
    group.agreed = group.agreed.plus(cost.totalAmount);
    group.paid = group.paid.plus(netPaidByCost.get(cost.id) ?? 0);
    group.costsCount += 1;
    groups.set(key, group);
  }
  return [...groups.values()]
    .sort(
      (a, b) =>
        PAYER_ORDER.indexOf(a.payer) - PAYER_ORDER.indexOf(b.payer) ||
        (a.payerName ?? '').localeCompare(b.payerName ?? '', 'ar'),
    )
    .map((group) => ({
      payer: group.payer,
      payerName: group.payerName,
      ownerMoney: paidFromOwnerMoney(group.payer, persona),
      agreed: group.agreed.toString(),
      paid: group.paid.toString(),
      outstanding: group.agreed.minus(group.paid).toString(),
      costsCount: group.costsCount,
    }));
}

/**
 * The owner's money in (D59, D104). `availableCash` («معك») is what was
 * received less what his own money paid and what he repaid on loans: a
 * payment someone else made for him never leaves his hands, a repayment
 * does; never below zero (RA-BE-17: money paid from outside the app). The
 * shortfall is the coverage's (D103), set by the caller.
 */
export function summarizeFunding(
  sources: readonly FundingSourceWithRepayments[],
  spent: {
    paidByOwner: Prisma.Decimal;
    today: Date;
  },
) {
  const zero = () => new Prisma.Decimal(0);
  let received = zero();
  let pledged = zero();
  let loanTotal = zero();
  let loanRepaid = zero();
  let overdueLoanRepayments = 0;
  let overduePledges = 0;
  let nextRepayment: {
    id: string;
    fundingSourceId: string;
    sourceName: string;
    amount: string;
    dueDate: Date;
    isOverdue: boolean;
  } | null = null;
  for (const source of sources) {
    if (source.status === FundingSourceStatus.RECEIVED) {
      received = received.plus(source.amount);
    } else {
      pledged = pledged.plus(source.amount);
      if (isPledgeOverdue(source, spent.today)) overduePledges += 1;
    }
    // G33: a promised loan is owed only once it arrived.
    if (
      source.kind !== FundingSourceKind.LOAN ||
      source.status !== FundingSourceStatus.RECEIVED
    ) {
      continue;
    }
    loanTotal = loanTotal.plus(source.amount);
    for (const repayment of source.repayments) {
      if (repayment.status === LoanRepaymentStatus.PAID) {
        loanRepaid = loanRepaid.plus(repayment.amount);
        continue;
      }
      if (repayment.status !== LoanRepaymentStatus.PLANNED || !repayment.dueDate) {
        continue;
      }
      const isOverdue = repayment.dueDate < spent.today;
      if (isOverdue) overdueLoanRepayments += 1;
      if (!nextRepayment || repayment.dueDate < nextRepayment.dueDate) {
        nextRepayment = {
          id: repayment.id,
          fundingSourceId: source.id,
          sourceName: source.sourceName,
          amount: repayment.amount.toString(),
          dueDate: repayment.dueDate,
          isOverdue,
        };
      }
    }
  }
  const total = received.plus(pledged);
  const unspent = received.minus(spent.paidByOwner).minus(loanRepaid);
  const inHand = unspent.gt(0) ? unspent : zero();
  return {
    total: total.toString(),
    received: received.toString(),
    pledged: pledged.toString(),
    /** What the owner's own money paid on agreements («صرفت»). */
    spent: spent.paidByOwner.toString(),
    /** D104: received − spent − loanRepaid, never below zero. */
    availableCash: inHand.toString(),
    loanTotal: loanTotal.toString(),
    loanRepaid: loanRepaid.toString(),
    loanOutstanding: loanTotal.minus(loanRepaid).toString(),
    overdueLoanRepayments,
    /** Promised money whose expected day passed without it arriving. */
    overduePledges,
    nextLoanRepayment: nextRepayment,
    sourcesCount: sources.length,
  };
}

/** Promised money whose expected day is before today («متأخر»). */
export function isPledgeOverdue(
  source: { status: FundingSourceStatus; expectedAt: Date | null },
  today: Date,
): boolean {
  return (
    source.status === FundingSourceStatus.PLEDGED &&
    source.expectedAt !== null &&
    source.expectedAt < today
  );
}

export function startOfTodayInRiyadh(now: Date) {
  const riyadh = new Date(now.getTime() + 3 * 60 * 60 * 1000);
  return new Date(
    Date.UTC(
      riyadh.getUTCFullYear(),
      riyadh.getUTCMonth(),
      riyadh.getUTCDate(),
    ) -
      3 * 60 * 60 * 1000,
  );
}
