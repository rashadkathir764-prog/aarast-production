import type { BudgetCategory, Prisma } from '@prisma/client';
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
  findCostForAcceptedOffer(
    tx: Prisma.TransactionClient,
    quoteOfferId: string,
  ): Promise<WeddingCostWithDetails | null>;
  createCostFromAcceptedOffer(
    tx: Prisma.TransactionClient,
    input: CreateCostFromAcceptedOfferInput,
  ): Promise<WeddingCostWithDetails>;
}
