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
  };
};

/** A cost's amounts for a money summary (non-cancelled costs of the plan, optionally only the given ones). */
export type CostAmounts = Pick<WeddingCost, 'id' | 'totalAmount' | 'paidAmount'>;

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
export interface FinancePort {
  /** Creates the plan's initial budget categories (names normalized as finance normalizes them) and returns the plan's categories, oldest first. */
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
  /** Account erasure: locks the plans' costs (`FOR UPDATE`, ascending) before any purge, in the money mutation order. */
  lockPlanCostsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
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
