import { Module } from '@nestjs/common';
import { AdministrativeCatalogService } from '../../../catalogs/administrative-catalog.service';
import { ReferenceCatalogService } from '../../../catalogs/reference-catalog.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { IdentityAdminPublicModule } from '../../identity/public/identity-admin-public.module';

@Module({
  imports: [PrismaModule, IdentityAdminPublicModule],
  providers: [ReferenceCatalogService, AdministrativeCatalogService],
  exports: [ReferenceCatalogService, AdministrativeCatalogService],
})
export class CatalogServicesInternalModule {}
