import { Module } from '@nestjs/common';
import {
  PLAN_READ_IMPLEMENTATION,
  PlanReadInternalModule,
} from '../internal/plan-read.internal.module';
import { PLAN_READ_PORT } from './plan-read.port';

@Module({
  imports: [PlanReadInternalModule],
  providers: [
    {
      provide: PLAN_READ_PORT,
      useExisting: PLAN_READ_IMPLEMENTATION,
    },
  ],
  exports: [PLAN_READ_PORT],
})
export class PlanReadPublicModule {}
