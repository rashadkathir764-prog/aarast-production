import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ConflictException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  mahrFundingViolation,
  mahrItemMoveViolation,
} from '../src/modules/finance/domain/mahr-policy';
import { paidFromOwnerMoney } from '../src/modules/finance/domain/payer-policy';
import { expectedFundingReminder } from '../src/modules/finance/domain/funding-policy';
import { FinancePortService } from '../src/modules/finance/infrastructure/finance-port.service';
import { recordMahrInTransaction } from '../src/modules/finance/infrastructure/mahr.repository';
import { readMoneyPicture } from '../src/modules/finance/infrastructure/money-picture';

// The B5 review (D59): one money read for every screen and the assistant,
// whose money paid, the mahr's boundaries and recording it again.

const d = (value: string | number) => new Prisma.Decimal(value);
const day = (iso: string) => new Date(`${iso}T00:00:00.000Z`);

/** The walk's groom plan: 7 million budget, the father pays the lunch and the hall. */
function groomPlanTx(sources: Array<Record<string, unknown>>) {
  const categories = [
    { id: 'mahr', name: 'المهر', kind: 'MAHR', allocatedAmount: null },
    { id: 'suit', name: 'بدلة العريس', kind: 'WEDDING', allocatedAmount: null },
    { id: 'lunch', name: 'الغداء', kind: 'WEDDING', allocatedAmount: null },
    { id: 'hosp', name: 'الضيافة', kind: 'WEDDING', allocatedAmount: null },
    { id: 'hall', name: 'القاعة', kind: 'WEDDING', allocatedAmount: d(2_500_000) },
  ];
  const cost = (id: string, total: number, payer: string | null, payerName: string | null = null) => ({
    id,
    budgetCategoryId: id,
    totalAmount: d(total),
    title: id,
    payer,
    payerName,
  });
  const costs = [
    cost('mahr', 3_000_000, 'GROOM'),
    cost('suit', 300_000, 'GROOM'),
    cost('lunch', 1_000_000, 'FAMILY', 'الوالد'),
    cost('hosp', 1_600_000, null),
    cost('hall', 2_000_000, 'FAMILY', 'الوالد'),
  ];
  const payment = (weddingCostId: string, amount: number) => ({
    weddingCostId,
    amount: d(amount),
    entryType: 'PAYMENT',
  });
  return {
    budgetCategory: { findMany: async () => categories },
    weddingCost: {
      // The private-cost pre-filter finds none.
      findMany: async ({ where }: any) => (where.privateToUserId ? [] : costs),
    },
    costPayment: {
      findMany: async () => [
        payment('mahr', 2_000_000),
        payment('suit', 200_000),
        payment('lunch', 800_000),
        payment('hosp', 1_100_000),
        payment('hall', 500_000),
      ],
    },
    paymentSchedule: { findMany: async () => [] },
    fundingSource: { findMany: async () => sources },
  } as unknown as Prisma.TransactionClient;
}

const source = (
  kind: string,
  amount: number,
  status: 'RECEIVED' | 'PLEDGED',
  expectedAt: Date | null = null,
) => ({
  id: `${kind}-${amount}`,
  kind,
  sourceName: kind,
  amount: d(amount),
  status,
  expectedAt,
  repayments: [],
});

const groomQuery = {
  weddingPlanId: 'plan-1',
  persona: 'GROOM',
  totalBudget: d(7_000_000),
  scope: null,
  readerUserId: 'owner-1',
  fundingVisible: true,
  now: new Date('2026-10-25T09:00:00.000Z'),
};

test('D59: whose money paid follows the agreement payer and the plan', () => {
  // The groom's plan: his own, unnamed and shared agreements are his money.
  assert.equal(paidFromOwnerMoney('GROOM', 'GROOM'), true);
  assert.equal(paidFromOwnerMoney(null, 'GROOM'), true);
  assert.equal(paidFromOwnerMoney('SHARED', 'GROOM'), true);
  // The bride, the family or anyone else pays for him.
  assert.equal(paidFromOwnerMoney('BRIDE', 'GROOM'), false);
  assert.equal(paidFromOwnerMoney('FAMILY', 'GROOM'), false);
  assert.equal(paidFromOwnerMoney('OTHER', 'GROOM'), false);
  // The bride's plan is the mirror.
  assert.equal(paidFromOwnerMoney('BRIDE', 'BRIDE'), true);
  assert.equal(paidFromOwnerMoney('GROOM', 'BRIDE'), false);
  // A helper's plan: neither partner is its owner.
  assert.equal(paidFromOwnerMoney('GROOM', 'HELPER'), false);
});

test('D59: what the father paid never leaves the groom\'s hands; agreements and what is left count every payment', async () => {
  const picture = await readMoneyPicture(
    groomPlanTx([
      source('SAVINGS', 4_500_000, 'RECEIVED'),
      source('FAMILY_SUPPORT', 2_400_000, 'RECEIVED'),
      source('LOAN', 600_000, 'RECEIVED'),
      // Promised for 20 October, five days ago: «متأخر».
      source('OTHER', 1_200_000, 'PLEDGED', day('2026-10-19')),
    ]),
    groomQuery,
  );
  // Every agreement, the mahr's included, and every payment.
  assert.equal(picture.costs.total, '7900000');
  assert.equal(picture.costs.paid, '4600000');
  assert.equal(picture.costs.outstanding, '3300000');
  // Before D59 «معك» was 7.5 - 4.6 = 2.9 million: the father's 1.3 million
  // was taken out of the groom's money.
  assert.equal(picture.costs.paidByOwner, '3300000');
  assert.equal(picture.costs.paidByOthers, '1300000');
  assert.equal(picture.funding?.spent, '3300000');
  assert.equal(picture.funding?.availableCash, '4200000');
  assert.equal(picture.funding?.received, '7500000');
  assert.equal(picture.funding?.pledged, '1200000');
  assert.equal(picture.funding?.shortfall, null);
  assert.equal(picture.funding?.overduePledges, 1);
  // The wedding's budget: WEDDING items only.
  assert.deepEqual(
    {
      confirmedCost: picture.budget.confirmedCost,
      paid: picture.budget.paid,
      paidByOwner: picture.budget.paidByOwner,
      paidByOthers: picture.budget.paidByOthers,
      outstanding: picture.budget.outstanding,
      count: picture.budget.count,
      remaining: picture.budget.remaining,
    },
    {
      confirmedCost: '4900000',
      paid: '2600000',
      paidByOwner: '1300000',
      paidByOthers: '1300000',
      outstanding: '2300000',
      count: 4,
      remaining: '2100000',
    },
  );
  assert.deepEqual(
    picture.payers.map((group) => [group.payer, group.payerName, group.ownerMoney, group.paid]),
    [
      ['GROOM', null, true, '2200000'],
      ['FAMILY', 'الوالد', false, '1300000'],
      [null, null, true, '1100000'],
    ],
  );
  assert.equal(picture.mahr?.total, '3000000');
  assert.equal(picture.mahr?.settled, '2000000');
});

test('D59: the shortfall leaves out what others paid; paid, in hand, promised and short make up every agreement', async () => {
  const picture = await readMoneyPicture(
    groomPlanTx([source('SAVINGS', 3_000_000, 'RECEIVED'), source('OTHER', 500_000, 'PLEDGED')]),
    groomQuery,
  );
  // 7.9 agreed - 1.3 the father paid - 3.5 in and promised.
  assert.equal(picture.funding?.shortfall, '3100000');
  const parts = [
    picture.costs.paid,
    picture.funding?.availableCash,
    picture.funding?.pledged,
    picture.funding?.shortfall,
  ].reduce((sum, part) => sum.plus(part ?? 0), d(0));
  assert.equal(parts.toString(), picture.costs.total);
});

test('D59: an agreement never moves between the wedding items and the mahr item', () => {
  assert.equal(mahrItemMoveViolation('WEDDING', 'WEDDING'), null);
  assert.equal(mahrItemMoveViolation('MAHR', 'MAHR'), null);
  assert.equal(mahrItemMoveViolation('WEDDING', 'MAHR')?.kind, 'conflict');
  assert.equal(mahrItemMoveViolation('MAHR', 'WEDDING')?.kind, 'conflict');
});

test('D59: mahr funding is the bride plan\'s only, and a source keeps its side of the mahr', () => {
  const create = (planPersona: string | null) =>
    mahrFundingViolation({ planPersona, currentKind: null, nextKind: 'MAHR' });
  assert.equal(create('BRIDE'), null);
  assert.equal(create('GROOM')?.kind, 'invalid');
  assert.equal(create('HELPER')?.kind, 'invalid');
  assert.equal(create(null)?.kind, 'invalid');
  // Other money on any plan is untouched by the rule.
  assert.equal(
    mahrFundingViolation({ planPersona: 'GROOM', currentKind: null, nextKind: 'SAVINGS' }),
    null,
  );
  // The mahr's parts stay the mahr; other money never becomes it.
  assert.equal(
    mahrFundingViolation({ planPersona: 'BRIDE', currentKind: 'MAHR', nextKind: 'GIFT' })?.kind,
    'conflict',
  );
  assert.equal(
    mahrFundingViolation({ planPersona: 'BRIDE', currentKind: 'GIFT', nextKind: 'MAHR' })?.kind,
    'conflict',
  );
  assert.equal(
    mahrFundingViolation({ planPersona: 'BRIDE', currentKind: 'MAHR', nextKind: 'MAHR' }),
    null,
  );
});

/** The groom's money tables as the mahr recording reads and writes them. */
function mahrTx(state: {
  mahrItem: { id: string; live: number } | null;
  named: { id: string } | null;
}) {
  const writes: Array<[string, unknown]> = [];
  const tx = {
    budgetCategory: {
      findFirst: async () =>
        state.mahrItem
          ? { id: state.mahrItem.id, _count: { weddingCosts: state.mahrItem.live } }
          : null,
      findUnique: async () => state.named,
      update: async (args: any) => {
        writes.push(['budgetCategory.update', args]);
        return { id: args.where.id };
      },
      create: async (args: any) => {
        writes.push(['budgetCategory.create', args]);
        return { id: 'new-item' };
      },
    },
    weddingCost: {
      create: async (args: any) => {
        writes.push(['weddingCost.create', args]);
        return { id: 'agreement' };
      },
    },
  } as unknown as Prisma.TransactionClient;
  return { tx, writes };
}

const agreement = {
  total: d(3_000_000),
  settled: d(2_000_000),
  remainingDueAt: day('2026-11-15'),
};

test('D59: deleting the mahr agreement lets it be recorded again in the same item', async () => {
  // Before D59 the empty MAHR item alone answered 409 MAHR_ALREADY_RECORDED.
  const { tx, writes } = mahrTx({ mahrItem: { id: 'mahr-item', live: 0 }, named: null });
  await recordMahrInTransaction(tx, 'plan-1', 'PAYS', agreement, day('2026-10-25'));
  assert.deepEqual(
    writes.map(([name]) => name),
    ['weddingCost.create'],
  );
  assert.equal((writes[0][1] as any).data.budgetCategoryId, 'mahr-item');
  assert.equal((writes[0][1] as any).data.totalAmount.toString(), '3000000');
});

test('D59: a live mahr agreement is still recorded once', async () => {
  const { tx, writes } = mahrTx({ mahrItem: { id: 'mahr-item', live: 1 }, named: null });
  await assert.rejects(
    recordMahrInTransaction(tx, 'plan-1', 'PAYS', agreement, day('2026-10-25')),
    (error: unknown) =>
      error instanceof ConflictException &&
      (error.getResponse() as { code: string }).code === 'MAHR_ALREADY_RECORDED',
  );
  assert.deepEqual(writes, []);
});

test('D59: the plan\'s own «المهر» item becomes the MAHR item with its agreements', async () => {
  // Before D59 an item named «المهر» with an agreement refused the mahr.
  const { tx, writes } = mahrTx({ mahrItem: null, named: { id: 'user-item' } });
  await recordMahrInTransaction(tx, 'plan-1', 'PAYS', agreement, day('2026-10-25'));
  assert.deepEqual(writes[0], [
    'budgetCategory.update',
    {
      where: { id: 'user-item' },
      data: { kind: 'MAHR', allocatedAmount: null },
      select: { id: true },
    },
  ]);
  assert.equal(writes[1][0], 'weddingCost.create');
  assert.equal((writes[1][1] as any).data.budgetCategoryId, 'user-item');
});

test('D59: promised money is reminded the day before and on its day, Sana\'a time', () => {
  // The mahr's rest is due 15 November (stored as the day at 00:00 UTC);
  // «today» is the start of the day in Sana'a (21:00 UTC the evening before).
  const due = new Date('2026-11-15T00:00:00.000Z');
  const startOf = (iso: string) => new Date(`${iso}T21:00:00.000Z`);
  assert.equal(expectedFundingReminder(due, startOf('2026-11-12')), null);
  assert.equal(expectedFundingReminder(due, startOf('2026-11-13')), 'DAY_BEFORE');
  assert.equal(expectedFundingReminder(due, startOf('2026-11-14')), 'ON_THE_DAY');
  assert.equal(expectedFundingReminder(due, startOf('2026-11-15')), null);
});

test('D59: finance lists the plans\' promised money due by a day, the soonest first', async () => {
  const calls: unknown[] = [];
  const client = {
    fundingSource: {
      findMany: async (args: unknown) => {
        calls.push(args);
        return [
          {
            id: 'rest',
            weddingPlanId: 'plan-1',
            kind: 'MAHR',
            sourceName: 'باقي المهر',
            amount: d(1_000_000),
            expectedAt: day('2026-11-15'),
          },
        ];
      },
    },
  } as unknown as Prisma.TransactionClient;
  const finance = new FinancePortService();
  assert.deepEqual(
    await finance.listDueExpectedFunding(client, { weddingPlanIds: [], dueBefore: day('2026-11-16') }),
    [],
  );
  const due = await finance.listDueExpectedFunding(client, {
    weddingPlanIds: ['plan-1'],
    dueBefore: day('2026-11-16'),
  });
  assert.deepEqual(calls, [
    {
      where: {
        weddingPlanId: { in: ['plan-1'] },
        status: 'PLEDGED',
        expectedAt: { not: null, lte: day('2026-11-16') },
      },
      select: {
        id: true,
        weddingPlanId: true,
        kind: true,
        sourceName: true,
        amount: true,
        expectedAt: true,
      },
      orderBy: [{ expectedAt: 'asc' }, { id: 'asc' }],
    },
  ]);
  assert.equal(due[0].sourceName, 'باقي المهر');
  assert.equal(due[0].expectedAt.toISOString(), '2026-11-15T00:00:00.000Z');
});
