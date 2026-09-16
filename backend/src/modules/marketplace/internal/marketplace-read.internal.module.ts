import { Module } from '@nestjs/common';
import { ProviderReadService } from './provider-read.service';
import { QuoteReadService } from './quote-read.service';

export const PROVIDER_READ_IMPLEMENTATION = Symbol('PROVIDER_READ_IMPLEMENTATION');
export const QUOTE_READ_IMPLEMENTATION = Symbol('QUOTE_READ_IMPLEMENTATION');

@Module({
  providers: [
    ProviderReadService,
    QuoteReadService,
    {
      provide: PROVIDER_READ_IMPLEMENTATION,
      useExisting: ProviderReadService,
    },
    {
      provide: QUOTE_READ_IMPLEMENTATION,
      useExisting: QuoteReadService,
    },
  ],
  exports: [
    ProviderReadService,
    QuoteReadService,
    PROVIDER_READ_IMPLEMENTATION,
    QUOTE_READ_IMPLEMENTATION,
  ],
})
export class MarketplaceReadInternalModule {}
