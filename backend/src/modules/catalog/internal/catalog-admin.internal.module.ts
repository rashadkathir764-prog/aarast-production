import { Module } from '@nestjs/common';
import { CatalogAdminService } from './catalog-admin.service';

export const CATALOG_ADMIN_IMPLEMENTATION = Symbol('CATALOG_ADMIN_IMPLEMENTATION');

@Module({
  providers: [
    CatalogAdminService,
    {
      provide: CATALOG_ADMIN_IMPLEMENTATION,
      useExisting: CatalogAdminService,
    },
  ],
  exports: [CatalogAdminService, CATALOG_ADMIN_IMPLEMENTATION],
})
export class CatalogAdminInternalModule {}
