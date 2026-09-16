import { Module } from '@nestjs/common';
import {
  FINANCE_IMPLEMENTATION,
  FinancePortInternalModule,
} from '../internal/finance-port.internal.module';
import { FINANCE_PORT } from './finance.port';

@Module({
  imports: [FinancePortInternalModule],
  providers: [
    {
      provide: FINANCE_PORT,
      useExisting: FINANCE_IMPLEMENTATION,
    },
  ],
  exports: [FINANCE_PORT],
})
export class FinancePublicModule {}
