'use strict';

const fs = require('fs');
const path = require('path');

const FORBIDDEN_SMOKE_DATABASES = new Set([
  'aarast',
  'aarast_dev',
  'postgres',
  'template0',
  'template1',
]);

function loadLocalEnvFile() {
  const envPath = path.resolve(__dirname, '..', '..', '.env');
  if (!fs.existsSync(envPath)) return;

  const lines = fs.readFileSync(envPath, 'utf8').split(/\r?\n/);
  for (const line of lines) {
    const match = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$/);
    if (!match) continue;

    const [, key, rawValue] = match;
    if (process.env[key] !== undefined) continue;

    let value = rawValue.trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

function configureSmokeDatabaseUrl() {
  const smokeDatabaseUrl = process.env.SMOKE_DATABASE_URL?.trim();
  if (!smokeDatabaseUrl) {
    throw new Error(
      'SMOKE_DATABASE_URL is required. Run smoke tests through the managed npm smoke commands.',
    );
  }

  process.env.DATABASE_URL = smokeDatabaseUrl;
  assertManagedSmokeEnvironment(process.env);
}

function databaseNameFromUrl(value) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw new Error('Smoke database URL is invalid.');
  }

  if (!['postgres:', 'postgresql:'].includes(parsed.protocol)) {
    throw new Error('Smoke database URL must use PostgreSQL.');
  }

  const encodedName = parsed.pathname.replace(/^\/+/, '');
  if (!encodedName || encodedName.includes('/')) {
    throw new Error('Smoke database URL must name exactly one database.');
  }

  let databaseName;
  try {
    databaseName = decodeURIComponent(encodedName);
  } catch {
    throw new Error('Smoke database name is invalid.');
  }

  if (!/^[a-z][a-z0-9_]{2,62}$/.test(databaseName)) {
    throw new Error('Smoke database name must be a safe lowercase identifier.');
  }
  return databaseName;
}

function assertSafeSmokeDatabaseUrl(value, expectedDatabaseName) {
  const databaseName = databaseNameFromUrl(value);
  if (!/(?:smoke|test)/.test(databaseName)) {
    throw new Error(
      `Refusing smoke database "${databaseName}": its name must contain "smoke" or "test".`,
    );
  }
  if (FORBIDDEN_SMOKE_DATABASES.has(databaseName)) {
    throw new Error(`Refusing permanent database "${databaseName}".`);
  }
  if (databaseName !== expectedDatabaseName) {
    throw new Error(
      `Smoke database mismatch: expected "${expectedDatabaseName}", got "${databaseName}".`,
    );
  }
  return databaseName;
}

function assertManagedSmokeEnvironment(environment = process.env) {
  if (environment.AARAST_SMOKE_MANAGED !== '1') {
    throw new Error(
      'Smoke execution is not managed. Use an official npm smoke command.',
    );
  }

  const runId = environment.AARAST_SMOKE_RUN_ID?.trim();
  if (!runId || !/^smoke_[a-z0-9_]{8,50}$/.test(runId)) {
    throw new Error('A valid managed smoke run id is required.');
  }

  const expectedDatabaseName =
    environment.AARAST_SMOKE_EXPECTED_DATABASE?.trim();
  if (!expectedDatabaseName) {
    throw new Error('AARAST_SMOKE_EXPECTED_DATABASE is required.');
  }

  const databaseUrl = environment.DATABASE_URL?.trim();
  const smokeDatabaseUrl = environment.SMOKE_DATABASE_URL?.trim();
  if (!databaseUrl || !smokeDatabaseUrl || databaseUrl !== smokeDatabaseUrl) {
    throw new Error(
      'DATABASE_URL and SMOKE_DATABASE_URL must be the same managed database.',
    );
  }
  assertSafeSmokeDatabaseUrl(databaseUrl, expectedDatabaseName);

  const expectedBaseUrl =
    environment.AARAST_SMOKE_EXPECTED_BASE_URL?.trim();
  const smokeBaseUrl = environment.SMOKE_BASE_URL?.trim();
  if (!expectedBaseUrl || smokeBaseUrl !== expectedBaseUrl) {
    throw new Error('SMOKE_BASE_URL is not owned by the managed smoke run.');
  }

  let parsedBaseUrl;
  try {
    parsedBaseUrl = new URL(smokeBaseUrl);
  } catch {
    throw new Error('SMOKE_BASE_URL is invalid.');
  }
  if (
    parsedBaseUrl.protocol !== 'http:' ||
    !['127.0.0.1', 'localhost'].includes(parsedBaseUrl.hostname) ||
    !parsedBaseUrl.port ||
    parsedBaseUrl.port === '3115'
  ) {
    throw new Error(
      'Managed smoke must use its own local backend port, never the development backend.',
    );
  }

  const expectedBucket = environment.AARAST_SMOKE_EXPECTED_BUCKET?.trim();
  if (
    !expectedBucket ||
    environment.AARAST_MEDIA_BUCKET?.trim() !== expectedBucket ||
    !expectedBucket.includes('smoke')
  ) {
    throw new Error('MinIO bucket is not owned by the managed smoke run.');
  }

  const expectedRedisDatabase =
    environment.AARAST_SMOKE_EXPECTED_REDIS_DB?.trim();
  let redisUrl;
  try {
    redisUrl = new URL(environment.REDIS_URL ?? '');
  } catch {
    throw new Error('REDIS_URL is invalid.');
  }
  const redisDatabase = redisUrl.pathname.replace(/^\/+/, '') || '0';
  if (
    !expectedRedisDatabase ||
    expectedRedisDatabase === '0' ||
    redisDatabase !== expectedRedisDatabase
  ) {
    throw new Error('Redis database is not isolated for this smoke run.');
  }

  return {
    runId,
    databaseName: expectedDatabaseName,
    bucketName: expectedBucket,
    redisDatabase: expectedRedisDatabase,
  };
}

function requireResponseId(label, response) {
  const id = response.body?.id;
  if (typeof id === 'string' && id.length > 0) {
    return id;
  }

  console.log(`${label} response status: ${response.status}`);
  console.log(`${label} response body: ${JSON.stringify(response.body, null, 2)}`);
  throw new Error(`${label} did not return an id`);
}

module.exports = {
  assertManagedSmokeEnvironment,
  assertSafeSmokeDatabaseUrl,
  configureSmokeDatabaseUrl,
  databaseNameFromUrl,
  loadLocalEnvFile,
  requireResponseId,
};
