import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { test } from 'node:test';
import { Prisma } from '@prisma/client';
import {
  allocationWithinBudgetViolation,
  budgetAllocationViolation,
} from '../src/modules/finance/domain/budget-allocation-policy';
import {
  scheduleAmountViolation,
  scheduledPaymentViolation,
  schedulesToCancelOnStatus,
} from '../src/modules/finance/domain/payment-schedule-policy';
import {
  costCancellationViolation,
  costDeletionViolation,
  deriveCostStatus,
  initialPaymentViolation,
  payableViolation,
  paymentAmountViolation,
  positiveAmountViolation,
  reversalViolation,
  statusAfterReversal,
  totalAmountViolation,
} from '../src/modules/finance/domain/wedding-cost-aggregate';
import {
  conflict as domainConflict,
  invalid as domainInvalid,
} from '../src/modules/finance/domain/finance-violation';
import { fundingSourceDeletionViolation } from '../src/modules/finance/domain/funding-policy';
import { raiseFinanceViolation } from '../src/modules/finance/internal/finance-violation.http';

// O3 / R11 target item 4: the money invariants live in Finance's pure
// domain. Each policy returns the violation the request would commit (the
// application maps it to its transport error) or the value it derives.

const d = (value: string | number) => new Prisma.Decimal(value);
// The rule's English message and kind; its code and Arabic wording (G22)
// come from the one wording table, checked whole below.
const invalid = (message: string) => domainInvalid(message);
const conflict = (message: string) => domainConflict(message);

test('WeddingCostAggregate: positive amounts and the paid <= total invariant', () => {
  assert.equal(positiveAmountViolation(d('0.01'), 'amount'), null);
  assert.deepEqual(positiveAmountViolation(d(0), 'amount'), invalid('amount must be greater than zero'));
  assert.deepEqual(positiveAmountViolation(d(-5), 'totalAmount'), invalid('totalAmount must be greater than zero'));

  assert.equal(initialPaymentViolation(d(100), d(100)), null);
  assert.deepEqual(initialPaymentViolation(d(101), d(100)), invalid('initialPaymentAmount cannot exceed totalAmount'));
  assert.equal(totalAmountViolation(d(100), d(100)), null);
  assert.deepEqual(totalAmountViolation(d(99), d(100)), invalid('totalAmount cannot be less than paidAmount'));
  assert.equal(paymentAmountViolation(d(40), d(100), d(60)), null);
  assert.deepEqual(
    paymentAmountViolation(d('40.01'), d(100), d(60)),
    invalid('Payment amount cannot exceed the remaining cost'),
  );
});

test('WeddingCostAggregate: status derivation and payability', () => {
  assert.equal(deriveCostStatus(d(100), d(0)), 'OPEN');
  assert.equal(deriveCostStatus(d(100), d('0.01')), 'PARTIALLY_PAID');
  assert.equal(deriveCostStatus(d(100), d(100)), 'PAID');
  assert.equal(deriveCostStatus(d(100), d(120)), 'PAID');

  assert.equal(payableViolation('OPEN'), null);
  assert.equal(payableViolation('PARTIALLY_PAID'), null);
  assert.deepEqual(payableViolation('CANCELLED'), conflict('Cancelled costs cannot receive payments'));
  assert.deepEqual(payableViolation('PAID'), conflict('Cost is already fully paid'));
});

// RA-BE-130 (D107): an expense is money paid in full the day it is recorded.
// Taking its payment back used to leave it OPEN with its whole amount owed:
// it entered «عليك من العرس» with no date, and recording it again counted it
// twice. The phone itself advises the reversal to correct an expense.
test('WeddingCostAggregate: taking an expense\'s payment back takes the expense back', () => {
  assert.equal(statusAfterReversal('EXPENSE', d(50_000), d(0)), 'CANCELLED');
  // An agreement owes again, as before.
  assert.equal(statusAfterReversal('AGREEMENT', d(50_000), d(0)), 'OPEN');
  assert.equal(statusAfterReversal('AGREEMENT', d(50_000), d(20_000)), 'PARTIALLY_PAID');
  // An expense with something still standing against it is not cancelled
  // from under that payment.
  assert.equal(statusAfterReversal('EXPENSE', d(50_000), d(50_000)), 'PAID');
  assert.equal(statusAfterReversal('EXPENSE', d(50_000), d(10_000)), 'PARTIALLY_PAID');
});

test('WeddingCostAggregate: one reversal per payment, and ledger-backed deletion/cancellation', () => {
  const payment = { entryType: 'PAYMENT' as const, reversed: false, amount: d(30) };
  assert.equal(reversalViolation(payment, d(30)), null);
  assert.deepEqual(
    reversalViolation({ ...payment, entryType: 'REVERSAL' }, d(30)),
    conflict('A reversal entry cannot be reversed'),
  );
  assert.deepEqual(
    reversalViolation({ ...payment, reversed: true }, d(30)),
    conflict('Payment has already been reversed'),
  );
  assert.deepEqual(reversalViolation(payment, d(29)), conflict('Payment ledger is inconsistent'));

  assert.equal(costDeletionViolation(0, d(0)), null);
  assert.deepEqual(costDeletionViolation(1, d(0)), conflict('A cost with payment history cannot be deleted'));
  assert.deepEqual(costDeletionViolation(0, d(5)), conflict('A cost with payment history cannot be deleted'));
  assert.equal(costCancellationViolation(d(0)), null);
  assert.deepEqual(
    costCancellationViolation(d(5)),
    conflict('Reverse the active payments before cancelling this cost'),
  );
});

test('PaymentSchedulePolicy: independent cap against the outstanding amount; full payment cancels pending schedules', () => {
  // Each schedule is capped by the cost's outstanding amount alone: other
  // pending schedules reserve nothing.
  assert.equal(scheduleAmountViolation(d(70), d(100), d(30)), null);
  assert.deepEqual(
    scheduleAmountViolation(d(71), d(100), d(30)),
    invalid('Payment schedule amount cannot exceed the remaining cost'),
  );
  assert.equal(scheduledPaymentViolation(d(70), d(100), d(30)), null);
  assert.deepEqual(
    scheduledPaymentViolation(d(71), d(100), d(30)),
    invalid('Scheduled payment exceeds the remaining cost'),
  );
  assert.equal(schedulesToCancelOnStatus('PAID'), true);
  assert.equal(schedulesToCancelOnStatus('PARTIALLY_PAID'), false);
  assert.equal(schedulesToCancelOnStatus('OPEN'), false);
});

test('BudgetAllocationPolicy: allocations never substitute the general budget', () => {
  assert.equal(budgetAllocationViolation(null, d(0)), null);
  assert.deepEqual(
    budgetAllocationViolation(null, d(1)),
    invalid('Set the general budget before allocating money to categories'),
  );
  assert.equal(budgetAllocationViolation(d(100), d(100)), null);
  assert.deepEqual(
    budgetAllocationViolation(d(100), d('100.01')),
    invalid('Category allocations cannot exceed the general budget'),
  );
  // A single category may be allocated before a general budget exists; it
  // may never exceed one that does.
  assert.equal(allocationWithinBudgetViolation(null, d(50)), null);
  assert.equal(allocationWithinBudgetViolation(d(100), d(100)), null);
  assert.deepEqual(
    allocationWithinBudgetViolation(d(100), d(101)),
    invalid('Category allocations cannot exceed the general budget'),
  );
});

test('the Finance domain is pure: no framework, no runtime Prisma, no persistence', () => {
  const domain = path.resolve(__dirname, '../src/modules/finance/domain');
  const files = readdirSync(domain).filter((name) => name.endsWith('.ts'));
  assert.ok(files.length >= 5, files.join(', '));
  for (const name of files) {
    const source = readFileSync(path.join(domain, name), 'utf8');
    const imports = [...source.matchAll(/^import\s+(type\s+)?[^;]*?from\s+['"]([^'"]+)['"]/gms)];
    for (const [, typeOnly, specifier] of imports) {
      assert.doesNotMatch(specifier, /^@nestjs\//u, `${name} imports ${specifier}`);
      assert.doesNotMatch(specifier, /platform\/database|prisma\.service/u, `${name} imports ${specifier}`);
      if (specifier === '@prisma/client') {
        assert.ok(typeOnly, `${name} must import @prisma/client for types only`);
      }
      assert.ok(
        specifier.startsWith('./') || specifier === '@prisma/client',
        `${name} imports ${specifier} outside the Finance domain`,
      );
    }
  }
});

test('G22: every money rule a person can hit has a code and an Arabic reason', () => {
  const domainDir = path.join(__dirname, '..', 'src', 'modules', 'finance', 'domain');
  const servicePaths = [
    path.join(__dirname, '..', 'src', 'wedding-costs', 'wedding-costs.service.ts'),
    path.join(__dirname, '..', 'src', 'money', 'money-budget.service.ts'),
  ];
  const sources = [
    ...readdirSync(domainDir)
      .filter((name) => name.endsWith('.ts') && name !== 'finance-violation.ts')
      .map((name) => readFileSync(path.join(domainDir, name), 'utf8')),
    ...servicePaths.map((file) => readFileSync(file, 'utf8')),
  ];
  const messages = sources.flatMap((source) =>
    [...source.matchAll(/(?:invalid|conflict|financeConflict)\(\s*(['"])((?:(?!\1).)+)\1/g)].map(
      (match) => match[2],
    ),
  );
  assert.ok(messages.length >= 30, `found ${messages.length}`);
  for (const message of messages) {
    const violation = domainInvalid(message);
    assert.notEqual(violation.code, 'FINANCE_RULE', message);
    assert.match(violation.userMessage, /[\u0600-\u06FF]/, message);
  }
  assert.equal(domainInvalid('amount must be greater than zero').code, 'FINANCE_AMOUNT_NOT_POSITIVE');
});

test('G22: the HTTP error carries the code, the Arabic reason and the rule', () => {
  assert.throws(
    () => raiseFinanceViolation(domainConflict('Cost is already fully paid')),
    (error: any) => {
      const body = error.getResponse();
      return (
        error.getStatus() === 409 &&
        body.code === 'FINANCE_COST_FULLY_PAID' &&
        body.message === 'الاتفاق مدفوع كامل.' &&
        body.detail === 'Cost is already fully paid'
      );
    },
  );
});

test('G16: a source with a paid repayment is not deleted; planned ones go with it', () => {
  assert.equal(fundingSourceDeletionViolation([]), null);
  assert.equal(fundingSourceDeletionViolation([{ status: 'PLANNED' }, { status: 'CANCELLED' }]), null);
  assert.deepEqual(
    fundingSourceDeletionViolation([{ status: 'PLANNED' }, { status: 'PAID' }]),
    domainConflict('A funding source with paid repayments cannot be deleted'),
  );
});
