import {
  BadRequestException,
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
import { AdminPermission } from '../modules/backoffice/public/admin-permission.port';
import { runAuthorizedAdminMutation } from '../modules/backoffice/public/admin-mutation-gate';
import { PrismaService } from '../platform/database/prisma.service';
import { duplicateValueConflict } from '../platform/http/duplicate-value';
import { ReferenceCatalogRepository } from '../modules/catalog/infrastructure/reference-catalog.repository';
import {
  AdminCatalogItemDto,
  type ReferenceCatalogMetadata,
} from './dto/admin-reference-catalog.dto';
import {
  supportedCatalogIconKeys,
  systemCatalogs,
} from './reference-catalog.defaults';

/** D73: a money item links to a handful of provider categories, never more. */
const MAX_PROVIDER_CATEGORY_SLUGS = 50;
const MAX_PROVIDER_CATEGORY_SLUG_LENGTH = 120;

@Injectable()
export class ReferenceCatalogService {
  private seedPromise: Promise<void> | null = null;
  private readonly repository = new ReferenceCatalogRepository();

  constructor(
    private readonly prisma: PrismaService,
    @Inject(IDENTITY_ADMIN_PORT) private readonly accounts: IdentityAdminPort,
  ) {}

  async getBootstrap(knownVersion?: string) {
    await this.ensureSystemCatalogs();
    const [catalogs, providerCategories, cities, governorates, districtVersion, localityVersion] =
      await this.repository.bootstrapRows(this.prisma);

    const version = this.bootstrapVersion({
      catalogs: catalogs.map((catalog) => ({
        key: catalog.key,
        version: catalog.version,
        updatedAt: catalog.updatedAt.toISOString(),
        // Items seeded later (or published) must change the version too, or
        // devices holding the old version never receive them.
        items: catalog.items.map((item) => [item.key, item.publishedRevision]),
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
    const catalogs = await this.repository.listAdminCatalogs(this.prisma);
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
    const catalog = await this.repository.getAdminCatalog(
      this.prisma,
      catalogKey,
    );
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
        const existing = await this.repository.getItemByKey(
          tx,
          catalog.id,
          itemKey,
        );
        if (existing) throw duplicateValueConflict('Catalog item key exists');
        await this.assertKnownProviderCategorySlugs(tx, dto.metadata);
        return this.repository.createItem(
          tx,
          catalog.id,
          itemKey,
          this.revisionData({ ...dto, nameAr }, 1),
        );
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
        const current = await this.repository.getRevision(
          tx,
          itemId,
          locked.currentRevision,
        );
        if (!current) throw new NotFoundException('Catalog draft not found');
        await this.assertKnownProviderCategorySlugs(tx, dto.metadata);
        const nextRevision = locked.currentRevision + 1;
        await this.repository.createRevision(
          tx,
          this.mergedRevisionData(itemId, nextRevision, current, dto),
        );
        return this.repository.updateCurrentRevision(tx, itemId, nextRevision);
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
        const target = await this.repository.getRevision(
          tx,
          itemId,
          targetRevision,
        );
        if (!target) throw new NotFoundException('Catalog revision not found');
        await this.repository.incrementCatalogVersion(tx, locked.catalogId);
        return this.repository.publishItem(tx, itemId, targetRevision);
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
        const current = await this.repository.getRevision(
          tx,
          itemId,
          locked.currentRevision,
        );
        if (!current) throw new NotFoundException('Catalog draft not found');
        const nextRevision = locked.currentRevision + 1;
        await this.repository.createRevision(tx, {
          ...this.copyRevision(current),
          itemId,
          revision: nextRevision,
          isActive: false,
        });
        await this.repository.incrementCatalogVersion(tx, locked.catalogId);
        return this.repository.disableItem(tx, itemId, nextRevision);
      },
    );
    return this.toAdminItem(result);
  }

  private async ensureSystemCatalogs(): Promise<void> {
    if (this.seedPromise != null) return this.seedPromise;
    this.seedPromise = this.seedSystemCatalogs().catch((error) => {
      this.seedPromise = null;
      throw error;
    });
    return this.seedPromise;
  }

  private async seedSystemCatalogs(): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await this.repository.lockSeed(tx);
      for (const definition of systemCatalogs) {
        const catalog = await this.repository.upsertSystemCatalog(tx, definition);
        for (const item of definition.items) {
          await this.repository.upsertSystemCatalogItem(tx, catalog.id, item);
        }
      }
    });
  }

  private async lockCatalog(tx: Prisma.TransactionClient, catalogKey: string) {
    const row = await this.repository.lockCatalog(tx, catalogKey);
    if (!row) {
      throw new NotFoundException('Reference catalog not found');
    }
    return row;
  }

  private async lockCatalogItem(
    tx: Prisma.TransactionClient,
    catalogKey: string,
    itemId: string,
  ) {
    const row = await this.repository.lockCatalogItem(tx, catalogKey, itemId);
    if (!row) throw new NotFoundException('Catalog item not found');
    return row;
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
        : { metadata: this.metadataInput(dto.metadata) }),
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
          : this.metadataInput(dto.metadata),
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

  /** D73: a link to a category that does not exist leaves the item with no «ابحث». */
  private async assertKnownProviderCategorySlugs(
    tx: Prisma.TransactionClient,
    metadata: ReferenceCatalogMetadata | null | undefined,
  ): Promise<void> {
    const slugs = metadata?.providerCategorySlugs;
    if (!Array.isArray(slugs) || slugs.length === 0) return;
    const known = await this.repository.listProviderCategorySlugs(tx);
    const unknown = slugs.find((slug) => !known.has(slug));
    if (unknown !== undefined) {
      throw new BadRequestException(`Unknown provider category: ${unknown}`);
    }
  }

  /**
   * D73: an item's `providerCategorySlugs` is the list of provider category
   * slugs the money catalog links it to; anything else is refused, never
   * stored to be misread later.
   */
  private metadataInput(
    value: ReferenceCatalogMetadata | null,
  ): Prisma.InputJsonValue | Prisma.NullTypes.JsonNull {
    const slugs = value?.providerCategorySlugs;
    if (
      slugs !== undefined &&
      !(
        Array.isArray(slugs) &&
        slugs.length <= MAX_PROVIDER_CATEGORY_SLUGS &&
        slugs.every(
          (slug) =>
            typeof slug === 'string' &&
            slug.trim() !== '' &&
            slug.length <= MAX_PROVIDER_CATEGORY_SLUG_LENGTH,
        )
      )
    ) {
      throw new BadRequestException('providerCategorySlugs must be a list of slugs');
    }
    return this.jsonInput(value);
  }

  private jsonInput(
    value: Prisma.JsonValue | ReferenceCatalogMetadata | null,
  ): Prisma.InputJsonValue | Prisma.NullTypes.JsonNull {
    return value === null ? Prisma.JsonNull : (value as Prisma.InputJsonValue);
  }
}
