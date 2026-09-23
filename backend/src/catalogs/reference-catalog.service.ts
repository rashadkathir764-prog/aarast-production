import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { createHash, randomUUID } from 'node:crypto';
import { Prisma } from '@prisma/client';
import {
  IDENTITY_ADMIN_PORT,
  type IdentityAdminPort,
} from '../modules/identity/public/identity-admin.port';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { runAuthorizedAdminMutation } from '../modules/backoffice/public/admin-mutation-gate';
import { PrismaService } from '../platform/database/prisma.service';
import { AdminCatalogItemDto } from './dto/admin-reference-catalog.dto';
import {
  MONEY_STARTER_CATALOG_KEY,
  moneyStarterDefaults,
  supportedCatalogIconKeys,
} from './reference-catalog.defaults';

const catalogSeedLock = 2_026_080_901;

@Injectable()
export class ReferenceCatalogService {
  private seedPromise: Promise<void> | null = null;

  constructor(
    private readonly prisma: PrismaService,
    @Inject(IDENTITY_ADMIN_PORT) private readonly accounts: IdentityAdminPort,
  ) {}

  async getBootstrap(knownVersion?: string) {
    await this.ensureSystemCatalogs();
    const [catalogs, providerCategories, cities, governorates, districtVersion, localityVersion] =
      await this.prisma.$transaction([
        this.prisma.referenceCatalog.findMany({
          where: { isActive: true },
          orderBy: { key: 'asc' },
          include: {
            items: {
              where: { publishedRevision: { gt: 0 } },
              orderBy: { key: 'asc' },
              include: { revisions: { orderBy: { revision: 'desc' } } },
            },
          },
        }),
        this.prisma.providerCategory.findMany({
          where: { isActive: true },
          orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
        }),
        this.prisma.city.findMany({
          where: { isActive: true },
          orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
        }),
        this.prisma.governorate.findMany({
          where: { isActive: true },
          orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
          include: {
            _count: {
              select: {
                districts: { where: { isActive: true } },
              },
            },
          },
        }),
        this.prisma.district.aggregate({ _max: { updatedAt: true } }),
        this.prisma.administrativeLocality.aggregate({
          _max: { updatedAt: true },
        }),
      ]);

    const version = this.bootstrapVersion({
      catalogs: catalogs.map((catalog) => ({
        key: catalog.key,
        version: catalog.version,
        updatedAt: catalog.updatedAt.toISOString(),
      })),
      providerCategories: providerCategories.map((item) => [
        item.id,
        item.updatedAt.toISOString(),
      ]),
      cities: cities.map((item) => [item.id, item.updatedAt.toISOString()]),
      governorates: governorates.map((item) => [
        item.id,
        item.updatedAt.toISOString(),
      ]),
      districtsUpdatedAt: districtVersion._max.updatedAt?.toISOString() ?? null,
      localitiesUpdatedAt:
        localityVersion._max.updatedAt?.toISOString() ?? null,
    });

    if (knownVersion?.trim() === version) {
      return { version, unchanged: true };
    }

    return {
      version,
      unchanged: false,
      catalogs: catalogs.map((catalog) => ({
        key: catalog.key,
        nameAr: catalog.nameAr,
        description: catalog.description,
        version: catalog.version,
        items: catalog.items.flatMap((item) => {
          const revision = item.revisions.find(
            (candidate) => candidate.revision === item.publishedRevision,
          );
          if (!revision?.isActive) return [];
          return [this.toPublishedItem(item.key, revision)];
        }),
      })),
      providerCategories: providerCategories.map((item) => ({
        id: item.id,
        key: item.slug,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        icon: item.icon,
        showForGroom: item.showForGroom,
        showForBride: item.showForBride,
        sortOrder: item.sortOrder,
      })),
      cities: cities.map((item) => ({
        id: item.id,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        countryCode: item.countryCode,
        sortOrder: item.sortOrder,
      })),
      governorates: governorates.map((item) => ({
        id: item.id,
        code: item.code,
        nameAr: item.nameAr,
        nameEn: item.nameEn,
        latitude: item.latitude,
        longitude: item.longitude,
        sortOrder: item.sortOrder,
        districtsCount: item._count.districts,
      })),
    };
  }

  async listAdminCatalogs() {
    await this.ensureSystemCatalogs();
    const catalogs = await this.prisma.referenceCatalog.findMany({
      orderBy: { key: 'asc' },
      include: { items: true },
    });
    return catalogs.map((catalog) => ({
      id: catalog.id,
      key: catalog.key,
      nameAr: catalog.nameAr,
      description: catalog.description,
      version: catalog.version,
      isActive: catalog.isActive,
      itemsCount: catalog.items.length,
      publishedCount: catalog.items.filter(
        (item) => item.publishedRevision > 0,
      ).length,
      pendingCount: catalog.items.filter(
        (item) => item.currentRevision !== item.publishedRevision,
      ).length,
      updatedAt: catalog.updatedAt,
    }));
  }

  async getAdminCatalog(catalogKey: string) {
    await this.ensureSystemCatalogs();
    const catalog = await this.prisma.referenceCatalog.findUnique({
      where: { key: catalogKey },
      include: {
        items: {
          orderBy: { key: 'asc' },
          include: { revisions: { orderBy: { revision: 'desc' } } },
        },
      },
    });
    if (!catalog) throw new NotFoundException('Reference catalog not found');
    return {
      id: catalog.id,
      key: catalog.key,
      nameAr: catalog.nameAr,
      description: catalog.description,
      version: catalog.version,
      isActive: catalog.isActive,
      updatedAt: catalog.updatedAt,
      items: catalog.items.map((item) => this.toAdminItem(item)),
    };
  }

  async createItem(
    currentUser: AuthenticatedUser,
    catalogKey: string,
    dto: AdminCatalogItemDto,
  ) {
    await this.ensureSystemCatalogs();
    const nameAr = this.requiredText(dto.nameAr, 'nameAr');
    this.validateIcon(dto.icon);
    const result = await runAuthorizedAdminMutation(
      this.prisma,
      this.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        const catalog = await this.lockCatalog(tx, catalogKey);
        const itemKey =
          this.optionalKey(dto.key) ?? `custom-${randomUUID().toLowerCase()}`;
        const existing = await tx.referenceCatalogItem.findUnique({
          where: { catalogId_key: { catalogId: catalog.id, key: itemKey } },
        });
        if (existing) throw new ConflictException('Catalog item key exists');
        return tx.referenceCatalogItem.create({
          data: {
            catalogId: catalog.id,
            key: itemKey,
            currentRevision: 1,
            publishedRevision: 0,
            revisions: {
              create: this.revisionData({ ...dto, nameAr }, 1),
            },
          },
          include: { revisions: { orderBy: { revision: 'desc' } } },
        });
      },
    );
    return this.toAdminItem(result);
  }

  async updateItem(
    currentUser: AuthenticatedUser,
    catalogKey: string,
    itemId: string,
    dto: AdminCatalogItemDto,
  ) {
    await this.ensureSystemCatalogs();
    this.validateIcon(dto.icon);
    const result = await runAuthorizedAdminMutation(
      this.prisma,
      this.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        const locked = await this.lockCatalogItem(tx, catalogKey, itemId);
        const current = await tx.referenceCatalogItemRevision.findUnique({
          where: {
            itemId_revision: {
              itemId,
              revision: locked.currentRevision,
            },
          },
        });
        if (!current) throw new NotFoundException('Catalog draft not found');
        const nextRevision = locked.currentRevision + 1;
        await tx.referenceCatalogItemRevision.create({
          data: this.mergedRevisionData(itemId, nextRevision, current, dto),
        });
        return tx.referenceCatalogItem.update({
          where: { id: itemId },
          data: { currentRevision: nextRevision },
          include: { revisions: { orderBy: { revision: 'desc' } } },
        });
      },
    );
    return this.toAdminItem(result);
  }

  async publishItem(
    currentUser: AuthenticatedUser,
    catalogKey: string,
    itemId: string,
    revision?: number,
  ) {
    await this.ensureSystemCatalogs();
    const result = await runAuthorizedAdminMutation(
      this.prisma,
      this.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        const locked = await this.lockCatalogItem(tx, catalogKey, itemId);
        const targetRevision = revision ?? locked.currentRevision;
        const target = await tx.referenceCatalogItemRevision.findUnique({
          where: { itemId_revision: { itemId, revision: targetRevision } },
        });
        if (!target) throw new NotFoundException('Catalog revision not found');
        await tx.referenceCatalog.update({
          where: { id: locked.catalogId },
          data: { version: { increment: 1 } },
        });
        return tx.referenceCatalogItem.update({
          where: { id: itemId },
          data: { publishedRevision: targetRevision },
          include: { revisions: { orderBy: { revision: 'desc' } } },
        });
      },
    );
    return this.toAdminItem(result);
  }

  async disableItem(
    currentUser: AuthenticatedUser,
    catalogKey: string,
    itemId: string,
  ) {
    await this.ensureSystemCatalogs();
    const result = await runAuthorizedAdminMutation(
      this.prisma,
      this.accounts,
      currentUser,
      AdminPermission.CATALOG_WRITE,
      async (tx) => {
        const locked = await this.lockCatalogItem(tx, catalogKey, itemId);
        const current = await tx.referenceCatalogItemRevision.findUnique({
          where: {
            itemId_revision: {
              itemId,
              revision: locked.currentRevision,
            },
          },
        });
        if (!current) throw new NotFoundException('Catalog draft not found');
        const nextRevision = locked.currentRevision + 1;
        await tx.referenceCatalogItemRevision.create({
          data: {
            ...this.copyRevision(current),
            itemId,
            revision: nextRevision,
            isActive: false,
          },
        });
        await tx.referenceCatalog.update({
          where: { id: locked.catalogId },
          data: { version: { increment: 1 } },
        });
        return tx.referenceCatalogItem.update({
          where: { id: itemId },
          data: {
            currentRevision: nextRevision,
            publishedRevision: nextRevision,
          },
          include: { revisions: { orderBy: { revision: 'desc' } } },
        });
      },
    );
    return this.toAdminItem(result);
  }

  private async ensureSystemCatalogs(): Promise<void> {
    if (this.seedPromise != null) return this.seedPromise;
    this.seedPromise = this.seedMoneyStarterCatalog().catch((error) => {
      this.seedPromise = null;
      throw error;
    });
    return this.seedPromise;
  }

  private async seedMoneyStarterCatalog(): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw(
        Prisma.sql`SELECT pg_advisory_xact_lock(${catalogSeedLock})`,
      );
      const catalog = await tx.referenceCatalog.upsert({
        where: { key: MONEY_STARTER_CATALOG_KEY },
        create: {
          key: MONEY_STARTER_CATALOG_KEY,
          nameAr: 'تصنيفات بداية الميزانية',
          description:
            'التصنيفات المقترحة للعريس والعروسة قبل تحديد الميزانية.',
          version: 1,
        },
        update: {},
      });
      for (const item of moneyStarterDefaults) {
        await tx.referenceCatalogItem.upsert({
          where: {
            catalogId_key: { catalogId: catalog.id, key: item.key },
          },
          create: {
            catalogId: catalog.id,
            key: item.key,
            currentRevision: 1,
            publishedRevision: 1,
            revisions: {
              create: {
                revision: 1,
                groupKey: item.groupKey,
                groupNameAr: item.groupNameAr,
                groupSubtitleAr: item.groupSubtitleAr,
                nameAr: item.nameAr,
                icon: item.icon,
                sortOrder: item.sortOrder,
                showForGroom: item.showForGroom,
                showForBride: item.showForBride,
                showForCustomer: true,
                showForProvider: false,
                isRecommended: item.isRecommended,
                isActive: true,
                metadata: item.metadata,
              },
            },
          },
          update: {},
        });
      }
    });
  }

  private async lockCatalog(tx: Prisma.TransactionClient, catalogKey: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ReferenceCatalog"
        WHERE "key" = ${catalogKey}
        FOR UPDATE
      `,
    );
    if (rows.length !== 1) {
      throw new NotFoundException('Reference catalog not found');
    }
    return rows[0];
  }

  private async lockCatalogItem(
    tx: Prisma.TransactionClient,
    catalogKey: string,
    itemId: string,
  ) {
    const rows = await tx.$queryRaw<
      Array<{
        id: string;
        catalogId: string;
        currentRevision: number;
        publishedRevision: number;
      }>
    >(
      Prisma.sql`
        SELECT item."id", item."catalogId", item."currentRevision", item."publishedRevision"
        FROM "ReferenceCatalogItem" item
        INNER JOIN "ReferenceCatalog" catalog ON catalog."id" = item."catalogId"
        WHERE item."id" = ${itemId} AND catalog."key" = ${catalogKey}
        FOR UPDATE OF item
      `,
    );
    if (rows.length !== 1) throw new NotFoundException('Catalog item not found');
    return rows[0];
  }

  private revisionData(dto: AdminCatalogItemDto, revision: number) {
    return {
      revision,
      groupKey: this.optionalText(dto.groupKey),
      groupNameAr: this.optionalText(dto.groupNameAr),
      groupSubtitleAr: this.optionalText(dto.groupSubtitleAr),
      nameAr: this.requiredText(dto.nameAr, 'nameAr'),
      nameEn: this.optionalText(dto.nameEn),
      icon: this.optionalText(dto.icon),
      sortOrder: dto.sortOrder ?? 0,
      showForGroom: dto.showForGroom ?? true,
      showForBride: dto.showForBride ?? true,
      showForCustomer: dto.showForCustomer ?? true,
      showForProvider: dto.showForProvider ?? false,
      isRecommended: dto.isRecommended ?? false,
      isActive: dto.isActive ?? true,
      ...(dto.metadata === undefined
        ? {}
        : { metadata: this.jsonInput(dto.metadata) }),
    };
  }

  private mergedRevisionData(
    itemId: string,
    revision: number,
    current: {
      groupKey: string | null;
      groupNameAr: string | null;
      groupSubtitleAr: string | null;
      nameAr: string;
      nameEn: string | null;
      icon: string | null;
      sortOrder: number;
      showForGroom: boolean;
      showForBride: boolean;
      showForCustomer: boolean;
      showForProvider: boolean;
      isRecommended: boolean;
      isActive: boolean;
      metadata: Prisma.JsonValue | null;
    },
    dto: AdminCatalogItemDto,
  ) {
    return {
      itemId,
      revision,
      groupKey:
        dto.groupKey === undefined
          ? current.groupKey
          : this.optionalText(dto.groupKey),
      groupNameAr:
        dto.groupNameAr === undefined
          ? current.groupNameAr
          : this.optionalText(dto.groupNameAr),
      groupSubtitleAr:
        dto.groupSubtitleAr === undefined
          ? current.groupSubtitleAr
          : this.optionalText(dto.groupSubtitleAr),
      nameAr:
        dto.nameAr === undefined
          ? current.nameAr
          : this.requiredText(dto.nameAr, 'nameAr'),
      nameEn:
        dto.nameEn === undefined
          ? current.nameEn
          : this.optionalText(dto.nameEn),
      icon:
        dto.icon === undefined ? current.icon : this.optionalText(dto.icon),
      sortOrder: dto.sortOrder ?? current.sortOrder,
      showForGroom: dto.showForGroom ?? current.showForGroom,
      showForBride: dto.showForBride ?? current.showForBride,
      showForCustomer: dto.showForCustomer ?? current.showForCustomer,
      showForProvider: dto.showForProvider ?? current.showForProvider,
      isRecommended: dto.isRecommended ?? current.isRecommended,
      isActive: dto.isActive ?? current.isActive,
      metadata:
        dto.metadata === undefined
          ? this.jsonInput(current.metadata)
          : this.jsonInput(dto.metadata),
    };
  }

  private copyRevision(current: {
    groupKey: string | null;
    groupNameAr: string | null;
    groupSubtitleAr: string | null;
    nameAr: string;
    nameEn: string | null;
    icon: string | null;
    sortOrder: number;
    showForGroom: boolean;
    showForBride: boolean;
    showForCustomer: boolean;
    showForProvider: boolean;
    isRecommended: boolean;
    metadata: Prisma.JsonValue | null;
  }) {
    return {
      groupKey: current.groupKey,
      groupNameAr: current.groupNameAr,
      groupSubtitleAr: current.groupSubtitleAr,
      nameAr: current.nameAr,
      nameEn: current.nameEn,
      icon: current.icon,
      sortOrder: current.sortOrder,
      showForGroom: current.showForGroom,
      showForBride: current.showForBride,
      showForCustomer: current.showForCustomer,
      showForProvider: current.showForProvider,
      isRecommended: current.isRecommended,
      metadata: this.jsonInput(current.metadata),
    };
  }

  private toPublishedItem(
    key: string,
    revision: {
      revision: number;
      groupKey: string | null;
      groupNameAr: string | null;
      groupSubtitleAr: string | null;
      nameAr: string;
      nameEn: string | null;
      icon: string | null;
      sortOrder: number;
      showForGroom: boolean;
      showForBride: boolean;
      showForCustomer: boolean;
      showForProvider: boolean;
      isRecommended: boolean;
      metadata: Prisma.JsonValue | null;
    },
  ) {
    return { key, ...revision };
  }

  private toAdminItem(item: {
    id: string;
    key: string;
    currentRevision: number;
    publishedRevision: number;
    createdAt: Date;
    updatedAt: Date;
    revisions: Array<{
      revision: number;
      groupKey: string | null;
      groupNameAr: string | null;
      groupSubtitleAr: string | null;
      nameAr: string;
      nameEn: string | null;
      icon: string | null;
      sortOrder: number;
      showForGroom: boolean;
      showForBride: boolean;
      showForCustomer: boolean;
      showForProvider: boolean;
      isRecommended: boolean;
      isActive: boolean;
      metadata: Prisma.JsonValue | null;
      createdAt: Date;
    }>;
  }) {
    const current = item.revisions.find(
      (revision) => revision.revision === item.currentRevision,
    );
    const published = item.revisions.find(
      (revision) => revision.revision === item.publishedRevision,
    );
    return {
      id: item.id,
      key: item.key,
      currentRevision: item.currentRevision,
      publishedRevision: item.publishedRevision,
      hasUnpublishedChanges:
        item.currentRevision !== item.publishedRevision,
      current,
      published,
      revisions: item.revisions.map((revision) => ({
        revision: revision.revision,
        nameAr: revision.nameAr,
        isActive: revision.isActive,
        createdAt: revision.createdAt,
      })),
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
    };
  }

  private validateIcon(icon?: string | null): void {
    const normalized = this.optionalText(icon);
    if (normalized && !supportedCatalogIconKeys.has(normalized)) {
      throw new BadRequestException('Unsupported catalog icon');
    }
  }

  private requiredText(value: string | null | undefined, field: string): string {
    const normalized = value?.trim();
    if (!normalized) throw new BadRequestException(`${field} is required`);
    return normalized;
  }

  private optionalText(value: string | null | undefined): string | null {
    const normalized = value?.trim();
    return normalized ? normalized : null;
  }

  private optionalKey(value: string | null | undefined): string | null {
    const normalized = value?.trim().toLowerCase();
    if (!normalized) return null;
    if (!/^[a-z0-9]+(?:[._-][a-z0-9]+)*$/.test(normalized)) {
      throw new BadRequestException('Catalog item key is invalid');
    }
    return normalized;
  }

  private bootstrapVersion(value: unknown): string {
    return createHash('sha256')
      .update(JSON.stringify(value))
      .digest('hex')
      .slice(0, 24);
  }

  private jsonInput(
    value:
      | Prisma.JsonValue
      | Record<string, string | number | boolean | null>
      | null,
  ): Prisma.InputJsonValue | Prisma.NullTypes.JsonNull {
    return value === null ? Prisma.JsonNull : (value as Prisma.InputJsonValue);
  }
}
