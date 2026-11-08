import type {
  BudgetCategoryKind,
  CostPayer,
  PaymentScheduleStatus,
  Prisma,
} from '@prisma/client';
import type { MahrPicture } from '../domain/mahr-policy';

/**
 * D59: finance's one money read, as the other contexts (the dashboards and
 * the assistant) receive it through `FinancePort.readMoneyPicture`, and as
 * `GET money-summary` serves it. Every amount is an exact decimal string.
 */

/** What one money read is about, and who reads it. */
export interface MoneyPictureQuery {
  weddingPlanId: string;
  /** The plan's persona: whose side of the mahr it is and whose money pays. */
  persona: string | null;
  /** The owner's budget; null for a reader who may not see it (or none set). */
  totalBudget: Prisma.Decimal | null;
  /** A contributor's own costs and items; null reads the whole plan. */
  scope: {
    costIds: readonly string[];
    categoryIds: readonly string[];
  } | null;
  /** V1 checklist 4.10: another account's private costs count nowhere. */
  readerUserId: string;
  /** Funding (and the bride's mahr, which is funding) is the owner's only. */
  fundingVisible: boolean;
  now?: Date;
}

export type MoneyWarningType =
  | 'BUDGET_EXCEEDED'
  | 'CATEGORY_EXCEEDED'
  | 'PAYMENT_SCHEDULE_OVERDUE'
  | 'PAYMENT_SCHEDULE_DUE_SOON'
  | 'FUNDING_SHORTFALL'
  | 'LOAN_REPAYMENT_OVERDUE';

export interface MoneyPicture {
  /** The wedding budget (C1): WEDDING items only, the mahr outside it. */
  budget: {
    total: string | null;
    allocated: string;
    unallocated: string | null;
    confirmedCost: string;
    paid: string;
    /** D59: of `paid`, what the owner's own money paid. */
    paidByOwner: string;
    /** D59: of `paid`, what others paid for the owner. */
    paidByOthers: string;
    outstanding: string;
    count: number;
    remaining: string | null;
  };
  /** Every agreement, the mahr's included. */
  costs: {
    total: string;
    paid: string;
    paidByOwner: string;
    paidByOthers: string;
    outstanding: string;
    count: number;
  };
  paymentSchedules: {
    totalCount: number;
    upcomingCount: number;
    overdueCount: number;
    paidCount: number;
    next: {
      id: string;
      weddingCostId: string;
      costTitle: string | null;
      amount: string;
      dueDate: Date;
      status: PaymentScheduleStatus;
      isOverdue: boolean;
    } | null;
  };
  categories: Array<{
    categoryId: string;
    name: string;
    kind: BudgetCategoryKind;
    allocatedAmount: string | null;
    confirmedCost: string;
    paid: string;
    outstanding: string;
    remainingAllocation: string | null;
    /** D109: the owner's own estimate of the item. */
    estimatedAmount: string | null;
    /** The estimate the rules use: his, else the allocation. */
    estimate: string | null;
    estimateSource: 'ESTIMATE' | 'ALLOCATION' | null;
    /** D105: agreements plus the estimate no agreement settled yet. */
    expectedCost: string;
    estimateLeft: string;
    /** An agreement or an estimate covers the whole item (or it is not needed). */
    costKnown: boolean;
    costsCount: number;
    paymentSchedulesCount: number;
    /** D105: expected above the allocation; null without an allocation. */
    overBudget: boolean | null;
    /** The owner's answer to the home suggesting it: «ما أحتاجها» or «بعدين». */
    suggestion: 'NOT_NEEDED' | 'LATER' | null;
    /** Until when «بعدين» keeps it off the home. */
    suggestionUntil: Date | null;
    /** The answer keeps it off the home now (finance's one rule). */
    suggestionHidden: boolean;
  }>;
  /** D105, D109: what the wedding is expected to cost (the mahr apart, C1). */
  expected: {
    wedding: MoneyExpectedTotals;
    mahr: MoneyExpectedTotals;
    /** The whole wedding, the mahr with it. */
    total: string;
    /** The budget less the wedding items' expected cost; null without a budget. */
    budgetLeft: string | null;
  };
  /** D102: what is left to pay, and on whom. */
  outstanding: {
    total: string;
    /** On the owner (D59): his agreements, shared ones, and the mahr he pays. */
    owner: string;
    /** Of `owner`, the mahr. */
    ownerMahr: string;
    /** On the family and the other side. */
    others: string;
  };
  /** D102, D106: everything still to pay, one line each. */
  obligations: MoneyObligation[];
  /** D102: the wedding's dues by month; loans are not in it. */
  duesByMonth: {
    months: Array<{ month: string } & MoneyBucket>;
    overdue: MoneyBucket;
    undated: MoneyBucket;
  };
  /** D103: the owner's money against what is on him, on its days. Owner only. */
  coverage: MoneyCoverage | null;
  /** D108: the family, person by person. Owner only. */
  family: Array<{
    name: string | null;
    payer: CostPayer | null;
    gave: string;
    promised: string;
    paid: string;
    left: string;
    costsCount: number;
  }> | null;
  /** The plan's mahr, or null before it is recorded or for a reader who may not see it. */
  mahr: MahrPicture | null;
  /** G14: who pays what, by each agreement's payer; D59: whose money it is. */
  payers: Array<{
    payer: CostPayer | null;
    payerName: string | null;
    ownerMoney: boolean;
    agreed: string;
    paid: string;
    outstanding: string;
    costsCount: number;
  }>;
  /** The owner's money in and in hand; null for anyone else. */
  funding: {
    total: string;
    received: string;
    pledged: string;
    /** What the owner's own money paid on agreements («صرفت»). */
    spent: string;
    /** D104: received − spent − loanRepaid, never below zero. */
    availableCash: string;
    /**
     * D103: what is needed beyond his money (and promised money with a day
     * to come) for everything on him to be paid on its day; null when it is.
     */
    shortfall: string | null;
    loanTotal: string;
    loanRepaid: string;
    loanOutstanding: string;
    overdueLoanRepayments: number;
    /** Promised money whose expected day passed without it arriving. */
    overduePledges: number;
    nextLoanRepayment: {
      id: string;
      fundingSourceId: string;
      sourceName: string;
      amount: string;
      dueDate: Date;
      isOverdue: boolean;
    } | null;
    sourcesCount: number;
  } | null;
  warnings: Array<{
    type: MoneyWarningType;
    severity: 'WARNING' | 'DANGER';
    categoryId?: string;
    count: number | null;
    amount: string | null;
  }>;
}

export interface MoneyExpectedTotals {
  agreed: string;
  estimateLeft: string;
  expected: string;
  /** Items whose cost is not known yet: no estimate and no whole agreement. */
  unknownCount: number;
}

export interface MoneyBucket {
  amount: string;
  /** Of `amount`, on the owner. */
  ownerAmount: string;
  count: number;
}

export interface MoneyObligation {
  kind: 'DUE' | 'UNDATED' | 'LOAN_REPAYMENT' | 'LOAN_UNPLANNED';
  /** The date (DUE), the agreement (UNDATED), the repayment, or the loan. */
  id: string;
  weddingCostId: string | null;
  budgetCategoryId: string | null;
  fundingSourceId: string | null;
  title: string;
  note: string | null;
  /** Still to pay on it now. */
  amount: string;
  /** DUE: as agreed, before partial payments. */
  scheduledAmount: string;
  /** DUE: paid towards it already. */
  paidTowards: string;
  dueDate: Date | null;
  isOverdue: boolean;
  remindAt: Date | null;
  rescheduledFrom: Date | null;
  payer: CostPayer | null;
  payerName: string | null;
  ownerMoney: boolean;
  mahr: boolean;
}

export interface MoneyCoverageShort {
  date: Date | null;
  amount: string;
  title: string;
  id: string;
}

export interface MoneyCoverageRun {
  /** The first line the money does not reach, and by how much that day. */
  firstShort: MoneyCoverageShort | null;
  /** The deepest it falls: what would make everything paid on its day. */
  deepest: MoneyCoverageShort | null;
  /** Left after everything (negative: short by that much). */
  end: string;
}

export interface MoneyCoveragePledge {
  id: string;
  sourceName: string;
  amount: string;
  expectedAt: Date | null;
}

export interface MoneyCoverage {
  /**
   * D103: NOTHING_DUE; COVERED (everything on its day, by `lastDate`);
   * COVERED_IF_PLEDGES (only if the promised money arrives on its day;
   * without it, `withoutPledges.firstShort`); SHORT (`withPledges.firstShort`,
   * and `withPledges.deepest` is what is needed beyond it).
   */
  verdict: 'NOTHING_DUE' | 'COVERED' | 'COVERED_IF_PLEDGES' | 'SHORT';
  cash: string;
  total: string;
  undated: string;
  lastDate: Date | null;
  hasLoan: boolean;
  withoutPledges: MoneyCoverageRun;
  withPledges: MoneyCoverageRun;
  steps: Array<{
    kind: 'DUE' | 'MAHR' | 'UNDATED' | 'LOAN_REPAYMENT' | 'LOAN_UNPLANNED' | 'PLEDGE';
    id: string;
    date: Date | null;
    late: boolean;
    title: string;
    note: string | null;
    amount: string;
    inflow: boolean;
    balance: string;
  }>;
  pledgesCounted: MoneyCoveragePledge[];
  pledgesIgnored: Array<MoneyCoveragePledge & { reason: 'NO_DATE' | 'LATE' }>;
  estimates: { left: string; endAfter: string };
}
