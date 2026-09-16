import { Module } from '@nestjs/common';
import { FinancePortService } from './finance-port.service';

export const FINANCE_IMPLEMENTATION = Symbol('FINANCE_IMPLEMENTATION');

@Module({
  providers: [
    FinancePortService,
    {
      provide: FINANCE_IMPLEMENTATION,
      useExisting: FinancePortService,
    },
  ],
  exports: [FinancePortService, FINANCE_IMPLEMENTATION],
})
export class FinancePortInternalModule {}
