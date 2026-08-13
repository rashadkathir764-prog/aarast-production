import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  Money,
  optionalMoneyAmount,
  requiredMoneyAmount,
} from '../src/shared-kernel/money/money';

const invalidMessage = (field: string) =>
  `${field} must be a non-negative amount with at most 12 digits and 2 decimal places`;

function assertInvalid(
  operation: () => unknown,
  field: string,
): void {
  assert.throws(operation, (error: unknown) => {
    assert.ok(error instanceof BadRequestException);
    assert.equal(error.message, invalidMessage(field));
    return true;
  });
}

test('required money preserves every current valid serialized form', () => {
  const cases: Array<[unknown, string]> = [
    ['0', '0'],
    ['00', '00'],
    ['1', '1'],
    ['1.2', '1.2'],
    ['1.20', '1.20'],
    ['999999999999.99', '999999999999.99'],
    [' 1.20 ', '1.20'],
    [0, '0'],
    [1, '1'],
    [1.2, '1.2'],
  ];

  for (const [value, expected] of cases) {
    assert.equal(requiredMoneyAmount(value, 'amount'), expected);
    assert.equal(Money.required(value, 'amount').toString(), expected);
  }
});

test('required money rejects current invalid types with the exact field error', () => {
  for (const value of [undefined, null, true, false, {}, [], Symbol('money')]) {
    assertInvalid(() => requiredMoneyAmount(value, 'total'), 'total');
    assertInvalid(() => Money.required(value, 'total'), 'total');
  }
});

test('required money rejects every invalid grammar boundary with the exact error', () => {
  const invalidValues = [
    '',
    '   ',
    '-1',
    -1,
    '1e3',
    1e21,
    '1,000',
    '1000000000000',
    '1.001',
    '+1',
    '.5',
    '1.',
    '1 0',
    Number.NaN,
    Number.POSITIVE_INFINITY,
  ];

  for (const value of invalidValues) {
    assertInvalid(() => requiredMoneyAmount(value, 'price'), 'price');
    assertInvalid(() => Money.required(value, 'price'), 'price');
  }
});

test('optional money returns null for absent and blank inputs without constructing Money', () => {
  for (const value of [undefined, null, '', ' ', '\t\r\n']) {
    assert.equal(optionalMoneyAmount(value, 'amount'), null);
    assert.equal(Money.optional(value, 'amount'), null);
  }
  assert.equal(optionalMoneyAmount(' 1.20 ', 'amount'), '1.20');
  assert.equal(Money.optional(' 1.20 ', 'amount')?.toString(), '1.20');
  assertInvalid(() => optionalMoneyAmount(false, 'amount'), 'amount');
});

test('Money exposes an exact Prisma Decimal while retaining input representation', () => {
  const money = Money.required(' 001.20 ', 'amount');
  const decimal = money.toDecimal();
  assert.ok(decimal instanceof Prisma.Decimal);
  assert.equal(decimal.equals(new Prisma.Decimal('1.20')), true);
  assert.equal(money.toString(), '001.20');
});

test('Money comparison returns exactly minus one zero or one and equality is decimal', () => {
  const one = Money.required('1.00', 'amount');
  const oneAlternate = Money.required('01', 'amount');
  const two = Money.required('2', 'amount');

  assert.equal(one.compare(two), -1);
  assert.equal(two.compare(one), 1);
  assert.equal(one.compare(oneAlternate), 0);
  assert.equal(one.equals(oneAlternate), true);
  assert.equal(one.equals(two), false);
});

test('Money addition and subtraction use exact decimal arithmetic', () => {
  const first = Money.required('0.10', 'amount');
  const second = Money.required('0.20', 'amount');
  assert.equal(first.add(second, 'total').toString(), '0.3');

  const total = Money.required('100.00', 'amount');
  const paid = Money.required('33.33', 'amount');
  assert.equal(total.subtract(paid, 'remaining').toString(), '66.67');
});

test('Money rejects negative subtraction with the exact result field error', () => {
  const smaller = Money.required('1', 'amount');
  const larger = Money.required('2', 'amount');
  assertInvalid(() => smaller.subtract(larger, 'remaining'), 'remaining');
});

test('Money rejects numeric(14,2) arithmetic overflow with the exact result field error', () => {
  const maximum = Money.required('999999999999.99', 'amount');
  const cent = Money.required('0.01', 'amount');
  assertInvalid(() => maximum.add(cent, 'total'), 'total');
});
