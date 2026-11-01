import { Module } from '@nestjs/common';
import { CatalogReadPublicModule } from '../../catalog/public/catalog-read-public.module';
import { FinancePortService } from '../infrastructure/finance-port.service';

export const FINANCE_IMPLEMENTATION = Symbol('FINANCE_IMPLEMENTATION');

@Module({
  // D73: acceptance files an offer by the money catalog's explicit links.
  imports: [CatalogReadPublicModule],
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
