import { Module } from '@nestjs/common';
import {
  PLANNING_BUDGET_WRITE_IMPLEMENTATION,
  PlanningBudgetWriteInternalModule,
} from '../internal/planning-budget-write.internal.module';
import { PLANNING_BUDGET_WRITE_PORT } from './planning-budget-write.port';

@Module({
  imports: [PlanningBudgetWriteInternalModule],
  providers: [
    {
      provide: PLANNING_BUDGET_WRITE_PORT,
      useExisting: PLANNING_BUDGET_WRITE_IMPLEMENTATION,
    },
  ],
  exports: [PLANNING_BUDGET_WRITE_PORT],
})
export class PlanningBudgetWritePublicModule {}
