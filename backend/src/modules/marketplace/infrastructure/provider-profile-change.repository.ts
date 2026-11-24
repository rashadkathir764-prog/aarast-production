import { Prisma, ProviderProfileChangeStatus } from '@prisma/client';
import type { ProviderProfileChange } from '@prisma/client';
import { imageVariantUrls } from '../../media/public/media-storage.port';
import type {
  AdminProfileChangeDecision,
  AdminProfileChangeRow,
} from '../public/marketplace-admin.port';
import { asksForChange, type ProfileChangeFields } from '../public/provider-profile-change';

type Client = Prisma.TransactionClient;

/**
 * RA-BE-152 (Q-39 (أ)): marketplace's own reads and writes of a provider's
 * profile change. The provider's writes hold his provider row lock; the
 * team's decision locks the provider row, then the request.
 */

/** His request waiting for the team, if any. */
export function findPendingProfileChange(
  client: Client,
  providerId: string,
): Promise<ProviderProfileChange | null> {
  return client.providerProfileChange.findFirst({
    where: { providerId, status: ProviderProfileChangeStatus.PENDING },
  });
}

/**
 * Writes his request as [fields] ask: the waiting one is updated, or a new
 * one starts; asking nothing withdraws the waiting one. Returns the request
 * left waiting (null when none is).
 */
export async function savePendingProfileChange(
  tx: Client,
  providerId: string,
  current: ProviderProfileChange | null,
  fields: ProfileChangeFields,
  at: Date,
): Promise<ProviderProfileChange | null> {
  if (!asksForChange(fields)) {
    if (current) await closePendingProfileChange(tx, current.id, withdrawal(at));
    return null;
  }
  if (current) {
    return tx.providerProfileChange.update({ where: { id: current.id }, data: fields });
  }
  return tx.providerProfileChange.create({ data: { providerId, ...fields } });
}

export function withdrawal(at: Date): AdminProfileChangeDecision {
  return {
    status: ProviderProfileChangeStatus.WITHDRAWN,
    reason: null,
    decidedAt: at,
    decidedById: null,
  };
}

/** Closes a waiting request; false when it was closed meanwhile. */
export async function closePendingProfileChange(
  tx: Client,
  id: string,
  decision: AdminProfileChangeDecision,
): Promise<boolean> {
  const updated = await tx.providerProfileChange.updateMany({
    where: { id, status: ProviderProfileChangeStatus.PENDING },
    data: {
      status: decision.status,
      rejectionReason: decision.reason,
      decidedAt: decision.decidedAt,
      decidedById: decision.decidedById,
    },
  });
  return updated.count === 1;
}

const adminInclude = {
  provider: {
    select: {
      id: true,
      businessName: true,
      userId: true,
      status: true,
      cityId: true,
      primaryCategoryId: true,
      logoUrl: true,
      coverUrl: true,
    },
  },
} satisfies Prisma.ProviderProfileChangeInclude;

/** The requests of one status, oldest first (the queue answers the oldest first). */
export async function listProfileChangesForReview(
  client: Client,
  status: ProviderProfileChangeStatus,
  page: { skip: number; take: number },
): Promise<{ total: number; items: AdminProfileChangeRow[] }> {
  const where = { status } satisfies Prisma.ProviderProfileChangeWhereInput;
  const [total, items] = await Promise.all([
    client.providerProfileChange.count({ where }),
    client.providerProfileChange.findMany({
      where,
      include: adminInclude,
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
      skip: page.skip,
      take: page.take,
    }),
  ]);
  return { total, items };
}

/**
 * Locks a request for its decision: its provider's row first (the order
 * the provider's own edit takes), then the request.
 */
export async function lockProfileChange(
  tx: Client,
  id: string,
): Promise<AdminProfileChangeRow | null> {
  const owner = await tx.providerProfileChange.findUnique({
    where: { id },
    select: { providerId: true },
  });
  if (!owner) return null;
  await tx.$queryRaw`
    SELECT "id" FROM "Provider" WHERE "id" = ${owner.providerId} FOR UPDATE
  `;
  const rows = await tx.$queryRaw<Array<{ id: string }>>`
    SELECT "id" FROM "ProviderProfileChange" WHERE "id" = ${id} FOR UPDATE
  `;
  if (rows.length === 0) return null;
  return tx.providerProfileChange.findUnique({ where: { id }, include: adminInclude });
}

/**
 * Decides a waiting request; on approval its asked values become the
 * listing's (a new logo or cover with its smaller copies, RA-MO-364).
 * Null when it was closed meanwhile.
 */
export async function decideProfileChange(
  tx: Client,
  id: string,
  decision: AdminProfileChangeDecision,
): Promise<AdminProfileChangeRow | null> {
  const row = await tx.providerProfileChange.findUnique({ where: { id } });
  if (!row || !(await closePendingProfileChange(tx, id, decision))) return null;
  if (decision.status === ProviderProfileChangeStatus.APPROVED) {
    await tx.provider.update({ where: { id: row.providerId }, data: listingValues(row) });
  }
  return tx.providerProfileChange.findUnique({ where: { id }, include: adminInclude });
}

function listingValues(change: ProfileChangeFields): Prisma.ProviderUncheckedUpdateInput {
  const logo = change.logoUrl ? imageVariantUrls(change.logoUrl) : null;
  const cover = change.coverUrl ? imageVariantUrls(change.coverUrl) : null;
  return {
    ...(change.businessName !== null ? { businessName: change.businessName } : {}),
    ...(change.cityId !== null ? { cityId: change.cityId } : {}),
    ...(change.primaryCategoryId !== null
      ? { primaryCategoryId: change.primaryCategoryId }
      : {}),
    ...(change.logoUrl && logo
      ? { logoUrl: change.logoUrl, logoThumbUrl: logo.thumbUrl, logoMediumUrl: logo.mediumUrl }
      : {}),
    ...(change.coverUrl && cover
      ? { coverUrl: change.coverUrl, coverThumbUrl: cover.thumbUrl, coverMediumUrl: cover.mediumUrl }
      : {}),
  };
}
