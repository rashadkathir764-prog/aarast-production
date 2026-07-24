import assert from 'node:assert/strict';
import { join } from 'node:path';
import { test } from 'node:test';

const backendRoot = join(__dirname, '..');
const sourceGuard = require('../scripts/smoke/phase0-source-guard.js');
const cleanliness = require('../scripts/smoke/phase0-git-cleanliness.js');
const fixtures = require('./support/phase0-postgres-support.js');

test('official mutating commands reject chained, prefixed, suffixed, and piped runner bypasses', () => {
  const runner = 'node scripts/smoke/run-isolated-smoke.js auth-smoke.js';
  for (const command of [
    `node unsafe-db-write.js && ${runner}`,
    `${runner} && node unsafe-db-write.js`,
    `${runner} | node unsafe-db-write.js`,
    `DATABASE_URL=postgresql://example/aarast ${runner}`,
  ]) {
    assert.throws(
      () => sourceGuard.assertOfficialMutatingScriptsUseManagedRunner({
        'smoke:auth': command,
      }),
      /exact managed command|must use the exact managed command/i,
    );
  }
  assert.doesNotThrow(() => sourceGuard.assertOfficialMutatingScriptsUseManagedRunner({
    'smoke:auth': runner,
    'load:test': 'node scripts/smoke/run-isolated-smoke.js --load-test',
  }));
});

test('source guard inventories official TypeScript, ESM, and CommonJS smoke/load/admin sources', () => {
  assert.equal(typeof sourceGuard.collectGuardedSourceFiles, 'function');
  const files = sourceGuard.collectGuardedSourceFiles();
  assert.ok(files.some((file: string) => file.endsWith('account-deletion-smoke.ts')));
  assert.ok(files.some((file: string) => file.endsWith('admin-runtime-smoke.mjs')));
  assert.ok(files.some((file: string) => file.endsWith('openwa-otp-smoke.js')));
});

test('external OpenWA mutation has an exact command, explicit confirmation, and no database access', () => {
  assert.equal(typeof sourceGuard.assertExternalOpenwaSmokeContract, 'function');
  assert.doesNotThrow(() => sourceGuard.assertExternalOpenwaSmokeContract(
    'node scripts/smoke/openwa-otp-smoke.js',
    [
      "const requiredConfirmation = 'I_ACCEPT_REAL_WHATSAPP_SEND';",
      'if (process.env.OPENWA_SMOKE_CONFIRM !== requiredConfirmation) throw new Error();',
    ].join('\n'),
  ));
  assert.throws(
    () => sourceGuard.assertExternalOpenwaSmokeContract(
      'node scripts/smoke/openwa-otp-smoke.js && node unsafe.js',
      "const requiredConfirmation = 'I_ACCEPT_REAL_WHATSAPP_SEND';",
    ),
    /exact external command/i,
  );
  assert.throws(
    () => sourceGuard.assertExternalOpenwaSmokeContract(
      'node scripts/smoke/openwa-otp-smoke.js',
      [
        "const requiredConfirmation = 'I_ACCEPT_REAL_WHATSAPP_SEND';",
        'if (process.env.OPENWA_SMOKE_CONFIRM !== requiredConfirmation) throw new Error();',
        'const db = process.env.DATABASE_URL;',
      ].join('\n'),
    ),
    /database/i,
  );
});

test('fixture wrapper rejects an unmanaged environment and cleans in finally after callback failure', async () => {
  assert.equal(typeof fixtures.withFixture, 'function');
  await assert.rejects(
    fixtures.withFixture(
      async () => ({ cleanup: async () => {} }),
      async () => {},
      {},
    ),
    /not managed|managed smoke/i,
  );

  const events: string[] = [];
  await assert.rejects(
    fixtures.withFixture(
      async () => ({ cleanup: async () => { events.push('cleanup'); } }),
      async () => { events.push('callback'); throw new Error('expected callback failure'); },
      managedEnvironment(),
    ),
    /expected callback failure/,
  );
  assert.deepEqual(events, ['callback', 'cleanup']);
});

test('quote fixture cleanup deletes operation outputs before fixture roots in one transaction', async () => {
  assert.equal(typeof fixtures.cleanupQuoteFixtureGraph, 'function');
  const calls: string[] = [];
  const database = new Proxy({}, {
    get(_target, model: string) {
      if (model === '$executeRaw') {
        return async () => { calls.push('$executeRaw'); };
      }

      return {
        findMany: async () => model === 'weddingCost'
          ? [{ id: 'cost-1' }]
          : model === 'chatMessage'
            ? [{ id: 'message-1' }]
            : [],
        deleteMany: async () => { calls.push(model); },
      };
    },
  });
  const prisma = {
    $transaction: async (callback: (tx: unknown) => Promise<void>) => callback(database),
  };
  await fixtures.cleanupQuoteFixtureGraph(prisma, {
    owner: { id: 'owner' }, providerUser: { id: 'provider-user' },
    member: { id: 'member' }, plan: { id: 'plan' }, provider: { id: 'provider' },
    city: { id: 'city' }, category: { id: 'category' }, service: { id: 'service' },
    conversation: { id: 'conversation' }, quoteRequest: { id: 'request' }, offer: { id: 'offer' },
  });
  assert.ok(calls.indexOf('$executeRaw') < calls.indexOf('costPayment'));
  assert.ok(calls.indexOf('costPayment') < calls.indexOf('weddingCost'));
  assert.ok(calls.indexOf('weddingCost') < calls.indexOf('quoteOffer'));
  assert.ok(calls.indexOf('conversationEvent') < calls.indexOf('conversation'));
  assert.ok(calls.includes('notification'));
  assert.ok(calls.includes('outboxEvent'));
});

test('cleanliness protection includes all tracked fixture and golden filename patterns', () => {
  const files = cleanliness.protectedTestArtifacts();
  assert.ok(files.includes('mobile/test/goldens'));
  assert.ok(files.includes('mobile/test/features/marketplace/goldens/provider_received_offer.png'));
  assert.equal(cleanliness.isProtectedTestArtifactPath('backend/test/phase0.fixture.json'), true);
  assert.equal(cleanliness.isProtectedTestArtifactPath('backend/test/fixtures/custom-output.txt'), true);
});

function managedEnvironment() {
  const database = 'aarast_smoke_20260724123456789_abcdef12';
  return {
    AARAST_SMOKE_MANAGED: '1',
    AARAST_SMOKE_RUN_ID: 'smoke_20260724123456789_abcdef12',
    AARAST_SMOKE_EXPECTED_DATABASE: database,
    DATABASE_URL: `postgresql://user:password@127.0.0.1:5433/${database}`,
    SMOKE_DATABASE_URL: `postgresql://user:password@127.0.0.1:5433/${database}`,
    AARAST_SMOKE_EXPECTED_BASE_URL: 'http://127.0.0.1:32145',
    SMOKE_BASE_URL: 'http://127.0.0.1:32145',
    AARAST_SMOKE_EXPECTED_BUCKET: 'aarast-smoke-20260724123456789-abcdef12',
    AARAST_MEDIA_BUCKET: 'aarast-smoke-20260724123456789-abcdef12',
    AARAST_SMOKE_EXPECTED_REDIS_DB: '15',
    REDIS_URL: 'redis://127.0.0.1:6380/15',
  };
}
