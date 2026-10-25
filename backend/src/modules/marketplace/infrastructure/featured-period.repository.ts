import { Prisma } from '@prisma/client';
import {
  activeFeaturedPeriodWhere,
  featuredNowProviderWhere,
  featuredRunAround,
  featuredShowsWhere,
  listedProviderConditions,
  type FeaturedWindow,
  type OpenFeaturedPeriod,
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

/** Every period of these providers that nobody ended, oldest first. */
export async function listOpenFeaturedPeriods(
  client: Client,
  providerIds: readonly string[],
): Promise<Array<OpenFeaturedPeriod & { providerId: string }>> {
  if (providerIds.length === 0) return [];
  return client.providerFeaturedPeriod.findMany({
    where: { providerId: { in: [...new Set(providerIds)] }, endedAt: null },
    select: { id: true, providerId: true, startsAt: true, endsAt: true },
    orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
  });
}

/**
 * The provider's placement he reads: the active one, else the next one
 * booked, ending where its run of back-to-back renewals really ends.
 */
export async function findProviderFeaturedView(
  client: Client,
  providerId: string,
  now: Date,
): Promise<FeaturedWindow | null> {
  const open = await listOpenFeaturedPeriods(client, [providerId]);
  const first = open.find((period) => period.endsAt.getTime() > now.getTime());
  if (!first) return null;
  const run = featuredRunAround(open, first.id)!;
  return { startsAt: first.startsAt, endsAt: run.endsAt };
}

/** Of these providers, the ones a placement shows on (the one rule). */
export async function listFeaturedShownProviderIds(
  client: Client,
  providerIds: readonly string[],
): Promise<string[]> {
  if (providerIds.length === 0) return [];
  const rows = await client.provider.findMany({
    where: { AND: [{ id: { in: [...new Set(providerIds)] } }, ...featuredShowsWhere().AND] },
    select: { id: true },
  });
  return rows.map((row) => row.id);
}

/** Each provider's active period at `now`, for the providers featured by the rule. */
export async function listActiveFeaturedPeriods(
  client: Client,
  providerIds: readonly string[],
  now: Date,
): Promise<Array<FeaturedWindow & { providerId: string }>> {
  if (providerIds.length === 0) return [];
  return client.providerFeaturedPeriod.findMany({
    where: {
      providerId: { in: [...new Set(providerIds)] },
      ...activeFeaturedPeriodWhere(now),
      provider: featuredShowsWhere(),
    },
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
 * a17's cards: the providers customers see (listed), how many of them are
 * featured now by the placement rule, and how many of those placements end
 * before `weekEnd` with no period booked right after. Four reads, whatever
 * the number of placements.
 */
export async function countFeaturedSummary(client: Client, now: Date, weekEnd: Date) {
  const [listedProviders, featured, ending] = await Promise.all([
    client.provider.count({ where: { AND: [...listedProviderConditions()] } }),
    client.provider.count({ where: featuredNowProviderWhere(now) }),
    client.providerFeaturedPeriod.findMany({
      where: {
        ...activeFeaturedPeriodWhere(now),
        endsAt: { gt: now, lte: weekEnd },
        provider: featuredShowsWhere(),
      },
      select: { id: true, providerId: true, endsAt: true },
    }),
  ]);
  const open = await listOpenFeaturedPeriods(client, ending.map((period) => period.providerId));
  const endingSoon = ending.filter((period) => {
    const run = featuredRunAround(
      open.filter((candidate) => candidate.providerId === period.providerId),
      period.id,
    );
    return run !== null && run.endsAt.getTime() === period.endsAt.getTime();
  }).length;
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
  /** Set when it starts now: the grant's own notice tells him it started. */
  startNoticeAt: Date | null;
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

/** Booked periods that started, whose provider was not told yet. */
export function listFeaturedPeriodIdsStarted(client: Client, now: Date, take: number) {
  return client.providerFeaturedPeriod.findMany({
    where: { ...activeFeaturedPeriodWhere(now), startNoticeAt: null },
    select: { id: true },
    orderBy: [{ startsAt: 'asc' }, { id: 'asc' }],
    take,
  });
}

/** Marks the start notice as given, only once. */
export function markFeaturedStartNotice(client: Client, id: string, at: Date) {
  return client.providerFeaturedPeriod.updateMany({
    where: { id, startNoticeAt: null, endedAt: null },
    data: { startNoticeAt: at },
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
