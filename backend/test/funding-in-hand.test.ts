import assert from 'node:assert/strict';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import { summarizeFunding } from '../src/modules/finance/infrastructure/money-picture';

// «معك» (D59, D104): what was received, less what the owner's own money
// paid, less what he repaid on loans; never below zero (RA-BE-17: an owner
// who paid more than he recorded as received, with money from outside the
// app, read «معك −500,000»). What he lacks is the coverage's (D103), tested
// in money-tab-rules.

const d = (value: number) => new Prisma.Decimal(value);
const today = new Date('2026-11-07T00:00:00.000Z');

function source(
  kind: 'SAVINGS' | 'LOAN',
  amount: number,
  repaid: Array<{ amount: number; status: 'PAID' | 'PLANNED' | 'CANCELLED' }> = [],
) {
  return {
    id: `${kind}-${amount}`,
    weddingPlanId: 'plan-1',
    kind,
    sourceName: kind === 'LOAN' ? 'خالي أحمد' : 'مدخراتي',
    sourcePhone: null,
    amount: d(amount),
    status: 'RECEIVED',
    receivedAt: null,
    expectedAt: null,
    note: null,
    contributorName: null,
    createdAt: today,
    updatedAt: today,
    repayments: repaid.map((repayment, index) => ({
      id: `r-${index}`,
      fundingSourceId: `${kind}-${amount}`,
      amount: d(repayment.amount),
      dueDate: today,
      paidAt: repayment.status === 'PAID' ? today : null,
      status: repayment.status,
      note: null,
      createdAt: today,
      updatedAt: today,
    })),
  } as unknown as Parameters<typeof summarizeFunding>[0][number];
}

test('RA-BE-17: an owner who paid more than he recorded has nothing in hand', () => {
  const funding = summarizeFunding([source('SAVINGS', 1_000_000)], {
    paidByOwner: d(1_500_000),
    today,
  });
  assert.equal(funding.availableCash, '0');
  assert.equal(funding.spent, '1500000');
});

test('D104: what he repaid on a loan leaves his hands', () => {
  const funding = summarizeFunding(
    [
      source('SAVINGS', 1_000_000),
      source('LOAN', 1_000_000, [
        { amount: 300_000, status: 'PAID' },
        { amount: 300_000, status: 'PLANNED' },
        { amount: 100_000, status: 'CANCELLED' },
      ]),
    ],
    { paidByOwner: d(500_000), today },
  );
  // 2,000,000 received − 500,000 paid − 300,000 repaid; what is planned or
  // cancelled has not left.
  assert.equal(funding.availableCash, '1200000');
  assert.equal(funding.loanRepaid, '300000');
  assert.equal(funding.loanOutstanding, '700000');
});

test('D104: repayments never take «معك» below zero', () => {
  const funding = summarizeFunding(
    [source('LOAN', 500_000, [{ amount: 400_000, status: 'PAID' }])],
    { paidByOwner: d(300_000), today },
  );
  assert.equal(funding.availableCash, '0');
});
