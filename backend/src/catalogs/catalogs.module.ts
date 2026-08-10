import { Module } from '@nestjs/common';
import { AdminGuard } from '../admin/admin.guard';
import { AdminPermissionGuard } from '../admin/admin-permission.guard';
import { PrismaModule } from '../prisma/prisma.module';
import { AdministrativeCatalogService } from './administrative-catalog.service';
import {
  AdminAdministrativeCatalogController,
  AdminReferenceCatalogsController,
  CatalogsController,
  DistrictLocalitiesController,
} from './catalogs.controller';
import { ReferenceCatalogService } from './reference-catalog.service';

@Module({
  imports: [PrismaModule],
  controllers: [
    CatalogsController,
    DistrictLocalitiesController,
    AdminReferenceCatalogsController,
    AdminAdministrativeCatalogController,
  ],
  providers: [
    ReferenceCatalogService,
    AdministrativeCatalogService,
    AdminGuard,
    AdminPermissionGuard,
  ],
  exports: [ReferenceCatalogService, AdministrativeCatalogService],
})
export class CatalogsModule {}
