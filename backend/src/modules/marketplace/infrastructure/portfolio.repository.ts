import { PortfolioItemStatus, Prisma } from '@prisma/client';
import type { PortfolioItem, Provider } from '@prisma/client';
import type { AdminPortfolioDecision, AdminPortfolioRow } from '../public/marketplace-admin.port';

type Client = Prisma.TransactionClient;

/**
 * B-16 (D62): marketplace's own reads and writes of «معرض الشغل». The
 * caller holds the provider's row lock for every write.
 */

export function listProviderPortfolio(client: Client, providerId: string): Promise<PortfolioItem[]> {
  return client.portfolioItem.findMany({
    where: { providerId },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
  });
}

/** The upload keys his portfolio already holds (no lock: the write re-reads them). */
export async function listPortfolioKeysOfOwner(client: Client, userId: string): Promise<string[]> {
  const rows = await client.portfolioItem.findMany({
    where: { provider: { userId } },
    select: { mediaKey: true },
  });
  return rows.map((row) => row.mediaKey);
}

/** p35's line: his photos (refused ones aside), those waiting, those refused. */
export async function countProviderPortfolio(client: Client, providerId: string) {
  const rows = await client.portfolioItem.findMany({
    where: { providerId },
    select: { status: true },
  });
  const count = (status: PortfolioItemStatus) => rows.filter((row) => row.status === status).length;
  const rejected = count(PortfolioItemStatus.REJECTED);
  return { photos: rows.length - rejected, pending: count(PortfolioItemStatus.PENDING), rejected };
}

/** His approved photos; who may read the women's album is the policy's (`isPortfolioItemVisibleTo`). */
export function listApprovedPortfolio(client: Client, providerId: string): Promise<PortfolioItem[]> {
  return client.portfolioItem.findMany({
    where: { providerId, status: PortfolioItemStatus.APPROVED },
    orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
  });
}

/** The category ids that say whom he serves: his main section and his active services'. */
export async function providerCategoryIds(client: Client, provider: Pick<Provider, 'id' | 'primaryCategoryId'>) {
  const services = await client.providerService.findMany({
    where: { providerId: provider.id, isActive: true },
    select: { categoryId: true },
  });
  return [
    ...new Set(
      [provider.primaryCategoryId, ...services.map((service) => service.categoryId)].filter(
        (id): id is string => typeof id === 'string',
      ),
    ),
  ];
}

export interface PortfolioWrite {
  create: Array<{
    mediaKey: string;
    imageUrl: string;
    album: string | null;
    forWomen: boolean;
    noFaces: boolean;
    sortOrder: number;
  }>;
  /** Kept photos: their order, and, when album or «بدون وجوه» changed, back to PENDING. */
  update: Array<{
    id: string;
    album: string | null;
    forWomen: boolean;
    noFaces: boolean;
    sortOrder: number;
    reset: boolean;
  }>;
  removeIds: string[];
}

/** Applies the provider's list; returns the ids of the photos it created. */
export async function writeProviderPortfolio(
  tx: Client,
  providerId: string,
  write: PortfolioWrite,
  socialLinks: Prisma.InputJsonValue | typeof Prisma.DbNull,
): Promise<string[]> {
  if (write.removeIds.length > 0) {
    await tx.portfolioItem.deleteMany({ where: { providerId, id: { in: write.removeIds } } });
  }
  for (const item of write.update) {
    await tx.portfolioItem.update({
      where: { id: item.id },
      data: {
        sortOrder: item.sortOrder,
        ...(item.reset
          ? {
              album: item.album,
              forWomen: item.forWomen,
              noFaces: item.noFaces,
              status: PortfolioItemStatus.PENDING,
              reviewedAt: null,
              reviewedById: null,
              rejectionReason: null,
            }
          : {}),
      },
    });
  }
  const created: string[] = [];
  for (const item of write.create) {
    const row = await tx.portfolioItem.create({
      data: { providerId, ...item },
      select: { id: true },
    });
    created.push(row.id);
  }
  await tx.provider.update({ where: { id: providerId }, data: { socialLinks } });
  return created;
}

const adminInclude = {
  provider: { select: { id: true, businessName: true, userId: true, status: true } },
} satisfies Prisma.PortfolioItemInclude;

/** n07: the photos of one status, oldest first (the queue answers the oldest first). */
export async function listPortfolioForReview(
  client: Client,
  status: PortfolioItemStatus,
  page: { skip: number; take: number },
): Promise<{ total: number; items: AdminPortfolioRow[] }> {
  const where = { status } satisfies Prisma.PortfolioItemWhereInput;
  const [total, items] = await Promise.all([
    client.portfolioItem.count({ where }),
    client.portfolioItem.findMany({
      where,
      include: adminInclude,
      // Photos sent together keep the provider's order.
      orderBy: [{ createdAt: 'asc' }, { providerId: 'asc' }, { sortOrder: 'asc' }, { id: 'asc' }],
      skip: page.skip,
      take: page.take,
    }),
  ]);
  return { total, items };
}

/** Locks one photo for its decision. */
export async function lockPortfolioItem(tx: Client, id: string): Promise<AdminPortfolioRow | null> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>`
    SELECT "id" FROM "PortfolioItem" WHERE "id" = ${id} FOR UPDATE
  `;
  if (rows.length === 0) return null;
  return tx.portfolioItem.findUnique({ where: { id }, include: adminInclude });
}

/** Decides a PENDING photo; null when it was decided or removed meanwhile. */
export async function decidePortfolioItem(
  tx: Client,
  id: string,
  decision: AdminPortfolioDecision,
): Promise<AdminPortfolioRow | null> {
  const updated = await tx.portfolioItem.updateMany({
    where: { id, status: PortfolioItemStatus.PENDING },
    data: {
      status: decision.status,
      rejectionReason: decision.reason,
      reviewedAt: decision.reviewedAt,
      reviewedById: decision.reviewedById,
    },
  });
  if (updated.count !== 1) return null;
  return tx.portfolioItem.findUnique({ where: { id }, include: adminInclude });
}
