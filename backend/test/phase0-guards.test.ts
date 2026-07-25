import assert from 'node:assert/strict';
import { join } from 'node:path';
import { readFileSync } from 'node:fs';
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
  assert.ok(files.some((file: string) => file.endsWith('phase2-auth-retention-smoke.ts')));
  assert.ok(files.some((file: string) => file.endsWith('phase2-idempotency-reconciliation-smoke.ts')));
  assert.ok(files.some((file: string) => file.endsWith('phase2-provider-rating-concurrency-smoke.ts')));
  assert.ok(files.some((file: string) => file.endsWith('phase2-conversation-revocation-smoke.ts')));
  assert.ok(files.some((file: string) => file.endsWith('phase2-quote-concurrency-smoke.ts')));
  assert.ok(files.some((file: string) => file.endsWith('admin-runtime-smoke.mjs')));
  assert.ok(files.some((file: string) => file.endsWith('openwa-otp-smoke.js')));
});

test('account-deletion smoke uses only explicit local-media environment keys', () => {
  const source = readFileSync(join(backendRoot, 'scripts', 'smoke', 'account-deletion-smoke.ts'), 'utf8');
  assert.doesNotMatch(source, /Object\.entries\(localMediaDefaults\)/);
  for (const key of [
    'AARAST_MEDIA_ENDPOINT', 'AARAST_MEDIA_SIGNED_ENDPOINT', 'AARAST_MEDIA_BUCKET',
    'AARAST_MEDIA_PUBLIC_BASE_URL', 'AARAST_MEDIA_REGION', 'AARAST_MEDIA_FORCE_PATH_STYLE',
    'AARAST_MEDIA_ACCESS_KEY_ID', 'AARAST_MEDIA_SECRET_ACCESS_KEY',
  ]) {
    assert.match(source, new RegExp(`process\\.env\\.${key}`));
  }
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

test('source guard rejects decoded permanent PostgreSQL database names without false positives', () => {
  for (const source of [
    "const url = 'postgresql://user:password@localhost:5432/aarast';",
    "const url = 'postgresql://user:password@localhost:5432/aarast_dev';",
    "const url = 'postgresql://user:password@localhost:5432/%61arast';",
    "const url = 'postgresql://user:password@localhost:5432/aarast%5Fdev?schema=public';",
    '// postgresql://user:password@localhost:5432/aarast%5Fdev',
  ]) {
    assert.throws(
      () => sourceGuard.assertNoUnsafeDatabaseTargets(source, 'encoded-target.ts'),
      /permanent Aarast database target|unresolved PostgreSQL expression/i,
    );
  }

  for (const source of [
    "const url = 'postgresql://user:password@localhost:5432/aarast_smoke_123';",
    "const url = 'https://example.invalid/postgresql://user/aarast%5Fdev';",
  ]) {
    assert.doesNotThrow(() => sourceGuard.assertNoUnsafeDatabaseTargets(source, 'safe-source.ts'));
  }
});

test('source guard evaluates escaped and concatenated PostgreSQL strings through the AST', () => {
  for (const source of [
    String.raw`const url = 'postgresql:\/\/user:password@localhost:5432\/aarast_dev';`,
    "const url = 'postgresql://' + 'user:password@localhost:5432/aarast_dev';",
    "const scheme = 'postgresql://'; const target = scheme + 'user:password@localhost:5432/%61arast';",
  ]) {
    assert.throws(
      () => sourceGuard.assertNoUnsafeDatabaseTargets(source, 'ast-target.ts'),
      /permanent Aarast database target|unresolved PostgreSQL expression/i,
    );
  }
  assert.doesNotThrow(() => sourceGuard.assertNoUnsafeDatabaseTargets(
    "const url = 'postgresql://' + 'user:password@localhost:5432/aarast_smoke_123';",
    'ast-safe.ts',
  ));
});

test('source guard evaluates template interpolation from constants', () => {
  for (const source of [
    "const database = 'aarast_dev' as const; const url = `postgresql://user:password@localhost:5432/${database}`;",
    "{ const database = 'aarast_dev'; } const database = 'aarast_smoke_123'; const url = `postgresql://user:password@localhost:5432/${database}`;",
    "const url = ('postgresql://user:password@localhost:5432/aarast_dev' as const)! satisfies string;",
    "const database = runtimeDatabase; const url = `postgresql://user:password@localhost:5432/${database}`;",
    "const database = runtimeDatabase; const url = 'postgresql://user:password@localhost:5432/' + database;",
  ]) {
    assert.throws(
      () => sourceGuard.assertNoUnsafeDatabaseTargets(source, 'template-target.ts'),
      /permanent Aarast database target|unresolved PostgreSQL expression/i,
    );
  }
});

test('source guard rejects independent datasource overrides and direct database clients in unapproved entrypoints', () => {
  assert.equal(typeof sourceGuard.assertEntrypointDatabaseContract, 'function');
  for (const source of [
    "const { PrismaClient } = require('@prisma/client'); new PrismaClient();",
    "const client = new PrismaClient({ datasourceUrl: 'postgresql://user:password@localhost:5432/aarast_smoke_123' });",
    "process.env.DATABASE_URL = 'postgresql://user:password@localhost:5432/aarast_smoke_123';",
    "const { PrismaClient: ManagedClient } = require('@prisma/client'); new ManagedClient();",
    "import { PrismaClient as ManagedClient } from '@prisma/client'; new ManagedClient();",
    "const pg = require('pg'); new pg.Client();",
    "const postgres = require('postgres');",
    "process.env['SMOKE_DATABASE_URL'] = 'postgresql://user:password@localhost:5432/aarast_smoke_123';",
    "const key = 'DATABASE_URL'; process.env[key] = 'postgresql://user:password@localhost:5432/aarast_smoke_123';",
    "process.env.DATABASE_URL ||= 'postgresql://user:password@localhost:5432/aarast_smoke_123';",
  ]) {
    assert.throws(
      () => sourceGuard.assertEntrypointDatabaseContract(source, 'scripts/smoke/unapproved.js'),
      /independent database client|datasource override|DATABASE_URL|environment mutation/i,
    );
  }
  assert.doesNotThrow(() => sourceGuard.assertEntrypointDatabaseContract(
    "const url = 'postgresql://user:password@localhost:5432/aarast_smoke_123';",
    'scripts/smoke/unapproved.js',
  ));
  assert.throws(
    () => sourceGuard.assertEntrypointDatabaseContract(
      "const { PrismaClient } = require('@prisma/client'); new PrismaClient({});",
      'backend/scripts/smoke/phase0-fixtures-smoke.js',
    ),
    /constructor arguments|datasource override/i,
  );
});

test('source guard uses a narrow fail-closed environment and Prisma grammar', () => {
  for (const source of [
    "const proc = process; proc.env.DATABASE_URL = value;",
    "const { env } = process; env.SMOKE_DATABASE_URL = value;",
    "let env; env = process.env; env.DATABASE_URL = value;",
    "const DATABASE_URL = value; Object.assign(process.env, { DATABASE_URL });",
    "Object.defineProperty(process.env, 'DATABASE_URL', { value });",
    "Reflect.defineProperty(process.env, 'SMOKE_DATABASE_URL', { value });",
    "const pg = module.require('pg');",
    "import pg = require('pg');",
    "async function connect() { const packageName = ['p', 'g'].join(''); return import(packageName); }",
    "const { PrismaClient } = require('@prisma/client'); const Database = PrismaClient; new Database();",
    "const { PrismaClient } = require('@prisma/client'); let Database; Database = PrismaClient; new Database({});",
    "const { PrismaClient } = require('@prisma/client'); Reflect.construct(PrismaClient, [{}]);",
    "const { PrismaClient } = require('@prisma/client'); consume(PrismaClient);",
    "const { PrismaClient } = require('@prisma/client'); const options = { PrismaClient };",
    "const { PrismaClient } = require('@prisma/client'); const clients = [PrismaClient];",
    "const { PrismaClient } = require('@prisma/client'); function create(value = PrismaClient) { return value; }",
    'const { PrismaClient } = unknown; consume(PrismaClient);',
    'const { PrismaClient } = unknown;',
    "const { PrismaClient: Database } = require('@prisma/client'); new Database();",
    "const database = require('@prisma/client'); new database.PrismaClient();",
    "import * as database from '@prisma/client'; new database.PrismaClient();",
    "import { PrismaClient as Database } from '@prisma/client'; new Database();",
  ]) {
    assert.throws(
      () => sourceGuard.assertEntrypointDatabaseContract(source, 'backend/scripts/smoke/unapproved.js'),
      /process alias|environment mutation|independent database client|PrismaClient|outside the narrow environment grammar|dynamic import/i,
    );
  }
  assert.throws(
    () => sourceGuard.assertEntrypointDatabaseContract(
      "const { PrismaClient } = require('@prisma/client'); const ManagedDatabase = PrismaClient; new ManagedDatabase({ log: ['query'] });",
      'backend/scripts/smoke/phase0-fixtures-smoke.js',
    ),
    /PrismaClient alias/i,
  );
  assert.throws(
    () => sourceGuard.assertEntrypointDatabaseContract(
      "const { PrismaClient } = require('@prisma/client'); new PrismaClient({});",
      'backend/scripts/smoke/phase0-fixtures-smoke.js',
    ),
    /constructor arguments/i,
  );
  assert.doesNotThrow(() => sourceGuard.assertEntrypointDatabaseContract(
    "const { PrismaClient, ProviderStatus } = require('@prisma/client'); new PrismaClient();",
    'backend/scripts/smoke/phase0-fixtures-smoke.js',
  ));
  assert.doesNotThrow(() => sourceGuard.assertEntrypointDatabaseContract(
    "import { PrismaClient, ProviderStatus } from '@prisma/client'; new PrismaClient();",
    'backend/scripts/smoke/account-deletion-smoke.ts',
  ));
  assert.doesNotThrow(() => sourceGuard.assertEntrypointDatabaseContract(
    "const { PrismaClient } = backendRequire('@prisma/client'); new PrismaClient();",
    'admin-web/scripts/admin-runtime-smoke.mjs',
  ));
  assert.doesNotThrow(() => sourceGuard.assertEntrypointDatabaseContract(
    "const baseUrl = process.env.SMOKE_BASE_URL ?? 'http://127.0.0.1:3115';",
    'backend/scripts/smoke/unapproved.js',
  ));
  assert.throws(
    () => sourceGuard.assertEntrypointDatabaseContract(
      'process.env = replacementEnvironment;',
      'backend/scripts/smoke/unapproved.js',
    ),
    /environment mutation|process\.env/i,
  );
});

test('source guard rejects computed require loaders and indirect process aliases', () => {
  for (const source of [
    "const pg = require(['p', 'g'].join(''));",
    "const req = require; const pg = req('pg');",
    "const proc = globalThis.process; proc.env.DATABASE_URL = value;",
    "const proc = globalThis['process']; proc.env.DATABASE_URL = value;",
    "const env = global.process.env; env.SMOKE_DATABASE_URL = value;",
    "const processModule = require('node:process'); processModule.env.DATABASE_URL = value;",
    "function connect(proc = process) { proc.env.DATABASE_URL = value; }",
    "function connect(env = process.env) { env.DATABASE_URL = value; }",
    "Object['defineProperty'](process.env, 'DATABASE_URL', { value });",
    "Reflect['defineProperty'](process.env, 'SMOKE_DATABASE_URL', { value });",
    "const defineProperty = Object.defineProperty; defineProperty(process.env, 'DATABASE_URL', { value });",
    "const { createRequire } = require('node:module'); const load = createRequire(__filename); load('pg');",
    "const load = require('module').createRequire(__filename); load('pg');",
  ]) {
    assert.throws(
      () => sourceGuard.assertEntrypointDatabaseContract(
        source,
        'backend/scripts/smoke/unapproved.js',
      ),
      /dynamic require|require alias|process alias|process module|environment grammar|environment mutation|module loader/i,
    );
  }

  assert.throws(
    () => sourceGuard.assertEntrypointDatabaseContract(
      "const loader = backendRequire; const { PrismaClient } = loader('@prisma/client'); new PrismaClient();",
      'admin-web/scripts/admin-runtime-smoke.mjs',
    ),
    /backendRequire alias|static database-client grammar/i,
  );

  assert.doesNotThrow(() => sourceGuard.assertEntrypointDatabaseContract(
    "const socket = require(path.join(socketIoRoot, 'client-dist', 'socket.io.js'));",
    'backend/scripts/smoke/conversation-unification-smoke.js',
  ));
});

test('source guard rejects process environment and mutator capability escapes', () => {
  for (const source of [
    "function mutate(target) { target.DATABASE_URL = value; } mutate(process.env);",
    "function mutate(target) { target.env.DATABASE_URL = value; } mutate(process);",
    "const env = (0, process.env); env.DATABASE_URL = value;",
    "const [env] = [process.env]; env.DATABASE_URL = value;",
    "const holder = { env: process.env }; holder.env.DATABASE_URL = value;",
    "const mutators = [Object.defineProperty]; mutators[0](process.env, 'DATABASE_URL', { value });",
    "function mutate(setter = Object.defineProperty) { setter(process.env, 'DATABASE_URL', { value }); }",
    "delete process.env.DATABASE_URL;",
    "process.env.DATABASE_URL++;",
    "const assertManagedSmokeEnvironment = (value) => value; const env = assertManagedSmokeEnvironment(process.env); env.DATABASE_URL = value;",
    "const { assertManagedSmokeEnvironment } = require('./smoke-utils'); function escape(assertManagedSmokeEnvironment) { assertManagedSmokeEnvironment(process.env); } escape((env) => { env.DATABASE_URL = value; });",
  ]) {
    assert.throws(
      () => sourceGuard.assertEntrypointDatabaseContract(
        source,
        'backend/scripts/smoke/unapproved.js',
      ),
      /process|environment|mutation capability/i,
    );
  }

  assert.throws(
    () => sourceGuard.assertEntrypointDatabaseContract(
      "const env = (0, process.env); env.DATABASE_URL = value;",
      'backend/scripts/smoke/run-isolated-smoke.js',
    ),
    /process|environment/i,
  );

  assert.doesNotThrow(() => sourceGuard.assertEntrypointDatabaseContract(
    "const { assertManagedSmokeEnvironment } = require('./smoke-utils'); assertManagedSmokeEnvironment(process.env); const baseUrl = process.env.SMOKE_BASE_URL;",
    'backend/scripts/smoke/auth-verification-smoke.js',
  ));
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

test('quote cleanup deletes notification outbox records using collected notification ids', async () => {
  const calls: Array<{ model: string; operation: string; value?: unknown }> = [];
  const database = new Proxy({}, {
    get(_target, model: string) {
      if (model === '$executeRaw') return async () => { calls.push({ model, operation: 'execute' }); };
      return {
        findMany: async () => {
          calls.push({ model, operation: 'find' });
          if (model === 'notification') return [{ id: 'notification-1' }];
          if (model === 'weddingCost') return [{ id: 'cost-1' }];
          if (model === 'chatMessage') return [{ id: 'message-1' }];
          return [];
        },
        deleteMany: async (value: unknown) => { calls.push({ model, operation: 'delete', value }); },
      };
    },
  });
  await fixtures.cleanupQuoteFixtureGraph({
    $transaction: async (callback: (tx: unknown) => Promise<void>) => callback(database),
  }, quoteFixture());

  const outboxDelete = calls.find((call) => call.model === 'outboxEvent' && call.operation === 'delete');
  assert.ok(calls.some((call) => call.model === 'notification' && call.operation === 'find'));
  const notificationClause = (outboxDelete?.value as {
    where: { OR: Array<{ aggregateType?: string; aggregateId?: { in: string[] } }> };
  }).where.OR.find((clause) => clause.aggregateType === 'notification');
  assert.deepEqual(notificationClause, {
    aggregateType: 'notification',
    aggregateId: { in: ['notification-1'] },
  });
});

test('permission fixture creation is one transaction and retains the stage failure', async () => {
  let transactionCalls = 0;
  const tx = new Proxy({}, {
    get(_target, model: string) {
      return {
        create: async () => {
          if (model === 'sharedMember') throw new Error('second-stage failure');
          return { id: `${model}-id` };
        },
      };
    },
  });
  const prisma = {
    $transaction: async (callback: (transaction: unknown) => Promise<void>) => {
      transactionCalls += 1;
      return callback(tx);
    },
  };

  await assert.rejects(
    fixtures.createPermissionRevocationFixture(prisma, managedEnvironment()),
    /second-stage failure/,
  );
  assert.equal(transactionCalls, 1);
});

test('cleanup users removes OTP codes by the fixture users actual phones', async () => {
  assert.equal(typeof fixtures.cleanupUsers, 'function');
  const deletions: Array<{ model: string; value: unknown }> = [];
  const tx = new Proxy({}, {
    get(_target, model: string) {
      return {
        findMany: async () => model === 'user' ? [{ phone: '+967700000001' }, { phone: '+967700000002' }] : [],
        deleteMany: async (value: unknown) => { deletions.push({ model, value }); },
      };
    },
  });
  await fixtures.cleanupUsers(tx, ['user-1', 'user-2']);
  const otpDeletion = deletions.find((entry) => entry.model === 'otpCode');
  assert.deepEqual(otpDeletion?.value, {
    where: { phone: { in: ['+967700000001', '+967700000002'] } },
  });
});

test('barrier runs every operation only after all arrivals and returns all values', async () => {
  const lifecycle: string[] = [];
  const values = await fixtures.runConcurrentlyAfterBarrier([
    async () => { lifecycle.push('first'); return 'first-result'; },
    async () => { lifecycle.push('second'); return 'second-result'; },
    async () => { lifecycle.push('third'); return 'third-result'; },
  ], {
    onAllArrived: ({ arrived, total }: { arrived: number; total: number }) => {
      lifecycle.push(`release:${arrived}/${total}`);
    },
  });
  assert.equal(lifecycle[0], 'release:3/3');
  assert.deepEqual(lifecycle.slice(1).sort(), ['first', 'second', 'third']);
  assert.deepEqual(values.sort(), ['first-result', 'second-result', 'third-result']);
});

test('barrier propagates an operation failure after every operation reaches it', async () => {
  const lifecycle: string[] = [];
  await assert.rejects(
    fixtures.runConcurrentlyAfterBarrier([
      async () => { lifecycle.push('first'); return 'first-result'; },
      async () => { lifecycle.push('second'); throw new Error('barrier operation failure'); },
      async () => { lifecycle.push('third'); return 'third-result'; },
    ], {
      onAllArrived: ({ arrived, total }: { arrived: number; total: number }) => {
        lifecycle.push(`release:${arrived}/${total}`);
      },
    }),
    /barrier operation failure/,
  );
  assert.equal(lifecycle[0], 'release:3/3');
  assert.deepEqual(lifecycle.slice(1).sort(), ['first', 'second', 'third']);
});

test('barrier waits for a slow settlement before withFixture cleanup after a fast failure', async () => {
  const events: string[] = [];
  await assert.rejects(
    fixtures.withFixture(
      async () => ({ cleanup: async () => { events.push('cleanup'); } }),
      async () => fixtures.runConcurrentlyAfterBarrier([
        async () => {
          events.push('slow-start');
          await new Promise((resolve) => setTimeout(resolve, 25));
          events.push('slow-finish');
        },
        async () => {
          events.push('fast-failure');
          throw new Error('fast failure');
        },
      ]),
      managedEnvironment(),
    ),
    /fast failure/,
  );
  assert.ok(events.indexOf('slow-finish') < events.indexOf('cleanup'));
});

test('barrier reports every failure only after all operations settle', async () => {
  await assert.rejects(
    fixtures.runConcurrentlyAfterBarrier([
      async () => { throw new Error('first failure'); },
      async () => { throw new Error('second failure'); },
    ]),
    (error: Error) => error instanceof AggregateError && error.errors.length === 2,
  );
});

test('cleanliness protection includes all tracked fixture and golden filename patterns', () => {
  const files = cleanliness.protectedTestArtifacts();
  assert.ok(files.includes('mobile/test/goldens'));
  assert.ok(files.includes('mobile/test/features/marketplace/goldens/provider_received_offer.png'));
  assert.ok(files.includes('backend/test/support/phase0-postgres-support.js'));
  assert.equal(cleanliness.isProtectedTestArtifactPath('backend/test/phase0.fixture.json'), true);
  assert.equal(cleanliness.isProtectedTestArtifactPath('backend/test/fixtures/custom-output.txt'), true);
  assert.equal(cleanliness.isProtectedTestArtifactPath('backend/test/fixtures/managed-fixture.ts'), true);
  assert.equal(cleanliness.isProtectedTestArtifactPath('backend/scripts/smoke/phase0-fixtures-smoke.js'), false);
});

test('isolated fixture smoke checks every dependent output table after cleanup', () => {
  const source = readFileSync(join(backendRoot, 'scripts', 'smoke', 'phase0-fixtures-smoke.js'), 'utf8');
  for (const model of [
    'budgetCategory', 'weddingCost', 'costPayment', 'paymentSchedule', 'planProviderLink',
    'chatMessage', 'chatAttachment', 'conversationEvent', 'conversationParticipant',
    'notification', 'outboxEvent', 'sharedMember', 'conversationReport',
    'otpCode', 'city', 'providerCategory', 'provider', 'providerService', 'quoteRequest',
  ]) {
    assert.match(source, new RegExp(`prisma\\.${model}\\.count`));
  }
});

test('fixture smoke exports output creation and fail-closed cleanup contracts without starting main', async () => {
  const smoke = require('../scripts/smoke/phase0-fixtures-smoke.js');
  assert.equal(typeof smoke.createOperationOutputs, 'function');
  assert.equal(typeof smoke.assertClean, 'function');
  assert.deepEqual(smoke.REQUIRED_OPERATION_OUTPUT_KEYS, [
    'budgetCategory', 'cost', 'costPayment', 'paymentSchedule', 'planProviderLink',
    'conversationEvent', 'chatMessage', 'chatAttachment', 'notification', 'outboxEvent',
  ]);

  const output = await smoke.createOperationOutputs(fakeOutputPrisma(), quoteFixture());
  for (const key of [
    'budgetCategory', 'cost', 'costPayment', 'paymentSchedule', 'planProviderLink',
    'conversationEvent', 'chatMessage', 'chatAttachment', 'notification', 'outboxEvent',
  ]) {
    assert.equal(output[key].id, `${key}-id`);
  }

  await assert.rejects(
    smoke.assertClean(fakeCountPrisma([]), quoteFixture()),
    /operationOutputs/i,
  );

  for (const key of smoke.REQUIRED_OPERATION_OUTPUT_KEYS) {
    const missingCalls: Array<{ model: string; where: unknown }> = [];
    const { [key]: _missing, ...withoutKey } = output;
    await assert.rejects(
      smoke.assertClean(fakeCountPrisma(missingCalls), {
        ...quoteFixture(), operationOutputs: withoutKey,
      }),
      new RegExp(key),
    );
    assert.equal(missingCalls.length, 0);

    for (const invalidOutput of [{}, { id: '' }, { id: '   ' }]) {
      const invalidCalls: Array<{ model: string; where: unknown }> = [];
      await assert.rejects(
        smoke.assertClean(fakeCountPrisma(invalidCalls), {
          ...quoteFixture(), operationOutputs: { ...output, [key]: invalidOutput },
        }),
        new RegExp(key),
      );
      assert.equal(invalidCalls.length, 0);
    }
  }

  const calls: Array<{ model: string; where: unknown }> = [];
  await smoke.assertClean(fakeCountPrisma(calls), { ...quoteFixture(), operationOutputs: output });
  for (const [outputKey, model] of [
    ['budgetCategory', 'budgetCategory'], ['cost', 'weddingCost'], ['costPayment', 'costPayment'],
    ['paymentSchedule', 'paymentSchedule'], ['planProviderLink', 'planProviderLink'],
    ['conversationEvent', 'conversationEvent'], ['chatMessage', 'chatMessage'],
    ['chatAttachment', 'chatAttachment'], ['notification', 'notification'], ['outboxEvent', 'outboxEvent'],
  ]) {
    assert.ok(calls.some((call) => call.model === model && JSON.stringify(call.where).includes(`${outputKey}-id`)));
  }
});

function quoteFixture() {
  return {
    owner: { id: 'owner' }, providerUser: { id: 'provider-user' },
    member: { id: 'member' }, plan: { id: 'plan' }, provider: { id: 'provider' },
    city: { id: 'city' }, category: { id: 'category' }, service: { id: 'service' },
    conversation: { id: 'conversation' }, quoteRequest: { id: 'request' }, offer: { id: 'offer' },
  };
}

function fakeOutputPrisma() {
  const transaction = new Proxy({}, {
    get(_target, model: string) {
      return {
        create: async () => ({ id: `${outputKeyForModel(model)}-id` }),
        update: async () => undefined,
      };
    },
  });
  return { $transaction: async (callback: (tx: unknown) => Promise<unknown>) => callback(transaction) };
}

function fakeCountPrisma(calls: Array<{ model: string; where: unknown }>) {
  return new Proxy({}, {
    get(_target, model: string) {
      return { count: async ({ where }: { where: unknown }) => { calls.push({ model, where }); return 0; } };
    },
  });
}

function outputKeyForModel(model: string) {
  return ({
    budgetCategory: 'budgetCategory', weddingCost: 'cost', costPayment: 'costPayment',
    paymentSchedule: 'paymentSchedule', planProviderLink: 'planProviderLink',
    conversationEvent: 'conversationEvent', chatMessage: 'chatMessage', chatAttachment: 'chatAttachment',
    notification: 'notification', outboxEvent: 'outboxEvent',
  } as Record<string, string>)[model] ?? model;
}

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
