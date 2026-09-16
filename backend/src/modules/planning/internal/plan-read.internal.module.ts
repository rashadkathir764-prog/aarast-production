import { Module } from '@nestjs/common';
import { PlanErasureService } from './plan-erasure.service';
import { PlanReadService } from './plan-read.service';

export const PLAN_READ_IMPLEMENTATION = Symbol('PLAN_READ_IMPLEMENTATION');
export const PLAN_ERASURE_IMPLEMENTATION = Symbol('PLAN_ERASURE_IMPLEMENTATION');

@Module({
  providers: [
    PlanReadService,
    PlanErasureService,
    {
      provide: PLAN_READ_IMPLEMENTATION,
      useExisting: PlanReadService,
    },
    {
      provide: PLAN_ERASURE_IMPLEMENTATION,
      useExisting: PlanErasureService,
    },
  ],
  exports: [
    PlanReadService,
    PlanErasureService,
    PLAN_READ_IMPLEMENTATION,
    PLAN_ERASURE_IMPLEMENTATION,
  ],
})
export class PlanReadInternalModule {}
