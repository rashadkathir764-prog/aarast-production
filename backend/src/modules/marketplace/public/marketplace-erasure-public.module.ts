import { Module } from '@nestjs/common';
import {
  MARKETPLACE_ERASURE_IMPLEMENTATION,
  MarketplaceReadInternalModule,
} from '../internal/marketplace-read.internal.module';
import { MARKETPLACE_ERASURE_PORT } from './marketplace-erasure.port';

@Module({
  imports: [MarketplaceReadInternalModule],
  providers: [
    {
      provide: MARKETPLACE_ERASURE_PORT,
      useExisting: MARKETPLACE_ERASURE_IMPLEMENTATION,
    },
  ],
  exports: [MARKETPLACE_ERASURE_PORT],
})
export class MarketplaceErasurePublicModule {}
