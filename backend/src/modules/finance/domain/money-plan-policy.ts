import type { Prisma } from '@prisma/client';
import {
  type ExpectedItem,
  type ExpectedTotals,
  expectedItem,
  sumExpected,
} from './expected-cost-policy';
import {
  type Contributor,
  familyContributions,
} from './family-contributions-policy';
import {
  type Coverage,
  type DuesByMonth,
  type Obligation,
  type TimelineCost,
  type TimelineSchedule,
  type TimelineSource,
  coverageOf,
  listObligations,
  weddingDuesByMonth,
} from './money-timeline-policy';

type Amount = Prisma.Decimal;

/**
 * The money tab's answers for one plan (D102-D109), from its rows as read:
 * what each item and the wedding are expected to cost, what is left and on
 * whom, every obligation on its day and the dues by month, whether the
 * owner's money covers what is on him in time, and the family person by
 * person. The money read (`readMoneyPicture`) and the phone's copy for a
 * plan kept on the phone (`finance_local_money_plan.dart`) compose the rules
 * this one way; `money-plan-fixtures` holds the two to the same answers.
 */
export interface MoneyPlanItem {
  id: string;
  kind: 'WEDDING' | 'MAHR';
  allocatedAmount: Amount | null;
  estimatedAmount: Amount | null;
  /** «ما أحتاجها». */
  notNeeded: boolean;
}

export interface MoneyPlanCost {
  id: string;
  budgetCategoryId: string;
  title: string;
  totalAmount: Amount;
  /** Net of reversals. */
  paid: Amount;
  payer: string | null;
  payerName: string | null;
  /** D59: its payments come out of the owner's money. */
  ownerMoney: boolean;
  estimateCover?: 'WHOLE' | 'PART' | null;
  estimatePart?: Amount | null;
}

export interface MoneyPlanSource extends TimelineSource {
  contributorName: string | null;
}

export interface MoneyPlanInput {
  /** The start of today in Riyadh (D11). */
  today: Date;
  zero: Amount;
  /** The wedding budget (C1); null without one. */
  budget: Amount | null;
  /** The owner pays the mahr (the groom's plan): its estimate is his «if». */
  mahrPays: boolean;
  items: readonly MoneyPlanItem[];
  costs: readonly MoneyPlanCost[];
  schedules: readonly TimelineSchedule[];
  /** The owner's sources of money; null for a reader who may not see them. */
  sources: readonly MoneyPlanSource[] | null;
  /** «معك» (D104), from the same sources; null with them. */
  cash: Amount | null;
}

export interface MoneyPlan {
  items: ReadonlyMap<string, ExpectedItem>;
  wedding: ExpectedTotals;
  mahr: ExpectedTotals;
  /** The budget less the wedding items' expected cost; null without one. */
  budgetLeft: Amount | null;
  outstanding: { total: Amount; owner: Amount; ownerMahr: Amount; others: Amount };
  obligations: Obligation[];
  dues: DuesByMonth;
  /** Null for anyone but the owner, and before any source is recorded. */
  coverage: Coverage | null;
  /** The estimates still expected that are his «if» (D103). */
  estimateLeft: Amount;
  family: Contributor[] | null;
}

export function composeMoneyPlan(input: MoneyPlanInput): MoneyPlan {
  const { zero } = input;
  const mahrItemIds = new Set(
    input.items.filter((item) => item.kind === 'MAHR').map((item) => item.id),
  );
  const costsByItem = new Map<string, MoneyPlanCost[]>();
  for (const cost of input.costs) {
    costsByItem.set(cost.budgetCategoryId, [
      ...(costsByItem.get(cost.budgetCategoryId) ?? []),
      cost,
    ]);
  }
  const items = new Map<string, ExpectedItem>(
    input.items.map((item) => [
      item.id,
      expectedItem(item, costsByItem.get(item.id) ?? [], zero),
    ]),
  );
  // A cost whose item this reader does not see (a contributor's own cost in
  // the owner's item) counts as agreed.
  const shown = new Set(input.items.map((item) => item.id));
  const outside = input.costs
    .filter((cost) => !shown.has(cost.budgetCategoryId))
    .map((cost) =>
      expectedItem(
        { allocatedAmount: null, estimatedAmount: null, notNeeded: false },
        [cost],
        zero,
      ),
    );
  const ofKind = (kind: MoneyPlanItem['kind']) =>
    input.items
      .filter((item) => item.kind === kind)
      .map((item) => items.get(item.id) as ExpectedItem);
  const wedding = sumExpected([...ofKind('WEDDING'), ...outside], zero);
  const mahr = sumExpected(ofKind('MAHR'), zero);

  const timelineCosts: TimelineCost[] = input.costs.map((cost) => ({
    id: cost.id,
    budgetCategoryId: cost.budgetCategoryId,
    title: cost.title,
    totalAmount: cost.totalAmount,
    paid: cost.paid,
    payer: cost.payer,
    payerName: cost.payerName,
    ownerMoney: cost.ownerMoney,
    mahr: mahrItemIds.has(cost.budgetCategoryId),
  }));
  const obligations = listObligations({
    costs: timelineCosts,
    schedules: input.schedules,
    sources: input.sources,
    today: input.today,
    zero,
  });
  const owed = (rows: readonly TimelineCost[]) =>
    rows.reduce((sum, cost) => {
      const left = cost.totalAmount.minus(cost.paid);
      return left.gt(0) ? sum.plus(left) : sum;
    }, zero);
  const coverage =
    input.sources && input.sources.length > 0 && input.cash
      ? coverageOf({
          cash: input.cash,
          obligations,
          sources: input.sources,
          today: input.today,
        })
      : null;
  return {
    items,
    wedding,
    mahr,
    budgetLeft: input.budget?.minus(wedding.expected) ?? null,
    outstanding: {
      total: owed(timelineCosts),
      owner: owed(timelineCosts.filter((cost) => cost.ownerMoney)),
      ownerMahr: owed(timelineCosts.filter((cost) => cost.ownerMoney && cost.mahr)),
      others: owed(timelineCosts.filter((cost) => !cost.ownerMoney)),
    },
    obligations,
    dues: weddingDuesByMonth(obligations, zero),
    coverage,
    // Items not agreed yet are his until an agreement names someone else;
    // the mahr's when he pays it.
    estimateLeft: wedding.estimateLeft.plus(input.mahrPays ? mahr.estimateLeft : zero),
    family: input.sources
      ? familyContributions({
          costs: timelineCosts,
          sources: input.sources.map((source) => ({
            contributorName: source.contributorName,
            amount: source.amount,
            status: source.status,
            kind: source.kind,
          })),
          zero,
        })
      : null,
  };
}
