import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import type {
  PlanningBudgetWritePort,
  UpdateWeddingPlanBudgetInput,
} from '../public/planning-budget-write.port';
import { updateWeddingPlanBudgetInTransaction } from '../infrastructure/wedding-plan.repository';

@Injectable()
export class WeddingPlanBudgetWriter implements PlanningBudgetWritePort {
  async updateBudgetInTransaction(
    tx: Prisma.TransactionClient,
    input: UpdateWeddingPlanBudgetInput,
  ): Promise<void> {
    await updateWeddingPlanBudgetInTransaction(tx, input);
  }
}
