import { Module } from '@nestjs/common';
import {
  AdminAdministrativeCatalogController,
  AdminReferenceCatalogsController,
  CatalogsController,
  DistrictLocalitiesController,
} from '../../catalogs/catalogs.controller';
import { CatalogServicesInternalModule } from './internal/catalog-services.internal.module';

@Module({
  imports: [CatalogServicesInternalModule],
  controllers: [
    CatalogsController,
    DistrictLocalitiesController,
    AdminReferenceCatalogsController,
    AdminAdministrativeCatalogController,
  ],
})
export class CatalogModule {}
