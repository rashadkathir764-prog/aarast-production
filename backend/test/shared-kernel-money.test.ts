import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import {
  Money,
  optionalMoneyAmount,
  requiredMoneyAmount,
  requiredSettlingAmount,
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
    assert.equal(Money.required(value, 'amount').toString(), expected);
  }
});

// D112 (Q-25), the owner's word: whole riyals everywhere. `Money` still
// holds what a column holds (old rows with a fraction, exact arithmetic);
// what a person sends is a whole amount. The phone's fields took whole
// amounts already; the server accepted two decimals from any other caller.
test('Q-25: an amount a person sends is whole; a fraction is refused by its own code', () => {
  const whole: Array<[unknown, string]> = [
    ['0', '0'],
    ['00', '00'],
    ['1', '1'],
    ['1.0', '1.0'],
    ['1.00', '1.00'],
    ['999999999999', '999999999999'],
    [' 1500000 ', '1500000'],
    [0, '0'],
    [1, '1'],
  ];
  for (const [value, expected] of whole) {
    assert.equal(requiredMoneyAmount(value, 'amount'), expected);
    assert.equal(optionalMoneyAmount(value, 'amount'), expected);
  }
  for (const value of ['1.2', '1.20', '0.5', '999999999999.99', 1.2, ' 400.01 ']) {
    for (const parse of [requiredMoneyAmount, optionalMoneyAmount]) {
      assert.throws(
        () => parse(value, 'amount'),
        (error: unknown) => {
          assert.ok(error instanceof BadRequestException);
          assert.deepEqual(error.getResponse(), {
            statusCode: 400,
            code: 'MONEY_AMOUNT_NOT_WHOLE',
            message: 'المبلغ رقم صحيح، بدون كسور.',
            field: 'amount',
          });
          return true;
        },
        String(value),
      );
    }
  }
});

// RA-BE-132: the one fraction a payment may carry is exactly what is still
// owed on an amount saved with a fraction before Q-25.
test('a settling amount takes a whole amount, or exactly the fraction owed', () => {
  const owed = new Prisma.Decimal('0.50');
  assert.equal(requiredSettlingAmount('0.50', 'amount', owed), '0.50');
  assert.equal(requiredSettlingAmount('0.5', 'amount', owed), '0.5');
  assert.equal(requiredSettlingAmount('7', 'amount', owed), '7');
  for (const value of ['0.25', '1.50']) {
    assert.throws(
      () => requiredSettlingAmount(value, 'amount', owed),
      (error: unknown) =>
        error instanceof BadRequestException &&
        (error.getResponse() as { code?: string }).code === 'MONEY_AMOUNT_NOT_WHOLE',
      value,
    );
  }
  assertInvalid(() => requiredSettlingAmount('0.505', 'amount', owed), 'amount');
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
  // Q-25: the input parser takes whole amounts; `Money` keeps the fraction.
  assert.equal(optionalMoneyAmount(' 1.00 ', 'amount'), '1.00');
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
