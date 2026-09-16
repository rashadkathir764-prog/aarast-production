import { Module } from '@nestjs/common';
import {
  MarketplaceReadInternalModule,
  PROVIDER_READ_IMPLEMENTATION,
} from '../internal/marketplace-read.internal.module';
import { PROVIDER_READ_PORT } from './provider-read.port';

@Module({
  imports: [MarketplaceReadInternalModule],
  providers: [
    {
      provide: PROVIDER_READ_PORT,
      useExisting: PROVIDER_READ_IMPLEMENTATION,
    },
  ],
  exports: [PROVIDER_READ_PORT],
})
export class ProviderReadPublicModule {}
