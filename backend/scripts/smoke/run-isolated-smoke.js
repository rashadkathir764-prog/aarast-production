#!/usr/bin/env node
'use strict';

const {
  AbortMultipartUploadCommand,
  CreateBucketCommand,
  DeleteBucketCommand,
  DeleteObjectsCommand,
  ListMultipartUploadsCommand,
  ListObjectsV2Command,
  PutBucketPolicyCommand,
  S3Client,
} = require('@aws-sdk/client-s3');
const { randomBytes } = require('crypto');
const { existsSync } = require('fs');
const net = require('net');
const path = require('path');
const { spawn } = require('child_process');
const Redis = require('ioredis');
const {
  assertManagedSmokeEnvironment,
  assertSafeSmokeDatabaseUrl,
  loadLocalEnvFile,
} = require('./smoke-utils');

const repositoryRoot = path.resolve(__dirname, '..', '..', '..');
const backendRoot = path.resolve(__dirname, '..', '..');
const adminWebRoot = path.join(repositoryRoot, 'admin-web');
const isolationHook = path.join(__dirname, 'smoke-isolation-hook.js');
const prismaCli = path.join(
  backendRoot,
  'node_modules',
  'prisma',
  'build',
  'index.js',
);
const SMOKE_REDIS_DATABASE = '15';
const REDIS_LOCK_KEY = 'aarast:managed-smoke:lock';

function createRunIdentity(now = new Date(), randomHex = randomBytes(4).toString('hex')) {
  const timestamp = now
    .toISOString()
    .replace(/[^0-9]/g, '')
    .slice(0, 17);
  const safeRandom = String(randomHex).toLowerCase();
  if (!/^[a-f0-9]{8}$/.test(safeRandom)) {
    throw new Error('Smoke run random suffix must contain eight hexadecimal characters.');
  }

  const runId = `smoke_${timestamp}_${safeRandom}`;
  return {
    runId,
    databaseName: `aarast_${runId}`,
    bucketName: `aarast-${runId.replace(/_/g, '-')}`,
  };
}

function assertExactRunResource(actual, expected, kind) {
  if (!actual || actual !== expected || !actual.includes('smoke')) {
    throw new Error(
      `Refusing to remove ${kind}: it is not the exact resource owned by this smoke run.`,
    );
  }
}

function safePostgresIdentifier(value, label) {
  if (!/^[a-z_][a-z0-9_]{0,62}$/i.test(value)) {
    throw new Error(`${label} is not a safe PostgreSQL identifier.`);
  }
  return `"${value.replace(/"/g, '""')}"`;
}

function composeEnvironment(value) {
  if (!value) return {};
  if (!Array.isArray(value)) return value;
  return Object.fromEntries(
    value.map((entry) => {
      const separator = entry.indexOf('=');
      return separator === -1
        ? [entry, '']
        : [entry.slice(0, separator), entry.slice(separator + 1)];
    }),
  );
}

function wait(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}

async function terminateProcessTree(child, graceMilliseconds = 5_000) {
  if (!child || child.exitCode !== null || !child.pid) return;

  if (process.platform === 'win32') {
    const result = await runCapturedCommand(
      'taskkill.exe',
      ['/PID', String(child.pid), '/T', '/F'],
      { allowFailure: true },
    );
    await wait(100);
    if (result.code !== 0 && child.exitCode === null) {
      throw new Error(`Could not stop managed process tree ${child.pid}.`);
    }
    return;
  }

  const exited = new Promise((resolve) => child.once('exit', resolve));
  try {
    child.kill('SIGTERM');
  } catch {
    // The process may have exited between the checks above.
  }

  const graceful = await Promise.race([
    exited.then(() => true),
    wait(graceMilliseconds).then(() => false),
  ]);
  if (graceful || child.exitCode !== null) return;

  try {
    child.kill('SIGKILL');
  } catch {
    // It exited while the fallback was being applied.
  }
}

function runCapturedCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd ?? repositoryRoot,
      env: options.env ?? process.env,
      shell: false,
      windowsHide: true,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    let aborted = false;

    const onAbort = () => {
      aborted = true;
      void terminateProcessTree(child, 1_000);
    };
    options.signal?.addEventListener('abort', onAbort, { once: true });
    child.stdout.on('data', (chunk) => { stdout += chunk.toString(); });
    child.stderr.on('data', (chunk) => { stderr += chunk.toString(); });
    child.once('error', reject);
    child.once('exit', (code) => {
      options.signal?.removeEventListener('abort', onAbort);
      if (aborted) {
        reject(options.signal.reason ?? new Error('Smoke execution was interrupted.'));
      } else if (code === 0 || options.allowFailure) {
        resolve({ code: code ?? 1, stdout, stderr });
      } else {
        reject(
          new Error(
            `${path.basename(command)} exited with ${code ?? 1}: ${stderr.trim() || stdout.trim()}`,
          ),
        );
      }
    });
  });
}

function runInheritedCommand(command, args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: options.cwd ?? backendRoot,
      env: options.env ?? process.env,
      shell: false,
      windowsHide: true,
      stdio: 'inherit',
    });
    let settled = false;
    let aborted = false;

    const finish = (error) => {
      if (settled) return;
      settled = true;
      options.signal?.removeEventListener('abort', onAbort);
      if (error) reject(error);
      else resolve();
    };
    const onAbort = () => {
      aborted = true;
      void terminateProcessTree(child, 1_000);
    };
    options.signal?.addEventListener('abort', onAbort, { once: true });
    child.once('error', finish);
    child.once('exit', (code) => {
      if (aborted) {
        finish(options.signal.reason ?? new Error('Smoke execution was interrupted.'));
      } else if (code === 0) {
        finish();
      } else {
        finish(new Error(`${path.basename(command)} exited with ${code ?? 1}.`));
      }
    });
  });
}

async function mappedPort(service, containerPort, signal) {
  const result = await runCapturedCommand(
    'docker',
    ['compose', 'port', service, String(containerPort)],
    { cwd: repositoryRoot, signal },
  );
  const match = result.stdout.trim().match(/:(\d+)$/);
  if (!match) {
    throw new Error(`Could not resolve the published port for ${service}:${containerPort}.`);
  }
  return match[1];
}

async function discoverCompose(signal) {
  for (const service of ['db', 'redis', 'media']) {
    const running = await runCapturedCommand(
      'docker',
      ['compose', 'ps', '--status', 'running', '-q', service],
      { cwd: repositoryRoot, signal },
    );
    if (!running.stdout.trim()) {
      throw new Error(`Docker Compose service "${service}" is not running.`);
    }
  }

  const rendered = await runCapturedCommand(
    'docker',
    ['compose', 'config', '--format', 'json'],
    { cwd: repositoryRoot, signal },
  );
  const config = JSON.parse(rendered.stdout);
  const postgres = composeEnvironment(config.services?.db?.environment);
  const media = composeEnvironment(config.services?.media?.environment);
  if (!postgres.POSTGRES_USER || !postgres.POSTGRES_PASSWORD) {
    throw new Error('PostgreSQL Compose credentials are incomplete.');
  }
  if (!media.MINIO_ROOT_USER || !media.MINIO_ROOT_PASSWORD) {
    throw new Error('MinIO Compose credentials are incomplete.');
  }

  return {
    postgresUser: postgres.POSTGRES_USER,
    postgresPassword: postgres.POSTGRES_PASSWORD,
    postgresPort: await mappedPort('db', 5432, signal),
    redisPort: await mappedPort('redis', 6379, signal),
    mediaPort: await mappedPort('media', 9000, signal),
    mediaAccessKey: media.MINIO_ROOT_USER,
    mediaSecretKey: media.MINIO_ROOT_PASSWORD,
  };
}

function postgresUrl(discovery, databaseName) {
  const url = new URL('postgresql://127.0.0.1');
  url.username = discovery.postgresUser;
  url.password = discovery.postgresPassword;
  url.port = discovery.postgresPort;
  url.pathname = `/${databaseName}`;
  url.searchParams.set('schema', 'public');
  // The live server's pool: Prisma's default on its one core is 3 (the
  // number of cores x 2 + 1). A request that holds one connection and waits
  // for a second deadlocks there under a few requests at once (RA-BE-91,
  // RA-BE-108); smokes that send requests together see it here too.
  url.searchParams.set('connection_limit', '3');
  return url.toString();
}

async function availablePort() {
  return new Promise((resolve, reject) => {
    const server = net.createServer();
    server.unref();
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      const address = server.address();
      const port = typeof address === 'object' && address ? address.port : null;
      server.close((error) => {
        if (error) reject(error);
        else if (!port) reject(new Error('Could not reserve a backend port.'));
        else resolve(port);
      });
    });
  });
}

function buildManagedEnvironment(discovery, identity, backendPort) {
  const databaseUrl = postgresUrl(discovery, identity.databaseName);
  const baseUrl = `http://127.0.0.1:${backendPort}`;
  const mediaEndpoint = `http://127.0.0.1:${discovery.mediaPort}`;
  const redisUrl = `redis://127.0.0.1:${discovery.redisPort}/${SMOKE_REDIS_DATABASE}`;
  const environment = {
    ...process.env,
    NODE_ENV: 'development',
    PORT: String(backendPort),
    DATABASE_URL: databaseUrl,
    SMOKE_DATABASE_URL: databaseUrl,
    SMOKE_BASE_URL: baseUrl,
    AARAST_SMOKE_MANAGED: '1',
    AARAST_SMOKE_RUN_ID: identity.runId,
    AARAST_SMOKE_EXPECTED_DATABASE: identity.databaseName,
    AARAST_SMOKE_EXPECTED_BASE_URL: baseUrl,
    AARAST_SMOKE_EXPECTED_BUCKET: identity.bucketName,
    AARAST_SMOKE_EXPECTED_REDIS_DB: SMOKE_REDIS_DATABASE,
    JWT_SECRET: process.env.JWT_SECRET || randomBytes(32).toString('hex'),
    AUTH_LOGIN_THROTTLE_PEPPER:
      process.env.AUTH_LOGIN_THROTTLE_PEPPER || randomBytes(32).toString('hex'),
    AUTH_OTP_MODE: 'dev',
    AUTH_DEV_OTP_CODE: process.env.AUTH_DEV_OTP_CODE || '123456',
    SENTRY_DSN: '',
    REDIS_URL: redisUrl,
    READINESS_REQUIRE_REDIS: 'true',
    READINESS_REQUIRE_MEDIA: 'true',
    AARAST_MEDIA_ENDPOINT: mediaEndpoint,
    AARAST_MEDIA_SIGNED_ENDPOINT: mediaEndpoint,
    AARAST_MEDIA_BUCKET: identity.bucketName,
    AARAST_MEDIA_PUBLIC_BASE_URL: `${mediaEndpoint}/${identity.bucketName}`,
    AARAST_MEDIA_REGION: 'us-east-1',
    AARAST_MEDIA_FORCE_PATH_STYLE: 'true',
    AARAST_MEDIA_ACCESS_KEY_ID: discovery.mediaAccessKey,
    AARAST_MEDIA_SECRET_ACCESS_KEY: discovery.mediaSecretKey,
  };
  assertManagedSmokeEnvironment(environment);
  return environment;
}

async function createDatabase(discovery, identity, signal) {
  assertSafeSmokeDatabaseUrl(
    postgresUrl(discovery, identity.databaseName),
    identity.databaseName,
  );
  const database = safePostgresIdentifier(identity.databaseName, 'Smoke database');
  const owner = safePostgresIdentifier(discovery.postgresUser, 'PostgreSQL owner');
  await runCapturedCommand(
    'docker',
    [
      'compose', 'exec', '-T', 'db', 'psql', '-X', '-v', 'ON_ERROR_STOP=1',
      '-U', discovery.postgresUser, '-d', 'postgres', '-c',
      `CREATE DATABASE ${database} OWNER ${owner};`,
    ],
    { cwd: repositoryRoot, signal },
  );
}

async function dropDatabase(discovery, identity) {
  assertExactRunResource(
    identity.databaseName,
    `aarast_${identity.runId}`,
    'PostgreSQL database',
  );
  const database = safePostgresIdentifier(identity.databaseName, 'Smoke database');
  await runCapturedCommand(
    'docker',
    [
      'compose', 'exec', '-T', 'db', 'psql', '-X', '-v', 'ON_ERROR_STOP=1',
      '-U', discovery.postgresUser, '-d', 'postgres', '-c',
      `DROP DATABASE ${database} WITH (FORCE);`,
    ],
    { cwd: repositoryRoot },
  );
}

async function reserveRedis(environment, identity) {
  const redis = new Redis(environment.REDIS_URL, {
    lazyConnect: true,
    connectTimeout: 5_000,
    maxRetriesPerRequest: 1,
  });
  redis.on('error', () => {});
  try {
    await redis.connect();
    const existingKeys = await redis.dbsize();
    if (existingKeys !== 0) {
      throw new Error(
        `Dedicated Redis DB ${SMOKE_REDIS_DATABASE} is not empty; refusing to delete unknown keys.`,
      );
    }
    const locked = await redis.set(
      REDIS_LOCK_KEY,
      identity.runId,
      'EX',
      7_200,
      'NX',
    );
    if (locked !== 'OK') {
      throw new Error('Could not reserve the dedicated Redis smoke database.');
    }
    return redis;
  } catch (error) {
    redis.disconnect();
    throw error;
  }
}

async function releaseRedis(redis, identity) {
  try {
    const owner = await redis.get(REDIS_LOCK_KEY);
    if (owner !== identity.runId) {
      throw new Error(
        'Refusing Redis cleanup because the smoke run no longer owns the namespace.',
      );
    }
    await redis.flushdb();
    if ((await redis.dbsize()) !== 0) {
      throw new Error('Redis smoke database was not emptied.');
    }
    await redis.quit();
  } catch (error) {
    redis.disconnect();
    throw error;
  }
}

function mediaClient(discovery) {
  return new S3Client({
    endpoint: `http://127.0.0.1:${discovery.mediaPort}`,
    region: 'us-east-1',
    forcePathStyle: true,
    credentials: {
      accessKeyId: discovery.mediaAccessKey,
      secretAccessKey: discovery.mediaSecretKey,
    },
  });
}

async function createBucket(discovery, identity) {
  assertExactRunResource(
    identity.bucketName,
    `aarast-${identity.runId.replace(/_/g, '-')}`,
    'MinIO bucket',
  );
  const client = mediaClient(discovery);
  try {
    await client.send(new CreateBucketCommand({ Bucket: identity.bucketName }));
    return client;
  } catch (error) {
    client.destroy();
    throw error;
  }
}

async function configureBucket(client, identity) {
  const publicPrefixes = [
    'user-avatar',
    'provider-logo',
    'provider-cover',
    'service-image',
    // B-16: listed to customers only after review; a refused one is deleted.
    'provider-portfolio',
    // D83: the invitation card photo, read on the public RSVP page.
    'guest-invitation-card',
  ];
  await client.send(new PutBucketPolicyCommand({
    Bucket: identity.bucketName,
    Policy: JSON.stringify({
      Version: '2012-10-17',
      Statement: [{
        Sid: 'SmokePublicMediaPrefixes',
        Effect: 'Allow',
        Principal: '*',
        Action: ['s3:GetObject'],
        Resource: publicPrefixes.map(
          (prefix) => `arn:aws:s3:::${identity.bucketName}/${prefix}/*`,
        ),
      }],
    }),
  }));
}

async function deleteBucket(client, identity) {
  assertExactRunResource(
    identity.bucketName,
    `aarast-${identity.runId.replace(/_/g, '-')}`,
    'MinIO bucket',
  );
  try {
    let continuationToken;
    do {
      const page = await client.send(new ListObjectsV2Command({
        Bucket: identity.bucketName,
        ContinuationToken: continuationToken,
      }));
      const objects = (page.Contents ?? [])
        .filter((item) => item.Key)
        .map((item) => ({ Key: item.Key }));
      if (objects.length > 0) {
        await client.send(new DeleteObjectsCommand({
          Bucket: identity.bucketName,
          Delete: { Objects: objects, Quiet: true },
        }));
      }
      continuationToken = page.IsTruncated
        ? page.NextContinuationToken
        : undefined;
    } while (continuationToken);

    const multipart = await client.send(new ListMultipartUploadsCommand({
      Bucket: identity.bucketName,
    }));
    for (const upload of multipart.Uploads ?? []) {
      if (upload.Key && upload.UploadId) {
        await client.send(new AbortMultipartUploadCommand({
          Bucket: identity.bucketName,
          Key: upload.Key,
          UploadId: upload.UploadId,
        }));
      }
    }
    await client.send(new DeleteBucketCommand({ Bucket: identity.bucketName }));
  } finally {
    client.destroy();
  }
}

async function migrateDatabase(environment, signal) {
  if (!existsSync(prismaCli)) {
    throw new Error('Prisma CLI is not installed. Run npm ci before smoke tests.');
  }
  await runInheritedCommand(
    process.execPath,
    [prismaCli, 'migrate', 'deploy'],
    { cwd: backendRoot, env: environment, signal },
  );
}

function startBackend(environment) {
  const child = spawn(
    process.execPath,
    [
      '-r', require.resolve('ts-node/register'),
      '-r', require.resolve('tsconfig-paths/register'),
      path.join(backendRoot, 'src', 'main.ts'),
    ],
    {
      cwd: backendRoot,
      env: environment,
      shell: false,
      windowsHide: true,
      stdio: 'inherit',
    },
  );
  child.spawnError = null;
  child.once('error', (error) => { child.spawnError = error; });
  return child;
}

async function waitForBackend(child, baseUrl, signal) {
  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    if (signal?.aborted) {
      throw signal.reason ?? new Error('Smoke execution was interrupted.');
    }
    if (child.spawnError) throw child.spawnError;
    if (child.exitCode !== null) {
      throw new Error(`Isolated backend exited with ${child.exitCode}.`);
    }
    try {
      const response = await fetch(`${baseUrl}/ready`, { signal });
      if (response.ok) return;
    } catch (error) {
      if (signal?.aborted) throw error;
    }
    await wait(400);
  }
  throw new Error('Timed out waiting for the isolated backend /ready endpoint.');
}

function validateSmokeScripts(values) {
  const scripts = values.length > 0 ? values : ['all-smoke.js'];
  const externalTargets = new Set([
    '--admin-runtime',
    '--contributor-history-migration',
    '--guest-phone-migration',
    '--schema-equivalence',
    '--load-test',
  ]);
  if (scripts.some((value) => externalTargets.has(value)) && scripts.length !== 1) {
    throw new Error('External managed checks must run in their own isolated lifecycle.');
  }
  if (scripts.includes('all-smoke.js') && scripts.length !== 1) {
    throw new Error('all-smoke.js cannot be combined with another smoke script.');
  }
  for (const fileName of scripts) {
    if (externalTargets.has(fileName)) continue;
    if (
      path.basename(fileName) !== fileName ||
      !/^[a-z0-9-]+-smoke\.(?:js|ts)$/.test(fileName) ||
      !existsSync(path.join(__dirname, fileName))
    ) {
      throw new Error(`Unknown smoke script "${fileName}".`);
    }
  }
  return scripts;
}

async function runSmokeScripts(scripts, environment, signal) {
  for (const [index, fileName] of scripts.entries()) {
    let target = path.join(__dirname, fileName);
    let cwd = backendRoot;
    let childEnvironment = {
      ...environment,
      SMOKE_CLIENT_IP: `198.18.1.${index + 1}`,
    };
    if (fileName === '--admin-runtime') {
      target = path.join(adminWebRoot, 'scripts', 'admin-runtime-smoke.mjs');
      cwd = adminWebRoot;
      childEnvironment = {
        ...childEnvironment,
        ADMIN_SMOKE_BASE_URL: environment.SMOKE_BASE_URL,
        ADMIN_SMOKE_DATABASE_URL: environment.SMOKE_DATABASE_URL,
        ADMIN_SMOKE_OTP_CODE: environment.AUTH_DEV_OTP_CODE,
        VITE_API_BASE_URL: environment.SMOKE_BASE_URL,
      };
    } else if (fileName === '--load-test') {
      target = path.join(backendRoot, 'scripts', 'load', 'load-test.js');
      childEnvironment = {
        ...childEnvironment,
        LOAD_BASE_URL: environment.SMOKE_BASE_URL,
      };
    }

    const args = [];
    if (fileName !== 'all-smoke.js') {
      args.push('-r', isolationHook);
    }
    if (fileName.endsWith('.ts')) {
      args.push('-r', require.resolve('ts-node/register'));
    }
    args.push(target);
    await runInheritedCommand(process.execPath, args, {
      cwd,
      env: childEnvironment,
      signal,
    });
  }
}

class CleanupStack {
  constructor() {
    this.entries = [];
  }

  add(label, cleanup) {
    this.entries.unshift({ label, cleanup });
  }

  async run() {
    const errors = [];
    for (const entry of this.entries) {
      try {
        await entry.cleanup();
      } catch (error) {
        errors.push(new Error(`${entry.label} cleanup failed: ${error.message}`));
      }
    }
    if (errors.length > 0) {
      throw new AggregateError(errors, 'Managed smoke cleanup failed.');
    }
  }
}

async function executeManagedRun(steps) {
  const cleanup = new CleanupStack();
  let primaryError = null;
  try {
    await steps.createDatabase();
    cleanup.add('PostgreSQL database', steps.dropDatabase);

    const redis = await steps.reserveRedis();
    cleanup.add('Redis namespace', () => steps.releaseRedis(redis));

    const bucket = await steps.createBucket();
    cleanup.add('MinIO bucket', () => steps.deleteBucket(bucket));
    await steps.configureBucket(bucket);

    await steps.migrateDatabase();
    const backend = steps.startBackend();
    cleanup.add('Backend process', () => steps.stopBackend(backend));
    await steps.waitForBackend(backend);
    await steps.runSmokeScripts();
  } catch (error) {
    primaryError = error;
  }

  let cleanupError = null;
  try {
    await cleanup.run();
  } catch (error) {
    cleanupError = error;
  }

  if (primaryError && cleanupError) {
    throw new AggregateError(
      [primaryError, cleanupError],
      'Managed smoke failed and cleanup was incomplete.',
    );
  }
  if (primaryError) throw primaryError;
  if (cleanupError) throw cleanupError;
}

async function executeManagedDatabaseRun(steps) {
  const cleanup = new CleanupStack();
  let primaryError = null;
  try {
    await steps.createDatabase();
    cleanup.add('PostgreSQL database', steps.dropDatabase);
    await steps.runSmoke();
  } catch (error) {
    primaryError = error;
  }

  let cleanupError = null;
  try {
    await cleanup.run();
  } catch (error) {
    cleanupError = error;
  }

  if (primaryError && cleanupError) {
    throw new AggregateError(
      [primaryError, cleanupError],
      'Managed database smoke failed and cleanup was incomplete.',
    );
  }
  if (primaryError) throw primaryError;
  if (cleanupError) throw cleanupError;
}

function errorMessages(error) {
  if (error instanceof AggregateError) {
    return [error.message, ...error.errors.flatMap(errorMessages)];
  }
  return [error instanceof Error ? error.message : String(error)];
}

async function main(args = process.argv.slice(2)) {
  loadLocalEnvFile();
  const scripts = validateSmokeScripts(args);
  const identity = createRunIdentity();
  const abortController = new AbortController();
  let interruptedBy = null;
  const interrupt = (signalName) => {
    interruptedBy = signalName;
    abortController.abort(new Error(`Managed smoke interrupted by ${signalName}.`));
  };
  const onSigInt = () => interrupt('SIGINT');
  const onSigTerm = () => interrupt('SIGTERM');
  process.once('SIGINT', onSigInt);
  process.once('SIGTERM', onSigTerm);

  try {
    const discovery = await discoverCompose(abortController.signal);
    const backendPort = await availablePort();
    const environment = buildManagedEnvironment(
      discovery,
      identity,
      backendPort,
    );
    if (scripts.includes('--load-test')) {
      environment.THROTTLE_LIMIT = process.env.LOAD_THROTTLE_LIMIT || '1000000';
    }
    if (scripts.includes('assistant-smoke.js') || scripts.includes('all-smoke.js')) {
      // V1 checklist 4.12: the planning assistant answers through the smoke's
      // local stand-in for the Claude API (never the real one, never a real key).
      const modelPort = await availablePort();
      environment.ANTHROPIC_API_KEY = 'smoke-assistant-key';
      environment.ANTHROPIC_BASE_URL = `http://127.0.0.1:${modelPort}`;
      environment.AARAST_ASSISTANT_DAILY_LIMIT = '2';
      environment.SMOKE_ASSISTANT_MODEL_PORT = String(modelPort);
    }
    console.log(`Managed smoke run: ${identity.runId}`);
    console.log(`Isolated database: ${identity.databaseName}`);
    const databaseOnlySmoke = new Map([
      ['--contributor-history-migration', 'contributor-history-migration-smoke.js'],
      ['--guest-phone-migration', 'guest-phone-migration-smoke.js'],
      ['--schema-equivalence', 'schema-equivalence-smoke.js'],
    ]).get(scripts[0]);
    if (databaseOnlySmoke) {
      await executeManagedDatabaseRun({
        createDatabase: () =>
          createDatabase(discovery, identity, abortController.signal),
        dropDatabase: () => dropDatabase(discovery, identity),
        runSmoke: () =>
          runInheritedCommand(
            process.execPath,
            [
              '-r',
              isolationHook,
              path.join(__dirname, databaseOnlySmoke),
            ],
            {
              cwd: backendRoot,
              env: environment,
              signal: abortController.signal,
            },
          ),
      });
      if (interruptedBy) {
        throw new Error(`Managed smoke interrupted by ${interruptedBy}.`);
      }
      return;
    }

    console.log(`Isolated backend: ${environment.SMOKE_BASE_URL}`);

    await executeManagedRun({
      createDatabase: () => createDatabase(discovery, identity, abortController.signal),
      dropDatabase: () => dropDatabase(discovery, identity),
      reserveRedis: () => reserveRedis(environment, identity),
      releaseRedis: (redis) => releaseRedis(redis, identity),
      createBucket: () => createBucket(discovery, identity),
      configureBucket: (client) => configureBucket(client, identity),
      deleteBucket: (client) => deleteBucket(client, identity),
      migrateDatabase: () => migrateDatabase(environment, abortController.signal),
      startBackend: () => startBackend(environment),
      stopBackend: (backend) => terminateProcessTree(backend),
      waitForBackend: (backend) => waitForBackend(
        backend,
        environment.SMOKE_BASE_URL,
        abortController.signal,
      ),
      runSmokeScripts: () => runSmokeScripts(
        scripts,
        environment,
        abortController.signal,
      ),
    });
    if (interruptedBy) {
      throw new Error(`Managed smoke interrupted by ${interruptedBy}.`);
    }
  } finally {
    process.removeListener('SIGINT', onSigInt);
    process.removeListener('SIGTERM', onSigTerm);
  }
}

if (require.main === module) {
  main().catch((error) => {
    for (const message of errorMessages(error)) {
      console.error(`ERROR - ${message}`);
    }
    process.exitCode = 1;
  });
}

module.exports = {
  CleanupStack,
  assertExactRunResource,
  buildManagedEnvironment,
  composeEnvironment,
  createRunIdentity,
  errorMessages,
  executeManagedDatabaseRun,
  executeManagedRun,
  safePostgresIdentifier,
  validateSmokeScripts,
};
