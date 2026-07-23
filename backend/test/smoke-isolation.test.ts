import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

const {
  assertExactRunResource,
  buildManagedEnvironment,
  createRunIdentity,
  executeManagedRun,
  safePostgresIdentifier,
  validateSmokeScripts,
} = require('../scripts/smoke/run-isolated-smoke.js');
const {
  assertManagedSmokeEnvironment,
  assertSafeSmokeDatabaseUrl,
  databaseNameFromUrl,
} = require('../scripts/smoke/smoke-utils.js');

const backendRoot = join(__dirname, '..');
const repositoryRoot = join(backendRoot, '..');

function managedFixture() {
  const identity = createRunIdentity(
    new Date('2026-07-23T12:34:56.789Z'),
    'abcdef12',
  );
  const discovery = {
    postgresUser: 'aarast',
    postgresPassword: 'local password',
    postgresPort: '5433',
    redisPort: '6380',
    mediaPort: '9000',
    mediaAccessKey: 'local-media-key',
    mediaSecretKey: 'local-media-secret',
  };
  const environment = buildManagedEnvironment(discovery, identity, 32145);
  return { identity, environment };
}

test('managed smoke identity names every disposable resource with one run id', () => {
  const identity = createRunIdentity(
    new Date('2026-07-23T12:34:56.789Z'),
    'abcdef12',
  );
  assert.deepEqual(identity, {
    runId: 'smoke_20260723123456789_abcdef12',
    databaseName: 'aarast_smoke_20260723123456789_abcdef12',
    bucketName: 'aarast-smoke-20260723123456789-abcdef12',
  });
});

test('database guard accepts only the exact disposable smoke database', () => {
  const expected = 'aarast_smoke_20260723_abcdef12';
  const safe = `postgresql://user:secret@127.0.0.1:5433/${expected}?schema=public`;
  assert.equal(databaseNameFromUrl(safe), expected);
  assert.equal(assertSafeSmokeDatabaseUrl(safe, expected), expected);

  for (const unsafe of [
    'postgresql://user:secret@127.0.0.1:5433/aarast',
    'postgresql://user:secret@127.0.0.1:5433/aarast_dev',
    'postgresql://user:secret@127.0.0.1:5433/postgres',
    'mysql://user:secret@127.0.0.1:3306/aarast_smoke_test',
    'postgresql://user:secret@127.0.0.1:5433/smoke%2Faarast',
  ]) {
    assert.throws(
      () => assertSafeSmokeDatabaseUrl(unsafe, expected),
      /Smoke|smoke|PostgreSQL|database/,
    );
  }
  assert.throws(
    () => assertSafeSmokeDatabaseUrl(
      'postgresql://user:secret@127.0.0.1:5433/another_smoke_db',
      expected,
    ),
    /mismatch/,
  );
});

test('managed environment binds API, Prisma, MinIO, and Redis to isolated resources', () => {
  const { identity, environment } = managedFixture();
  assert.deepEqual(assertManagedSmokeEnvironment(environment), {
    runId: identity.runId,
    databaseName: identity.databaseName,
    bucketName: identity.bucketName,
    redisDatabase: '15',
  });
  assert.equal(environment.DATABASE_URL, environment.SMOKE_DATABASE_URL);
  assert.equal(environment.SMOKE_BASE_URL, 'http://127.0.0.1:32145');
  assert.equal(environment.AARAST_MEDIA_BUCKET, identity.bucketName);
  assert.match(environment.REDIS_URL, /\/15$/);

  assert.throws(
    () => assertManagedSmokeEnvironment({
      ...environment,
      DATABASE_URL: environment.DATABASE_URL.replace(identity.databaseName, 'aarast'),
    }),
    /same managed database/,
  );
  assert.throws(
    () => assertManagedSmokeEnvironment({
      ...environment,
      SMOKE_BASE_URL: 'http://127.0.0.1:3115',
      AARAST_SMOKE_EXPECTED_BASE_URL: 'http://127.0.0.1:3115',
    }),
    /never the development backend/,
  );
  assert.throws(
    () => assertManagedSmokeEnvironment({
      ...environment,
      REDIS_URL: environment.REDIS_URL.replace('/15', '/0'),
    }),
    /Redis database/,
  );
});

test('resource cleanup guard requires the exact current run resource', () => {
  assert.doesNotThrow(() => assertExactRunResource(
    'aarast_smoke_current',
    'aarast_smoke_current',
    'database',
  ));
  assert.throws(
    () => assertExactRunResource(
      'aarast_smoke_old',
      'aarast_smoke_current',
      'database',
    ),
    /exact resource/,
  );
  assert.throws(
    () => safePostgresIdentifier('aarast; DROP DATABASE aarast', 'database'),
    /safe PostgreSQL identifier/,
  );
});

test('managed lifecycle cleans resources in reverse ownership order', async () => {
  const events: string[] = [];
  await executeManagedRun({
    createDatabase: async () => { events.push('create-db'); },
    dropDatabase: async () => { events.push('drop-db'); },
    reserveRedis: async () => { events.push('reserve-redis'); return 'redis'; },
    releaseRedis: async () => { events.push('release-redis'); },
    createBucket: async () => { events.push('create-bucket'); return 'bucket'; },
    configureBucket: async () => { events.push('configure-bucket'); },
    deleteBucket: async () => { events.push('delete-bucket'); },
    migrateDatabase: async () => { events.push('migrate'); },
    startBackend: () => { events.push('start-backend'); return 'backend'; },
    stopBackend: async () => { events.push('stop-backend'); },
    waitForBackend: async () => { events.push('ready'); },
    runSmokeScripts: async () => { events.push('smoke'); },
  });
  assert.deepEqual(events, [
    'create-db',
    'reserve-redis',
    'create-bucket',
    'configure-bucket',
    'migrate',
    'start-backend',
    'ready',
    'smoke',
    'stop-backend',
    'delete-bucket',
    'release-redis',
    'drop-db',
  ]);
});

test('managed lifecycle cleans every owned resource after a smoke failure', async () => {
  const events: string[] = [];
  await assert.rejects(
    executeManagedRun({
      createDatabase: async () => { events.push('create-db'); },
      dropDatabase: async () => { events.push('drop-db'); },
      reserveRedis: async () => 'redis',
      releaseRedis: async () => { events.push('release-redis'); },
      createBucket: async () => 'bucket',
      configureBucket: async () => {},
      deleteBucket: async () => { events.push('delete-bucket'); },
      migrateDatabase: async () => {},
      startBackend: () => 'backend',
      stopBackend: async () => { events.push('stop-backend'); },
      waitForBackend: async () => {},
      runSmokeScripts: async () => { throw new Error('deliberate smoke failure'); },
    }),
    /deliberate smoke failure/,
  );
  assert.deepEqual(events, [
    'create-db',
    'stop-backend',
    'delete-bucket',
    'release-redis',
    'drop-db',
  ]);
});

test('cleanup failures fail the managed run instead of being hidden', async () => {
  await assert.rejects(
    executeManagedRun({
      createDatabase: async () => {},
      dropDatabase: async () => { throw new Error('drop refused'); },
      reserveRedis: async () => 'redis',
      releaseRedis: async () => {},
      createBucket: async () => 'bucket',
      configureBucket: async () => {},
      deleteBucket: async () => {},
      migrateDatabase: async () => {},
      startBackend: () => 'backend',
      stopBackend: async () => {},
      waitForBackend: async () => {},
      runSmokeScripts: async () => {},
    }),
    /cleanup failed|cleanup was incomplete|Managed smoke cleanup failed/,
  );
});

test('only known internal or explicitly managed external scripts are accepted', () => {
  assert.deepEqual(validateSmokeScripts([]), ['all-smoke.js']);
  assert.deepEqual(validateSmokeScripts(['auth-smoke.js']), ['auth-smoke.js']);
  assert.deepEqual(validateSmokeScripts(['--admin-runtime']), ['--admin-runtime']);
  assert.deepEqual(validateSmokeScripts(['--load-test']), ['--load-test']);
  assert.throws(() => validateSmokeScripts(['../auth-smoke.js']), /Unknown/);
  assert.throws(
    () => validateSmokeScripts(['--admin-runtime', 'auth-smoke.js']),
    /own isolated lifecycle/,
  );
});

test('official mutating smoke and load commands use managed isolation', () => {
  const backendPackage = JSON.parse(
    readFileSync(join(backendRoot, 'package.json'), 'utf8'),
  );
  for (const [name, command] of Object.entries<string>(backendPackage.scripts)) {
    if ((name.startsWith('smoke') && name !== 'smoke:openwa-otp') || name === 'load:test') {
      assert.match(command, /run-isolated-smoke\.js/, name);
    }
  }

  const adminPackage = JSON.parse(
    readFileSync(join(repositoryRoot, 'admin-web', 'package.json'), 'utf8'),
  );
  assert.match(
    adminPackage.scripts['smoke:admin-runtime'],
    /run-isolated-smoke\.js --admin-runtime/,
  );
  assert.doesNotMatch(adminPackage.scripts['smoke:routes'], /run-isolated/);
  assert.doesNotMatch(adminPackage.scripts['smoke:honesty'], /run-isolated/);

  const ciWorkflow = readFileSync(
    join(repositoryRoot, '.github', 'workflows', 'ci.yml'),
    'utf8',
  );
  assert.match(ciWorkflow, /npm run smoke:all/);
  assert.match(ciWorkflow, /npm run smoke:admin-runtime/);
  assert.doesNotMatch(ciWorkflow, /node scripts\/smoke\/all-smoke\.js/);
  assert.doesNotMatch(
    ciWorkflow,
    /ADMIN_SMOKE_DATABASE_URL=.*admin-runtime-smoke\.mjs/,
  );
});

test('isolation sources contain no permanent database fallback or destructive Prisma command', () => {
  const runner = readFileSync(
    join(backendRoot, 'scripts', 'smoke', 'run-isolated-smoke.js'),
    'utf8',
  );
  const utilities = readFileSync(
    join(backendRoot, 'scripts', 'smoke', 'smoke-utils.js'),
    'utf8',
  );
  const adminRuntime = readFileSync(
    join(repositoryRoot, 'admin-web', 'scripts', 'admin-runtime-smoke.mjs'),
    'utf8',
  );
  const load = readFileSync(
    join(backendRoot, 'scripts', 'load', 'load-test.js'),
    'utf8',
  );
  for (const source of [runner, utilities, adminRuntime, load]) {
    assert.doesNotMatch(source, /migrate\s+reset|db\s+push/i);
    assert.doesNotMatch(source, /postgresql:\/\/aarast:[^\s]+\/aarast(?:\?|["'])/);
  }
  assert.match(runner, /prismaCli, 'migrate', 'deploy'/);
  assert.match(adminRuntime, /assertManagedSmokeEnvironment/);
  assert.match(load, /assertManagedSmokeEnvironment/);
});

test('direct data-writing smoke entrypoints fail closed before creating fixtures', () => {
  const fixtureEntrypoints = [
    'auth-smoke.js',
    'auth-verification-smoke.js',
    'wedding-plan-smoke.js',
    'onboarding-active-plan-smoke.js',
    'dashboard-summary-smoke.js',
    'money-apis-smoke.js',
    'financial-ledger-concurrency-smoke.js',
    'money-budget-smoke.js',
    'tasks-apis-smoke.js',
    'task-timeline-smoke.js',
    'sharing-smoke.js',
    'sharing-roles-smoke.js',
    'sharing-security-smoke.js',
    'notifications-smoke.js',
    'notifications-apis-smoke.js',
    'guests-smoke.js',
    'guests-apis-smoke.js',
    'otp-profile-smoke.js',
    'marketplace-smoke.js',
    'providers-quotes-smoke.js',
    'quote-stability-smoke.js',
    'conversation-unification-smoke.js',
    'private-chat-media-smoke.js',
    'account-deletion-smoke.ts',
    'provider-dashboard-smoke.js',
    'ux-backend-support-smoke.js',
    'ux-c4-c7-smoke.js',
    'backend-completion-smoke.js',
  ];

  for (const fileName of fixtureEntrypoints) {
    const source = readFileSync(
      join(backendRoot, 'scripts', 'smoke', fileName),
      'utf8',
    );
    assert.match(
      source,
      /smoke-isolation-hook|assertManagedSmokeEnvironment|configureSmokeDatabaseUrl/,
      fileName,
    );
  }
});
