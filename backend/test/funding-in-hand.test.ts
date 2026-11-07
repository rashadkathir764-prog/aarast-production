import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import { summarizeFunding } from '../src/modules/finance/infrastructure/money-picture';

// RA-BE-17: «معك» was what the owner recorded as received less what his own
// money paid, with no floor, and «ناقصك» every agreement less what others
// paid less every source. An owner who paid more than he recorded as
// received (money from outside the app, not entered) read «معك −500,000»
// and «ناقصك 2,000,000» with 1,500,000 left to pay. D59's four parts (paid,
// in hand, promised, short) still make up every agreement.

const d = (value: number) => new Prisma.Decimal(value);
const today = new Date('2026-11-07T00:00:00.000Z');

function savings(amount: number, status: 'RECEIVED' | 'PLEDGED' = 'RECEIVED') {
  return {
    id: `savings-${status}-${amount}`,
    weddingPlanId: 'plan-1',
    kind: 'SAVINGS',
    sourceName: 'مدخراتي',
    sourcePhone: null,
    amount: d(amount),
    status,
    receivedAt: null,
    expectedAt: null,
    note: null,
    createdAt: today,
    updatedAt: today,
    repayments: [],
  } as unknown as Parameters<typeof summarizeFunding>[0][number];
}

test('an owner who paid more than he recorded has nothing in hand, and lacks only what is left', () => {
  const funding = summarizeFunding([savings(1_000_000)], {
    confirmedCost: d(3_000_000),
    paidByOwner: d(1_500_000),
    paidByOthers: d(0),
    today,
  });
  assert.equal(funding.availableCash, '0');
  assert.equal(funding.shortfall, '1500000');
  assert.equal(funding.spent, '1500000');
});

test('promised money still counts against what is left', () => {
  const funding = summarizeFunding([savings(1_000_000), savings(400_000, 'PLEDGED')], {
    confirmedCost: d(3_000_000),
    paidByOwner: d(1_500_000),
    paidByOthers: d(200_000),
    today,
  });
  // left: 3,000,000 − 1,500,000 − 200,000 = 1,300,000; in hand 0; promised 400,000
  assert.equal(funding.availableCash, '0');
  assert.equal(funding.shortfall, '900000');
});

test('while the owner holds money, the figures are as before', () => {
  const funding = summarizeFunding([savings(5_000_000)], {
    confirmedCost: d(6_000_000),
    paidByOwner: d(3_000_000),
    paidByOthers: d(400_000),
    today,
  });
  assert.equal(funding.availableCash, '2000000');
  // 6,000,000 − 400,000 − 5,000,000
  assert.equal(funding.shortfall, '600000');
});

test('the four parts make up every agreement', () => {
  const spent = { confirmedCost: d(3_000_000), paidByOwner: d(1_500_000), paidByOthers: d(0), today };
  const funding = summarizeFunding([savings(1_000_000)], spent);
  const parts = spent.paidByOwner
    .plus(spent.paidByOthers)
    .plus(funding.availableCash)
    .plus(funding.pledged)
    .plus(funding.shortfall ?? 0);
  assert.equal(parts.toString(), '3000000');
});
