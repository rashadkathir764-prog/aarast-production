import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import type {
  PlanningBudgetWritePort,
  UpdateWeddingPlanBudgetInput,
} from '../public/planning-budget-write.port';

@Injectable()
export class WeddingPlanBudgetWriter implements PlanningBudgetWritePort {
  async updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void> {
    await tx.weddingPlan.update({
      where: { id: input.weddingPlanId },
      data: {
        estimatedBudget: input.estimatedBudget,
        currency: input.currency,
      },
    });
  }
}
