import { Module } from '@nestjs/common';
import { AdministrativeCatalogService } from '../../../catalogs/administrative-catalog.service';
import { ReferenceCatalogService } from '../../../catalogs/reference-catalog.service';
import { PrismaModule } from '../../../platform/database/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [ReferenceCatalogService, AdministrativeCatalogService],
  exports: [ReferenceCatalogService, AdministrativeCatalogService],
})
export class CatalogServicesInternalModule {}
