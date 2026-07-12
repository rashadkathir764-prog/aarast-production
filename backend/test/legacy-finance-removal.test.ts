import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

const backendRoot = join(__dirname, '..');

test('legacy debt and installment modules cannot return to the live backend', () => {
  const schema = readFileSync(join(backendRoot, 'prisma', 'schema.prisma'), 'utf8');
  const appModule = readFileSync(join(backendRoot, 'src', 'app.module.ts'), 'utf8');

  for (const forbiddenSchemaToken of [
    'model Debt ',
    'model Installment ',
    'legacyDebtId',
    'legacyInstallmentId',
    'legacyExpenseId',
    'canViewDebts',
    'MANUAL_DEBT',
  ]) {
    assert.equal(
      schema.includes(forbiddenSchemaToken),
      false,
      `Prisma schema must not contain ${forbiddenSchemaToken}`,
    );
  }

  for (const removedPath of [
    join(backendRoot, 'src', 'common', 'finance', 'legacy-finance-bridge.ts'),
    join(backendRoot, 'src', 'common', 'money', 'debt-balance.ts'),
  ]) {
    assert.equal(existsSync(removedPath), false, `${removedPath} must stay deleted`);
  }

  assert.equal(appModule.includes('DebtsModule'), false);
  assert.equal(appModule.includes('InstallmentsModule'), false);

  const packageJson = JSON.parse(
    readFileSync(join(backendRoot, 'package.json'), 'utf8'),
  ) as { scripts?: { build?: string } };
  assert.match(
    packageJson.scripts?.build ?? '',
    /^node scripts\/clean-dist\.cjs && tsc /,
    'backend build must clean dist before TypeScript emits new runtime files',
  );
  assert.equal(
    existsSync(join(backendRoot, 'scripts', 'clean-dist.cjs')),
    true,
    'safe dist cleaner must remain in the repository',
  );
});

test('terminal cleanup migration removes the last legacy payment bridge', () => {
  const migration = readFileSync(
    join(
      backendRoot,
      'prisma',
      'migrations',
      '20260711163000_remove_financial_payment_legacy_expense',
      'migration.sql',
    ),
    'utf8',
  );

  for (const requiredStatement of [
    'DROP INDEX IF EXISTS "FinancialPaymentRecord_legacyExpenseId_key"',
    'DROP COLUMN IF EXISTS "legacyExpenseId"',
  ]) {
    assert.equal(
      migration.includes(requiredStatement),
      true,
      `Terminal cleanup migration must contain ${requiredStatement}`,
    );
  }
});

test('destructive migration removes every live legacy finance artifact', () => {
  const migration = readFileSync(
    join(
      backendRoot,
      'prisma',
      'migrations',
      '20260711150000_remove_legacy_debt_system',
      'migration.sql',
    ),
    'utf8',
  );

  for (const requiredStatement of [
    'RAISE EXCEPTION \'Legacy Debt rows are not fully migrated\'',
    'RAISE EXCEPTION \'Legacy Installment rows are not fully migrated\'',
    'commitment."legacyDebtId" = debt."id"',
    'financial_installment."legacyInstallmentId" = installment."id"',
    'DROP TABLE IF EXISTS "Installment"',
    'DROP TABLE IF EXISTS "Debt"',
    'DROP TYPE IF EXISTS "DebtStatus"',
    'DROP COLUMN "legacyDebtId"',
    'DROP COLUMN "legacyInstallmentId"',
  ]) {
    assert.equal(
      migration.includes(requiredStatement),
      true,
      `Removal migration must contain ${requiredStatement}`,
    );
  }
});
