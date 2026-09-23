import { Module } from '@nestjs/common';
import { MarketplaceAdminService } from './marketplace-admin.service';

export const MARKETPLACE_ADMIN_IMPLEMENTATION = Symbol('MARKETPLACE_ADMIN_IMPLEMENTATION');

@Module({
  providers: [
    MarketplaceAdminService,
    {
      provide: MARKETPLACE_ADMIN_IMPLEMENTATION,
      useExisting: MarketplaceAdminService,
    },
  ],
  exports: [MarketplaceAdminService, MARKETPLACE_ADMIN_IMPLEMENTATION],
})
export class MarketplaceAdminInternalModule {}
