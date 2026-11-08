import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AdminRole, ProviderStatus, UserRole, UserStatus } from '@prisma/client';
import { AdminFeaturedPlacements } from '../src/admin/admin-featured-placements';
import {
  arabicDayLabel,
  featuredEndAfter,
  featuredLastDay,
  featuredPeriodState,
  featuredRunAround,
  featuredRunWarnsBeforeEnd,
  yemenDayOf,
  yemenDayStart,
} from '../src/modules/marketplace/public/featured-placement';
import { searchActiveProviders } from '../src/modules/marketplace/infrastructure/marketplace-core.repository';
import {
  countFeaturedSummary,
  findProviderFeaturedView,
} from '../src/modules/marketplace/infrastructure/featured-period.repository';
import {
  FeaturedPeriodNoticesService,
  noticeMessage,
} from '../src/marketplace/featured-period-notices.service';

// B-43 (D41): featured placement is a period the back office records after
// the provider paid outside the app; «مميز» and the ranking are read from it.

test('placements are bought by Yemen calendar days', () => {
  assert.equal(yemenDayStart('2026-12-31')?.toISOString(), '2026-12-30T21:00:00.000Z');
  assert.equal(featuredEndAfter('2026-12-31')?.toISOString(), '2026-12-31T21:00:00.000Z');
  assert.equal(featuredLastDay(new Date('2026-12-31T21:00:00.000Z')), '2026-12-31');
  assert.equal(yemenDayOf(new Date('2026-10-24T22:30:00.000Z')), '2026-10-25');
  assert.equal(yemenDayStart('2026-02-30'), null);
  assert.equal(yemenDayStart('31-12-2026'), null);
  assert.equal(arabicDayLabel('2026-12-31'), '31 ديسمبر');
});

test('a period is active, booked, over or ended by an administrator', () => {
  const now = new Date('2026-10-25T09:00:00.000Z');
  const period = (startsAt: string, endsAt: string, endedAt: string | null = null) => ({
    startsAt: new Date(startsAt),
    endsAt: new Date(endsAt),
    endedAt: endedAt ? new Date(endedAt) : null,
  });
  assert.equal(featuredPeriodState(period('2026-10-01T00:00:00Z', '2026-11-01T00:00:00Z'), now), 'ACTIVE');
  assert.equal(featuredPeriodState(period('2026-11-01T00:00:00Z', '2026-12-01T00:00:00Z'), now), 'SCHEDULED');
  assert.equal(featuredPeriodState(period('2026-09-01T00:00:00Z', '2026-10-25T09:00:00Z'), now), 'EXPIRED');
  assert.equal(
    featuredPeriodState(period('2026-10-01T00:00:00Z', '2026-11-01T00:00:00Z', '2026-10-20T00:00:00Z'), now),
    'ENDED',
  );
});

test('the customers\' list puts the featured first and cuts pages across both groups', async () => {
  const now = new Date('2026-10-25T09:00:00.000Z');
  const featured = ['f1', 'f2', 'f3'];
  const regular = ['r1', 'r2', 'r3', 'r4'];
  const calls: Array<{ group: string; skip: number; take: number }> = [];
  const groupOf = (where: any) =>
    JSON.stringify(where).includes('"some":{"startsAt"') ? 'featured' : 'regular';
  const client = {
    provider: {
      count: async ({ where }: any) => (groupOf(where) === 'featured' ? featured.length : regular.length),
      findMany: async ({ where, skip, take, include }: any) => {
        const group = groupOf(where);
        calls.push({ group, skip, take });
        assert.deepEqual(include.featuredPeriods.where, {
          startsAt: { lte: now },
          endsAt: { gt: now },
          endedAt: null,
        });
        return (group === 'featured' ? featured : regular).slice(skip, skip + take).map((id) => ({ id }));
      },
    },
  } as any;
  const where = { AND: [{ status: ProviderStatus.ACTIVE }] } as any;
  const page = async (pageNo: number, limit: number) => {
    calls.length = 0;
    const rows = await searchActiveProviders(client, where, { page: pageNo, limit, skip: (pageNo - 1) * limit }, now);
    return rows.map((row: any) => row.id);
  };

  assert.deepEqual(await page(1, 2), ['f1', 'f2']);
  assert.deepEqual(calls, [{ group: 'featured', skip: 0, take: 2 }]);
  assert.deepEqual(await page(2, 2), ['f3', 'r1']);
  assert.deepEqual(calls, [
    { group: 'featured', skip: 2, take: 2 },
    { group: 'regular', skip: 0, take: 1 },
  ]);
  assert.deepEqual(await page(3, 2), ['r2', 'r3']);
  assert.deepEqual(calls, [{ group: 'regular', skip: 1, take: 2 }]);
  // The original search stays whole inside each group.
  assert.equal(where.AND.length, 1);
});

const admin = { id: 'admin-1', role: UserRole.ADMIN, adminMfa: true } as any;

function placements(options: {
  adminRole?: AdminRole;
  provider?: { userId: string | null; status: ProviderStatus } | null;
  overlap?: { id: string; startsAt: Date; endsAt: Date } | null;
  period?: any;
  /** The placement rule holds for the provider (listed and claimed); default true. */
  listed?: boolean;
  /** What a17's list reads. */
  periods?: any[];
}) {
  const created: any[] = [];
  const ended: any[] = [];
  const notices: any[] = [];
  const provider = options.provider === undefined
    ? { userId: 'owner-1', status: ProviderStatus.ACTIVE }
    : options.provider;
  const owners = {
    accounts: {
      lockAccountsForUpdateInTransaction: async (_tx: unknown, ids: string[]) =>
        ids.map((id) =>
          id === admin.id
            ? { id, role: UserRole.ADMIN, adminRole: options.adminRole ?? AdminRole.OPERATIONS, status: UserStatus.ACTIVE }
            : { id, role: UserRole.PROVIDER, adminRole: null, status: UserStatus.ACTIVE },
        ),
    },
    marketplace: {
      findProviderAccount: async () => (provider ? { userId: provider.userId } : null),
      lockProviderForUpdateInTransaction: async () =>
        provider ? { ...provider, phone: '+967777000000' } : null,
      listFeaturedShownProviderIds: async (_tx: unknown, ids: string[]) =>
        options.listed === false ? [] : ids,
      listFeaturedPeriods: async () => ({ total: options.periods?.length ?? 0, items: options.periods ?? [] }),
      findOverlappingFeaturedPeriod: async () => options.overlap ?? null,
      createFeaturedPeriodInTransaction: async (_tx: unknown, fields: any) => {
        const row = {
          id: 'period-1',
          ...fields,
          createdAt: new Date(),
          endedAt: null,
          endedById: null,
          endNote: null,
          endingNoticeAt: null,
          endNoticeAt: null,
          provider: { id: fields.providerId, userId: provider?.userId ?? null },
        };
        created.push(row);
        return row;
      },
      lockFeaturedPeriodForUpdateInTransaction: async () => options.period ?? null,
      endFeaturedPeriodInTransaction: async (_tx: unknown, id: string, fields: any) => {
        const row = { ...options.period, ...fields, id };
        ended.push(row);
        return row;
      },
    },
    attachFeaturedPeriods: async (_tx: unknown, rows: any[]) =>
      rows.map((row) => ({
        ...row,
        grantedBy: null,
        endedBy: null,
        provider: {
          id: row.providerId,
          businessName: 'قاعة سبأ',
          phone: '+967777000000',
          whatsapp: null,
          logoUrl: null,
          status: ProviderStatus.ACTIVE,
          ratingAverage: { toString: () => '0' },
          ratingCount: 0,
          city: null,
          primaryCategory: null,
        },
      })),
  };
  const prisma = { $transaction: async (operation: any) => operation({}) } as any;
  const service = new AdminFeaturedPlacements({
    prisma,
    owners: owners as any,
    notifications: {
      createNotificationInTransaction: async (_tx: unknown, input: any) => {
        notices.push(input);
        return null;
      },
    } as any,
  });
  return { service, created, ended, notices };
}

async function refuses(promise: Promise<unknown>, status: number, code?: string) {
  await assert.rejects(promise, (error: any) => {
    assert.equal(error.getStatus(), status);
    if (code) assert.equal(error.getResponse().code, code);
    return true;
  });
}

function yemenDay(offset: number): string {
  return new Date(Date.now() + 3 * 60 * 60 * 1000 + offset * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

test('only an administrator who may still write providers records a placement', async () => {
  const { service, created } = placements({ adminRole: AdminRole.SUPPORT });
  await refuses(service.grant(admin, 'provider-1', { endsOn: yemenDay(30) }), 403);
  assert.equal(created.length, 0);
});

test('a placement needs a claimed, active provider, starts now or later and covers a year at most', async () => {
  await refuses(
    placements({ provider: { userId: null, status: ProviderStatus.ACTIVE } }).service.grant(admin, 'p', { endsOn: yemenDay(30) }),
    409,
    'FEATURED_PROVIDER_UNCLAIMED',
  );
  await refuses(
    placements({ provider: { userId: 'owner-1', status: ProviderStatus.SUSPENDED } }).service.grant(admin, 'p', { endsOn: yemenDay(30) }),
    409,
    'FEATURED_PROVIDER_NOT_ACTIVE',
  );
  await refuses(placements({ provider: null }).service.grant(admin, 'p', { endsOn: yemenDay(30) }), 404);
  await refuses(
    placements({ provider: { userId: admin.id, status: ProviderStatus.ACTIVE } }).service.grant(admin, 'p', { endsOn: yemenDay(30) }),
    400,
  );
  const { service } = placements({});
  await refuses(service.grant(admin, 'p', { startsOn: yemenDay(-2), endsOn: yemenDay(30) }), 422, 'FEATURED_PERIOD_START_PAST');
  await refuses(service.grant(admin, 'p', { endsOn: yemenDay(-1) }), 422, 'FEATURED_PERIOD_INVALID');
  await refuses(service.grant(admin, 'p', { endsOn: yemenDay(400) }), 422, 'FEATURED_PERIOD_TOO_LONG');
  await refuses(service.grant(admin, 'p', { endsOn: '2026-13-01' }), 422, 'FEATURED_PERIOD_INVALID');
  const overlapping = placements({
    overlap: { id: 'other', startsAt: new Date(), endsAt: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000) },
  });
  await refuses(overlapping.service.grant(admin, 'p', { endsOn: yemenDay(30) }), 409, 'FEATURED_PERIOD_OVERLAP');
  assert.equal(overlapping.created.length, 0);
  // The one placement rule: a provider customers cannot find (no active
  // service) is not featured; the placement would rank and badge nothing.
  const unlisted = placements({ listed: false });
  await refuses(unlisted.service.grant(admin, 'p', { endsOn: yemenDay(30) }), 409, 'FEATURED_PROVIDER_NOT_LISTED');
  assert.equal(unlisted.created.length, 0);
});

test('the database refusing an overlap reads as the same 409', async () => {
  const { service } = placements({});
  const owners = (service as any).owners;
  owners.marketplace.createFeaturedPeriodInTransaction = async () => {
    throw new Error(
      'conflicting key value violates exclusion constraint "ProviderFeaturedPeriod_no_overlap" (23P01)',
    );
  };
  await refuses(service.grant(admin, 'p', { endsOn: yemenDay(30) }), 409, 'FEATURED_PERIOD_OVERLAP');
  owners.marketplace.createFeaturedPeriodInTransaction = async () => {
    throw new Error('connection lost');
  };
  await assert.rejects(service.grant(admin, 'p', { endsOn: yemenDay(30) }), /connection lost/);
});

test('a recorded placement keeps who and the note, no amount, and tells the provider', async () => {
  const { service, created, notices } = placements({});
  const before = Date.now();
  const response = await service.grant(admin, 'provider-1', { endsOn: yemenDay(30), note: ' كاش · شهر ' });
  assert.equal(created.length, 1);
  assert.equal(created[0].grantedById, admin.id);
  assert.equal(created[0].note, 'كاش · شهر');
  assert.ok(created[0].startsAt.getTime() >= before);
  assert.equal(created[0].endsAt.toISOString(), featuredEndAfter(yemenDay(30))!.toISOString());
  assert.equal(response.state, 'ACTIVE');
  assert.equal(response.lastDay, yemenDay(30));
  assert.equal('amount' in response, false);
  assert.equal(notices.length, 1);
  assert.equal(notices[0].userId, 'owner-1');
  assert.equal(notices[0].title, 'تفعّل ظهورك المميز');
  // The truth: he comes up with the featured, not «أول في قسمك ومدينتك».
  assert.ok(notices[0].body.includes('يطلع مع المميزين أول'));
  assert.equal(notices[0].body.includes('قسمك ومدينتك'), false);
  assert.equal(notices[0].data.recipientAudience, 'PROVIDER');
  assert.equal(notices[0].dedupeKey, 'featured-period:period-1:granted');
  // Starting now, the grant's notice is the start notice: the job does not repeat it.
  assert.ok(created[0].startNoticeAt instanceof Date);
  assert.equal(response.providerShown, true);

  const later = placements({});
  await later.service.grant(admin, 'provider-1', { startsOn: yemenDay(10), endsOn: yemenDay(40) });
  assert.equal(later.created[0].startsAt.toISOString(), yemenDayStart(yemenDay(10))!.toISOString());
  assert.equal(later.notices[0].title, 'ظهورك المميز محجوز');
  // Booked for later: the hourly job tells him when it starts.
  assert.equal(later.created[0].startNoticeAt, null);
});

test('a17 says «مو ظاهر للعرسان» instead of «شغّال» when the rule does not hold', async () => {
  const row = (id: string, providerId: string) => ({
    id,
    providerId,
    startsAt: new Date(Date.now() - 24 * 60 * 60 * 1000),
    endsAt: new Date(Date.now() + 9 * 24 * 60 * 60 * 1000),
    note: null,
    grantedById: 'admin-0',
    createdAt: new Date(),
    endedAt: null,
    endedById: null,
    endNote: null,
    startNoticeAt: new Date(),
    endingNoticeAt: null,
    endNoticeAt: null,
    provider: { id: providerId, userId: 'owner' },
  });
  const { service } = placements({ periods: [row('a', 'shown'), row('b', 'hidden')] });
  (service as any).owners.marketplace.listFeaturedShownProviderIds = async (_tx: unknown, ids: string[]) =>
    ids.filter((id) => id === 'shown');
  const listing = await service.list({}, { page: 1, limit: 50, skip: 0 });
  assert.deepEqual(
    listing.items.map((item: any) => [item.id, item.state, item.providerShown]),
    [['a', 'ACTIVE', true], ['b', 'ACTIVE', false]],
  );
});

test('a run of back-to-back renewals ends where its last period ends', () => {
  const day = 24 * 60 * 60 * 1000;
  const at = (days: number) => new Date(Date.UTC(2026, 9, 1) + days * day);
  const periods = [
    { id: 'c', startsAt: at(40), endsAt: at(50) },
    { id: 'a', startsAt: at(0), endsAt: at(30) },
    { id: 'b', startsAt: at(30), endsAt: at(40) },
    { id: 'far', startsAt: at(60), endsAt: at(65) },
  ];
  assert.deepEqual(featuredRunAround(periods, 'a'), { startsAt: at(0), endsAt: at(50) });
  assert.deepEqual(featuredRunAround(periods, 'c'), { startsAt: at(0), endsAt: at(50) });
  assert.deepEqual(featuredRunAround(periods, 'far'), { startsAt: at(60), endsAt: at(65) });
  assert.equal(featuredRunAround(periods, 'missing'), null);
  // «ينتهي قريب» only for a run longer than the week it warns about.
  assert.equal(featuredRunWarnsBeforeEnd({ startsAt: at(60), endsAt: at(65) }), false);
  assert.equal(featuredRunWarnsBeforeEnd({ startsAt: at(0), endsAt: at(7) }), false);
  assert.equal(featuredRunWarnsBeforeEnd({ startsAt: at(0), endsAt: new Date(at(7).getTime() + 1) }), true);
});

/**
 * A small in-memory database for the hourly job: the period table (with the
 * few filters the job's reads use) and the providers the placement rule holds for.
 */
function noticeDatabase(periods: any[], shownProviders: string[]) {
  const matches = (value: any, condition: any): boolean => {
    if (condition === null) return value === null;
    if (condition instanceof Date || typeof condition !== 'object') {
      return value instanceof Date ? value.getTime() === new Date(condition).getTime() : value === condition;
    }
    if ('in' in condition) return condition.in.includes(value);
    if ('lte' in condition && !(value <= condition.lte)) return false;
    if ('lt' in condition && !(value < condition.lt)) return false;
    if ('gt' in condition && !(value > condition.gt)) return false;
    return true;
  };
  const where = (row: any, filter: any) =>
    Object.entries(filter ?? {}).every(([key, condition]) => matches(row[key], condition));
  const notices: any[] = [];
  const client: any = {
    $queryRaw: async (query: any) => {
      const id = query.values?.[0];
      return periods.some((period) => period.id === id) ? [{ id }] : [];
    },
    providerFeaturedPeriod: {
      findMany: async ({ where: filter, take, select }: any) => {
        const rows = periods
          .filter((period) => where(period, filter))
          .sort((left, right) => left.startsAt - right.startsAt);
        return (take ? rows.slice(0, take) : rows).map((row) =>
          select ? Object.fromEntries(Object.keys(select).map((key) => [key, row[key]])) : row,
        );
      },
      findUnique: async ({ where: { id } }: any) => {
        const period = periods.find((row) => row.id === id);
        return period ? { ...period, provider: { id: period.providerId, userId: `owner-${period.providerId}` } } : null;
      },
      updateMany: async ({ where: filter, data }: any) => {
        const rows = periods.filter((period) => where(period, filter));
        for (const row of rows) Object.assign(row, data);
        return { count: rows.length };
      },
    },
    provider: {
      findMany: async ({ where: filter }: any) =>
        filter.AND[0].id.in.filter((id: string) => shownProviders.includes(id)).map((id: string) => ({ id })),
    },
  };
  client.$transaction = async (operation: any) => operation(client);
  const notifications = {
    createNotificationInTransaction: async (_tx: unknown, input: any) => {
      notices.push(input);
      return null;
    },
  };
  return { client, notices, service: new FeaturedPeriodNoticesService(client, notifications as any) };
}

test('the hourly job tells a booked start once, warns only a run longer than a week, and stays silent inside a run', async () => {
  const day = 24 * 60 * 60 * 1000;
  const now = new Date('2026-10-25T09:00:00.000Z');
  const at = (days: number) => new Date(now.getTime() + days * day);
  const period = (id: string, providerId: string, startsAt: Date, endsAt: Date, startNoticeAt: Date | null = null) => ({
    id,
    providerId,
    startsAt,
    endsAt,
    endedAt: null,
    startNoticeAt,
    endingNoticeAt: null,
    endNoticeAt: null,
  });
  const periods = [
    // A month booked for a later day that started an hour ago: told once.
    period('booked', 'p1', new Date(now.getTime() - 60 * 60 * 1000), at(30)),
    // Three days recorded a minute ago: no «ينتهي قريب» minutes after it started.
    period('short', 'p2', new Date(now.getTime() - 60 * 1000), at(3), now),
    // A month ending in five days with a renewal booked right after: silent.
    period('first', 'p3', at(-25), at(5), at(-25)),
    period('renewal', 'p3', at(5), at(35)),
    // A month ending in five days on a provider not in the list: no «جدّده».
    period('hidden', 'p4', at(-25), at(5), at(-25)),
    // A month ending in four days, alone: warned once.
    period('alone', 'p5', at(-26), at(4), at(-26)),
  ];
  const { notices, service } = noticeDatabase(periods, ['p1', 'p2', 'p3', 'p5']);
  const first = await service.run(now);
  assert.deepEqual(first.failures, []);
  assert.deepEqual(
    notices.map((notice) => [notice.entityId, notice.title]),
    [
      ['booked', 'بدأ ظهورك المميز'],
      ['alone', 'ظهورك المميز ينتهي قريب'],
    ],
  );
  assert.deepEqual([first.started, first.warned, first.ended], [1, 1, 0]);
  // Every due period is marked, told or not, so nothing is said twice.
  assert.ok(periods.find((row) => row.id === 'short')!.endingNoticeAt);
  assert.ok(periods.find((row) => row.id === 'hidden')!.endingNoticeAt);
  const second = await service.run(now);
  assert.deepEqual([second.started, second.warned, second.ended], [0, 0, 0]);
  assert.equal(notices.length, 2);

  // The renewal starts right after the first: nothing starts for him.
  const later = new Date(now.getTime() + 6 * day);
  const third = await service.run(later);
  assert.equal(third.started, 0);
  assert.ok(periods.find((row) => row.id === 'renewal')!.startNoticeAt);
  assert.equal(notices.some((notice) => notice.entityId === 'first' || notice.entityId === 'renewal'), false);
  // The hidden one ended: told the truth, not «يظهر عادي».
  const hiddenEnd = notices.find((notice) => notice.entityId === 'hidden');
  assert.equal(hiddenEnd?.title, 'خلص ظهورك المميز');
  assert.equal(hiddenEnd?.body.includes('يظهر عادي'), false);
});

test('the provider reads where his run of renewals really ends', async () => {
  const day = 24 * 60 * 60 * 1000;
  const now = new Date('2026-10-25T09:00:00.000Z');
  const at = (days: number) => new Date(now.getTime() + days * day);
  const { client } = noticeDatabase(
    [
      { id: 'over', providerId: 'p1', startsAt: at(-60), endsAt: at(-30), endedAt: null },
      { id: 'now', providerId: 'p1', startsAt: at(-5), endsAt: at(10), endedAt: null },
      { id: 'next', providerId: 'p1', startsAt: at(10), endsAt: at(40), endedAt: null },
      { id: 'gap', providerId: 'p1', startsAt: at(50), endsAt: at(60), endedAt: null },
    ],
    ['p1'],
  );
  assert.deepEqual(await findProviderFeaturedView(client, 'p1', now), { startsAt: at(-5), endsAt: at(40) });
  assert.equal(await findProviderFeaturedView(client, 'p2', now), null);
});

test('a17\'s counts follow the placement rule in a fixed number of reads', async () => {
  const day = 24 * 60 * 60 * 1000;
  const now = new Date('2026-10-25T09:00:00.000Z');
  const at = (days: number) => new Date(now.getTime() + days * day);
  const reads: string[] = [];
  const counts: any[] = [];
  const ending = [
    { id: 'e1', providerId: 'p1', endsAt: at(3) },
    { id: 'e2', providerId: 'p2', endsAt: at(4) },
    { id: 'e3', providerId: 'p3', endsAt: at(5) },
  ];
  const open = [
    { id: 'e1', providerId: 'p1', startsAt: at(-20), endsAt: at(3) },
    { id: 'e2', providerId: 'p2', startsAt: at(-20), endsAt: at(4) },
    { id: 'r2', providerId: 'p2', startsAt: at(4), endsAt: at(30) },
    { id: 'e3', providerId: 'p3', startsAt: at(-20), endsAt: at(5) },
  ];
  const client: any = {
    provider: {
      count: async ({ where }: any) => {
        reads.push('provider.count');
        counts.push(where);
        return counts.length === 1 ? 10 : 3;
      },
    },
    providerFeaturedPeriod: {
      findMany: async ({ where }: any) => {
        reads.push('providerFeaturedPeriod.findMany');
        if (where.provider) {
          // Only the placements the rule holds for are counted as ending.
          assert.deepEqual(where.provider.AND.at(-1), { userId: { not: null } });
          return ending;
        }
        return open.filter((period) => where.providerId.in.includes(period.providerId));
      },
    },
  };
  const summary = await countFeaturedSummary(client, now, at(7));
  // p2's placement carries on with a renewal: it does not end this week.
  assert.deepEqual(summary, { listedProviders: 10, featured: 3, endingSoon: 2 });
  assert.equal(reads.length, 4);
  // After the listing rule (listedProviderConditions, which RA-BE-26 grew by
  // «not leaving»), the placement rule's two conditions.
  assert.deepEqual(counts[1].AND.slice(-2), [
    { userId: { not: null } },
    { featuredPeriods: { some: { startsAt: { lte: now }, endsAt: { gt: now }, endedAt: null } } },
  ]);
});

test('the list never badges a row of the regular group (an unclaimed listing with a period)', async () => {
  const now = new Date('2026-10-25T09:00:00.000Z');
  const window = { startsAt: now, endsAt: new Date(now.getTime() + 1000) };
  const client: any = {
    provider: {
      count: async () => 0,
      findMany: async ({ where }: any) => {
        assert.ok(JSON.stringify(where).includes('{"userId":null}'));
        return [{ id: 'unclaimed', userId: null, featuredPeriods: [window] }];
      },
    },
  };
  const rows = await searchActiveProviders(
    client,
    { AND: [{ status: ProviderStatus.ACTIVE }] } as any,
    { page: 1, limit: 20, skip: 0 },
    now,
  );
  assert.deepEqual(rows.map((row: any) => [row.id, row.featuredPeriods]), [['unclaimed', []]]);
});

test('what the hourly job says is true for where the provider stands', () => {
  const started = noticeMessage('started', '2026-12-31', true)!;
  assert.equal(started.title, 'بدأ ظهورك المميز');
  assert.ok(started.body.includes('يطلع مع المميزين أول'));
  assert.ok(noticeMessage('started', '2026-12-31', false)!.body.includes('مو ظاهر للعرسان'));
  // RA-BE-32 (D96): this asked the ending notice to say «لو تبي تجدده كلّم
  // فريق اعّرست», a sale outside Google Play's billing, and the ended one
  // «لو تبي ترجع مميز»; the phone and the admin's words had dropped both.
  // The days are said, and nothing is sold.
  const ending = noticeMessage('ending', '2026-12-31', true)!;
  assert.ok(ending.body.includes('آخر يوم له'));
  assert.equal(/تجدده|جدّده|ترجع مميز/.test(ending.body), false);
  // Not in the customers' list: nothing to say.
  assert.equal(noticeMessage('ending', '2026-12-31', false), null);
  const endedShown = noticeMessage('ended', '2026-12-31', true)!;
  assert.ok(endedShown.body.includes('يظهر عادي'));
  assert.equal(/تجدده|جدّده|ترجع مميز/.test(endedShown.body), false);
  const endedHidden = noticeMessage('ended', '2026-12-31', false)!;
  assert.equal(endedHidden.body.includes('يظهر عادي'), false);
  assert.equal(endedHidden.body.includes('ترجع مميز'), false);
});

test('an administrator stops an active placement or cancels a booked one; one that is over stays over', async () => {
  const base = {
    id: 'period-1',
    providerId: 'provider-1',
    note: null,
    grantedById: 'admin-0',
    createdAt: new Date(),
    endedAt: null,
    endedById: null,
    endNote: null,
    endingNoticeAt: null,
    endNoticeAt: null,
    provider: { id: 'provider-1', userId: 'owner-1' },
  };
  const day = 24 * 60 * 60 * 1000;
  const active = placements({
    period: { ...base, startsAt: new Date(Date.now() - day), endsAt: new Date(Date.now() + 9 * day) },
  });
  const stopped = await active.service.end(admin, 'period-1', { note: 'طلب يوقفها' });
  assert.equal(stopped.state, 'ENDED');
  assert.equal(active.ended[0].endedById, admin.id);
  assert.equal(active.notices[0].title, 'وقّفنا ظهورك المميز');
  // The note is added to the standard sentence, never instead of it.
  assert.equal(
    active.notices[0].body,
    'من اليوم ملفك يظهر عادي. لو عندك سؤال كلّم فريق اعّرست.\nملاحظة الفريق: طلب يوقفها',
  );
  assert.equal(stopped.providerShown, true);

  const booked = placements({
    period: { ...base, startsAt: new Date(Date.now() + 5 * day), endsAt: new Date(Date.now() + 9 * day) },
  });
  await booked.service.end(admin, 'period-1', {});
  assert.equal(booked.notices[0].title, 'لغينا ظهورك المميز');
  assert.ok(booked.notices[0].body.includes('انلغى'));
  assert.equal(booked.notices[0].body.includes('ملاحظة الفريق'), false);

  // Stopped while he is not in the customers' list: «يظهر عادي» would be untrue.
  const hidden = placements({
    listed: false,
    period: { ...base, startsAt: new Date(Date.now() - day), endsAt: new Date(Date.now() + 9 * day) },
  });
  const hiddenStop = await hidden.service.end(admin, 'period-1', {});
  assert.equal(hidden.notices[0].body.includes('يظهر عادي'), false);
  assert.equal(hiddenStop.providerShown, false);

  const over = placements({
    period: { ...base, startsAt: new Date(Date.now() - 9 * day), endsAt: new Date(Date.now() - day) },
  });
  await refuses(over.service.end(admin, 'period-1', {}), 409, 'FEATURED_PERIOD_FINISHED');
  assert.equal(over.ended.length, 0);
  await refuses(placements({ period: null }).service.end(admin, 'missing', {}), 404);
});
