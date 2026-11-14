import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import { readMoneyPicture } from '../src/modules/finance/infrastructure/money-picture';
import type { MoneyPicture } from '../src/modules/finance/public/money-picture';
import { budgetVersionOf } from '../src/modules/finance/public/budget-version';
import {
  budgetIncludesMahrViolation,
  mahrCountsInBudget,
} from '../src/modules/finance/public/budget-mahr';
import { allocationRoomViolation } from '../src/modules/finance/domain/budget-allocation-policy';
import { MoneyBudgetService } from '../src/money/money-budget.service';
import { BudgetCategoriesService } from '../src/budget-categories/budget-categories.service';
import { PlanReadService } from '../src/modules/planning/infrastructure/plan-read.service';
import { WeddingPlansService } from '../src/wedding-plans/wedding-plans.service';
import {
  collaborationHistory,
  collaborationPermissions,
  planningOwnerPorts,
} from './support/owner-ports';

// D114: the groom may count the mahr inside his budget, chosen while he
// writes it. The owner's real plan: a 7,000,000 budget, a 2,000,000 mahr,
// 500,000 of it handed over, nothing else agreed.

const d = (value: string | number) => new Prisma.Decimal(value);

interface Row {
  id: string;
  kind?: 'WEDDING' | 'MAHR';
  allocatedAmount?: number | null;
  estimatedAmount?: number | null;
}
interface CostRow {
  id: string;
  item: string;
  total: number;
  paid?: number;
  payer?: string | null;
}

function planTx(input: { items?: Row[]; costs?: CostRow[]; sources?: unknown[] } = {}) {
  const items: Row[] = [{ id: 'mahr', kind: 'MAHR' }, ...(input.items ?? [])];
  const costs: CostRow[] = [
    { id: 'mahr', item: 'mahr', total: 2_000_000, paid: 500_000, payer: null },
    ...(input.costs ?? []),
  ];
  return {
    budgetCategory: {
      findMany: async () =>
        items.map((item) => ({
          id: item.id,
          name: item.id,
          kind: item.kind ?? 'WEDDING',
          allocatedAmount: item.allocatedAmount == null ? null : d(item.allocatedAmount),
          estimatedAmount: item.estimatedAmount == null ? null : d(item.estimatedAmount),
          suggestion: null,
          suggestionUntil: null,
        })),
    },
    weddingCost: {
      findMany: async ({ where }: any) =>
        where.privateToUserId
          ? []
          : costs.map((cost) => ({
              id: cost.id,
              budgetCategoryId: cost.item,
              totalAmount: d(cost.total),
              title: cost.id,
              payer: cost.payer ?? null,
              payerName: null,
              estimateCover: 'WHOLE',
              estimatePart: null,
            })),
    },
    costPayment: {
      findMany: async () =>
        costs
          .filter((cost) => (cost.paid ?? 0) > 0)
          .map((cost) => ({
            id: `pay-${cost.id}`,
            weddingCostId: cost.id,
            amount: d(cost.paid as number),
            entryType: 'PAYMENT',
            lowersScheduleId: null,
            reversalOfId: null,
          })),
    },
    paymentSchedule: { findMany: async () => [] },
    fundingSource: {
      findMany: async () =>
        input.sources ?? [
          {
            id: 'savings',
            kind: 'SAVINGS',
            sourceName: 'الادخار',
            contributorName: null,
            amount: d(3_000_000),
            status: 'RECEIVED',
            expectedAt: null,
            repayments: [],
          },
        ],
    },
  } as unknown as Prisma.TransactionClient;
}

const query = (over: Record<string, unknown> = {}) => ({
  weddingPlanId: 'plan-1',
  persona: 'GROOM',
  totalBudget: d(7_000_000),
  scope: null,
  readerUserId: 'owner-1',
  fundingVisible: true,
  now: new Date('2026-11-14T09:00:00.000Z'),
  ...over,
});

/** What the mahr's place does not touch: everything outside the budget. */
const untouched = (picture: MoneyPicture) => ({
  costs: picture.costs,
  outstanding: picture.outstanding,
  mahr: picture.mahr,
  funding: picture.funding,
  coverage: picture.coverage,
  expectedWedding: picture.expected.wedding,
  expectedMahr: picture.expected.mahr,
  obligations: picture.obligations,
  payers: picture.payers,
});

test('D114 off: the owner\'s numbers stay as today, the mahr outside the budget', async () => {
  const picture = await readMoneyPicture(planTx(), query());
  assert.deepEqual(picture.budget, {
    total: '7000000',
    includesMahr: false,
    allocated: '0',
    unallocated: '7000000',
    confirmedCost: '0',
    paid: '0',
    paidByOwner: '0',
    paidByOthers: '0',
    outstanding: '0',
    count: 0,
    remaining: '7000000',
  });
  assert.equal(picture.costs.total, '2000000');
  assert.equal(picture.costs.paid, '500000');
  assert.equal(picture.costs.outstanding, '1500000');
  assert.equal(picture.expected.budgetLeft, '7000000');
  assert.equal(picture.expected.mahr.expected, '2000000');
});

test('D114 on: the mahr counts against the budget, and nothing outside the budget moves', async () => {
  const off = await readMoneyPicture(planTx(), query());
  const on = await readMoneyPicture(planTx(), query({ budgetIncludesMahr: true }));
  assert.deepEqual(on.budget, {
    total: '7000000',
    includesMahr: true,
    allocated: '0',
    unallocated: '5000000',
    confirmedCost: '2000000',
    paid: '500000',
    paidByOwner: '500000',
    paidByOthers: '0',
    outstanding: '1500000',
    // The first agreement with a provider is still to come (RA-MO-147).
    count: 0,
    remaining: '5000000',
  });
  assert.equal(on.expected.budgetLeft, '5000000');
  // «منها المهر»: the two figures stay apart in both modes.
  assert.equal(on.expected.wedding.expected, '0');
  assert.equal(on.expected.mahr.expected, '2000000');
  assert.deepEqual(untouched(on), untouched(off));
  assert.notEqual(on.coverage, null);
});

test('D114 on: wedding agreements and estimates with the mahr cross the budget', async () => {
  const tx = () =>
    planTx({
      items: [{ id: 'hall' }, { id: 'food', estimatedAmount: 2_500_000 }],
      costs: [{ id: 'hall', item: 'hall', total: 3_000_000, paid: 1_000_000 }],
    });
  const off = await readMoneyPicture(tx(), query());
  const on = await readMoneyPicture(tx(), query({ budgetIncludesMahr: true }));
  assert.equal(off.expected.budgetLeft, '1500000');
  assert.equal(off.warnings.some((warning) => warning.type === 'BUDGET_EXCEEDED'), false);
  assert.equal(on.expected.budgetLeft, '-500000');
  assert.deepEqual(
    on.warnings.find((warning) => warning.type === 'BUDGET_EXCEEDED'),
    { type: 'BUDGET_EXCEEDED', severity: 'DANGER', count: null, amount: '500000' },
  );
  assert.equal(on.budget.confirmedCost, '5000000');
  assert.equal(on.budget.paid, '1500000');
  assert.equal(on.budget.outstanding, '3500000');
  assert.equal(on.budget.remaining, '2000000');
  assert.equal(on.budget.count, 1);
  assert.equal(off.budget.count, 1);
  assert.deepEqual(untouched(on), untouched(off));
});

test('D114 on: allocations that no longer fit are an over-budget state, not an error', async () => {
  const tx = () =>
    planTx({
      items: [
        { id: 'hall', allocatedAmount: 4_000_000 },
        { id: 'food', allocatedAmount: 2_000_000 },
      ],
    });
  const off = await readMoneyPicture(tx(), query());
  const on = await readMoneyPicture(tx(), query({ budgetIncludesMahr: true }));
  assert.equal(off.budget.unallocated, '1000000');
  assert.equal(on.budget.unallocated, '-1000000');
  assert.equal(on.expected.budgetLeft, '-1000000');
  assert.equal(on.warnings.some((warning) => warning.type === 'BUDGET_EXCEEDED'), true);
});

test('D114: on a plan that receives the mahr the choice means nothing', async () => {
  const tx = () =>
    planTx({
      items: [{ id: 'dress', estimatedAmount: 1_000_000 }],
      sources: [],
    });
  const off = await readMoneyPicture(tx(), query({ persona: 'BRIDE' }));
  const sent = await readMoneyPicture(tx(), query({ persona: 'BRIDE', budgetIncludesMahr: true }));
  assert.equal(sent.budget.includesMahr, false);
  assert.deepEqual(sent, off);
  assert.equal(mahrCountsInBudget('BRIDE', true), false);
  assert.equal(mahrCountsInBudget(null, true), false);
  assert.equal(mahrCountsInBudget('HELPER', true), false);
  assert.equal(mahrCountsInBudget('GROOM', true), true);
  assert.equal(mahrCountsInBudget('GROOM', false), false);
});

test('D114: writing the choice on a plan that does not pay the mahr is refused with its reason', () => {
  const refused = budgetIncludesMahrViolation('BRIDE', true);
  assert.equal(refused?.kind, 'invalid');
  assert.equal(refused?.code, 'FINANCE_MAHR_BUDGET_PAYER_ONLY');
  assert.match(refused?.userMessage ?? '', /المهر/);
  assert.notEqual(budgetIncludesMahrViolation(null, true), null);
  assert.equal(budgetIncludesMahrViolation('GROOM', true), null);
  assert.equal(budgetIncludesMahrViolation('BRIDE', false), null);
  assert.equal(budgetIncludesMahrViolation('BRIDE', undefined), null);
});

test('D114: items cannot be given what the mahr already takes of the budget', () => {
  const budget = d(7_000_000);
  const mahr = d(2_000_000);
  // Room is 5,000,000 with the mahr inside.
  assert.equal(allocationRoomViolation(budget, mahr, d(5_000_000), d(0)), null);
  assert.equal(
    allocationRoomViolation(budget, mahr, d(5_500_000), d(0))?.code,
    'FINANCE_ALLOCATIONS_EXCEED_BUDGET_AFTER_MAHR',
  );
  // Turning the choice on over allocations that no longer fit is allowed:
  // nothing more is given, the result is over budget.
  assert.equal(allocationRoomViolation(budget, mahr, d(6_000_000), d(6_000_000)), null);
  assert.equal(allocationRoomViolation(budget, mahr, d(5_500_000), d(6_000_000)), null);
  // Giving more on top of that is not.
  assert.notEqual(allocationRoomViolation(budget, mahr, d(6_500_000), d(6_000_000)), null);
  // The budget itself stays the hard cap, with or without the mahr.
  assert.equal(
    allocationRoomViolation(budget, d(0), d(7_500_000), d(7_500_000))?.code,
    'FINANCE_ALLOCATIONS_EXCEED_BUDGET',
  );
  assert.equal(allocationRoomViolation(null, mahr, d(0), d(0)), null);
});

test('D114 (Q-4): the budget version changes with the choice, and not for a plan without it', () => {
  const base = {
    totalBudget: '7000000',
    currency: 'YER',
    categories: [{ id: 'hall', name: 'القاعة', allocatedAmount: null, estimatedAmount: null }],
  };
  // Every version a phone holds today stays valid after the column lands.
  assert.equal(budgetVersionOf({ ...base, budgetIncludesMahr: false }), budgetVersionOf(base));
  assert.notEqual(budgetVersionOf({ ...base, budgetIncludesMahr: true }), budgetVersionOf(base));
});

// The write paths: the versioned budget replace (Q-4 still applies), the
// plan's create and its persona change.

function budgetService(plan: { persona: string | null; budgetIncludesMahr: boolean }, allocated = 0) {
  const writes: Array<Record<string, unknown>> = [];
  const stored = [
    {
      id: 'hall',
      name: 'القاعة',
      normalizedName: 'القاعة',
      weddingPlanId: 'plan-1',
      allocatedAmount: allocated ? d(allocated) : null,
      estimatedAmount: null,
      createdAt: new Date(0),
      updatedAt: new Date(0),
      _count: { weddingCosts: 0 },
    },
  ];
  const tx = {
    $queryRaw: async () => [{ id: 'plan-1' }],
    weddingCost: { count: async () => 1, findFirst: async () => ({ id: 'mahr' }), findMany: async () => [] },
    fundingSource: { findFirst: async () => null, findMany: async () => [] },
    budgetCategory: {
      findMany: async ({ where }: any) =>
        where.kind === 'MAHR'
          ? [
              {
                allocatedAmount: null,
                estimatedAmount: null,
                suggestion: null,
                weddingCosts: [{ totalAmount: d(2_000_000), estimateCover: 'WHOLE', estimatePart: null }],
              },
            ]
          : stored,
      deleteMany: async () => ({ count: 0 }),
      update: async () => stored[0],
      create: async () => stored[0],
    },
  };
  const service = new MoneyBudgetService(
    { $transaction: async (operation: (client: any) => unknown) => operation(tx) } as any,
    {
      assertMoneyManageableForUpdateInTransaction: async () => ({
        plan: {
          id: 'plan-1',
          currency: 'YER',
          estimatedBudget: d(7_000_000),
          ...plan,
        },
        isOwner: true,
        sharedMember: null,
      }),
      canViewMoney: () => true,
      canManageMoney: () => true,
    } as any,
    {
      updateBudgetInTransaction: async (_tx: unknown, input: Record<string, unknown>) => {
        writes.push(input);
      },
    } as any,
    new PlanReadService(),
    { listActiveCategories: async () => [], listMoneyCatalogItems: async () => [] } as any,
  );
  const save = (over: Record<string, unknown>) =>
    service.replace({ id: 'owner-1' } as any, 'plan-1', {
      totalBudget: '7000000',
      currency: 'YER',
      categories: [{ id: 'hall', name: 'القاعة', allocatedAmount: allocated ? String(allocated) : null }],
      ...over,
    } as any);
  return { save, writes };
}

const refusedWith = (code: string) => (error: any) => {
  assert.equal(error.getStatus?.(), 400);
  assert.equal(error.getResponse().code, code);
  return true;
};

test('D114: the budget replace refuses the mahr inside a bride\'s budget, and writes nothing', async () => {
  const { save, writes } = budgetService({ persona: 'BRIDE', budgetIncludesMahr: false });
  await assert.rejects(save({ budgetIncludesMahr: true }), refusedWith('FINANCE_MAHR_BUDGET_PAYER_ONLY'));
  assert.equal(writes.length, 0);
});

test('D114: the budget replace writes the groom\'s choice, and leaves it when omitted', async () => {
  const on = budgetService({ persona: 'GROOM', budgetIncludesMahr: false });
  await on.save({ budgetIncludesMahr: true }).catch(() => null);
  assert.equal(on.writes[0]?.budgetIncludesMahr, true);
  const older = budgetService({ persona: 'GROOM', budgetIncludesMahr: true });
  await older.save({}).catch(() => null);
  assert.equal(older.writes.length, 1);
  assert.equal(older.writes[0]?.budgetIncludesMahr, undefined);
});

test('D114: turning the choice on over allocations that no longer fit is allowed; giving more is not', async () => {
  // 6,000,000 allocated; the mahr's 2,000,000 leaves room for 5,000,000.
  const turned = budgetService({ persona: 'GROOM', budgetIncludesMahr: false }, 6_000_000);
  await turned.save({ budgetIncludesMahr: true }).catch(() => null);
  assert.equal(turned.writes.length, 1);
  const more = budgetService({ persona: 'GROOM', budgetIncludesMahr: true }, 4_000_000);
  await assert.rejects(
    more.save({ categories: [{ id: 'hall', name: 'القاعة', allocatedAmount: '5500000' }] }),
    refusedWith('FINANCE_ALLOCATIONS_EXCEED_BUDGET_AFTER_MAHR'),
  );
  assert.equal(more.writes.length, 0);
  // With the mahr outside, the same allocation fits the budget.
  const outside = budgetService({ persona: 'GROOM', budgetIncludesMahr: false }, 4_000_000);
  await outside
    .save({ categories: [{ id: 'hall', name: 'القاعة', allocatedAmount: '5500000' }] })
    .catch(() => null);
  assert.equal(outside.writes.length, 1);
});

test('D114: a new item is not given what the mahr takes of the budget', async () => {
  const run = async (budgetIncludesMahr: boolean, allocatedAmount: string) => {
    const created: unknown[] = [];
    const tx = {
      budgetCategory: {
        aggregate: async () => ({ _sum: { allocatedAmount: d(4_000_000) } }),
        findMany: async () => [
          {
            allocatedAmount: null,
            estimatedAmount: null,
            suggestion: null,
            weddingCosts: [{ totalAmount: d(2_000_000), estimateCover: 'WHOLE', estimatePart: null }],
          },
        ],
        create: async ({ data }: any) => {
          created.push(data);
          throw new Error('stop after the write');
        },
      },
    };
    const service = new BudgetCategoriesService(
      { $transaction: async (work: (client: any) => unknown) => work(tx) } as any,
      {
        assertMoneyManageableForUpdateInTransaction: async () => ({
          plan: { id: 'plan-1', estimatedBudget: d(7_000_000), persona: 'GROOM', budgetIncludesMahr },
          isOwner: true,
          sharedMember: null,
        }),
      } as any,
    );
    const result = await service
      .create({ id: 'owner-1' } as any, 'plan-1', { name: 'الأكل', allocatedAmount } as any)
      .then(() => 'saved', (error: any) => error.getResponse?.().code ?? 'written');
    return { result, created: created.length };
  };
  // 4,000,000 given, the mahr's 2,000,000: room for 1,000,000 more.
  assert.deepEqual(await run(true, '1500000'), {
    result: 'FINANCE_ALLOCATIONS_EXCEED_BUDGET_AFTER_MAHR',
    created: 0,
  });
  assert.equal((await run(true, '1000000')).created, 1);
  assert.equal((await run(false, '1500000')).created, 1);
});

function planService(context?: any) {
  const created: Array<Record<string, unknown>> = [];
  const updated: Array<Record<string, unknown>> = [];
  const tx = {
    $queryRaw: async () => [{ id: 'owner-1', status: 'ACTIVE' }],
    weddingPlan: {
      create: async ({ data }: any) => {
        created.push(data);
        throw new Error('stop after the write');
      },
      update: async ({ data }: any) => {
        updated.push(data);
        return { ...context.plan, ...data };
      },
    },
    // Q-1: no money recorded yet, so the persona may change.
    weddingCost: { count: async () => 0, findFirst: async () => null },
    fundingSource: { count: async () => 0, findFirst: async () => null },
    $executeRaw: async () => 0,
  };
  const service = new WeddingPlansService(
    { $transaction: async (work: (client: any) => Promise<unknown>) => work(tx) } as any,
    collaborationPermissions({
      assertPlanManageableForUpdateInTransaction: async () => context,
      canViewMoney: () => true,
    }) as any,
    collaborationHistory({ recordForContextInTransaction: async () => ({}) }) as any,
    ...planningOwnerPorts,
  );
  return { service, created, updated };
}

test('D114: a plan is created with the choice only where it pays the mahr', async () => {
  const owner = { id: 'owner-1' } as any;
  const bride = planService();
  await assert.rejects(
    bride.service.create(owner, { title: 'عرس', persona: 'BRIDE', budgetIncludesMahr: true } as any),
    refusedWith('FINANCE_MAHR_BUDGET_PAYER_ONLY'),
  );
  assert.equal(bride.created.length, 0);
  const groom = planService();
  await groom.service
    .create(owner, { title: 'عرس', persona: 'GROOM', estimatedBudget: '7000000', budgetIncludesMahr: true } as any)
    .catch(() => null);
  assert.equal(groom.created[0]?.budgetIncludesMahr, true);
  const older = planService();
  await older.service.create(owner, { title: 'عرس', persona: 'GROOM' } as any).catch(() => null);
  assert.equal(older.created[0]?.budgetIncludesMahr, false);
});

test('D114: a persona that changes (before any money) takes the mahr back out of the budget', async () => {
  const plan = {
    id: 'plan-1',
    ownerUserId: 'owner-1',
    title: 'عرس',
    city: null,
    location: null,
    weddingDate: null,
    priorities: [],
    estimatedBudget: d(7_000_000),
    budgetIncludesMahr: true,
    currency: 'YER',
    onboardingPath: null,
    persona: 'GROOM',
    onboardingCompletedAt: null,
    status: 'PLANNING',
    createdAt: new Date(0),
    updatedAt: new Date(0),
  };
  const context = { plan, isOwner: true, sharedMember: null };
  const owner = { id: 'owner-1' } as any;
  const changed = planService(context);
  const response = await changed.service.update(owner, 'plan-1', { persona: 'BRIDE' } as any);
  assert.equal(changed.updated[0]?.budgetIncludesMahr, false);
  assert.equal(response.budgetIncludesMahr, false);
  const same = planService(context);
  const kept = await same.service.update(owner, 'plan-1', { title: 'عرسنا', persona: 'GROOM' } as any);
  assert.equal('budgetIncludesMahr' in (same.updated[0] ?? {}), false);
  assert.equal(kept.budgetIncludesMahr, true);
});
