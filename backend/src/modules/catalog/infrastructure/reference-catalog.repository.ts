import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';
import type {
  DefaultReferenceCatalogItem,
  SystemCatalogDefinition,
} from '../../../catalogs/reference-catalog.defaults';

type Client = Prisma.TransactionClient;
const catalogSeedLock = 2_026_080_901;

@Injectable()
export class ReferenceCatalogRepository {
  bootstrapRows(client: PrismaService) {
    return client.$transaction([
      client.referenceCatalog.findMany({
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
      client.providerCategory.findMany({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      }),
      client.city.findMany({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      }),
      client.governorate.findMany({
        where: { isActive: true },
        orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
        include: {
          _count: { select: { districts: { where: { isActive: true } } } },
        },
      }),
      client.district.aggregate({ _max: { updatedAt: true } }),
      client.administrativeLocality.aggregate({ _max: { updatedAt: true } }),
    ]);
  }

  listAdminCatalogs(client: Client) {
    return client.referenceCatalog.findMany({
      orderBy: { key: 'asc' },
      include: { items: true },
    });
  }

  getAdminCatalog(client: Client, catalogKey: string) {
    return client.referenceCatalog.findUnique({
      where: { key: catalogKey },
      include: {
        items: {
          orderBy: { key: 'asc' },
          include: { revisions: { orderBy: { revision: 'desc' } } },
        },
      },
    });
  }

  getItemByKey(tx: Client, catalogId: string, key: string) {
    return tx.referenceCatalogItem.findUnique({
      where: { catalogId_key: { catalogId, key } },
    });
  }

  /** D73: the slugs a money item may link to. */
  async listProviderCategorySlugs(tx: Client): Promise<Set<string>> {
    const categories = await tx.providerCategory.findMany({
      select: { slug: true },
    });
    return new Set(categories.map((category) => category.slug));
  }

  createItem(tx: Client, catalogId: string, key: string, revision: Prisma.ReferenceCatalogItemRevisionCreateWithoutItemInput) {
    return tx.referenceCatalogItem.create({
      data: {
        catalogId,
        key,
        currentRevision: 1,
        publishedRevision: 0,
        revisions: { create: {
          revision: revision.revision,
          groupKey: revision.groupKey,
          groupNameAr: revision.groupNameAr,
          groupSubtitleAr: revision.groupSubtitleAr,
          nameAr: revision.nameAr,
          nameEn: revision.nameEn,
          icon: revision.icon,
          sortOrder: revision.sortOrder,
          showForGroom: revision.showForGroom,
          showForBride: revision.showForBride,
          showForCustomer: revision.showForCustomer,
          showForProvider: revision.showForProvider,
          isRecommended: revision.isRecommended,
          isActive: revision.isActive,
          ...(revision.metadata === undefined ? {} : { metadata: revision.metadata }),
        } },
      },
      include: { revisions: { orderBy: { revision: 'desc' } } },
    });
  }

  getRevision(tx: Client, itemId: string, revision: number) {
    return tx.referenceCatalogItemRevision.findUnique({
      where: { itemId_revision: { itemId, revision } },
    });
  }

  createRevision(tx: Client, data: Prisma.ReferenceCatalogItemRevisionUncheckedCreateInput) {
    return tx.referenceCatalogItemRevision.create({ data: {
      itemId: data.itemId,
      revision: data.revision,
      groupKey: data.groupKey,
      groupNameAr: data.groupNameAr,
      groupSubtitleAr: data.groupSubtitleAr,
      nameAr: data.nameAr,
      nameEn: data.nameEn,
      icon: data.icon,
      sortOrder: data.sortOrder,
      showForGroom: data.showForGroom,
      showForBride: data.showForBride,
      showForCustomer: data.showForCustomer,
      showForProvider: data.showForProvider,
      isRecommended: data.isRecommended,
      isActive: data.isActive,
      ...(data.metadata === undefined ? {} : { metadata: data.metadata }),
    } });
  }

  updateCurrentRevision(tx: Client, itemId: string, currentRevision: number) {
    return tx.referenceCatalogItem.update({
      where: { id: itemId },
      data: { currentRevision },
      include: { revisions: { orderBy: { revision: 'desc' } } },
    });
  }

  incrementCatalogVersion(tx: Client, catalogId: string) {
    return tx.referenceCatalog.update({
      where: { id: catalogId },
      data: { version: { increment: 1 } },
    });
  }

  publishItem(tx: Client, itemId: string, publishedRevision: number) {
    return tx.referenceCatalogItem.update({
      where: { id: itemId },
      data: { publishedRevision },
      include: { revisions: { orderBy: { revision: 'desc' } } },
    });
  }

  disableItem(tx: Client, itemId: string, revision: number) {
    return tx.referenceCatalogItem.update({
      where: { id: itemId },
      data: { currentRevision: revision, publishedRevision: revision },
      include: { revisions: { orderBy: { revision: 'desc' } } },
    });
  }

  lockSeed(tx: Client) {
    return tx.$executeRaw(Prisma.sql`SELECT pg_advisory_xact_lock(${catalogSeedLock})`);
  }

  /** Creates a system catalog once; an existing one (and its admin edits) is kept. */
  upsertSystemCatalog(tx: Client, catalog: SystemCatalogDefinition) {
    return tx.referenceCatalog.upsert({
      where: { key: catalog.key },
      create: {
        key: catalog.key,
        nameAr: catalog.nameAr,
        description: catalog.description,
        version: 1,
      },
      update: {},
    });
  }

  upsertSystemCatalogItem(tx: Client, catalogId: string, item: DefaultReferenceCatalogItem) {
    return tx.referenceCatalogItem.upsert({
      where: { catalogId_key: { catalogId, key: item.key } },
      create: {
        catalogId,
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

  async lockCatalog(tx: Client, catalogKey: string) {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "ReferenceCatalog"
        WHERE "key" = ${catalogKey}
        FOR UPDATE
      `,
    );
    return rows[0] ?? null;
  }

  async lockCatalogItem(tx: Client, catalogKey: string, itemId: string) {
    const rows = await tx.$queryRaw<Array<{
      id: string;
      catalogId: string;
      currentRevision: number;
      publishedRevision: number;
    }>>(
      Prisma.sql`
        SELECT item."id", item."catalogId", item."currentRevision", item."publishedRevision"
        FROM "ReferenceCatalogItem" item
        INNER JOIN "ReferenceCatalog" catalog ON catalog."id" = item."catalogId"
        WHERE item."id" = ${itemId} AND catalog."key" = ${catalogKey}
        FOR UPDATE OF item
      `,
    );
    return rows[0] ?? null;
  }
}
