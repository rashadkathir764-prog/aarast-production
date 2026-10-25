import { Prisma, ProviderStatus } from '@prisma/client';
import {
  activeFeaturedPeriodWhere,
  type FeaturedWindow,
} from '../public/featured-placement';
import type {
  AdminFeaturedPeriodFilter,
  AdminFeaturedPeriodState,
} from '../public/marketplace-admin.port';

// Marketplace's own reads and writes of featured placement (B-43). A period
// is recorded by an administrator, ended early by one, and read at request
// time; the hourly job only marks that the provider was told.

type Client = Prisma.TransactionClient;

const periodOrder = [
  { startsAt: 'desc' },
  { createdAt: 'desc' },
  { id: 'desc' },
] satisfies Prisma.ProviderFeaturedPeriodOrderByWithRelationInput[];

/** The provider's placement he reads: the active one, else the next one booked. */
export function findProviderFeaturedView(
  client: Client,
  providerId: string,
  now: Date,
): Promise<FeaturedWindow | null> {
  return client.providerFeaturedPeriod.findFirst({
    where: { providerId, endedAt: null, endsAt: { gt: now } },
    orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
    select: { startsAt: true, endsAt: true },
  });
}

/** Each provider's active period at `now`. */
export async function listActiveFeaturedPeriods(
  client: Client,
  providerIds: readonly string[],
  now: Date,
): Promise<Array<FeaturedWindow & { providerId: string }>> {
  if (providerIds.length === 0) return [];
  return client.providerFeaturedPeriod.findMany({
    where: { providerId: { in: [...new Set(providerIds)] }, ...activeFeaturedPeriodWhere(now) },
    select: { providerId: true, startsAt: true, endsAt: true },
  });
}

function stateWhere(state: AdminFeaturedPeriodState | null, now: Date) {
  switch (state) {
    case 'CURRENT':
      return { endedAt: null, endsAt: { gt: now } };
    case 'ACTIVE':
      return activeFeaturedPeriodWhere(now);
    case 'SCHEDULED':
      return { endedAt: null, startsAt: { gt: now } };
    case 'FINISHED':
      return { OR: [{ endedAt: { not: null } }, { endsAt: { lte: now } }] };
    default:
      return {};
  }
}

export async function listFeaturedPeriods(
  client: Client,
  filter: AdminFeaturedPeriodFilter,
  page: { skip: number; take: number },
  now: Date,
) {
  const where = {
    ...stateWhere(filter.state, now),
    ...(filter.providerId ? { providerId: filter.providerId } : {}),
  };
  const [total, items] = await Promise.all([
    client.providerFeaturedPeriod.count({ where }),
    client.providerFeaturedPeriod.findMany({
      where,
      include: { provider: true },
      orderBy: periodOrder,
      skip: page.skip,
      take: page.take,
    }),
  ]);
  return { total, items };
}

/**
 * a17's cards: the providers customers see (active, with an active
 * service), how many of them are featured now, and how many placements end
 * before `weekEnd` with no period booked right after.
 */
export async function countFeaturedSummary(client: Client, now: Date, weekEnd: Date) {
  const listed = {
    status: ProviderStatus.ACTIVE,
    services: { some: { isActive: true } },
  };
  const active = activeFeaturedPeriodWhere(now);
  const [listedProviders, featured, ending] = await Promise.all([
    client.provider.count({ where: listed }),
    client.provider.count({ where: { ...listed, featuredPeriods: { some: active } } }),
    client.providerFeaturedPeriod.findMany({
      where: { ...active, endsAt: { gt: now, lte: weekEnd } },
      select: { id: true, providerId: true, endsAt: true },
    }),
  ]);
  let endingSoon = 0;
  for (const period of ending) {
    if (!(await findFeaturedContinuation(client, period))) endingSoon += 1;
  }
  return { listedProviders, featured, endingSoon };
}

/** A period of the provider that is not ended and overlaps [startsAt, endsAt). */
export function findOverlappingFeaturedPeriod(
  client: Client,
  providerId: string,
  startsAt: Date,
  endsAt: Date,
) {
  return client.providerFeaturedPeriod.findFirst({
    where: {
      providerId,
      endedAt: null,
      startsAt: { lt: endsAt },
      endsAt: { gt: startsAt },
    },
    select: { id: true, startsAt: true, endsAt: true },
  });
}

export interface FeaturedPeriodGrant {
  providerId: string;
  startsAt: Date;
  endsAt: Date;
  note: string | null;
  grantedById: string;
}

export function createFeaturedPeriod(client: Client, grant: FeaturedPeriodGrant) {
  return client.providerFeaturedPeriod.create({
    data: grant,
    include: { provider: true },
  });
}

export async function lockFeaturedPeriodForUpdate(tx: Client, id: string) {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "ProviderFeaturedPeriod"
      WHERE "id" = ${id}
      FOR UPDATE
    `,
  );
  if (rows.length !== 1) return null;
  return tx.providerFeaturedPeriod.findUnique({
    where: { id },
    include: { provider: true },
  });
}

export interface FeaturedPeriodEnding {
  endedAt: Date;
  endedById: string;
  endNote: string | null;
}

/** Ends the period, only while nobody ended it before. */
export function endFeaturedPeriod(client: Client, id: string, ending: FeaturedPeriodEnding) {
  return client.providerFeaturedPeriod.updateMany({
    where: { id, endedAt: null },
    data: {
      endedAt: ending.endedAt,
      endedById: ending.endedById,
      endNote: ending.endNote,
      // He is told now; the job does not tell him again.
      endNoticeAt: ending.endedAt,
    },
  });
}

export function findFeaturedPeriod(client: Client, id: string) {
  return client.providerFeaturedPeriod.findUnique({
    where: { id },
    include: { provider: true },
  });
}

// The hourly job.

/** Active periods ending before `until` whose provider was not told yet. */
export function listFeaturedPeriodIdsEndingSoon(client: Client, now: Date, until: Date, take: number) {
  return client.providerFeaturedPeriod.findMany({
    where: {
      ...activeFeaturedPeriodWhere(now),
      endsAt: { gt: now, lte: until },
      endingNoticeAt: null,
    },
    select: { id: true },
    orderBy: [{ endsAt: 'asc' }, { id: 'asc' }],
    take,
  });
}

/** Periods that reached their end whose provider was not told yet. */
export function listFeaturedPeriodIdsEnded(client: Client, now: Date, take: number) {
  return client.providerFeaturedPeriod.findMany({
    where: { endedAt: null, endsAt: { lte: now }, endNoticeAt: null },
    select: { id: true },
    orderBy: [{ endsAt: 'asc' }, { id: 'asc' }],
    take,
  });
}

/** A period of the same provider that picks up where this one ends. */
export function findFeaturedContinuation(
  client: Client,
  period: { id: string; providerId: string; endsAt: Date },
) {
  return client.providerFeaturedPeriod.findFirst({
    where: {
      id: { not: period.id },
      providerId: period.providerId,
      endedAt: null,
      startsAt: { lte: period.endsAt },
      endsAt: { gt: period.endsAt },
    },
    select: { id: true, endsAt: true },
  });
}

/** Marks the warning as given, only once. */
export function markFeaturedEndingNotice(client: Client, id: string, at: Date) {
  return client.providerFeaturedPeriod.updateMany({
    where: { id, endingNoticeAt: null, endedAt: null },
    data: { endingNoticeAt: at },
  });
}

/** Marks the end notice as given, only once. */
export function markFeaturedEndNotice(client: Client, id: string, at: Date) {
  return client.providerFeaturedPeriod.updateMany({
    where: { id, endNoticeAt: null, endedAt: null },
    data: { endNoticeAt: at },
  });
}
