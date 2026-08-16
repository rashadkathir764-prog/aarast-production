import type { Prisma } from '@prisma/client';

export const PLANNING_BUDGET_WRITE_PORT = Symbol(
  'PLANNING_BUDGET_WRITE_PORT',
);

export interface UpdateWeddingPlanBudgetInput {
  weddingPlanId: string;
  estimatedBudget: Prisma.Decimal | null;
  currency: string;
}

export interface PlanningBudgetWritePort {
  updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void>;
}
