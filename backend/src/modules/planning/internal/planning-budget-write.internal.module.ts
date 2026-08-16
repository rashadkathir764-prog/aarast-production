import { Module } from '@nestjs/common';
import { WeddingPlanBudgetWriter } from './wedding-plan-budget-writer';

export const PLANNING_BUDGET_WRITE_IMPLEMENTATION = Symbol(
  'PLANNING_BUDGET_WRITE_IMPLEMENTATION',
);

@Module({
  providers: [
    WeddingPlanBudgetWriter,
    {
      provide: PLANNING_BUDGET_WRITE_IMPLEMENTATION,
      useExisting: WeddingPlanBudgetWriter,
    },
  ],
  exports: [WeddingPlanBudgetWriter, PLANNING_BUDGET_WRITE_IMPLEMENTATION],
})
export class PlanningBudgetWriteInternalModule {}
