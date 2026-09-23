import { Module } from '@nestjs/common';
import {
  MARKETPLACE_ADMIN_IMPLEMENTATION,
  MarketplaceAdminInternalModule,
} from '../internal/marketplace-admin.internal.module';
import { MARKETPLACE_ADMIN_PORT } from './marketplace-admin.port';

@Module({
  imports: [MarketplaceAdminInternalModule],
  providers: [
    {
      provide: MARKETPLACE_ADMIN_PORT,
      useExisting: MARKETPLACE_ADMIN_IMPLEMENTATION,
    },
  ],
  exports: [MARKETPLACE_ADMIN_PORT],
})
export class MarketplaceAdminPublicModule {}
