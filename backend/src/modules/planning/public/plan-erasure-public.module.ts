import { Module } from '@nestjs/common';
import {
  PLAN_ERASURE_IMPLEMENTATION,
  PlanReadInternalModule,
} from '../internal/plan-read.internal.module';
import { PLAN_ERASURE_PORT } from './plan-erasure.port';

@Module({
  imports: [PlanReadInternalModule],
  providers: [
    {
      provide: PLAN_ERASURE_PORT,
      useExisting: PLAN_ERASURE_IMPLEMENTATION,
    },
  ],
  exports: [PLAN_ERASURE_PORT],
})
export class PlanErasurePublicModule {}
