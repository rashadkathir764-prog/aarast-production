import type { Prisma } from '@prisma/client';

type Amount = Prisma.Decimal;

/**
 * What an item is expected to cost (D105, D109): its agreements, plus the
 * part of its estimate no agreement has settled yet, never both for the same
 * part. An agreement settles the whole estimate (WHOLE, the default and every
 * agreement written before D105) or a part of it (PART, `estimatePart` of the
 * estimate; an expense is a part at its own value). The estimate is the
 * owner's own (`estimatedAmount`); without one, the item's allocation stands
 * in for it, so a plan that only split its budget keeps its numbers (D109).
 */
export interface ExpectedItemInput {
  allocatedAmount: Amount | null;
  estimatedAmount: Amount | null;
  /** «ما أحتاجها»: the owner said the plan does not need the item. */
  notNeeded: boolean;
}

export interface ExpectedCostInput {
  totalAmount: Amount;
  /** Missing: WHOLE, as every agreement written before D105. */
  estimateCover?: 'WHOLE' | 'PART' | null;
  estimatePart?: Amount | null;
}

export type EstimateSource = 'ESTIMATE' | 'ALLOCATION';

export interface ExpectedItem {
  /** The estimate the rule uses: the owner's, else the allocation, else none. */
  estimate: Amount | null;
  estimateSource: EstimateSource | null;
  /** Every live agreement in the item, as agreed. */
  agreed: Amount;
  /** What agreements settled of the estimate (WHOLE settles all of it). */
  settled: Amount;
  /** The estimate no agreement settled yet: what is still expected beyond them. */
  estimateLeft: Amount;
  /** agreed + estimateLeft. */
  expected: Amount;
  /**
   * The item's cost is known: an agreement settled the whole of it, or an
   * estimate covers what is not agreed yet, or the owner said it is not
   * needed. Otherwise the recorded cost is not the item's cost («مو نهائية»).
   */
  costKnown: boolean;
}

export function expectedItem(
  item: ExpectedItemInput,
  costs: readonly ExpectedCostInput[],
  zero: Amount,
): ExpectedItem {
  const ZERO = zero;
  const own = item.estimatedAmount ?? null;
  const allocation = item.allocatedAmount ?? null;
  const estimate = own ?? allocation;
  const estimateSource: EstimateSource | null =
    own !== null ? 'ESTIMATE' : allocation !== null ? 'ALLOCATION' : null;
  const agreed = costs.reduce((sum, cost) => sum.plus(cost.totalAmount), ZERO);
  const isPart = (cost: ExpectedCostInput) => cost.estimateCover === 'PART';
  const whole = costs.some((cost) => !isPart(cost));
  const parts = costs.reduce(
    (sum, cost) => (isPart(cost) ? sum.plus(cost.estimatePart ?? cost.totalAmount) : sum),
    ZERO,
  );
  let settled: Amount;
  let estimateLeft: Amount;
  if (whole) {
    settled = estimate ?? ZERO;
    estimateLeft = ZERO;
  } else if (estimate === null) {
    settled = ZERO;
    estimateLeft = ZERO;
  } else {
    settled = parts.lt(estimate) ? parts : estimate;
    estimateLeft = estimate.minus(settled);
  }
  return {
    estimate,
    estimateSource,
    agreed,
    settled,
    estimateLeft,
    expected: agreed.plus(estimateLeft),
    costKnown: whole || estimate !== null || (item.notNeeded && costs.length === 0),
  };
}

/** The plan's items summed: wedding items (the budget's, C1) and the mahr apart. */
export interface ExpectedTotals {
  agreed: Amount;
  estimateLeft: Amount;
  expected: Amount;
  /** Items whose cost is not known yet (see `costKnown`). */
  unknownCount: number;
}

export function sumExpected(items: readonly ExpectedItem[], zero: Amount): ExpectedTotals {
  const ZERO = zero;
  return items.reduce<ExpectedTotals>(
    (total, item) => ({
      agreed: total.agreed.plus(item.agreed),
      estimateLeft: total.estimateLeft.plus(item.estimateLeft),
      expected: total.expected.plus(item.expected),
      unknownCount: total.unknownCount + (item.costKnown ? 0 : 1),
    }),
    { agreed: ZERO, estimateLeft: ZERO, expected: ZERO, unknownCount: 0 },
  );
}

/**
 * What an agreement settles of its item's estimate, as it is written (D105,
 * D107): WHOLE needs no part; PART needs one above zero; an expense with no
 * choice is a part at its own value.
 */
export function estimateCoverOf(input: {
  entryKind: 'AGREEMENT' | 'EXPENSE';
  totalAmount: Amount;
  estimateCover?: 'WHOLE' | 'PART' | null;
  estimatePart?: Amount | null;
}): { estimateCover: 'WHOLE' | 'PART'; estimatePart: Amount | null } {
  const cover =
    input.estimateCover ?? (input.entryKind === 'EXPENSE' ? 'PART' : 'WHOLE');
  if (cover === 'WHOLE') return { estimateCover: 'WHOLE', estimatePart: null };
  return {
    estimateCover: 'PART',
    estimatePart: input.estimatePart ?? input.totalAmount,
  };
}
