import type {
  BudgetCategory,
  PaymentSchedule,
  Prisma,
  WeddingCost,
  WeddingCostStatus,
} from '@prisma/client';
import type { WeddingCostWithDetails } from './wedding-cost.presenter';
import type { MoneyPicture, MoneyPictureQuery } from './money-picture';

/** D11: the day in Riyadh a moment falls on, as the money's dates read it. */
export { riyadhDay } from '../domain/money-timeline-policy';
export const FINANCE_PORT = Symbol('FINANCE_PORT');

export interface ImportedCostPaymentInput {
  amount: Prisma.Decimal;
  paidAt: Date;
  method: string | null;
  note: string | null;
  /** D106: a partial payment of the agreement's date at this index. */
  lowersScheduleIndex?: number | null;
}

export interface ImportedPaymentScheduleInput {
  amount: Prisma.Decimal;
  dueDate: Date;
  note: string | null;
  /** D106. */
  remindAt?: Date | null;
  rescheduledFrom?: Date | null;
}

/** D109: an imported item's own estimate and allocation. */
export interface ImportedItemAmountInput {
  budgetCategoryId: string;
  allocatedAmount: Prisma.Decimal | null;
  estimatedAmount: Prisma.Decimal | null;
}

/** Money in a plan kept on the phone recorded. */
export interface ImportedFundingSourceInput {
  kind: string;
  sourceName: string;
  sourcePhone: string | null;
  contributorName: string | null;
  amount: Prisma.Decimal;
  status: 'RECEIVED' | 'PLEDGED';
  receivedAt: Date | null;
  expectedAt: Date | null;
  note: string | null;
  repayments: ReadonlyArray<{
    amount: Prisma.Decimal;
    dueDate: Date | null;
    status: 'PLANNED' | 'PAID' | 'CANCELLED';
    paidAt: Date | null;
    note: string | null;
  }>;
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
  /** D59: the phone's own answer of who pays. */
  payer?: string | null;
  payerName?: string | null;
  /** D107, D105. */
  entryKind?: 'AGREEMENT' | 'EXPENSE';
  estimateCover?: 'WHOLE' | 'PART';
  estimatePart?: Prisma.Decimal | null;
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

export type { MoneyPicture, MoneyPictureQuery };

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
  /** D106: also the dates whose own reminder day has come by then. */
  remindBefore?: Date;
  /** Narrows to these schedules (the re-read under the row locks). */
  scheduleIds?: readonly string[];
}

/**
 * A budget category expected to cost more than its allocation (D105): its
 * non-cancelled agreements plus the estimate they have not settled.
 */
export interface ExceededBudgetCategory {
  id: string;
  weddingPlanId: string;
  name: string;
  allocatedAmount: Prisma.Decimal;
  /** Its agreements as agreed. */
  committedAmount: Prisma.Decimal;
  /** D105: agreements plus the estimate not settled yet. */
  expectedAmount: Prisma.Decimal;
}

/** D59: promised money with the day it is expected (the bride's mahr rest, a promise). */
export interface DueExpectedFunding {
  id: string;
  weddingPlanId: string;
  kind: string;
  sourceName: string;
  amount: Prisma.Decimal;
  expectedAt: Date;
}

/** A planned repayment of one of the plan's loans that has a due date. */
export interface DueLoanRepayment {
  id: string;
  weddingPlanId: string;
  sourceName: string;
  amount: Prisma.Decimal;
  dueDate: Date;
}

/** A cost an accepted offer created, with its money totals (B-18). */
export interface OfferCost {
  id: string;
  quoteOfferId: string;
  budgetCategoryId: string;
  totalAmount: Prisma.Decimal;
  /** Everyone's payments on it, net of reversals (D59 keeps who paid inside finance). */
  paidAmount: Prisma.Decimal;
  status: WeddingCostStatus;
  lastPaidAt: Date | null;
}

export interface CreateCostFromAcceptedOfferInput {
  weddingPlanId: string;
  providerId: string;
  quoteOfferId: string;
  title: string;
  amount: Prisma.Decimal;
  /** The provider category the accepted service belongs to, if any. */
  providerCategoryName: string | null;
  /**
   * D73: that category's slug, which the money catalog's explicit links
   * name; absent or null, no link names it and its name's words file it
   * among the items without a link.
   */
  providerCategorySlug?: string | null;
  /** D73: the plan's persona, which picks the catalog items its own came from. */
  planPersona?: string | null;
}

// Finance owns `BudgetCategory`, `WeddingCost`, `CostPayment` and
// `PaymentSchedule`. Quote acceptance links an accepted offer to a cost
// through this seam inside the caller's serializable transaction: finance
// matches the budget category (its own policy, `أخرى` fallback included) and
// creates the cost; the caller never touches the finance tables.
export interface SpendingSample {
  weddingPlanId: string;
  /** The item's normalized name («قاعة أو مخدرة الرجال»). */
  itemName: string;
  /** In the plan's currency (planning's). */
  total: Prisma.Decimal;
}

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
  /**
   * G41: what each plan agreed per wedding item and currency (cancelled,
   * private and mahr agreements left out), for the back office's
   * anonymous spending report. No names, parties or providers.
   */
  listSpendingSamples(client: Prisma.TransactionClient): Promise<SpendingSample[]>;
  createBudgetCategoriesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    names: readonly string[],
  ): Promise<BudgetCategory[]>;
  listBudgetCategories(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<BudgetCategory[]>;
  /**
   * Creates the imported costs with their payments and schedules, in a few
   * statements whatever their number (RA-BE-113); each status follows
   * finance's paid/total rule.
   */
  createImportedCostsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    costs: readonly ImportedCostInput[],
  ): Promise<void>;
  /**
   * D109: the imported items' own estimates and allocations. Allocations are
   * kept only while they fit the budget, the rule the account keeps (an
   * estimate needs no budget and may pass it).
   */
  setImportedItemAmountsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    budget: Prisma.Decimal | null,
    items: readonly ImportedItemAmountInput[],
  ): Promise<void>;
  /** The money in a plan kept on the phone recorded (the owner's). */
  createImportedFundingSourcesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    persona: string | null,
    sources: readonly ImportedFundingSourceInput[],
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
  /**
   * D59: the plan's money in one read, the one `money-summary` serves: the
   * wedding budget (WEDDING items only), every agreement, the mahr on its
   * own line, who paid what and whose money it was, and the owner's money
   * in (only when `fundingVisible`). The dashboards and the assistant read
   * it instead of adding the costs up again.
   */
  readMoneyPicture(
    client: Prisma.TransactionClient,
    query: MoneyPictureQuery,
  ): Promise<MoneyPicture>;
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
  /**
   * D59: the plans' promised money (PLEDGED sources) expected at or before
   * `dueBefore`, the soonest first: the owner's private money, reminded to
   * the owner only (`expectedFundingReminder` says on which day).
   */
  listDueExpectedFunding(
    client: Prisma.TransactionClient,
    query: { weddingPlanIds: readonly string[]; dueBefore: Date },
  ): Promise<DueExpectedFunding[]>;
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
  /** R4: the plan's item this service is filed under, by the rule that files an offer (D73 links included); null when no item names it. */
  findItemForService(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    serviceName: string,
    planPersona: string | null,
  ): Promise<string | null>;
  /** R4: whether the item is this plan's. */
  isPlanItem(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    budgetCategoryId: string,
  ): Promise<boolean>;
  /** R4: the plan's payment a task may wait on; null when it is not this plan's. */
  findPlanSchedule(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scheduleId: string,
  ): Promise<{ costId: string; settled: boolean } | null>;
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
  /**
   * The costs linked to any of the offers: whether a quote's accepted offer
   * already has one, the money item it is filed under («محجوز», D60), and
   * what was agreed and paid on it (B-18: the provider reads those totals,
   * never the payments).
   */
  listCostsForOffers(
    client: Prisma.TransactionClient,
    quoteOfferIds: readonly string[],
  ): Promise<OfferCost[]>;
  /**
   * D60: the plan's wedding items booked with someone outside اعّرست: a
   * live cost with a named party and no provider or offer. `costIds` narrows
   * to the reader's costs (null: the whole plan).
   */
  listOutsidePartyItemIds(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    costIds: readonly string[] | null,
  ): Promise<string[]>;
  createCostFromAcceptedOffer(
    tx: Prisma.TransactionClient,
    input: CreateCostFromAcceptedOfferInput,
  ): Promise<WeddingCostWithDetails>;
}
