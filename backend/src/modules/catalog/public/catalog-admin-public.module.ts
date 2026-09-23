import { Module } from '@nestjs/common';
import {
  CATALOG_ADMIN_IMPLEMENTATION,
  CatalogAdminInternalModule,
} from '../internal/catalog-admin.internal.module';
import { CATALOG_ADMIN_PORT } from './catalog-admin.port';

@Module({
  imports: [CatalogAdminInternalModule],
  providers: [
    {
      provide: CATALOG_ADMIN_PORT,
      useExisting: CATALOG_ADMIN_IMPLEMENTATION,
    },
  ],
  exports: [CATALOG_ADMIN_PORT],
})
export class CatalogAdminPublicModule {}
