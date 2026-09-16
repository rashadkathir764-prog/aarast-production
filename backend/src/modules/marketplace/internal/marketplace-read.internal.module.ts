import { Module } from '@nestjs/common';
import { MarketplaceErasureService } from './marketplace-erasure.service';
import { ProviderReadService } from './provider-read.service';
import { QuoteReadService } from './quote-read.service';

export const PROVIDER_READ_IMPLEMENTATION = Symbol('PROVIDER_READ_IMPLEMENTATION');
export const QUOTE_READ_IMPLEMENTATION = Symbol('QUOTE_READ_IMPLEMENTATION');
export const MARKETPLACE_ERASURE_IMPLEMENTATION = Symbol('MARKETPLACE_ERASURE_IMPLEMENTATION');

@Module({
  providers: [
    ProviderReadService,
    QuoteReadService,
    MarketplaceErasureService,
    {
      provide: PROVIDER_READ_IMPLEMENTATION,
      useExisting: ProviderReadService,
    },
    {
      provide: QUOTE_READ_IMPLEMENTATION,
      useExisting: QuoteReadService,
    },
    {
      provide: MARKETPLACE_ERASURE_IMPLEMENTATION,
      useExisting: MarketplaceErasureService,
    },
  ],
  exports: [
    ProviderReadService,
    QuoteReadService,
    MarketplaceErasureService,
    PROVIDER_READ_IMPLEMENTATION,
    QUOTE_READ_IMPLEMENTATION,
    MARKETPLACE_ERASURE_IMPLEMENTATION,
  ],
})
export class MarketplaceReadInternalModule {}
