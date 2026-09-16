import type { Prisma } from '@prisma/client';
import type { WeddingCostWithDetails } from './wedding-cost.presenter';

export const FINANCE_PORT = Symbol('FINANCE_PORT');

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
  findCostForAcceptedOffer(
    tx: Prisma.TransactionClient,
    quoteOfferId: string,
  ): Promise<WeddingCostWithDetails | null>;
  createCostFromAcceptedOffer(
    tx: Prisma.TransactionClient,
    input: CreateCostFromAcceptedOfferInput,
  ): Promise<WeddingCostWithDetails>;
}
