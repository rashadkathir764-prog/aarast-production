import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { AdministrativeLocalityType, Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { runAuthorizedAdminMutation } from '../admin/admin-mutation-gate';
import { PrismaService } from '../platform/database/prisma.service';
import {
  AdminDistrictDto,
  AdminGovernorateDto,
  AdminLocalityDto,
} from './dto/admin-reference-catalog.dto';

@Injectable()
export class AdministrativeCatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async listGovernorates() {
    return this.prisma.governorate.findMany({
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { districts: true } } },
    });
  }

  async listDistricts(governorateId: string) {
    await this.requireGovernorate(governorateId, false);
    return this.prisma.district.findMany({
      where: { governorateId },
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      include: { _count: { select: { localities: true } } },
    });
  }

  async listLocalities(districtId: string) {
    await this.requireDistrict(districtId, false);
    return this.prisma.administrativeLocality.findMany({
      where: { districtId },
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { nameAr: 'asc' }],
    });
  }

  async listPublicLocalities(districtId: string) {
    const district = await this.prisma.district.findFirst({
      where: {
        id: districtId,
        isActive: true,
        governorate: { isActive: true },
      },
      select: { id: true },
    });
    if (!district) throw new NotFoundException('District not found');
    return this.prisma.administrativeLocality.findMany({
      where: { districtId, isActive: true },
      orderBy: [{ type: 'asc' }, { sortOrder: 'asc' }, { nameAr: 'asc' }],
      select: {
        id: true,
        districtId: true,
        parentId: true,
        code: true,
        type: true,
        nameAr: true,
        nameEn: true,
        latitude: true,
        longitude: true,
        sortOrder: true,
      },
    });
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
        return await tx.governorate.create({
          data: {
            code,
            nameAr,
            nameEn,
            latitude: dto.latitude,
            longitude: dto.longitude,
            sortOrder: dto.sortOrder ?? 0,
            isActive: dto.isActive ?? true,
          },
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
      const current = await tx.governorate.findUnique({ where: { id } });
      if (!current) throw new NotFoundException('Governorate not found');
      this.assertCodeUnchanged(dto.code, current.code);
      try {
        return await tx.governorate.update({
          where: { id },
          data: {
            ...(dto.nameAr === undefined
              ? {}
              : { nameAr: this.requiredText(dto.nameAr, 'nameAr') }),
            ...(dto.nameEn === undefined
              ? {}
              : { nameEn: this.requiredText(dto.nameEn, 'nameEn') }),
            ...(dto.latitude === undefined ? {} : { latitude: dto.latitude }),
            ...(dto.longitude === undefined
              ? {}
              : { longitude: dto.longitude }),
            ...(dto.sortOrder === undefined ? {} : { sortOrder: dto.sortOrder }),
            ...(dto.isActive === undefined ? {} : { isActive: dto.isActive }),
          },
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  disableGovernorate(currentUser: AuthenticatedUser, id: string) {
    return this.authorizedMutation(currentUser, async (tx) => {
      await this.requireGovernorate(id, false, tx);
      return tx.governorate.update({
        where: { id },
        data: { isActive: false },
      });
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
        return await tx.district.create({
          data: {
            governorateId,
            code,
            nameAr,
            nameEn,
            latitude: dto.latitude,
            longitude: dto.longitude,
            sortOrder: dto.sortOrder ?? 0,
            isActive: dto.isActive ?? true,
          },
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
      const current = await tx.district.findUnique({ where: { id } });
      if (!current) throw new NotFoundException('District not found');
      this.assertCodeUnchanged(dto.code, current.code);
      if (dto.governorateId && dto.governorateId !== current.governorateId) {
        throw new BadRequestException('District governorate is immutable');
      }
      try {
        return await tx.district.update({
          where: { id },
          data: this.namedLocationUpdate(dto),
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  disableDistrict(currentUser: AuthenticatedUser, id: string) {
    return this.authorizedMutation(currentUser, async (tx) => {
      await this.requireDistrict(id, false, tx);
      return tx.district.update({ where: { id }, data: { isActive: false } });
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
        return await tx.administrativeLocality.create({
          data: {
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
          },
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
      const current = await tx.administrativeLocality.findUnique({
        where: { id },
      });
      if (!current) throw new NotFoundException('Locality not found');
      this.assertCodeUnchanged(dto.code, current.code);
      if (dto.districtId && dto.districtId !== current.districtId) {
        throw new BadRequestException('Locality district is immutable');
      }
      if (dto.parentId !== undefined) {
        await this.assertParent(tx, current.districtId, dto.parentId, id);
      }
      try {
        return await tx.administrativeLocality.update({
          where: { id },
          data: {
            ...this.namedLocationUpdate(dto),
            ...(dto.nameEn === undefined
              ? {}
              : { nameEn: this.optionalText(dto.nameEn) }),
            ...(dto.type === undefined ? {} : { type: dto.type }),
            ...(dto.parentId === undefined ? {} : { parentId: dto.parentId }),
          },
        });
      } catch (error) {
        this.rethrowUnique(error);
      }
    });
  }

  disableLocality(currentUser: AuthenticatedUser, id: string) {
    return this.authorizedMutation(currentUser, async (tx) => {
      const locality = await tx.administrativeLocality.findUnique({
        where: { id },
      });
      if (!locality) throw new NotFoundException('Locality not found');
      return tx.administrativeLocality.update({
        where: { id },
        data: { isActive: false },
      });
    });
  }

  private authorizedMutation<T>(
    currentUser: AuthenticatedUser,
    mutation: (tx: Prisma.TransactionClient) => Promise<T>,
  ) {
    return runAuthorizedAdminMutation(
      this.prisma,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      mutation,
    );
  }

  private namedLocationUpdate(dto: AdminGovernorateDto) {
    return {
      ...(dto.nameAr === undefined
        ? {}
        : { nameAr: this.requiredText(dto.nameAr, 'nameAr') }),
      ...(dto.nameEn === undefined
        ? {}
        : { nameEn: this.requiredText(dto.nameEn, 'nameEn') }),
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
        await tx.administrativeLocality.findUnique({
          where: { id: cursor },
          select: { districtId: true, parentId: true },
        });
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
    const [governorate, district, locality] = await Promise.all([
      tx.governorate.findUnique({ where: { code }, select: { id: true } }),
      tx.district.findUnique({ where: { code }, select: { id: true } }),
      tx.administrativeLocality.findUnique({
        where: { code },
        select: { id: true },
      }),
    ]);
    if (governorate || district || locality) {
      throw new ConflictException('Administrative code already exists');
    }
  }

  private async requireGovernorate(
    id: string,
    activeOnly: boolean,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ) {
    const governorate = await client.governorate.findFirst({
      where: { id, ...(activeOnly ? { isActive: true } : {}) },
    });
    if (!governorate) throw new NotFoundException('Governorate not found');
    return governorate;
  }

  private async requireDistrict(
    id: string,
    activeOnly: boolean,
    client: Prisma.TransactionClient | PrismaService = this.prisma,
  ) {
    const district = await client.district.findFirst({
      where: { id, ...(activeOnly ? { isActive: true } : {}) },
    });
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
      throw new ConflictException('Administrative entry already exists');
    }
    throw error;
  }
}
