import type { Prisma } from '@prisma/client';

export const PLANNING_BUDGET_WRITE_PORT = Symbol(
  'PLANNING_BUDGET_WRITE_PORT',
);

export interface UpdateWeddingPlanBudgetInput {
  weddingPlanId: string;
  estimatedBudget: Prisma.Decimal | null;
  currency: string;
  /** D114: the mahr counts inside the budget; undefined leaves it as it is. */
  budgetIncludesMahr?: boolean;
}

export interface PlanningBudgetWritePort {
  updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void>;
}
