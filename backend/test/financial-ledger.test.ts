import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

const read = (path: string) => readFileSync(join(process.cwd(), path), 'utf8');

test('financial installment payments and reversals are unique at the database layer', () => {
  const schema = read('prisma/schema.prisma');
  const payment = schema.match(/model FinancialPaymentRecord \{[\s\S]*?\n\}/)?.[0] ?? '';
  assert.match(payment, /financialInstallmentId\s+String\?\s+@unique/);
  assert.match(payment, /reversalOfId\s+String\?\s+@unique/);
  assert.match(payment, /entryType\s+FinancialPaymentRecordType/);

  const migration = read(
    'prisma/migrations/20260710143000_immutable_financial_ledger/migration.sql',
  );
  assert.match(migration, /FinancialPaymentRecord_financialInstallmentId_key/);
  assert.match(migration, /FinancialPaymentRecord_reversalOfId_key/);
  assert.match(migration, /FinancialPaymentRecord_reversalOfId_fkey/);
  assert.match(migration, /FinancialPaymentRecord_reversal_type/);
});

test('primary installment pay locks the installment before reading its state', () => {
  const service = read(
    'src/financial-commitments/financial-commitments.service.ts',
  );
  const payMethod = service.slice(
    service.indexOf('async payInstallment('),
    service.indexOf('async removeInstallment('),
  );
  assert.ok(payMethod.indexOf('lockInstallment(tx, id)') >= 0);
  assert.ok(
    payMethod.indexOf('lockInstallment(tx, id)') <
      payMethod.indexOf('financialInstallment.findUniqueOrThrow'),
  );
  assert.match(payMethod, /financialInstallmentId: current\.id/);
});

test('legacy finance bridge appends ledger entries without mutating payment history', () => {
  const bridge = read('src/common/finance/legacy-finance-bridge.ts');
  assert.doesNotMatch(
    bridge,
    /financialPaymentRecord\.(?:delete|deleteMany|update|updateMany|upsert)\(/,
  );
  assert.match(bridge, /appendLedgerToDesiredBalance/);
  assert.match(bridge, /FinancialPaymentRecordType\.REVERSAL/);
});

test('payment removal creates a reversal row and never deletes the original', () => {
  const service = read(
    'src/financial-commitments/financial-commitments.service.ts',
  );
  const reversal = service.slice(
    service.indexOf('async removePaymentRecord('),
    service.indexOf('async createInstallment('),
  );
  assert.match(reversal, /entryType: FinancialPaymentRecordType\.REVERSAL/);
  assert.match(reversal, /reversalOfId: current\.id/);
  assert.doesNotMatch(reversal, /financialPaymentRecord\.delete/);
});

test('balance-changing updates and destructive routes acquire row locks', () => {
  const commitments = read(
    'src/financial-commitments/financial-commitments.service.ts',
  );
  const commitmentUpdate = commitments.slice(
    commitments.indexOf('async update('),
    commitments.indexOf('async remove('),
  );
  assert.match(commitmentUpdate, /lockCommitment\(tx, id\)/);
  assert.ok(
    commitmentUpdate.indexOf('lockCommitment(tx, id)') <
      commitmentUpdate.indexOf('assertPaidDoesNotExceedTotal'),
  );

  const removeInstallment = commitments.slice(
    commitments.indexOf('async removeInstallment('),
    commitments.indexOf('private async findCommitmentOrThrow'),
  );
  assert.match(removeInstallment, /lockInstallment\(tx, id\)/);
  assert.match(removeInstallment, /financialPaymentRecord\.count/);

  const debts = read('src/debts/debts.service.ts');
  assert.match(debts, /lockDebtInstallments\(tx, id\)/);
  assert.match(debts, /lockDebt\(tx, id\)/);

  const installments = read('src/installments/installments.service.ts');
  assert.match(
    installments,
    /installment payment cannot exceed the remaining debt balance/,
  );
});
