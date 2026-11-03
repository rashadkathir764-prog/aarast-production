import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  BudgetCategoryKind,
  FundingSourceKind,
  FundingSourceStatus,
  Prisma,
  SharedMemberRole,
  WeddingPlanStatus,
} from '@prisma/client';
import { dashboardService } from './support/owner-ports';

// J1-04: the home shows the first server item as the next step, so the
// dashboard hands the presenter the plan's mahr and its wedding agreements,
// read from finance's one money picture on the same snapshot.

type Fixture = {
  persona: 'GROOM' | 'BRIDE' | null;
  categories?: Array<{ id: string; name: string; kind: BudgetCategoryKind }>;
  costs?: Array<{ id: string; budgetCategoryId: string; totalAmount: string }>;
  fundingSources?: Array<{ id: string; kind: FundingSourceKind; status: FundingSourceStatus; amount: string }>;
  reader?: 'OWNER' | 'PARTNER';
  canManageMoney?: boolean;
};

async function nextSteps(fixture: Fixture) {
  const plan = {
    id: 'plan-1',
    ownerUserId: 'owner-1',
    title: 'Plan',
    weddingDate: new Date('2027-01-01T00:00:00.000Z'),
    city: 'صنعاء',
    location: null,
    estimatedBudget: new Prisma.Decimal('5000000'),
    currency: 'YER',
    status: WeddingPlanStatus.PLANNING,
    persona: fixture.persona,
    importMigrationId: null,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
  };
  const emptyModel = new Proxy(
    {},
    {
      get: (_target, property) => async () =>
        property === 'count' ? 0 : property === 'findFirst' || property === 'findUnique' ? null : [],
    },
  );
  const categories = (fixture.categories ?? []).map((category) => ({
    ...category,
    weddingPlanId: plan.id,
    allocatedAmount: null,
    suggestion: null,
    suggestionUntil: null,
    createdAt: plan.createdAt,
  }));
  const costs = (fixture.costs ?? []).map((cost) => ({
    ...cost,
    totalAmount: new Prisma.Decimal(cost.totalAmount),
    title: 'اتفاق',
    payer: null,
    payerName: null,
  }));
  const fundingSources = (fixture.fundingSources ?? []).map((source) => ({
    ...source,
    weddingPlanId: plan.id,
    sourceName: 'المهر من العريس',
    amount: new Prisma.Decimal(source.amount),
    expectedAt: null,
    repayments: [],
  }));
  const tables: Record<string, unknown> = {
    budgetCategory: { findMany: async () => categories },
    // Only the money picture's read selects the amounts; the private-cost
    // and venue reads find nothing.
    weddingCost: {
      findMany: async (args: { select?: Record<string, unknown> }) =>
        args?.select?.totalAmount ? costs : [],
      count: async () => 0,
      findFirst: async () => null,
    },
    fundingSource: { findMany: async () => fundingSources },
  };
  const tx = new Proxy(tables, {
    get: (target, property: string) => target[property] ?? emptyModel,
  });
  const prisma = new Proxy(
    {
      $transaction: async (operation: (client: unknown) => Promise<unknown>) =>
        operation(tx),
    } as Record<string, unknown>,
    { get: (target, property: string) => target[property] ?? emptyModel },
  );
  const partner = fixture.reader === 'PARTNER';
  const service = dashboardService(
    prisma,
    {
      assertPlanReadableInTransaction: async () => ({
        plan,
        isOwner: !partner,
        sharedMember: partner
          ? { id: 'member-1', role: SharedMemberRole.BRIDE, authorityVersion: 1 }
          : null,
      }),
      canViewMoney: () => true,
      canManageMoney: () => fixture.canManageMoney ?? true,
      canManageTasks: () => true,
      canManageGuests: () => true,
      canManageProviders: () => true,
      canManageMembers: () => true,
      canManagePlan: () => true,
    },
    { visibilityWhereForUser: async () => null },
    undefined,
    { summary: async () => null },
  );
  const summary = await service.getWeddingPlanDashboardSummary(
    { id: partner ? 'partner-1' : 'owner-1' } as never,
    plan.id,
  );
  return summary.importantItems.map((item) => item.type);
}

const mahrItem = { id: 'mahr-item', name: 'المهر', kind: BudgetCategoryKind.MAHR };
const hallItem = { id: 'hall-item', name: 'القاعة', kind: BudgetCategoryKind.WEDDING };

test('home next step: the groom without his mahr is asked for it first', async () => {
  assert.deepEqual(await nextSteps({ persona: 'GROOM' }), [
    'RECORD_MAHR',
    'ADD_FIRST_COST',
    'ADD_GUESTS',
  ]);
});

test('home next step: the groom\'s recorded mahr is not a wedding agreement', async () => {
  assert.deepEqual(
    await nextSteps({
      persona: 'GROOM',
      categories: [mahrItem],
      costs: [{ id: 'mahr-cost', budgetCategoryId: mahrItem.id, totalAmount: '3000000' }],
    }),
    ['ADD_FIRST_COST', 'ADD_GUESTS', 'REQUEST_QUOTE'],
  );
  assert.deepEqual(
    await nextSteps({
      persona: 'GROOM',
      categories: [mahrItem, hallItem],
      costs: [
        { id: 'mahr-cost', budgetCategoryId: mahrItem.id, totalAmount: '3000000' },
        { id: 'hall-cost', budgetCategoryId: hallItem.id, totalAmount: '800000' },
      ],
    }),
    ['ADD_GUESTS', 'REQUEST_QUOTE'],
  );
});

test('home next step: the bride\'s mahr is her funding, read for the owner', async () => {
  assert.deepEqual(await nextSteps({ persona: 'BRIDE' }), [
    'RECORD_MAHR',
    'ADD_FIRST_COST',
    'ADD_GUESTS',
  ]);
  assert.deepEqual(
    await nextSteps({
      persona: 'BRIDE',
      fundingSources: [
        {
          id: 'mahr-source',
          kind: FundingSourceKind.MAHR,
          status: FundingSourceStatus.RECEIVED,
          amount: '3000000',
        },
      ],
    }),
    ['ADD_FIRST_COST', 'ADD_GUESTS', 'REQUEST_QUOTE'],
  );
});

test('home next step: a plan without a mahr side is never asked for one', async () => {
  assert.deepEqual(await nextSteps({ persona: null }), [
    'ADD_FIRST_COST',
    'ADD_GUESTS',
    'REQUEST_QUOTE',
  ]);
});

test('home next step: only the owner records the mahr; the money steps need money rights', async () => {
  // The mahr is recorded by the plan's owner only (POST mahr refuses others).
  assert.deepEqual(await nextSteps({ persona: 'GROOM', reader: 'PARTNER' }), [
    'ADD_FIRST_COST',
    'ADD_GUESTS',
    'REQUEST_QUOTE',
  ]);
  assert.deepEqual(
    await nextSteps({ persona: 'GROOM', reader: 'PARTNER', canManageMoney: false }),
    ['ADD_GUESTS', 'REQUEST_QUOTE'],
  );
});
