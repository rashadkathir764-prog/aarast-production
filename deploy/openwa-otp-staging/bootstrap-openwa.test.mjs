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
  };

  const server = http.createServer(async (request, response) => {
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
    transport: path.join(backend, 'openwa.env'),
    audit: path.join(operator, 'openwa-audit.env'),
  };
}

async function runBootstrap(baseUrl, paths) {
  return execFileAsync(process.execPath, [scriptPath], {
    env: {
      ...process.env,
      OPENWA_BASE_URL: baseUrl,
      OPENWA_MASTER_KEY: masterKey,
      OPENWA_SESSION_NAME: 'aarast-otp-staging',
      OPENWA_KEY_TTL_DAYS: '7',
      OPENWA_TRANSPORT_SECRET_PATH: paths.transport,
      OPENWA_AUDIT_SECRET_PATH: paths.audit,
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

  await fs.writeFile(`${paths.transport}.stale.tmp`, 'stale');
  await runBootstrap(baseUrl, paths);
  assert.equal(state.keyCreates, 2);
  assert.deepEqual(
    state.keys.map((key) => key.role).sort(),
    ['transient_sender', 'viewer'],
  );
  assert.equal(state.transientValidateAttempts, 0);
  await assert.rejects(fs.access(`${paths.transport}.stale.tmp`));

  await runBootstrap(baseUrl, paths);
  assert.equal(state.keyCreates, 2);
  assert.equal(state.keys.length, 2);

  const oldTransport = state.keys.find((key) => key.role === 'transient_sender');
  oldTransport.isActive = false;
  await runBootstrap(baseUrl, paths);
  assert.equal(state.keyCreates, 3);
  assert.equal(state.keys.length, 2);
  const transportSecret = await parseSecret(paths.transport);
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
  assert.equal(state.keys.length, 2);
  assert.ok(state.keys.every((key) => key.allowedSessions[0] === 'session-replacement'));
  assert.ok(state.keys.every((key) => key.allowedSessions.length === 1));
  assert.ok(state.keys.every((key) => key.expiresAt));
  assert.notEqual((await parseSecret(paths.transport)).OPENWA_SESSION_ID, firstSessionId);
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
