import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import { DebtStatus, Prisma } from '@prisma/client';
import { applyDebtPaymentDelta } from '../src/common/money/debt-balance';
import {
  optionalMoneyAmount,
  requiredMoneyAmount,
} from '../src/common/validation/money';

const d = (value: string | number) => new Prisma.Decimal(value);

test('payment delta moves debt through OPEN -> PARTIALLY_PAID -> PAID', () => {
  const partial = applyDebtPaymentDelta(d('100000'), d(0), d('40000'));
  assert.equal(partial.status, DebtStatus.PARTIALLY_PAID);
  assert.equal(partial.paidAmount.toString(), '40000');

  const paid = applyDebtPaymentDelta(d('100000'), d('40000'), d('60000'));
  assert.equal(paid.status, DebtStatus.PAID);
  assert.equal(paid.paidAmount.toString(), '100000');
});

test('un-pay and delete compensation never drops the balance below zero', () => {
  const result = applyDebtPaymentDelta(d('100000'), d('30000'), d('-50000'));
  assert.equal(result.paidAmount.toString(), '0');
  assert.equal(result.status, DebtStatus.OPEN);
});

test('overpayment is clamped at the debt total', () => {
  const result = applyDebtPaymentDelta(d('100000'), d('90000'), d('40000'));
  assert.equal(result.paidAmount.toString(), '100000');
  assert.equal(result.status, DebtStatus.PAID);
});

test('decimal amounts keep exact cents — no float drift', () => {
  // 0.1 + 0.2 style drift would break this with Number arithmetic.
  const result = applyDebtPaymentDelta(d('1000.30'), d('1000.10'), d('0.20'));
  assert.equal(result.paidAmount.toString(), '1000.3');
  assert.equal(result.status, DebtStatus.PAID);
});

test('zero-total debt never reports PAID', () => {
  const result = applyDebtPaymentDelta(d(0), d(0), d('500'));
  assert.equal(result.paidAmount.toString(), '0');
  assert.equal(result.status, DebtStatus.OPEN);
});

test('money validation accepts sane amounts', () => {
  assert.equal(requiredMoneyAmount('1500000', 'amount'), '1500000');
  assert.equal(requiredMoneyAmount('99.25', 'amount'), '99.25');
  assert.equal(requiredMoneyAmount(250, 'amount'), '250');
  assert.equal(optionalMoneyAmount(undefined, 'amount'), null);
});

test('money validation rejects overflow, extra decimals and garbage', () => {
  // 13+ integer digits used to overflow numeric(14,2) into a raw 500.
  assert.throws(
    () => requiredMoneyAmount('9999999999999', 'amount'),
    BadRequestException,
  );
  // >2 decimals used to be silently rounded by Postgres.
  assert.throws(() => requiredMoneyAmount('10.999', 'amount'), BadRequestException);
  assert.throws(() => requiredMoneyAmount('-5', 'amount'), BadRequestException);
  assert.throws(() => requiredMoneyAmount('abc', 'amount'), BadRequestException);
  assert.throws(() => requiredMoneyAmount('', 'amount'), BadRequestException);
});

test('wedding plan financial children cannot cascade-delete private data', () => {
  const schema = readFileSync(join(process.cwd(), 'prisma/schema.prisma'), 'utf8');
  for (const model of [
    'BudgetCategory',
    'Expense',
    'Debt',
    'WeddingTask',
    'SharedMember',
    'PlanInvite',
    'Guest',
    'GuestGroup',
    'PlanProviderLink',
  ]) {
    const block = schema.match(new RegExp(`model ${model} \\{[\\s\\S]*?\\n\\}`))?.[0];
    assert.ok(block, `missing ${model} model`);
    assert.match(block, /weddingPlan\s+WeddingPlan\??\s+@relation\([^\n]*onDelete: Restrict\)/);
  }
  const notification = schema.match(/model Notification \{[\s\S]*?\n\}/)?.[0];
  assert.ok(notification);
  assert.match(notification, /weddingPlan\s+WeddingPlan\?\s+@relation\([^\n]*onDelete: SetNull\)/);
});

test('money summary reports manage permission through PermissionService', () => {
  const service = readFileSync(
    join(process.cwd(), 'src/money/money-summary.service.ts'),
    'utf8',
  );
  assert.match(
    service,
    /const canManageFinancialRecords =\s*this\.permissions\.canManageFinancialRecords\(context\);/,
  );
  assert.doesNotMatch(
    service,
    /context\.sharedMember\?\.canManageFinancialRecords/,
  );
});
