import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { HttpException } from '@nestjs/common';
import {
  AdminRole,
  Prisma,
  ProviderClaimStatus,
  ProviderReviewEventKind,
  ProviderStatus,
  UserRole,
  UserStatus,
} from '@prisma/client';
import { AdminProviderClaims } from '../src/admin/admin-provider-claims';
import { MarketplaceAdminRepository } from '../src/modules/marketplace/infrastructure/marketplace-admin.repository';
import {
  findLatestProviderDecision,
  hasJoiningService,
  latestProviderDecisionInclude,
  listProviderReviewEvents,
} from '../src/modules/marketplace/infrastructure/provider-review.repository';
import { adminService, providerDashboardService } from './support/owner-ports';

// The review of the provider account cycle (B-01, B-02, B-10, B-12): each
// test below failed on the code it fixes.

const providerUserId = '11111111-1111-4111-8111-111111111111';
const providerId = '22222222-2222-4222-8222-222222222222';
const categoryId = '33333333-3333-4333-8333-333333333333';
const serviceId = '44444444-4444-4444-8444-444444444444';
const adminId = '55555555-5555-4555-8555-555555555555';
const claimId = '66666666-6666-4666-8666-666666666666';
const now = new Date('2026-10-25T00:00:00.000Z');
const city = {
  id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  nameAr: 'صنعاء',
  nameEn: 'Sanaa',
  countryCode: 'YE',
  sortOrder: 1,
  isActive: true,
  createdAt: now,
  updatedAt: now,
};
const category = {
  id: categoryId,
  nameAr: 'تصوير',
  nameEn: 'Photography',
  slug: 'photography',
  icon: null,
  showForGroom: true,
  showForBride: true,
  sortOrder: 1,
  isActive: true,
  createdAt: now,
  updatedAt: now,
};
const providerUser = {
  id: providerUserId,
  phone: '+967700000002',
  role: UserRole.PROVIDER,
} as any;
const reviewer = { id: adminId, role: UserRole.ADMIN, adminMfa: true } as any;

function errorCode(error: unknown): unknown {
  if (!(error instanceof HttpException)) return undefined;
  const response = error.getResponse();
  return typeof response === 'object' && response !== null
    ? (response as { code?: unknown }).code
    : undefined;
}

async function rejectsWith(run: () => Promise<unknown>, status: number, code: string) {
  await assert.rejects(run, (error: unknown) => {
    assert.ok(error instanceof HttpException, `expected an HTTP error, got ${String(error)}`);
    assert.equal(error.getStatus(), status);
    assert.equal(errorCode(error), code);
    return true;
  });
}

/** Records every delegate call and answers from `answers`. */
function recordingClient(answers: Record<string, unknown> = {}) {
  const calls: Array<[string, any]> = [];
  const client: any = new Proxy(
    {},
    {
      get(_target, model: string) {
        return new Proxy(
          {},
          {
            get(_delegate, operation: string) {
              return async (args: unknown) => {
                const name = `${model}.${operation}`;
                calls.push([name, args]);
                const answer = answers[name];
                return typeof answer === 'function' ? answer(args) : answer;
              };
            },
          },
        );
      },
    },
  );
  return { client, calls };
}

// ------------------------------------------------------------ finding 10

test('every read of the review history orders the steps by their sequence, never by time alone', async () => {
  const { client, calls } = recordingClient({
    'providerReviewEvent.findFirst': null,
    'providerReviewEvent.findMany': [],
  });
  await findLatestProviderDecision(client, providerId);
  await listProviderReviewEvents(client, providerId);
  assert.deepEqual(calls[0][1].orderBy, { sequence: 'desc' });
  assert.deepEqual(calls[0][1].where.providerId, providerId);
  assert.deepEqual(calls[1][1].orderBy, { sequence: 'asc' });
  assert.deepEqual(latestProviderDecisionInclude.reviewEvents.orderBy, { sequence: 'desc' });
  assert.equal(latestProviderDecisionInclude.reviewEvents.take, 1);
});

// ------------------------------------------------------------ findings 8, 9

test('the joining rule counts only active services priced above zero', async () => {
  const { client, calls } = recordingClient({ 'providerService.count': 0 });
  assert.equal(await hasJoiningService(client, providerId), false);
  assert.deepEqual(calls[0], [
    'providerService.count',
    { where: { providerId, isActive: true, basePrice: { gt: 0 } } },
  ]);
  const priced = recordingClient({ 'providerService.count': 1 });
  assert.equal(await hasJoiningService(priced.client, providerId), true);
});

function joiningService(overrides: Record<string, unknown> = {}) {
  return {
    id: serviceId,
    providerId,
    categoryId,
    title: 'تصوير الليلة',
    description: null,
    basePrice: new Prisma.Decimal('150000'),
    priceUnit: null,
    currency: 'YER',
    priceUpdatedAt: now,
    cityId: null,
    isActive: true,
    images: [],
    category,
    city: null,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

/**
 * A provider waiting for approval (or another status) on a fake client:
 * `activePriced` is what the joining rule counts, `latestDecisionId` the
 * latest decision on record. Writes the code must not reach throw.
 */
function dashboardFor(
  status: ProviderStatus,
  options: {
    activePriced?: number;
    latestDecisionId?: string | null;
    services?: unknown[];
    onCreate?: (data: any) => void;
    onResubmit?: () => void;
  } = {},
) {
  const provider = {
    id: providerId,
    userId: providerUserId,
    cityId: city.id,
    primaryCategoryId: categoryId,
    businessName: 'استوديو ضوء صنعاء',
    ownerName: null,
    phone: '+967700000003',
    whatsapp: null,
    email: null,
    description: null,
    address: null,
    latitude: null,
    longitude: null,
    logoUrl: null,
    coverUrl: null,
    status,
    resubmittedAt: null,
    resubmitCount: 0,
    reopenedAt: null,
    reviewedAt: null,
    reviewedById: null,
    ratingAverage: { toString: () => '0' },
    ratingCount: 0,
    createdAt: now,
    updatedAt: now,
    city,
    primaryCategory: category,
  };
  const latestDecisionId = options.latestDecisionId ?? null;
  const prisma: any = {
    $queryRaw: async (query: { strings?: readonly string[] }) => {
      const sql = query.strings?.join('') ?? '';
      if (sql.includes('FROM "User"')) return [{ id: providerUserId, status: UserStatus.ACTIVE }];
      if (sql.includes('FROM "Provider"')) return [{ id: providerId }];
      if (sql.includes('FROM "ProviderCategory"')) return [{ id: categoryId }];
      if (sql.includes('FROM "ProviderService"')) return [{ id: serviceId }];
      return [];
    },
    provider: {
      findUnique: async () => provider,
      findFirst: async () => provider,
      update: async ({ data }: any) => {
        options.onResubmit?.();
        return { ...provider, ...data, resubmitCount: 1 };
      },
    },
    providerCategory: {
      findFirst: async () => category,
      findMany: async () => [category],
      count: async () => 1,
    },
    city: { findMany: async () => [city], findFirst: async () => city },
    providerReviewEvent: {
      findFirst: async () =>
        latestDecisionId
          ? {
              id: latestDecisionId,
              kind: ProviderReviewEventKind.CHANGES_REQUESTED,
              createdAt: now,
              notes: [],
            }
          : null,
      create: async ({ data }: any) => ({ id: 'resubmitted-step', ...data, notes: [] }),
    },
    // No featured placement on record (B-43).
    providerFeaturedPeriod: { findMany: async () => [] },
    portfolioItem: { findMany: async () => [] },
    providerService: {
      count: async () => options.activePriced ?? 1,
      findMany: async () => options.services ?? [joiningService()],
      findFirst: async () => joiningService(),
      findUnique: async () => joiningService(),
      update: async ({ data }: any) => ({ ...joiningService(), ...data }),
      create: async ({ data }: any) => {
        options.onCreate?.(data);
        return joiningService({ id: '77777777-7777-4777-8777-777777777777', ...data });
      },
    },
  };
  prisma.$transaction = async (operation: (client: any) => Promise<unknown>) => operation(prisma);
  return providerDashboardService(
    prisma,
    { createNotificationInTransaction: async () => null },
    { verifyPublicMediaUrl: async (_user: unknown, url: string) => url },
    {},
  );
}

test('a provider whose joining service the team switched off adds a new one before approval (finding 8)', async () => {
  const created: any[] = [];
  const switchedOff = joiningService({ isActive: false });
  for (const status of [ProviderStatus.PENDING, ProviderStatus.NEEDS_CHANGES]) {
    const dashboard = dashboardFor(status, {
      activePriced: 0,
      services: [switchedOff],
      onCreate: (data) => created.push(data),
    });
    const service = await dashboard.createService(providerUser, {
      categoryId,
      title: 'تصوير الليلة',
      basePrice: '150000',
      currency: 'YER',
    });
    assert.equal(service.isActive, true);
  }
  assert.equal(created.length, 2);
  assert.equal(created[0].currency, 'YER');

  // While an active priced service exists, it stays the only one.
  const priced = dashboardFor(ProviderStatus.PENDING, { activePriced: 1 });
  await rejectsWith(
    () => priced.createService(providerUser, { categoryId, title: 'ثانية', basePrice: '1000' }),
    403,
    'PROVIDER_JOINING_SERVICE_ONLY',
  );
});

test('the joining service is edited by its name, price and words only, in YER (finding 12)', async () => {
  const dashboard = dashboardFor(ProviderStatus.NEEDS_CHANGES);
  await rejectsWith(
    () => dashboard.updateService(providerUser, serviceId, { priceUnit: 'لليلة' }),
    403,
    'PROVIDER_JOINING_SERVICE_ONLY',
  );
  await rejectsWith(
    () => dashboard.updateService(providerUser, serviceId, { currency: 'USD' }),
    422,
    'PROVIDER_JOINING_CURRENCY',
  );
  const kept = await dashboard.updateService(providerUser, serviceId, {
    title: 'تصوير الزفة',
    currency: 'yer',
  });
  assert.equal(kept.currency, 'YER');

  const empty = dashboardFor(ProviderStatus.PENDING, { activePriced: 0, services: [] });
  await rejectsWith(
    () =>
      empty.createService(providerUser, {
        categoryId,
        title: 'تصوير',
        basePrice: '1000',
        currency: 'SAR',
      }),
    422,
    'PROVIDER_JOINING_CURRENCY',
  );
  await rejectsWith(
    () =>
      empty.createService(providerUser, {
        categoryId,
        title: 'تصوير',
        basePrice: '1000',
        priceUnit: 'للساعة',
      }),
    403,
    'PROVIDER_JOINING_SERVICE_ONLY',
  );
});

test('joining in another currency than YER is refused before anything is written (finding 12)', async () => {
  const dashboard = dashboardFor(ProviderStatus.PENDING);
  await rejectsWith(
    () =>
      dashboard.apply(providerUser, {
        businessName: 'استوديو',
        phone: '+967700000002',
        cityId: city.id,
        categoryIds: [categoryId],
        services: [{ title: 'تصوير', basePrice: '150000', currency: 'USD' }],
      }),
    422,
    'PROVIDER_JOINING_CURRENCY',
  );
});

// ------------------------------------------------------------ finding 7

test('«أرسلت التعديل» names the decision the provider read; a newer one is refused (finding 7)', async () => {
  let resubmitted = 0;
  const stale = dashboardFor(ProviderStatus.NEEDS_CHANGES, {
    latestDecisionId: 'decision-rewritten',
    onResubmit: () => (resubmitted += 1),
  });
  await assert.rejects(
    () => stale.resubmitApplication(providerUser, { latestDecisionId: 'decision-read' }),
    (error: unknown) => {
      assert.ok(error instanceof HttpException);
      assert.equal(error.getStatus(), 409);
      const body = error.getResponse() as Record<string, unknown>;
      assert.equal(body.code, 'PROVIDER_REVIEW_CHANGED');
      assert.equal(body.latestDecisionId, 'decision-rewritten');
      return true;
    },
  );
  assert.equal(resubmitted, 0);

  const current = dashboardFor(ProviderStatus.NEEDS_CHANGES, {
    latestDecisionId: 'decision-read',
    onResubmit: () => (resubmitted += 1),
  });
  const profile = await current.resubmitApplication(providerUser, {
    latestDecisionId: 'decision-read',
  });
  assert.equal(profile.status, ProviderStatus.PENDING);
  assert.equal(resubmitted, 1);

  // A switched-off joining service is not one: the rule refuses it.
  const switchedOff = dashboardFor(ProviderStatus.NEEDS_CHANGES, {
    latestDecisionId: 'decision-read',
    activePriced: 0,
  });
  await rejectsWith(
    () => switchedOff.resubmitApplication(providerUser, { latestDecisionId: 'decision-read' }),
    422,
    'PROVIDER_SERVICE_REQUIRED',
  );
});

test('the profile names the latest decision it shows (finding 7)', async () => {
  const profile = await dashboardFor(ProviderStatus.NEEDS_CHANGES, {
    latestDecisionId: 'decision-read',
  }).getProfile(providerUser);
  assert.deepEqual(profile.latestDecision, {
    id: 'decision-read',
    kind: ProviderReviewEventKind.CHANGES_REQUESTED,
    at: now,
  });
});

// ------------------------------------------------------------ finding 13

test('p02 reads the listing with its category and city (finding 13)', async () => {
  const listing = {
    id: providerId,
    businessName: 'استوديو ضوء صنعاء',
    phone: '+967700000002',
    cityId: city.id,
    primaryCategoryId: categoryId,
  };
  const prisma: any = {
    provider: {
      findFirst: async ({ where }: any) => (where.userId === null ? listing : null),
    },
    city: { findMany: async () => [city] },
    providerCategory: { findMany: async () => [category] },
  };
  const service = providerDashboardService(prisma, {}, {}, {});
  const found = await service.findClaimableListing(providerUser);
  assert.deepEqual(found, {
    listing: {
      id: providerId,
      businessName: 'استوديو ضوء صنعاء',
      city: { id: city.id, nameAr: 'صنعاء' },
      primaryCategory: { id: categoryId, nameAr: 'تصوير' },
    },
  });
});

// ------------------------------------------------------------ finding 4

function claimsFor(claimantPhone: string | null) {
  const linked: string[] = [];
  const owners: any = {
    accounts: {
      lockAccountsForUpdateInTransaction: async (_tx: unknown, ids: string[]) =>
        ids.map((id) =>
          id === adminId
            ? { id, role: UserRole.ADMIN, adminRole: AdminRole.OPERATIONS, status: UserStatus.ACTIVE }
            : { id, role: UserRole.USER, adminRole: null, status: UserStatus.ACTIVE },
        ),
      getAccount: async (_tx: unknown, id: string) =>
        id === providerUserId ? { id, phone: claimantPhone, status: UserStatus.ACTIVE } : null,
    },
    marketplace: {
      findClaimRequestParties: async () => ({ userId: providerUserId, providerId }),
      lockClaimRequestForUpdateInTransaction: async () => ({
        id: claimId,
        providerId,
        userId: providerUserId,
        status: ProviderClaimStatus.PENDING,
      }),
      lockProviderForUpdateInTransaction: async () => ({
        userId: null,
        status: ProviderStatus.ACTIVE,
        phone: '+967777123456',
      }),
      getAccountProviders: async () => [],
      linkClaimedListingInTransaction: async (_tx: unknown, listingId: string) => {
        linked.push(listingId);
      },
      decideClaimRequestInTransaction: async () => ({
        id: claimId,
        status: ProviderClaimStatus.APPROVED,
        note: null,
        createdAt: now,
        decidedAt: now,
        provider: {
          id: providerId,
          businessName: 'ملف بلا حساب',
          phone: '+967777123456',
          whatsapp: null,
          logoUrl: null,
          status: ProviderStatus.ACTIVE,
          ratingAverage: { toString: () => '0' },
          ratingCount: 0,
          city: null,
          primaryCategory: null,
        },
      }),
    },
    providerAccounts: { promoteToProviderInTransaction: async () => true },
    attachClaimRequests: async (_tx: unknown, rows: unknown[]) => rows,
  };
  const prisma: any = {
    $transaction: async (operation: (client: unknown) => Promise<unknown>) => operation({}),
  };
  const claims = new AdminProviderClaims({
    prisma,
    owners,
    notifications: { createNotificationInTransaction: async () => null } as any,
  });
  return { claims, linked };
}

test('approving a claim checks the claimant still holds the listing phone (finding 4)', async () => {
  const changed = claimsFor('+967711000000');
  await rejectsWith(
    () => changed.claims.approve(reviewer, claimId),
    409,
    'PROVIDER_CLAIM_PHONE_CHANGED',
  );
  assert.deepEqual(changed.linked, []);

  const none = claimsFor(null);
  await rejectsWith(() => none.claims.approve(reviewer, claimId), 409, 'PROVIDER_CLAIM_PHONE_CHANGED');
  assert.deepEqual(none.linked, []);

  // Another spelling of the same phone still proves it, as at claim time.
  const same = claimsFor('0777123456');
  await same.claims.approve(reviewer, claimId);
  assert.deepEqual(same.linked, [providerId]);
});

// ------------------------------------------------------------ finding 9

test('a profile without an active priced service is not approved (finding 9)', async () => {
  let decided = 0;
  const prisma: any = {
    $queryRaw: async (query: { strings?: readonly string[] }) => {
      const sql = query.strings?.join('') ?? '';
      if (sql.includes('FROM "User"')) {
        return [
          { id: adminId, role: UserRole.ADMIN, adminRole: AdminRole.OPERATIONS, status: UserStatus.ACTIVE },
          { id: providerUserId, role: UserRole.PROVIDER, adminRole: null, status: UserStatus.ACTIVE },
        ].sort((left, right) => left.id.localeCompare(right.id));
      }
      if (sql.includes('FROM "Provider"')) return [{ id: providerId }];
      throw new Error(`Unexpected statement: ${sql}`);
    },
    provider: {
      findUnique: async () => ({
        userId: providerUserId,
        status: ProviderStatus.PENDING,
        phone: '+967700000003',
      }),
      update: async () => {
        decided += 1;
        throw new Error('approved without a joining service');
      },
    },
    providerService: { count: async () => 0 },
    providerReviewEvent: {
      create: async () => {
        decided += 1;
        throw new Error('approved without a joining service');
      },
    },
  };
  prisma.$transaction = async (operation: (client: any) => Promise<unknown>) => operation(prisma);
  const service = adminService(prisma, {}, { createNotificationInTransaction: async () => null });
  await rejectsWith(
    () => service.approveProvider(reviewer, providerId),
    422,
    'PROVIDER_SERVICE_REQUIRED',
  );
  assert.equal(decided, 0);
});

// ------------------------------------------------------------ finding 11

test('«أُعيد إرسالها» narrows the profiles waiting for review only (finding 11)', async () => {
  const { client, calls } = recordingClient({
    'provider.count': 0,
    'provider.findMany': [],
  });
  const repository = new MarketplaceAdminRepository();
  await repository.listProviders(
    client,
    {
      statuses: [ProviderStatus.PENDING, ProviderStatus.NEEDS_CHANGES, ProviderStatus.REJECTED],
      cityId: null,
      categoryId: null,
      search: null,
      resubmitted: true,
    },
    { skip: 0, take: 20 },
  );
  const where = calls.find(([name]) => name === 'provider.findMany')![1].where;
  assert.ok(
    where.AND.some(
      (condition: any) =>
        Array.isArray(condition.status?.in) &&
        condition.status.in.length === 1 &&
        condition.status.in[0] === ProviderStatus.PENDING,
    ),
    'resubmitted=true must keep PENDING profiles only',
  );

  const service = adminService(
    { $transaction: async () => assert.fail('a contradicting filter must not query') },
    {},
    {},
  );
  await assert.rejects(
    () =>
      service.listProviderApplications({ status: 'NEEDS_CHANGES', resubmitted: 'true' } as any),
    (error: unknown) => error instanceof HttpException && error.getStatus() === 400,
  );
});
