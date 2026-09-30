import { Module } from '@nestjs/common';
import { CatalogReadService } from '../infrastructure/catalog-read.service';

export const CATALOG_READ_IMPLEMENTATION = Symbol('CATALOG_READ_IMPLEMENTATION');

@Module({
  providers: [
    CatalogReadService,
    {
      provide: CATALOG_READ_IMPLEMENTATION,
      useExisting: CatalogReadService,
    },
  ],
  exports: [CatalogReadService, CATALOG_READ_IMPLEMENTATION],
})
export class CatalogReadInternalModule {}
