import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { CurrentUser } from '../modules/identity/public/current-user.decorator';
import { JwtSessionGuard } from '../modules/identity/public/jwt-session.guard';
import { AdminGuard } from '../admin/admin.guard';
import { AdminPermissionGuard } from '../admin/admin-permission.guard';
import { RequireAdminPermission } from '../admin/admin-permission.decorator';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { AdministrativeCatalogService } from './administrative-catalog.service';
import {
  AdminCatalogItemDto,
  AdminDistrictDto,
  AdminGovernorateDto,
  AdminLocalityDto,
  PublishCatalogItemDto,
} from './dto/admin-reference-catalog.dto';
import { CatalogBootstrapQueryDto } from './dto/catalog-bootstrap-query.dto';
import { ReferenceCatalogService } from './reference-catalog.service';

@Controller('api/v1/catalogs')
export class CatalogsController {
  constructor(private readonly catalogs: ReferenceCatalogService) {}

  @Get('bootstrap')
  getBootstrap(@Query() query: CatalogBootstrapQueryDto) {
    return this.catalogs.getBootstrap(query.version);
  }
}

@Controller('api/v1/districts')
export class DistrictLocalitiesController {
  constructor(private readonly locations: AdministrativeCatalogService) {}

  @Get(':id/localities')
  listLocalities(@Param('id') id: string) {
    return this.locations.listPublicLocalities(id);
  }
}

@Controller('admin/reference-catalogs')
@UseGuards(JwtSessionGuard, AdminGuard, AdminPermissionGuard)
export class AdminReferenceCatalogsController {
  constructor(private readonly catalogs: ReferenceCatalogService) {}

  @Get()
  @RequireAdminPermission(AdminPermission.CATALOG_READ)
  listCatalogs() {
    return this.catalogs.listAdminCatalogs();
  }

  @Get(':catalogKey')
  @RequireAdminPermission(AdminPermission.CATALOG_READ)
  getCatalog(@Param('catalogKey') catalogKey: string) {
    return this.catalogs.getAdminCatalog(catalogKey);
  }

  @Post(':catalogKey/items')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  createItem(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('catalogKey') catalogKey: string,
    @Body() dto: AdminCatalogItemDto,
  ) {
    return this.catalogs.createItem(currentUser, catalogKey, dto);
  }

  @Patch(':catalogKey/items/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  updateItem(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('catalogKey') catalogKey: string,
    @Param('id') id: string,
    @Body() dto: AdminCatalogItemDto,
  ) {
    return this.catalogs.updateItem(currentUser, catalogKey, id, dto);
  }

  @Post(':catalogKey/items/:id/publish')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  publishItem(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('catalogKey') catalogKey: string,
    @Param('id') id: string,
    @Body() dto: PublishCatalogItemDto,
  ) {
    return this.catalogs.publishItem(currentUser, catalogKey, id, dto.revision);
  }

  @Delete(':catalogKey/items/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  disableItem(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('catalogKey') catalogKey: string,
    @Param('id') id: string,
  ) {
    return this.catalogs.disableItem(currentUser, catalogKey, id);
  }
}

@Controller('admin')
@UseGuards(JwtSessionGuard, AdminGuard, AdminPermissionGuard)
export class AdminAdministrativeCatalogController {
  constructor(private readonly locations: AdministrativeCatalogService) {}

  @Get('governorates')
  @RequireAdminPermission(AdminPermission.CATALOG_READ)
  listGovernorates() {
    return this.locations.listGovernorates();
  }

  @Post('governorates')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  createGovernorate(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Body() dto: AdminGovernorateDto,
  ) {
    return this.locations.createGovernorate(currentUser, dto);
  }

  @Patch('governorates/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  updateGovernorate(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminGovernorateDto,
  ) {
    return this.locations.updateGovernorate(currentUser, id, dto);
  }

  @Delete('governorates/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  disableGovernorate(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.locations.disableGovernorate(currentUser, id);
  }

  @Get('governorates/:id/districts')
  @RequireAdminPermission(AdminPermission.CATALOG_READ)
  listDistricts(@Param('id') id: string) {
    return this.locations.listDistricts(id);
  }

  @Post('governorates/:id/districts')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  createDistrict(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminDistrictDto,
  ) {
    return this.locations.createDistrict(currentUser, id, dto);
  }

  @Patch('districts/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  updateDistrict(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminDistrictDto,
  ) {
    return this.locations.updateDistrict(currentUser, id, dto);
  }

  @Delete('districts/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  disableDistrict(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.locations.disableDistrict(currentUser, id);
  }

  @Get('districts/:id/localities')
  @RequireAdminPermission(AdminPermission.CATALOG_READ)
  listLocalities(@Param('id') id: string) {
    return this.locations.listLocalities(id);
  }

  @Post('districts/:id/localities')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  createLocality(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminLocalityDto,
  ) {
    return this.locations.createLocality(currentUser, id, dto);
  }

  @Patch('localities/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  updateLocality(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
    @Body() dto: AdminLocalityDto,
  ) {
    return this.locations.updateLocality(currentUser, id, dto);
  }

  @Delete('localities/:id')
  @RequireAdminPermission(AdminPermission.CATALOG_WRITE)
  disableLocality(
    @CurrentUser() currentUser: AuthenticatedUser,
    @Param('id') id: string,
  ) {
    return this.locations.disableLocality(currentUser, id);
  }
}
