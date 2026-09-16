import { Module } from '@nestjs/common';
import {
  MarketplaceReadInternalModule,
  QUOTE_READ_IMPLEMENTATION,
} from '../internal/marketplace-read.internal.module';
import { QUOTE_READ_PORT } from './quote-read.port';

@Module({
  imports: [MarketplaceReadInternalModule],
  providers: [
    {
      provide: QUOTE_READ_PORT,
      useExisting: QUOTE_READ_IMPLEMENTATION,
    },
  ],
  exports: [QUOTE_READ_PORT],
})
export class QuoteReadPublicModule {}
