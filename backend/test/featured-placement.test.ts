import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AdminRole, ProviderStatus, UserRole, UserStatus } from '@prisma/client';
import { AdminFeaturedPlacements } from '../src/admin/admin-featured-placements';
import {
  arabicDayLabel,
  featuredEndAfter,
  featuredLastDay,
  featuredPeriodState,
  yemenDayOf,
  yemenDayStart,
} from '../src/modules/marketplace/public/featured-placement';
import { searchActiveProviders } from '../src/modules/marketplace/infrastructure/marketplace-core.repository';

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
  assert.equal(notices[0].data.recipientAudience, 'PROVIDER');
  assert.equal(notices[0].dedupeKey, 'featured-period:period-1:granted');

  const later = placements({});
  await later.service.grant(admin, 'provider-1', { startsOn: yemenDay(10), endsOn: yemenDay(40) });
  assert.equal(later.created[0].startsAt.toISOString(), yemenDayStart(yemenDay(10))!.toISOString());
  assert.equal(later.notices[0].title, 'ظهورك المميز محجوز');
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
  assert.equal(active.notices[0].body, 'طلب يوقفها');

  const booked = placements({
    period: { ...base, startsAt: new Date(Date.now() + 5 * day), endsAt: new Date(Date.now() + 9 * day) },
  });
  await booked.service.end(admin, 'period-1', {});
  assert.equal(booked.notices[0].title, 'لغينا ظهورك المميز');

  const over = placements({
    period: { ...base, startsAt: new Date(Date.now() - 9 * day), endsAt: new Date(Date.now() - day) },
  });
  await refuses(over.service.end(admin, 'period-1', {}), 409, 'FEATURED_PERIOD_FINISHED');
  assert.equal(over.ended.length, 0);
  await refuses(placements({ period: null }).service.end(admin, 'missing', {}), 404);
});
