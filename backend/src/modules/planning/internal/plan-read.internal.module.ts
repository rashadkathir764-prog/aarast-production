import { Module } from '@nestjs/common';
import { PlanReadService } from './plan-read.service';

export const PLAN_READ_IMPLEMENTATION = Symbol('PLAN_READ_IMPLEMENTATION');

@Module({
  providers: [
    PlanReadService,
    {
      provide: PLAN_READ_IMPLEMENTATION,
      useExisting: PlanReadService,
    },
  ],
  exports: [PlanReadService, PLAN_READ_IMPLEMENTATION],
})
export class PlanReadInternalModule {}
