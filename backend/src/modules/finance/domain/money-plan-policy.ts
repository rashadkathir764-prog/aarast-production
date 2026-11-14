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
  /**
   * D114: the owner counts the mahr inside the budget. Read only where the
   * owner pays it (`mahrPays`); missing is false, as every plan before it.
   */
  budgetIncludesMahr?: boolean;
  items: readonly MoneyPlanItem[];
  costs: readonly MoneyPlanCost[];
  schedules: readonly TimelineSchedule[];
  /** The owner's sources of money; null for a reader who may not see them. */
  sources: readonly MoneyPlanSource[] | null;
  /** «معك» (D104), from the same sources; null with them. */
  cash: Amount | null;
}

/**
 * The budget's figures (C1, D114): the wedding items' agreements, and the
 * mahr's with them when the owner counts it inside the budget.
 */
export interface MoneyPlanBudget {
  total: Amount | null;
  /** D114: the mahr counts against the budget (only where the owner pays it). */
  includesMahr: boolean;
  allocated: Amount;
  /** The budget less the allocations (and the mahr's expected cost, D114). */
  unallocated: Amount | null;
  confirmedCost: Amount;
  paid: Amount;
  /** D59: of `paid`, what the owner's own money paid. */
  paidByOwner: Amount;
  paidByOthers: Amount;
  outstanding: Amount;
  /** The wedding agreements, the mahr's never among them (RA-MO-147). */
  count: number;
  remaining: Amount | null;
}

export interface MoneyPlan {
  items: ReadonlyMap<string, ExpectedItem>;
  wedding: ExpectedTotals;
  mahr: ExpectedTotals;
  budget: MoneyPlanBudget;
  /**
   * The budget less the wedding items' expected cost, and the mahr's when
   * it counts inside the budget (D114); null without one.
   */
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
  // C1, D114: the budget holds the wedding items; the mahr with them only
  // where the owner pays it and chose so.
  const includesMahr = input.mahrPays && input.budgetIncludesMahr === true;
  const inBudget = timelineCosts.filter((cost) => includesMahr || !cost.mahr);
  const sumOf = (rows: readonly TimelineCost[], of: (cost: TimelineCost) => Amount) =>
    rows.reduce((sum, cost) => sum.plus(of(cost)), zero);
  const budgetCost = sumOf(inBudget, (cost) => cost.totalAmount);
  const budgetPaid = sumOf(inBudget, (cost) => cost.paid);
  const budgetPaidByOwner = sumOf(
    inBudget.filter((cost) => cost.ownerMoney),
    (cost) => cost.paid,
  );
  const allocated = input.items.reduce(
    (sum, item) => sum.plus(item.allocatedAmount ?? zero),
    zero,
  );
  const mahrTaken = includesMahr ? mahr.expected : zero;
  const budget: MoneyPlanBudget = {
    total: input.budget,
    includesMahr,
    allocated,
    unallocated: input.budget?.minus(allocated).minus(mahrTaken) ?? null,
    confirmedCost: budgetCost,
    paid: budgetPaid,
    paidByOwner: budgetPaidByOwner,
    paidByOthers: budgetPaid.minus(budgetPaidByOwner),
    outstanding: budgetCost.minus(budgetPaid),
    count: timelineCosts.filter((cost) => !cost.mahr).length,
    remaining: input.budget?.minus(budgetCost) ?? null,
  };
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
    budget,
    budgetLeft: input.budget?.minus(wedding.expected).minus(mahrTaken) ?? null,
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
            sourceName: source.sourceName,
            amount: source.amount,
            status: source.status,
            kind: source.kind,
          })),
          zero,
        })
      : null,
  };
}
