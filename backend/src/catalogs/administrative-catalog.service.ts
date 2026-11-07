import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AdministrativeLocalityType, Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import {
  IDENTITY_ADMIN_PORT,
  type IdentityAdminPort,
} from '../modules/identity/public/identity-admin.port';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { AdminPermission } from '../modules/backoffice/public/admin-permission.port';
import { runAuthorizedAdminMutation } from '../modules/backoffice/public/admin-mutation-gate';
import { PrismaService } from '../platform/database/prisma.service';
import { duplicateValueConflict } from '../platform/http/duplicate-value';
import { AdministrativeCatalogRepository } from '../modules/catalog/infrastructure/administrative-catalog.repository';
import {
  AdminDistrictDto,
  AdminGovernorateDto,
  AdminLocalityDto,
} from './dto/admin-reference-catalog.dto';

@Injectable()
export class AdministrativeCatalogService {
  private readonly repository = new AdministrativeCatalogRepository();
  constructor(
    private readonly prisma: PrismaService,
    @Inject(IDENTITY_ADMIN_PORT) private readonly accounts: IdentityAdminPort,
  ) {}

  async listGovernorates() {
    return this.repository.listGovernorates(this.prisma);
  }

  async listDistricts(governorateId: string) {
    await this.requireGovernorate(governorateId, false);
    return this.repository.listDistricts(this.prisma, governorateId);
  }

  async listLocalities(districtId: string) {
    await this.requireDistrict(districtId, false);
    return this.repository.listLocalities(this.prisma, districtId);
  }

  async listPublicLocalities(districtId: string) {
    const district = await this.repository.findActiveDistrictWithGovernorate(
      this.prisma,
      districtId,
    );
    if (!district) throw new NotFoundException('District not found');
    return this.repository.listActiveLocalities(this.prisma, districtId);
  }

  createGovernorate(
    currentUser: AuthenticatedUser,
    dto: AdminGovernorateDto,
  ) {
    const nameAr = this.requiredText(dto.nameAr, 'nameAr');
    const nameEn = this.optionalText(dto.nameEn) ?? nameAr;
    const code = this.normalizedCode(dto.code);
    return this.authorizedMutation(currentUser, async (tx) => {
      await this.assertCodeAvailable(tx, code);
      try {
        return await this.repository.createGovernorate(tx, {
          code,
          nameAr,
          nameEn,
          latitude: dto.latitude,
          longitude: dto.longitude,
          sortOrder: dto.sortOrder ?? 0,
          isActive: dto.isActive ?? true,
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  updateGovernorate(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminGovernorateDto,
  ) {
    return this.authorizedMutation(currentUser, async (tx) => {
      const current = await this.repository.getGovernorate(tx, id);
      if (!current) throw new NotFoundException('Governorate not found');
      this.assertCodeUnchanged(dto.code, current.code);
      try {
        return await this.repository.updateGovernorate(tx, id, {
          ...(dto.nameAr === undefined
            ? {}
            : { nameAr: this.requiredText(dto.nameAr, 'nameAr') }),
          ...this.englishNameUpdate(dto, current.nameAr),
          ...(dto.latitude === undefined ? {} : { latitude: dto.latitude }),
          ...(dto.longitude === undefined ? {} : { longitude: dto.longitude }),
          ...(dto.sortOrder === undefined ? {} : { sortOrder: dto.sortOrder }),
          ...(dto.isActive === undefined ? {} : { isActive: dto.isActive }),
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  disableGovernorate(currentUser: AuthenticatedUser, id: string) {
    return this.authorizedMutation(currentUser, async (tx) => {
      await this.requireGovernorate(id, false, tx);
      return this.repository.disableGovernorate(tx, id);
    });
  }

  createDistrict(
    currentUser: AuthenticatedUser,
    governorateId: string,
    dto: AdminDistrictDto,
  ) {
    const nameAr = this.requiredText(dto.nameAr, 'nameAr');
    const nameEn = this.optionalText(dto.nameEn) ?? nameAr;
    const code = this.normalizedCode(dto.code);
    return this.authorizedMutation(currentUser, async (tx) => {
      await this.requireGovernorate(governorateId, false, tx);
      if (dto.governorateId && dto.governorateId !== governorateId) {
        throw new BadRequestException('Governorate does not match route');
      }
      await this.assertCodeAvailable(tx, code);
      try {
        return await this.repository.createDistrict(tx, {
          governorateId,
          code,
          nameAr,
          nameEn,
          latitude: dto.latitude,
          longitude: dto.longitude,
          sortOrder: dto.sortOrder ?? 0,
          isActive: dto.isActive ?? true,
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  updateDistrict(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminDistrictDto,
  ) {
    return this.authorizedMutation(currentUser, async (tx) => {
      const current = await this.repository.getDistrict(tx, id);
      if (!current) throw new NotFoundException('District not found');
      this.assertCodeUnchanged(dto.code, current.code);
      if (dto.governorateId && dto.governorateId !== current.governorateId) {
        throw new BadRequestException('District governorate is immutable');
      }
      try {
        return await this.repository.updateDistrict(
          tx,
          id,
          this.namedLocationUpdate(dto, current.nameAr),
        );
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  disableDistrict(currentUser: AuthenticatedUser, id: string) {
    return this.authorizedMutation(currentUser, async (tx) => {
      await this.requireDistrict(id, false, tx);
      return this.repository.disableDistrict(tx, id);
    });
  }

  createLocality(
    currentUser: AuthenticatedUser,
    districtId: string,
    dto: AdminLocalityDto,
  ) {
    const nameAr = this.requiredText(dto.nameAr, 'nameAr');
    const code = this.normalizedCode(dto.code);
    const type = dto.type ?? AdministrativeLocalityType.NEIGHBORHOOD;
    return this.authorizedMutation(currentUser, async (tx) => {
      await this.requireDistrict(districtId, false, tx);
      if (dto.districtId && dto.districtId !== districtId) {
        throw new BadRequestException('District does not match route');
      }
      await this.assertParent(tx, districtId, dto.parentId ?? null);
      await this.assertCodeAvailable(tx, code);
      try {
        return await this.repository.createLocality(tx, {
          districtId,
          parentId: dto.parentId ?? null,
          code,
          type,
          nameAr,
          nameEn: this.optionalText(dto.nameEn),
          latitude: dto.latitude,
          longitude: dto.longitude,
          sortOrder: dto.sortOrder ?? 0,
          isActive: dto.isActive ?? true,
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  updateLocality(
    currentUser: AuthenticatedUser,
    id: string,
    dto: AdminLocalityDto,
  ) {
    return this.authorizedMutation(currentUser, async (tx) => {
      const current = await this.repository.getLocality(tx, id);
      if (!current) throw new NotFoundException('Locality not found');
      this.assertCodeUnchanged(dto.code, current.code);
      if (dto.districtId && dto.districtId !== current.districtId) {
        throw new BadRequestException('Locality district is immutable');
      }
      if (dto.parentId !== undefined) {
        await this.assertParent(tx, current.districtId, dto.parentId, id);
      }
      try {
        return await this.repository.updateLocality(tx, id, {
          ...this.namedLocationUpdate(dto, current.nameAr),
          ...(dto.nameEn === undefined
            ? {}
            : { nameEn: this.optionalText(dto.nameEn) }),
          ...(dto.type === undefined ? {} : { type: dto.type }),
          ...(dto.parentId === undefined ? {} : { parentId: dto.parentId }),
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  disableLocality(currentUser: AuthenticatedUser, id: string) {
    return this.authorizedMutation(currentUser, async (tx) => {
      const locality = await this.repository.getLocality(tx, id);
      if (!locality) throw new NotFoundException('Locality not found');
      return this.repository.disableLocality(tx, id);
    });
  }

  private authorizedMutation<T>(
    currentUser: AuthenticatedUser,
    mutation: (tx: Prisma.TransactionClient) => Promise<T>,
  ) {
    return runAuthorizedAdminMutation(
      this.prisma,
      this.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      mutation,
    );
  }

  /**
   * RA-AD-16: the English name is optional (the form says so). An empty one
   * takes the Arabic name, on an edit as on create, instead of a 400.
   */
  private englishNameUpdate(dto: AdminGovernorateDto, currentNameAr: string) {
    if (dto.nameEn === undefined) return {};
    const nameAr =
      dto.nameAr === undefined ? currentNameAr : this.requiredText(dto.nameAr, 'nameAr');
    return { nameEn: this.optionalText(dto.nameEn) ?? nameAr };
  }

  private namedLocationUpdate(dto: AdminGovernorateDto, currentNameAr: string) {
    return {
      ...(dto.nameAr === undefined
        ? {}
        : { nameAr: this.requiredText(dto.nameAr, 'nameAr') }),
      ...this.englishNameUpdate(dto, currentNameAr),
      ...(dto.latitude === undefined ? {} : { latitude: dto.latitude }),
      ...(dto.longitude === undefined ? {} : { longitude: dto.longitude }),
      ...(dto.sortOrder === undefined ? {} : { sortOrder: dto.sortOrder }),
      ...(dto.isActive === undefined ? {} : { isActive: dto.isActive }),
    };
  }

  private async assertParent(
    tx: Prisma.TransactionClient,
    districtId: string,
    parentId: string | null,
    localityId?: string,
  ): Promise<void> {
    if (!parentId) return;
    if (parentId === localityId) {
      throw new BadRequestException('Locality cannot be its own parent');
    }
    let cursor: string | null = parentId;
    const visited = new Set<string>();
    while (cursor) {
      if (cursor === localityId || visited.has(cursor)) {
        throw new BadRequestException('Locality hierarchy contains a cycle');
      }
      visited.add(cursor);
      const parent: { districtId: string; parentId: string | null } | null =
        await this.repository.getLocalityParent(tx, cursor);
      if (!parent || parent.districtId !== districtId) {
        throw new BadRequestException('Parent must belong to the same district');
      }
      cursor = parent.parentId;
    }
  }

  private async assertCodeAvailable(
    tx: Prisma.TransactionClient,
    code: string,
  ): Promise<void> {
    if (await this.repository.isAdministrativeCodeTaken(tx, code)) {
      throw duplicateValueConflict('Administrative code already exists');
    }
  }

  private async requireGovernorate(
    id: string,
    activeOnly: boolean,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ) {
    const governorate = await this.repository.findGovernorate(
      client,
      id,
      activeOnly,
    );
    if (!governorate) throw new NotFoundException('Governorate not found');
    return governorate;
  }

  private async requireDistrict(
    id: string,
    activeOnly: boolean,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ) {
    const district = await this.repository.findDistrict(client, id, activeOnly);
    if (!district) throw new NotFoundException('District not found');
    return district;
  }

  private normalizedCode(value?: string | null): string {
    const normalized = value?.trim().toUpperCase();
    if (!normalized) {
      return `CUSTOM-${randomUUID().replaceAll('-', '').slice(0, 20).toUpperCase()}`;
    }
    if (!/^[A-Z0-9][A-Z0-9_-]{1,39}$/.test(normalized)) {
      throw new BadRequestException('Administrative code is invalid');
    }
    return normalized;
  }

  private assertCodeUnchanged(value: string | null | undefined, code: string) {
    if (value !== undefined && this.normalizedCode(value) !== code) {
      throw new BadRequestException('Administrative code is immutable');
    }
  }

  private requiredText(value: string | null | undefined, field: string): string {
    const normalized = value?.trim();
    if (!normalized) throw new BadRequestException(`${field} is required`);
    return normalized;
  }

  private optionalText(value: string | null | undefined): string | null {
    const normalized = value?.trim();
    return normalized || null;
  }

  private rethrowUnique(error: unknown): never {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      throw duplicateValueConflict('Administrative entry already exists');
    }
    throw error;
  }
}
