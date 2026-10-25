import type {
  BudgetCategory,
  PaymentSchedule,
  Prisma,
  WeddingCost,
} from '@prisma/client';
import type { WeddingCostWithDetails } from './wedding-cost.presenter';

export const FINANCE_PORT = Symbol('FINANCE_PORT');

export interface ImportedCostPaymentInput {
  amount: Prisma.Decimal;
  paidAt: Date;
  method: string | null;
  note: string | null;
}

export interface ImportedPaymentScheduleInput {
  amount: Prisma.Decimal;
  dueDate: Date;
  note: string | null;
}

/** One cost of a local plan import; `paidAmount` is the sum of its payments. */
export interface ImportedCostInput {
  budgetCategoryId: string;
  title: string;
  partyName: string | null;
  partyPhone: string | null;
  totalAmount: Prisma.Decimal;
  paidAmount: Prisma.Decimal;
  agreementDate: Date | null;
  note: string | null;
  payments: readonly ImportedCostPaymentInput[];
  paymentSchedules: readonly ImportedPaymentScheduleInput[];
}

export interface PlanImportCounts {
  costs: number;
  payments: number;
  paymentSchedules: number;
}

/** A pending payment schedule a reminder names, with the cost it belongs to (the provider is marketplace's, by id). */
export type DuePaymentSchedule = PaymentSchedule & {
  weddingCost: {
    weddingPlanId: string;
    title: string;
    partyName: string | null;
    providerId: string | null;
    /** V1 checklist 4.10: when set, only this account is reminded. */
    privateToUserId: string | null;
  };
};

/** A cost's amounts and category for a money summary (non-cancelled costs of the plan, optionally only the given ones). */
export type CostAmounts = Pick<
  WeddingCost,
  'id' | 'budgetCategoryId' | 'totalAmount' | 'paidAmount'
> & {
  /** False for the groom's mahr item: it is outside the wedding budget (C1). */
  inBudget: boolean;
};

/** a06: the agreed mahr, what was handed over, and when the rest is due. */
export interface MahrAgreementInput {
  total: Prisma.Decimal;
  settled: Prisma.Decimal;
  remainingDueAt: Date | null;
}

/** a06 as a request carries it (the mahr endpoint and the onboarding). */
export interface MahrAgreementRequest {
  total: string | number;
  settled?: string | number | null;
  remainingDueDate?: string | null;
}

/** A pending schedule with the title of its cost (dashboard and timeline). */
export type PendingPaymentSchedule = PaymentSchedule & {
  weddingCost: { title: string };
};

export interface DuePaymentScheduleQuery {
  weddingPlanIds: readonly string[];
  dueBefore: Date;
  /** Narrows to these schedules (the re-read under the row locks). */
  scheduleIds?: readonly string[];
}

/** A budget category whose non-cancelled costs total more than its allocation. */
export interface ExceededBudgetCategory {
  id: string;
  weddingPlanId: string;
  name: string;
  allocatedAmount: Prisma.Decimal;
  committedAmount: Prisma.Decimal;
}

/** A planned repayment of one of the plan's loans that has a due date. */
export interface DueLoanRepayment {
  id: string;
  weddingPlanId: string;
  sourceName: string;
  amount: Prisma.Decimal;
  dueDate: Date;
}

export interface CreateCostFromAcceptedOfferInput {
  weddingPlanId: string;
  providerId: string;
  quoteOfferId: string;
  title: string;
  amount: Prisma.Decimal;
  /** The provider category the accepted service belongs to, if any. */
  providerCategoryName: string | null;
}

// Finance owns `BudgetCategory`, `WeddingCost`, `CostPayment` and
// `PaymentSchedule`. Quote acceptance links an accepted offer to a cost
// through this seam inside the caller's serializable transaction: finance
// matches the budget category (its own policy, `أخرى` fallback included) and
// creates the cost; the caller never touches the finance tables.
export interface RecordedCostCounts {
  costs: number;
  plans: number;
}

export interface FinancePort {
  /** Creates the plan's initial budget categories (names normalized as finance normalizes them) and returns the plan's categories, oldest first. */
  /**
   * The reader's cost scope (null = the whole plan) without the costs
   * private to another account (V1 checklist 4.10).
   */
  excludeOthersPrivateCosts(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    readerUserId: string,
    costIds: readonly string[] | null,
  ): Promise<string[] | null>;
  /** Every recorded cost, and how many plans have one (V1 checklist 4.21 back-office indicators). */
  countRecordedCosts(client: Prisma.TransactionClient): Promise<RecordedCostCounts>;
  createBudgetCategoriesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    names: readonly string[],
  ): Promise<BudgetCategory[]>;
  listBudgetCategories(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<BudgetCategory[]>;
  /** Creates one imported cost with its payments and schedules; the status follows finance's paid/total rule. */
  createImportedCostInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    cost: ImportedCostInput,
  ): Promise<void>;
  getPlanImportCounts(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<PlanImportCounts>;
  /**
   * Records a06's mahr once: the groom's agreement with the bride's family
   * (a MAHR item outside the budget) or the bride's mahr coming in (MAHR
   * funding sources), by the plan's persona. 409 `MAHR_NOT_FOR_PLAN` without
   * a groom or bride persona, 409 `MAHR_ALREADY_RECORDED` the second time.
   */
  recordMahrInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    persona: string | null,
    request: MahrAgreementRequest,
    recordedAt: Date,
  ): Promise<void>;
  /** Account erasure: locks the plans' costs (`FOR UPDATE`, ascending) before any purge, in the money mutation order. */
  lockPlanCostsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  /** Account erasure (V1 checklist 4.10): locks the account's private costs in other plans, in the money mutation order. */
  lockPrivateCostsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
  /** Account erasure (V1 checklist 4.10): the account's private costs, with their payments and schedules, go with it. */
  purgePrivateCostsInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
  /**
   * Account erasure (V1 checklist 4.4): the receipts of the plans' costs, of
   * the account's private costs, and the receipts the account uploaded in any
   * plan, so their files can be scheduled for deletion before the rows go.
   */
  listErasedReceiptIdsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    userId: string,
  ): Promise<string[]>;
  deleteReceiptsInTransaction(
    tx: Prisma.TransactionClient,
    receiptIds: readonly string[],
  ): Promise<void>;
  /** Account erasure: the one explicit ledger purge — payments, schedules, costs, then funding sources (and their loan repayments) of the plans. */
  purgePlanLedgerInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  deletePlanBudgetCategoriesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  findCostForAcceptedOffer(
    tx: Prisma.TransactionClient,
    quoteOfferId: string,
  ): Promise<WeddingCostWithDetails | null>;
  /** The plan's non-cancelled cost amounts; `costIds` narrows to a contributor's costs. */
  listPlanCostAmounts(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    costIds?: readonly string[] | null,
  ): Promise<CostAmounts[]>;
  /** C24: whether a non-cancelled cost sits in a venue budget category (a recorded venue agreement); `costIds` narrows to a contributor's costs. */
  hasVenueCost(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    costIds?: readonly string[] | null,
  ): Promise<boolean>;
  /** The plan's pending schedules of non-cancelled costs, due date then creation order; `costIds` narrows to a contributor's costs. */
  listPendingPaymentSchedules(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    costIds?: readonly string[] | null,
  ): Promise<PendingPaymentSchedule[]>;
  /** Pending schedules of non-cancelled costs in the plans, due at or before `dueBefore`. */
  listDuePaymentSchedules(
    client: Prisma.TransactionClient,
    query: DuePaymentScheduleQuery,
  ): Promise<DuePaymentSchedule[]>;
  /** The plans' categories whose non-cancelled costs total more than their allocation. */
  listExceededBudgetCategories(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<ExceededBudgetCategory[]>;
  /** Planned repayments of the plans' loans due at or before `dueBefore`. */
  listDueLoanRepayments(
    client: Prisma.TransactionClient,
    query: { weddingPlanIds: readonly string[]; dueBefore: Date },
  ): Promise<DueLoanRepayment[]>;
  /** The schedules of the given costs of the plan (a contributor's payment reminders). */
  listPaymentScheduleIdsForCosts(
    client: Prisma.TransactionClient,
    scopes: ReadonlyArray<{ weddingPlanId: string; costIds: readonly string[] }>,
  ): Promise<Array<{ id: string; weddingPlanId: string }>>;
  /** Whether the schedule belongs to one of the plan's given costs. */
  isPaymentScheduleOfCosts(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scheduleId: string,
    costIds: readonly string[],
  ): Promise<boolean>;
  /** Locks the cost rows for share in id order. */
  lockCostRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    costIds: readonly string[],
  ): Promise<void>;
  /** Locks the schedule rows for share in id order. */
  lockPaymentScheduleRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    scheduleIds: readonly string[],
  ): Promise<void>;
  /** The costs linked to any of the offers (a quote shows whether its accepted offer already has one). */
  listCostsForOffers(
    client: Prisma.TransactionClient,
    quoteOfferIds: readonly string[],
  ): Promise<Array<{ id: string; quoteOfferId: string }>>;
  createCostFromAcceptedOffer(
    tx: Prisma.TransactionClient,
    input: CreateCostFromAcceptedOfferInput,
  ): Promise<WeddingCostWithDetails>;
}
