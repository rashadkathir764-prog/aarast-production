import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ContributionEntityType, Prisma } from '@prisma/client';
import {
  buildContributionSnapshot,
  validateContributionSnapshot,
} from '../src/modules/collaboration/public/contribution-snapshot.builder';

// RA-BE-31: an amount became a string ("10000000") and was tested against
// the phone patterns, which match any whole number of eight digits or more.
// Every money write that records history threw «Sensitive contribution
// snapshot value»: the owner accepting an offer of 10,000,000 riyals or
// more (the snapshot is built before the owner is skipped), and every money
// write of a member on an agreement that size. An amount is a number, not
// contact data; text a person writes stays checked.

const cost = (totalAmount: string, title = 'القاعة') =>
  buildContributionSnapshot(ContributionEntityType.WEDDING_COST, {
    title,
    currency: 'YER',
    totalAmount: new Prisma.Decimal(totalAmount),
    paidAmount: new Prisma.Decimal('2500000'),
    amount: new Prisma.Decimal('750000000'),
  });

test('amounts of ten million and more go into the history', () => {
  for (const amount of ['10000000', '12500000', '750000000', '999999999999.99']) {
    const snapshot = cost(amount);
    assert.equal(snapshot.totalAmount, new Prisma.Decimal(amount).toString());
  }
});

test('a title that reads like a phone number is still kept out of the history', () => {
  const snapshot = cost('10000000', '777123456');
  assert.equal(snapshot.title, undefined);
  assert.equal(snapshot.totalAmount, '10000000');
});

test('a number that is not an amount, under an amount key, is still refused', () => {
  assert.throws(
    () => validateContributionSnapshot({ amount: '+967 777 123 456' }),
    /Sensitive contribution snapshot value/,
  );
  assert.throws(
    () => validateContributionSnapshot({ title: '777123456' }),
    /Sensitive contribution snapshot value/,
  );
});
