import { Prisma } from '@prisma/client';

/**
 * REFINEMENT_SPEC 2.1, «ترتيب الخطوة التالية»: the order of the home's next
 * steps, decided here alone; the phone shows the first one and up to two
 * more. A step's tier is its place in the spec's list; inside a tier the
 * step's own key decides (a day, or the chain's order), then the larger
 * amount, then a payment before a task before an offer, then the order the
 * steps were built in.
 */

/** The home shows the first step and up to two more. */
export const NEXT_STEP_LIMIT = 3;
/** A task late by more than this many days is no next step (rule 8). */
export const LATE_TASK_WINDOW_DAYS = 7;
/** A payment due within this many days is «دفعة خلال 1 إلى 7 أيام» (rule 4). */
export const PAYMENT_SOON_DAYS = 7;
/** A booking left unconfirmed matters once the wedding is this close (rule 2). */
export const UNCONFIRMED_BOOKING_WINDOW_DAYS = 7;
/** The setup steps are asked only while the wedding is further than this (rule 6). */
export const SETUP_STEPS_AFTER_DAYS = 30;

const DAY_MS = 86_400_000;
const ZERO = new Prisma.Decimal(0);

/** The oldest due day a late task may have and still be a next step. */
export function lateTaskWindowStart(today: Date): Date {
  return new Date(today.getTime() - LATE_TASK_WINDOW_DAYS * DAY_MS);
}

/** Before the wedding (or with no date), in the spec's order. */
export const BEFORE_WEDDING_TIERS = {
  PAYMENT_DUE: 1,
  BOOKING_UNCONFIRMED: 2,
  TASK_DUE: 3,
  PAYMENT_SOON: 4,
  QUOTE_RECEIVED: 5,
  SETUP: 6,
  LATER: 7,
} as const;

/** After the wedding day, in the spec's order. */
export const AFTER_WEDDING_TIERS = {
  PAYMENT_DUE: 1,
  PAYMENT_NEXT: 2,
  DEBT_UNDATED: 3,
  LOAN_OUTSTANDING: 4,
  RATE_PROVIDERS: 5,
} as const;

/** The spec's tie: a payment before a task before an offer. */
export type NextStepKind = 'PAYMENT' | 'TASK' | 'QUOTE' | 'OTHER';
const KIND_RANK: Record<NextStepKind, number> = {
  PAYMENT: 0,
  TASK: 1,
  QUOTE: 2,
  OTHER: 3,
};

export interface RankedNextStep<T> {
  tier: number;
  /** Smaller first inside the tier: a day's time, or a place in a chain. */
  key: number;
  /** Larger first when the keys are equal (an amount, exact); null counts as none. */
  amount: Prisma.Decimal | null;
  kind: NextStepKind;
  step: T;
}

/** The steps in the spec's order, at most `limit`. */
export function orderNextSteps<T>(
  steps: readonly RankedNextStep<T>[],
  limit = NEXT_STEP_LIMIT,
): T[] {
  return steps
    .map((step, index) => ({ step, index }))
    .sort((left, right) => {
      const a = left.step;
      const b = right.step;
      return (
        a.tier - b.tier ||
        a.key - b.key ||
        (b.amount ?? ZERO).comparedTo(a.amount ?? ZERO) ||
        KIND_RANK[a.kind] - KIND_RANK[b.kind] ||
        left.index - right.index
      );
    })
    .slice(0, limit)
    .map(({ step }) => step.step);
}
