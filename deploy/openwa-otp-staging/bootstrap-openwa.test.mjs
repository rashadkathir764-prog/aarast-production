import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import fs from 'node:fs/promises';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const scriptPath = path.join(
  path.dirname(new URL(import.meta.url).pathname.replace(/^\/(.:)/, '$1')),
  'bootstrap-openwa.mjs',
);
const masterKey = 'm'.repeat(32);

function createOpenWaMock() {
  const state = {
    sessions: [],
    keys: [],
    keySequence: 0,
    keyCreates: 0,
    transientValidateAttempts: 0,
    startMode: 'normal',
    requestDelayMs: 0,
    rejectNewestReadiness: false,
  };

  const server = http.createServer(async (request, response) => {
    if (state.requestDelayMs > 0) {
      await new Promise((resolve) => setTimeout(resolve, state.requestDelayMs));
    }
    const url = new URL(request.url, 'http://127.0.0.1');
    const route = url.pathname.replace(/^\/api/, '');
    const apiKey = request.headers['x-api-key'];
    const body = await readJson(request);
    const key = state.keys.find(
      (candidate) =>
        candidate.raw === apiKey &&
        candidate.isActive &&
        Date.parse(candidate.expiresAt) > Date.now(),
    );
    const isMaster = apiKey === masterKey;

    if (route === '/sessions' && request.method === 'GET' && isMaster) {
      return json(response, 200, state.sessions);
    }
    if (route === '/sessions' && request.method === 'POST' && isMaster) {
      const session = {
        id: `session-${state.sessions.length + 1}`,
        name: body.name,
        status: 'created',
        phone: null,
      };
      state.sessions.push(session);
      return json(response, 201, session);
    }
    if (route === '/auth/api-keys' && request.method === 'GET' && isMaster) {
      return json(
        response,
        200,
        state.keys.map(({ raw: _raw, ...record }) => record),
      );
    }
    if (route === '/auth/api-keys' && request.method === 'POST' && isMaster) {
      state.keySequence += 1;
      state.keyCreates += 1;
      const raw = `owa_k1_${String(state.keySequence).padStart(5, '0')}${'a'.repeat(59)}`;
      const record = {
        id: `key-${state.keySequence}`,
        name: body.name,
        role: body.role,
        allowedSessions: body.allowedSessions,
        expiresAt: body.expiresAt,
        isActive: true,
        keyPrefix: raw.slice(0, 12),
        raw,
      };
      state.keys.push(record);
      return json(response, 201, { ...record, apiKey: raw });
    }
    const deleteMatch = route.match(/^\/auth\/api-keys\/([^/]+)$/);
    if (deleteMatch && request.method === 'PUT' && isMaster) {
      const record = state.keys.find((candidate) => candidate.id === deleteMatch[1]);
      if (!record) return json(response, 404, { statusCode: 404 });
      if (body.name) record.name = body.name;
      return json(response, 200, { ...record, raw: undefined });
    }
    if (deleteMatch && request.method === 'DELETE' && isMaster) {
      state.keys = state.keys.filter((candidate) => candidate.id !== deleteMatch[1]);
      response.writeHead(204).end();
      return;
    }
    if (
      route === '/auth/validate' &&
      request.method === 'POST' &&
      key?.role === 'transient_sender'
    ) {
      state.transientValidateAttempts += 1;
      return json(response, 403, { statusCode: 403 });
    }
    if (route === '/auth/validate' && request.method === 'POST' && key) {
      return json(response, 200, { valid: true, role: key.role });
    }

    const readinessMatch = route.match(/^\/sessions\/([^/]+)\/otp-readiness$/);
    if (
      readinessMatch &&
      request.method === 'GET' &&
      key?.role === 'transient_sender' &&
      key.allowedSessions.includes(readinessMatch[1])
    ) {
      if (
        state.rejectNewestReadiness &&
        key.id === `key-${state.keySequence}`
      ) {
        return json(response, 503, { statusCode: 503 });
      }
      return json(response, 200, { ready: false, transientText: true });
    }
    const startMatch = route.match(/^\/sessions\/([^/]+)\/start$/);
    if (startMatch && request.method === 'POST' && isMaster) {
      const session = state.sessions.find((candidate) => candidate.id === startMatch[1]);
      if (!session) return json(response, 404, { statusCode: 404 });
      if (state.startMode === 'nonbenign') {
        session.status = 'created';
        return json(response, 400, { statusCode: 400 });
      }
      if (session.status !== 'created') return json(response, 400, { statusCode: 400 });
      session.status = 'qr_ready';
      return json(response, 200, session);
    }
    const sessionMatch = route.match(/^\/sessions\/([^/]+)$/);
    if (sessionMatch && request.method === 'GET') {
      const session = state.sessions.find((candidate) => candidate.id === sessionMatch[1]);
      if (!session) return json(response, 404, { statusCode: 404 });
      if (
        !isMaster &&
        !(key?.role === 'viewer' && key.allowedSessions.includes(session.id))
      ) {
        return json(response, 403, { statusCode: 403 });
      }
      return json(response, 200, session);
    }
    return json(response, apiKey ? 403 : 401, { statusCode: apiKey ? 403 : 401 });
  });

  return { server, state };
}

async function readJson(request) {
  const chunks = [];
  for await (const chunk of request) chunks.push(chunk);
  if (chunks.length === 0) return {};
  return JSON.parse(Buffer.concat(chunks).toString('utf8'));
}

function json(response, status, body) {
  response.writeHead(status, { 'content-type': 'application/json' });
  response.end(JSON.stringify(body));
}

async function listen(server) {
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  return `http://127.0.0.1:${server.address().port}`;
}

async function createSecretPaths() {
  const root = await fs.mkdtemp(path.join(os.tmpdir(), 'aarast-openwa-bootstrap-'));
  const backend = path.join(root, 'backend');
  const operator = path.join(root, 'operator');
  await fs.mkdir(backend);
  await fs.mkdir(operator);
  return {
    root,
    staging: path.join(backend, 'openwa.env'),
    production: path.join(root, 'production', 'openwa.env'),
    audit: path.join(operator, 'openwa-audit.env'),
    lock: path.join(operator, 'bootstrap.lock'),
  };
}

async function runBootstrap(baseUrl, paths, extraEnvironment = {}) {
  await fs.mkdir(path.dirname(paths.production), { recursive: true });
  return execFileAsync(process.execPath, [scriptPath], {
    env: {
      ...process.env,
      OPENWA_BASE_URL: baseUrl,
      OPENWA_MASTER_KEY: masterKey,
      OPENWA_SESSION_NAME: 'aarast-otp-staging',
      OPENWA_KEY_TTL_DAYS: '7',
      OPENWA_STAGING_TRANSPORT_SECRET_PATH: paths.staging,
      OPENWA_PRODUCTION_TRANSPORT_SECRET_PATH: paths.production,
      OPENWA_AUDIT_SECRET_PATH: paths.audit,
      OPENWA_BOOTSTRAP_LOCK_PATH: paths.lock,
      ...extraEnvironment,
    },
  });
}

async function parseSecret(secretPath) {
  return Object.fromEntries(
    (await fs.readFile(secretPath, 'utf8'))
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => line.split(/=(.*)/s).slice(0, 2)),
  );
}

test('fresh and recreated bootstrap stays idempotent and rotates a revoked key', async (t) => {
  const { server, state } = createOpenWaMock();
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await fs.writeFile(`${paths.staging}.stale.tmp`, 'stale');
  await runBootstrap(baseUrl, paths);
  assert.equal(state.keyCreates, 3);
  assert.deepEqual(
    state.keys.map((key) => key.role).sort(),
    ['transient_sender', 'transient_sender', 'viewer'],
  );
  assert.equal(state.transientValidateAttempts, 0);
  await assert.rejects(fs.access(`${paths.staging}.stale.tmp`));

  await runBootstrap(baseUrl, paths);
  assert.equal(state.keyCreates, 3);
  assert.equal(state.keys.length, 3);

  const oldTransport = state.keys.find((key) => key.name === 'Aarast OTP transport staging');
  oldTransport.isActive = false;
  await runBootstrap(baseUrl, paths);
  assert.equal(state.keyCreates, 4);
  assert.equal(state.keys.length, 3);
  const transportSecret = await parseSecret(paths.staging);
  assert.notEqual(transportSecret.OPENWA_API_KEY_ID, oldTransport.id);
});

test('orphan keys and a deleted session are reconciled without widening scope', async (t) => {
  const { server, state } = createOpenWaMock();
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await runBootstrap(baseUrl, paths);
  const firstSessionId = state.sessions[0].id;
  state.sessions = [
    { id: 'session-replacement', name: 'aarast-otp-staging', status: 'created', phone: null },
  ];
  await runBootstrap(baseUrl, paths);
  assert.equal(state.keys.length, 3);
  assert.ok(state.keys.every((key) => key.allowedSessions[0] === 'session-replacement'));
  assert.ok(state.keys.every((key) => key.allowedSessions.length === 1));
  assert.ok(state.keys.every((key) => key.expiresAt));
  assert.notEqual((await parseSecret(paths.staging)).OPENWA_SESSION_ID, firstSessionId);
});

test('a non-benign start 400 fails closed', async (t) => {
  const { server, state } = createOpenWaMock();
  state.startMode = 'nonbenign';
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await assert.rejects(runBootstrap(baseUrl, paths));
  assert.equal(state.sessions[0].status, 'created');
});

test('credential rotation begins before expiry and keeps the previous key valid', async (t) => {
  const { server, state } = createOpenWaMock();
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await runBootstrap(baseUrl, paths);
  const previous = state.keys.find((key) => key.name === 'Aarast OTP transport staging');
  previous.expiresAt = new Date(Date.now() + 36 * 60 * 60 * 1000).toISOString();

  await runBootstrap(baseUrl, paths);

  const currentSecret = await parseSecret(paths.staging);
  assert.equal(state.keyCreates, 4);
  assert.notEqual(currentSecret.OPENWA_API_KEY_ID, previous.id);
  assert.equal(state.keys.some((key) => key.id === previous.id), true);
  assert.equal(previous.isActive, true);

  const firstReplacement = state.keys.find(
    (key) => key.id === currentSecret.OPENWA_API_KEY_ID,
  );
  firstReplacement.expiresAt = new Date(
    Date.now() + 36 * 60 * 60 * 1000,
  ).toISOString();
  await runBootstrap(baseUrl, paths);

  const stagingKeys = state.keys.filter((key) =>
    ['Aarast OTP transport staging', 'Aarast OTP transport'].includes(key.name),
  );
  assert.equal(state.keyCreates, 5);
  assert.equal(stagingKeys.length, 2);
  assert.equal(stagingKeys.some((key) => key.id === previous.id), false);
});

test('a replaced key with widened session scope is removed after the safe key is installed', async (t) => {
  const { server, state } = createOpenWaMock();
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await runBootstrap(baseUrl, paths);
  const widened = state.keys.find(
    (key) => key.name === 'Aarast OTP transport staging',
  );
  widened.allowedSessions = [state.sessions[0].id, 'unexpected-session'];

  await runBootstrap(baseUrl, paths);

  assert.equal(state.keyCreates, 4);
  assert.equal(state.keys.some((key) => key.id === widened.id), false);
  const current = await parseSecret(paths.staging);
  assert.notEqual(current.OPENWA_API_KEY_ID, widened.id);
});

test('concurrent reconciliation is serialized before session or key creation', async (t) => {
  const { server, state } = createOpenWaMock();
  state.requestDelayMs = 25;
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  const outcomes = await Promise.allSettled([
    runBootstrap(baseUrl, paths),
    runBootstrap(baseUrl, paths),
  ]);

  assert.equal(outcomes.filter((outcome) => outcome.status === 'fulfilled').length, 1);
  assert.equal(outcomes.filter((outcome) => outcome.status === 'rejected').length, 1);
  assert.equal(state.sessions.length, 1);
  assert.equal(state.keyCreates, 3);
});

test('duplicate named sessions fail closed before credentials are created', async (t) => {
  const { server, state } = createOpenWaMock();
  state.sessions = [
    { id: 'session-one', name: 'aarast-otp-staging', status: 'ready', phone: null },
    { id: 'session-two', name: 'aarast-otp-staging', status: 'ready', phone: null },
  ];
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await assert.rejects(runBootstrap(baseUrl, paths));
  assert.equal(state.keyCreates, 0);
  assert.equal(state.keys.length, 0);
});

test('a failed replacement validation preserves the current file and removes the candidate', async (t) => {
  const { server, state } = createOpenWaMock();
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await runBootstrap(baseUrl, paths);
  const before = await parseSecret(paths.staging);
  const current = state.keys.find((key) => key.id === before.OPENWA_API_KEY_ID);
  current.expiresAt = new Date(Date.now() + 36 * 60 * 60 * 1000).toISOString();
  state.rejectNewestReadiness = true;

  await assert.rejects(runBootstrap(baseUrl, paths));

  const after = await parseSecret(paths.staging);
  assert.equal(after.OPENWA_API_KEY_ID, before.OPENWA_API_KEY_ID);
  assert.equal(state.keys.some((key) => key.id === current.id), true);
  assert.equal(state.keys.length, 3);
  assert.equal(state.keyCreates, 4);
});

test('unknown fields in an existing credential fail closed without creating keys', async (t) => {
  const { server, state } = createOpenWaMock();
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await runBootstrap(baseUrl, paths);
  await fs.appendFile(paths.staging, 'UNREVIEWED_FIELD=value\n');
  const createsBefore = state.keyCreates;

  await assert.rejects(runBootstrap(baseUrl, paths));
  assert.equal(state.keyCreates, createsBefore);
});

test('the legacy shared transport migrates in place while production receives a distinct key', async (t) => {
  const { server, state } = createOpenWaMock();
  const baseUrl = await listen(server);
  const paths = await createSecretPaths();
  t.after(async () => {
    server.close();
    await fs.rm(paths.root, { recursive: true, force: true });
  });

  await runBootstrap(baseUrl, paths);
  const stagingBefore = await parseSecret(paths.staging);
  const legacyKey = state.keys.find(
    (key) => key.id === stagingBefore.OPENWA_API_KEY_ID,
  );
  legacyKey.name = 'Aarast OTP transport';
  const productionBefore = await parseSecret(paths.production);
  state.keys = state.keys.filter(
    (key) => key.id !== productionBefore.OPENWA_API_KEY_ID,
  );
  await fs.rm(paths.production, { force: true });
  await fs.writeFile(
    paths.staging,
    [
      `OPENWA_SESSION_ID=${stagingBefore.OPENWA_SESSION_ID}`,
      `OPENWA_API_KEY_ID=${stagingBefore.OPENWA_API_KEY_ID}`,
      `OPENWA_API_KEY=${stagingBefore.OPENWA_API_KEY}`,
      '',
    ].join('\n'),
    { mode: 0o600 },
  );

  await runBootstrap(baseUrl, paths);

  const stagingAfter = await parseSecret(paths.staging);
  const productionAfter = await parseSecret(paths.production);
  assert.equal(stagingAfter.OPENWA_API_KEY_ID, stagingBefore.OPENWA_API_KEY_ID);
  assert.notEqual(productionAfter.OPENWA_API_KEY_ID, stagingAfter.OPENWA_API_KEY_ID);
  assert.equal(productionAfter.OPENWA_SESSION_ID, stagingAfter.OPENWA_SESSION_ID);
  assert.equal(legacyKey.name, 'Aarast OTP transport staging');
  assert.equal(state.keys.length, 3);
  assert.equal(state.keyCreates, 4);
});
