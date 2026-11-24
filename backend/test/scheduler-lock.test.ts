import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { IdempotencyCleanupScheduler } from '../src/platform/idempotency/idempotency-cleanup.scheduler';
import { metricsRegistry } from '../src/platform/observability/metrics';
import { PrismaService } from '../src/platform/database/prisma.service';

function idempotencyCleanupWithLock(locked: boolean) {
  let deleteCalls = 0;
  let deleteWhere: unknown;
  let countCalls = 0;
  const countWheres: unknown[] = [];
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
        countWheres.push(where);
        // The expired tombstones, then the reservations left open past an
        // hour (C-1).
        return countCalls === 1 ? 2 : 4;
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
    countWhere: (call = 0) => countWheres[call],
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
  // Changed on purpose (C-1): a second count measures the reservations left
  // open past an hour; the first is still the expired tombstones.
  assert.equal(fixture.countCalls(), 2);
  const countWhere = fixture.countWhere() as {
    completedAt?: null;
    expiresAt?: { lt?: unknown };
  };
  assert.equal(countWhere.completedAt, null);
  assert.ok(countWhere.expiresAt?.lt instanceof Date);

  const metric = metricsRegistry.getSingleMetric('aarast_idempotency_ambiguous_tombstones');
  assert.ok(metric);
  const value = await metric.get();
  assert.equal(value.values[0]?.value, 2);
});

test('C-1: idempotency cleanup measures reservations left open for more than an hour', async () => {
  const fixture = idempotencyCleanupWithLock(true);
  const before = Date.now();
  await fixture.scheduler.removeExpiredKeys();
  assert.equal(fixture.countCalls(), 2);
  const stalledWhere = fixture.countWhere(1) as {
    completedAt?: null;
    createdAt?: { lt?: unknown };
  };
  assert.equal(stalledWhere.completedAt, null);
  assert.ok(stalledWhere.createdAt?.lt instanceof Date);
  const cutoff = (stalledWhere.createdAt.lt as Date).getTime();
  assert.ok(cutoff <= before - 60 * 60 * 1_000 + 1_000);
  assert.ok(cutoff >= before - 60 * 60 * 1_000 - 1_000);

  const metric = metricsRegistry.getSingleMetric(
    'aarast_idempotency_stalled_reservations',
  );
  assert.ok(metric, 'the gauge the alert reads is registered');
  const value = await metric.get();
  assert.equal(value.values[0]?.value, 4);
});

test('scheduled jobs use distinct PostgreSQL advisory lock namespaces', () => {
  const schedulerSources = [
    'src/platform/idempotency/idempotency-cleanup.scheduler.ts',
    'src/modules/identity/infrastructure/auth-cleanup.repository.ts',
    'src/notifications/notifications.service.ts',
    'src/modules/media/infrastructure/media-upload-ticket.service.ts',
    'src/platform/outbox/outbox-cleanup.scheduler.ts',
  ].map((path) => readFileSync(join(process.cwd(), path), 'utf8'));
  const lockKeys = schedulerSources.flatMap((source) =>
    [...source.matchAll(/pg_try_advisory_xact_lock\((\d+),\s*(\d+)\)/g)].map(
      (match) => `${match[1]}:${match[2]}`,
    ),
  );

  assert.ok(lockKeys.length >= schedulerSources.length);
  assert.equal(
    new Set(lockKeys).size,
    lockKeys.length,
    `duplicate advisory scheduler lock: ${lockKeys.join(', ')}`,
  );
  for (const [scheduler, delegate] of [
    ['login-throttle-cleanup.scheduler.ts', 'removeExpiredLoginThrottleWindows'],
    ['otp-dispatch-quota-cleanup.scheduler.ts', 'removeExpiredOtpQuotaWindows'],
    ['auth-challenge-cleanup.scheduler.ts', 'removeExpiredAuthChallenges'],
  ]) {
    const source = readFileSync(
      join(process.cwd(), 'src/modules/identity/internal/auth', scheduler),
      'utf8',
    );
    assert.match(source, new RegExp(`${delegate}\\(\\s*this\\.prisma`));
  }
});
