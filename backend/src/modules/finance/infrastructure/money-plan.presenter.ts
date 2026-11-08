import type { CostPayer, Prisma } from '@prisma/client';
import type { ExpectedTotals } from '../domain/expected-cost-policy';
import type { Contributor } from '../domain/family-contributions-policy';
import type { MoneyPlan } from '../domain/money-plan-policy';
import {
  type Coverage,
  type CoverageRun,
  type DuesByMonth,
  type Obligation,
  coverageVerdict,
} from '../domain/money-timeline-policy';

/**
 * The money tab's answers as `money-summary` serves them (D102-D109), every
 * amount an exact decimal string. The money read and the phone fixtures
 * (`scripts/contracts/money-plan-fixtures.ts`) present a plan this one way.
 */
export function presentMoneyPlan(plan: MoneyPlan) {
  return {
    /**
     * D105, D109: what the wedding is expected to cost: agreements plus the
     * estimates no agreement settled. The budget is the wedding items' (C1);
     * the mahr is apart. «المسجّلة»: never final while `unknownCount` > 0.
     */
    expected: {
      wedding: presentExpected(plan.wedding),
      mahr: presentExpected(plan.mahr),
      total: plan.wedding.expected.plus(plan.mahr.expected).toString(),
      budgetLeft: plan.budgetLeft?.toString() ?? null,
    },
    /** D102: what is left to pay, and on whom: the owner (mahr with it) or others. */
    outstanding: {
      total: plan.outstanding.total.toString(),
      owner: plan.outstanding.owner.toString(),
      ownerMahr: plan.outstanding.ownerMahr.toString(),
      others: plan.outstanding.others.toString(),
    },
    /** D102, D106: everything still to pay, one line each (loans: the owner's only). */
    obligations: plan.obligations.map(presentObligation),
    /** D102: the wedding's dues by month (loans apart). */
    duesByMonth: presentDues(plan.dues),
    /**
     * D103: will the owner's money cover what is on him, in time. Null for
     * anyone but the owner, and before any source of money is recorded.
     */
    coverage: plan.coverage ? presentCoverage(plan.coverage, plan.estimateLeft) : null,
    /** D108: the family, person by person (the owner's only). */
    family: plan.family ? plan.family.map(presentContributor) : null,
  };
}

/** D105, D109: each item's answer, as the summary's categories carry it. */
export function presentPlanItem(
  plan: MoneyPlan,
  item: { id: string; allocatedAmount: Prisma.Decimal | null },
) {
  const expected = plan.items.get(item.id);
  if (!expected) throw new Error(`no plan item ${item.id}`);
  return {
    id: item.id,
    estimate: expected.estimate?.toString() ?? null,
    estimateSource: expected.estimateSource,
    expectedCost: expected.expected.toString(),
    estimateLeft: expected.estimateLeft.toString(),
    costKnown: expected.costKnown,
    overBudget:
      item.allocatedAmount === null ? null : expected.expected.gt(item.allocatedAmount),
  };
}

export function presentExpected(total: ExpectedTotals) {
  return {
    agreed: total.agreed.toString(),
    estimateLeft: total.estimateLeft.toString(),
    expected: total.expected.toString(),
    unknownCount: total.unknownCount,
  };
}

export function presentObligation(line: Obligation) {
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

export function presentDues(dues: DuesByMonth) {
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

export function presentRun(run: CoverageRun) {
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

export function presentCoverage(coverage: Coverage, estimateLeft: Prisma.Decimal) {
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

export function presentContributor(person: Contributor) {
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
