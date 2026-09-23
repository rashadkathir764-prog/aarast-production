import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  PlanProviderLinkStatus,
  Prisma,
  ProviderStatus,
  WeddingPlanStatus,
} from '@prisma/client';
import { dashboardService } from './support/owner-ports';

test('dashboard provider count excludes linked providers that are not active', async () => {
  const activeLink = providerLink('link-active', 'provider-active', ProviderStatus.ACTIVE);
  const suspendedLink = providerLink(
    'link-suspended',
    'provider-suspended',
    ProviderStatus.SUSPENDED,
  );
  const links = [activeLink, suspendedLink];
  const emptyModel = new Proxy(
    {},
    {
      get: (_target, property) => async () =>
        property === 'count' ? 0 : property === 'findFirst' ? null : [],
    },
  );
  const planProviderLink = {
    count: async ({ where }: any) => matchingLinks(links, where).length,
    findMany: async ({ where, take }: any) =>
      matchingLinks(links, where).slice(0, take ?? links.length),
  };
  const tx = new Proxy(
    { planProviderLink } as Record<string, unknown>,
    {
      get: (target, property: string) => target[property] ?? emptyModel,
    },
  );
  const prisma = new Proxy(
    {
      $transaction: async (operation: (client: unknown) => Promise<unknown>) =>
        operation(tx as any),
    } as Record<string, unknown>,
    {
      get: (target, property: string) => target[property] ?? emptyModel,
    },
  );
  const service = dashboardService(
    prisma as any,
    {
      assertPlanReadableInTransaction: async () => ({
        plan: weddingPlan,
        isOwner: true,
        sharedMember: null,
      }),
      canViewMoney: () => true,
      canManageMoney: () => true,
      canManageTasks: () => true,
      canManageGuests: () => true,
      canManageProviders: () => true,
      canManageMembers: () => true,
      canManagePlan: () => true,
    } as any,
    { visibilityWhereForUser: async () => null } as any,
  );

  const result = await service.getWeddingPlanDashboardSummary(
    { id: 'owner-1' } as any,
    weddingPlan.id,
  );

  assert.equal(result.providerCount, 1);
  assert.equal(result.acceptedProviders, 1);
  assert.equal(result.acceptedProvidersCount, 1);
  assert.deepEqual(
    result.planProviders.map((provider) => provider.providerId),
    ['provider-active'],
  );
});

const weddingPlan = {
  id: 'plan-1',
  ownerUserId: 'owner-1',
  title: 'Plan',
  weddingDate: new Date('2027-01-01T00:00:00.000Z'),
  city: null,
  location: null,
  estimatedBudget: null,
  currency: 'YER',
  status: WeddingPlanStatus.PLANNING,
  importMigrationId: null,
  createdAt: new Date('2026-01-01T00:00:00.000Z'),
  updatedAt: new Date('2026-01-01T00:00:00.000Z'),
};

function providerLink(id: string, providerId: string, status: ProviderStatus) {
  return {
    id,
    weddingPlanId: weddingPlan.id,
    providerId,
    quoteRequestId: `quote-${id}`,
    quoteOfferId: `offer-${id}`,
    status: PlanProviderLinkStatus.ACTIVE,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
    provider: {
      id: providerId,
      status,
      businessName: `Provider ${providerId}`,
      coverUrl: null,
      logoUrl: null,
      ratingAverage: new Prisma.Decimal(0),
      ratingCount: 0,
      primaryCategory: null,
      services: [],
    },
  };
}

function matchingLinks(
  links: ReturnType<typeof providerLink>[],
  where: any,
) {
  return links.filter((link) => {
    if (link.weddingPlanId !== where.weddingPlanId) return false;
    if (link.status !== where.status) return false;
    if (where.provider?.status && link.provider.status !== where.provider.status) {
      return false;
    }
    return true;
  });
}
