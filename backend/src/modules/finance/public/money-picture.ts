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
    costsCount: number;
    paymentSchedulesCount: number;
    overBudget: boolean | null;
    /** The owner's answer to the home suggesting it: «ما أحتاجها» or «بعدين». */
    suggestion: 'NOT_NEEDED' | 'LATER' | null;
    /** Until when «بعدين» keeps it off the home. */
    suggestionUntil: Date | null;
    /** The answer keeps it off the home now (finance's one rule). */
    suggestionHidden: boolean;
  }>;
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
    /** What the owner's own money paid («صرفت»): received = spent + in hand. */
    spent: string;
    availableCash: string;
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
