import { Module } from '@nestjs/common';
import {
  CATALOG_READ_IMPLEMENTATION,
  CatalogReadInternalModule,
} from '../internal/catalog-read.internal.module';
import { CATALOG_READ_PORT } from './catalog-read.port';

@Module({
  imports: [CatalogReadInternalModule],
  providers: [
    {
      provide: CATALOG_READ_PORT,
      useExisting: CATALOG_READ_IMPLEMENTATION,
    },
  ],
  exports: [CATALOG_READ_PORT],
})
export class CatalogReadPublicModule {}
