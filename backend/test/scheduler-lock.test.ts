import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { InstallmentsOverdueScheduler } from '../src/installments/installments-overdue.scheduler';
import { IdempotencyCleanupScheduler } from '../src/common/idempotency/idempotency-cleanup.scheduler';
import { metricsRegistry } from '../src/common/observability/metrics';
import { PrismaService } from '../src/prisma/prisma.service';

function schedulerWithLock(locked: boolean) {
  let updateCalls = 0;
  const transactionClient = {
    $queryRaw: async () => [{ locked }],
    installment: {
      updateMany: async () => {
        updateCalls += 1;
        return { count: 2 };
      },
    },
  };
  const prisma = {
    $transaction: async (operation: (tx: typeof transactionClient) => unknown) =>
      operation(transactionClient),
  } as unknown as PrismaService;
  return {
    scheduler: new InstallmentsOverdueScheduler(prisma),
    updateCalls: () => updateCalls,
  };
}

test('overdue scheduler skips work when another replica owns the lock', async () => {
  const fixture = schedulerWithLock(false);
  await fixture.scheduler.markOverdueInstallments();
  assert.equal(fixture.updateCalls(), 0);
});

test('overdue scheduler updates once while holding the transaction lock', async () => {
  const fixture = schedulerWithLock(true);
  await fixture.scheduler.markOverdueInstallments();
  assert.equal(fixture.updateCalls(), 1);
});

function idempotencyCleanupWithLock(locked: boolean) {
  let deleteCalls = 0;
  let deleteWhere: unknown;
  let countCalls = 0;
  let countWhere: unknown;
  const transactionClient = {
    $queryRaw: async () => [{ locked }],
    idempotencyKey: {
      deleteMany: async ({ where }: { where: unknown }) => {
        deleteCalls += 1;
        deleteWhere = where;
        return { count: 3 };
      },
      count: async ({ where }: { where: unknown }) => {
        countCalls += 1;
        countWhere = where;
        return 2;
      },
    },
  };
  const prisma = {
    $transaction: async (operation: (tx: typeof transactionClient) => unknown) =>
      operation(transactionClient),
  } as unknown as PrismaService;
  return {
    scheduler: new IdempotencyCleanupScheduler(prisma),
    deleteCalls: () => deleteCalls,
    deleteWhere: () => deleteWhere,
    countCalls: () => countCalls,
    countWhere: () => countWhere,
  };
}

test('idempotency cleanup skips work when another replica owns the lock', async () => {
  const fixture = idempotencyCleanupWithLock(false);
  await fixture.scheduler.removeExpiredKeys();
  assert.equal(fixture.deleteCalls(), 0);
  assert.equal(fixture.countCalls(), 0);
});

test('idempotency cleanup deletes only expired completed keys while holding the lock', async () => {
  const fixture = idempotencyCleanupWithLock(true);
  await fixture.scheduler.removeExpiredKeys();
  assert.equal(fixture.deleteCalls(), 1);
  const where = fixture.deleteWhere() as {
    completedAt?: { not?: null };
    expiresAt?: { lt?: unknown };
  };
  assert.deepEqual(where.completedAt, { not: null });
  assert.ok(where.expiresAt?.lt instanceof Date);
  assert.equal(fixture.countCalls(), 1);
  const countWhere = fixture.countWhere() as {
    completedAt?: null;
    expiresAt?: { lt?: unknown };
  };
  assert.equal(countWhere.completedAt, null);
  assert.ok(countWhere.expiresAt?.lt instanceof Date);

  const metric = metricsRegistry.getSingleMetric(
    'aarast_idempotency_ambiguous_tombstones',
  );
  assert.ok(metric);
  const value = await metric.get();
  assert.equal(value.values[0]?.value, 2);
});
