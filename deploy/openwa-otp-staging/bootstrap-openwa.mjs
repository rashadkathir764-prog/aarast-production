import fs from 'node:fs';
import nodePath from 'node:path';
import { randomUUID } from 'node:crypto';

const baseUrl = required('OPENWA_BASE_URL').replace(/\/$/, '');
const masterKey = required('OPENWA_MASTER_KEY');
const sessionName = process.env.OPENWA_SESSION_NAME || 'aarast-otp-staging';
const transportSecretPath =
  process.env.OPENWA_TRANSPORT_SECRET_PATH || '/run/aarast/backend/openwa.env';
const auditSecretPath =
  process.env.OPENWA_AUDIT_SECRET_PATH || '/run/aarast/operator/openwa-audit.env';
const keyTtlDays = boundedInteger('OPENWA_KEY_TTL_DAYS', 7, 1, 30);

const TRANSPORT = {
  name: 'Aarast OTP transport',
  role: 'transient_sender',
  path: transportSecretPath,
  idField: 'OPENWA_API_KEY_ID',
  keyField: 'OPENWA_API_KEY',
};
const AUDIT = {
  name: 'Aarast OTP audit',
  role: 'viewer',
  path: auditSecretPath,
  idField: 'OPENWA_AUDIT_API_KEY_ID',
  keyField: 'OPENWA_AUDIT_API_KEY',
};

class HttpRequestError extends Error {
  constructor(status) {
    super(`OpenWA bootstrap request failed: ${status}`);
    this.status = status;
  }
}

async function requestWithKey(path, apiKey, options = {}) {
  const response = await fetch(`${baseUrl}/api${path}`, {
    ...options,
    headers: {
      'X-API-Key': apiKey,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
    redirect: 'error',
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new HttpRequestError(response.status);
  if (response.status === 204) return null;
  const text = await response.text();
  if (text.length > 64 * 1024) {
    throw new Error('OpenWA bootstrap response exceeded 64 KiB');
  }
  return text ? JSON.parse(text) : null;
}

function request(path, options = {}) {
  return requestWithKey(path, masterKey, options);
}

function readSecret(spec) {
  if (!fs.existsSync(spec.path)) return null;
  const values = Object.fromEntries(
    fs
      .readFileSync(spec.path, 'utf8')
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => line.split(/=(.*)/s).slice(0, 2)),
  );
  const requiredFields = ['OPENWA_SESSION_ID', spec.idField, spec.keyField];
  if (requiredFields.some((field) => !values[field])) {
    throw new Error(`Existing OpenWA secret is incomplete: ${spec.path}`);
  }
  return values;
}

function removeSecret(spec) {
  fs.rmSync(spec.path, { force: true });
}

function cleanupStaleTemps(secretPath) {
  const directory = nodePath.dirname(secretPath);
  const prefix = `${nodePath.basename(secretPath)}.`;
  for (const entry of fs.readdirSync(directory)) {
    if (entry.startsWith(prefix) && entry.endsWith('.tmp')) {
      fs.rmSync(nodePath.join(directory, entry), { force: true });
    }
  }
}

function writeSecret(spec, values) {
  const temporaryPath = `${spec.path}.${process.pid}.${randomUUID()}.tmp`;
  const body = Object.entries(values)
    .map(([key, value]) => `${key}=${value}`)
    .join('\n');
  let descriptor;
  try {
    descriptor = fs.openSync(temporaryPath, 'wx', 0o400);
    fs.writeFileSync(descriptor, `${body}\n`, { encoding: 'utf8' });
    fs.fsyncSync(descriptor);
    fs.closeSync(descriptor);
    descriptor = undefined;
    fs.renameSync(temporaryPath, spec.path);
    if (process.platform !== 'win32') {
      const directoryDescriptor = fs.openSync(nodePath.dirname(spec.path), 'r');
      try {
        fs.fsyncSync(directoryDescriptor);
      } finally {
        fs.closeSync(directoryDescriptor);
      }
    }
  } catch (error) {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    fs.rmSync(temporaryPath, { force: true });
    throw error;
  }
}

async function listKeys() {
  return request('/auth/api-keys');
}

async function deleteKey(id) {
  await request(`/auth/api-keys/${encodeURIComponent(id)}`, { method: 'DELETE' });
}

async function deleteNamedKeys(name, exceptId = null) {
  const keys = await listKeys();
  for (const key of keys) {
    if (key.name === name && key.id !== exceptId) await deleteKey(key.id);
  }
}

function recordMatches(record, spec, secret, sessionId) {
  const allowedSessions = Array.isArray(record?.allowedSessions)
    ? record.allowedSessions
    : [];
  const expiry = record?.expiresAt ? Date.parse(record.expiresAt) : Number.NaN;
  return (
    record?.id === secret[spec.idField] &&
    record?.keyPrefix === secret[spec.keyField].slice(0, 12) &&
    record?.name === spec.name &&
    record?.role === spec.role &&
    record?.isActive === true &&
    allowedSessions.length === 1 &&
    allowedSessions[0] === sessionId &&
    Number.isFinite(expiry) &&
    expiry > Date.now() + 60_000
  );
}

async function rawCredentialIsValid(spec, secret, sessionId) {
  try {
    if (spec.role === 'transient_sender') {
      await requestWithKey(
        `/sessions/${encodeURIComponent(sessionId)}/otp-readiness`,
        secret[spec.keyField],
      );
      return true;
    }
    const validation = await requestWithKey('/auth/validate', secret[spec.keyField], {
      method: 'POST',
    });
    if (validation?.valid !== true || validation?.role !== spec.role) return false;
    await requestWithKey(
      `/sessions/${encodeURIComponent(sessionId)}`,
      secret[spec.keyField],
    );
    return true;
  } catch {
    return false;
  }
}

async function reconcileCredential(spec, existing, sessionId) {
  if (existing) {
    const record = (await listKeys()).find(
      (candidate) => candidate.id === existing[spec.idField],
    );
    if (
      recordMatches(record, spec, existing, sessionId) &&
      (await rawCredentialIsValid(spec, existing, sessionId))
    ) {
      await deleteNamedKeys(spec.name, record.id);
      return existing;
    }
    removeSecret(spec);
  }

  await deleteNamedKeys(spec.name);
  const expiresAt = new Date(
    Date.now() + keyTtlDays * 24 * 60 * 60 * 1000,
  ).toISOString();
  let created;
  try {
    created = await request('/auth/api-keys', {
      method: 'POST',
      body: JSON.stringify({
        name: spec.name,
        role: spec.role,
        allowedSessions: [sessionId],
        expiresAt,
      }),
    });
    const secret = {
      OPENWA_SESSION_ID: sessionId,
      [spec.idField]: created.id,
      [spec.keyField]: created.apiKey,
    };
    writeSecret(spec, secret);
    if (!(await rawCredentialIsValid(spec, secret, sessionId))) {
      throw new Error(`New OpenWA credential validation failed: ${spec.name}`);
    }
    return secret;
  } catch (error) {
    removeSecret(spec);
    if (created?.id) await deleteKey(created.id).catch(() => undefined);
    throw error;
  }
}

async function resolveSession(transport, audit) {
  if (
    transport &&
    audit &&
    transport.OPENWA_SESSION_ID !== audit.OPENWA_SESSION_ID
  ) {
    throw new Error('OpenWA bootstrap secrets reference different sessions');
  }
  const hintedId = transport?.OPENWA_SESSION_ID || audit?.OPENWA_SESSION_ID;
  if (hintedId) {
    try {
      const session = await request(`/sessions/${encodeURIComponent(hintedId)}`);
      if (session.name !== sessionName) {
        throw new Error('OpenWA bootstrap secret references an unexpected session');
      }
      return session;
    } catch (error) {
      if (!(error instanceof HttpRequestError) || error.status !== 404) throw error;
      await deleteNamedKeys(TRANSPORT.name);
      await deleteNamedKeys(AUDIT.name);
      removeSecret(TRANSPORT);
      removeSecret(AUDIT);
    }
  }

  const sessions = await request('/sessions?limit=1000');
  const existing = sessions.find((candidate) => candidate.name === sessionName);
  if (existing) return existing;
  return request('/sessions', {
    method: 'POST',
    body: JSON.stringify({
      name: sessionName,
      config: { autoReconnect: true },
    }),
  });
}

async function ensureStarted(sessionId) {
  try {
    return await request(`/sessions/${encodeURIComponent(sessionId)}/start`, {
      method: 'POST',
    });
  } catch (error) {
    if (!(error instanceof HttpRequestError) || error.status !== 400) throw error;
    const session = await request(`/sessions/${encodeURIComponent(sessionId)}`);
    const active = ['initializing', 'qr_ready', 'authenticating', 'ready'].includes(
      session.status,
    );
    const reconnecting = session.status === 'disconnected' && Boolean(session.phone);
    if (!active && !reconnecting) throw error;
    return session;
  }
}

async function main() {
  cleanupStaleTemps(TRANSPORT.path);
  cleanupStaleTemps(AUDIT.path);
  let transport = readSecret(TRANSPORT);
  let audit = readSecret(AUDIT);
  const session = await resolveSession(transport, audit);

  if (transport?.OPENWA_SESSION_ID !== session.id) transport = null;
  if (audit?.OPENWA_SESSION_ID !== session.id) audit = null;
  await reconcileCredential(TRANSPORT, transport, session.id);
  await reconcileCredential(AUDIT, audit, session.id);
  await ensureStarted(session.id);
  process.stdout.write('OpenWA staging bootstrap completed.\n');
}

function boundedInteger(name, fallback, minimum, maximum) {
  const raw = process.env[name]?.trim();
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < minimum || value > maximum) {
    throw new Error(`${name} must be an integer between ${minimum} and ${maximum}`);
  }
  return value;
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

await main();
