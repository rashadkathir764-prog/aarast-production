import fs from 'node:fs';
import nodePath from 'node:path';
import { randomUUID } from 'node:crypto';

const baseUrl = required('OPENWA_BASE_URL').replace(/\/$/, '');
const masterKey = required('OPENWA_MASTER_KEY');
const sessionName = process.env.OPENWA_SESSION_NAME || 'aarast-otp-staging';
const keyTtlDays = boundedInteger('OPENWA_KEY_TTL_DAYS', 7, 2, 30);
const rotateBeforeHours = boundedInteger('OPENWA_ROTATE_BEFORE_HOURS', 48, 1, 24 * 29);
if (rotateBeforeHours >= keyTtlDays * 24) {
  throw new Error('OPENWA_ROTATE_BEFORE_HOURS must be less than OPENWA_KEY_TTL_DAYS');
}
const bootstrapLockPath =
  process.env.OPENWA_BOOTSTRAP_LOCK_PATH ||
  '/run/aarast/operator/bootstrap.lock';
const bootstrapLockStaleSeconds = boundedInteger(
  'OPENWA_BOOTSTRAP_LOCK_STALE_SECONDS',
  1800,
  60,
  86400,
);
if (!nodePath.isAbsolute(bootstrapLockPath)) {
  throw new Error('OPENWA_BOOTSTRAP_LOCK_PATH must be absolute');
}

const STAGING_TRANSPORT = {
  name: 'Aarast OTP transport staging',
  legacyNames: ['Aarast OTP transport'],
  role: 'transient_sender',
  path:
    process.env.OPENWA_STAGING_TRANSPORT_SECRET_PATH ||
    '/run/aarast/staging/openwa.env',
  idField: 'OPENWA_API_KEY_ID',
  keyField: 'OPENWA_API_KEY',
  expiryField: 'OPENWA_API_KEY_EXPIRES_AT',
};
const PRODUCTION_TRANSPORT = {
  name: 'Aarast OTP transport production',
  legacyNames: [],
  role: 'transient_sender',
  path:
    process.env.OPENWA_PRODUCTION_TRANSPORT_SECRET_PATH ||
    '/run/aarast/production/openwa.env',
  idField: 'OPENWA_API_KEY_ID',
  keyField: 'OPENWA_API_KEY',
  expiryField: 'OPENWA_API_KEY_EXPIRES_AT',
};
const AUDIT = {
  name: 'Aarast OTP audit',
  legacyNames: [],
  role: 'viewer',
  path:
    process.env.OPENWA_AUDIT_SECRET_PATH ||
    '/run/aarast/operator/openwa-audit.env',
  idField: 'OPENWA_AUDIT_API_KEY_ID',
  keyField: 'OPENWA_AUDIT_API_KEY',
  expiryField: 'OPENWA_AUDIT_API_KEY_EXPIRES_AT',
};
const credentialSpecs = [STAGING_TRANSPORT, PRODUCTION_TRANSPORT, AUDIT];
const MAX_SECRET_BYTES = 16 * 1024;

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
  return readSecretPath(spec, spec.path, true);
}

function readSecretPath(spec, secretPath, allowMissingExpiry = false) {
  if (!fs.existsSync(secretPath)) return null;
  const flags =
    process.platform === 'win32'
      ? fs.constants.O_RDONLY
      : fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW;
  const descriptor = fs.openSync(secretPath, flags);
  let body;
  try {
    const metadata = fs.fstatSync(descriptor);
    if (!metadata.isFile()) throw new Error('Existing OpenWA secret is not a file');
    if (process.platform !== 'win32' && (metadata.mode & 0o077) !== 0) {
      throw new Error('Existing OpenWA secret permissions are too broad');
    }
    if (metadata.size <= 0 || metadata.size > MAX_SECRET_BYTES) {
      throw new Error('Existing OpenWA secret size is invalid');
    }
    body = fs.readFileSync(descriptor, 'utf8');
  } finally {
    fs.closeSync(descriptor);
  }
  const values = parseSecret(spec, body, allowMissingExpiry);
  const requiredFields = [
    'OPENWA_SESSION_ID',
    spec.idField,
    spec.keyField,
  ];
  if (requiredFields.some((field) => !values[field])) {
    throw new Error(`Existing OpenWA secret is incomplete: ${spec.path}`);
  }
  return values;
}

function parseSecret(spec, body, allowMissingExpiry = false) {
  const values = {};
  const allowedFields = new Set([
    'OPENWA_SESSION_ID',
    spec.idField,
    spec.keyField,
    spec.expiryField,
  ]);
  for (const line of body.split(/\r?\n/)) {
    if (!line) continue;
    const separator = line.indexOf('=');
    if (separator <= 0) throw new Error('Existing OpenWA secret is malformed');
    const key = line.slice(0, separator);
    const value = line.slice(separator + 1);
    if (!allowedFields.has(key) || !value || values[key] !== undefined) {
      throw new Error('Existing OpenWA secret contains duplicate fields');
    }
    values[key] = value;
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{1,63}$/.test(values.OPENWA_SESSION_ID || '')) {
    throw new Error('Existing OpenWA session id is invalid');
  }
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{1,127}$/.test(values[spec.idField] || '')) {
    throw new Error('Existing OpenWA credential id is invalid');
  }
  if (!/^[A-Za-z0-9._~-]{32,256}$/.test(values[spec.keyField] || '')) {
    throw new Error('Existing OpenWA credential value is invalid');
  }
  const expiry = values[spec.expiryField];
  if (!allowMissingExpiry && !expiry) {
    throw new Error('Existing OpenWA credential expiry is missing');
  }
  if (expiry && !Number.isFinite(Date.parse(expiry))) {
    throw new Error('Existing OpenWA credential expiry is invalid');
  }
  return values;
}

function removeSecret(spec) {
  fs.rmSync(spec.path, { force: true });
  fs.rmSync(`${spec.path}.previous`, { force: true });
}

function cleanupStaleTemps(secretPath) {
  const directory = nodePath.dirname(secretPath);
  const prefixes = [
    `${nodePath.basename(secretPath)}.`,
    `${nodePath.basename(secretPath)}.previous.`,
  ];
  for (const entry of fs.readdirSync(directory)) {
    if (prefixes.some((prefix) => entry.startsWith(prefix)) && entry.endsWith('.tmp')) {
      fs.rmSync(nodePath.join(directory, entry), { force: true });
    }
  }
}

function secretBody(spec, values, allowMissingExpiry = false) {
  const fields = [
    'OPENWA_SESSION_ID',
    spec.idField,
    spec.keyField,
    spec.expiryField,
  ];
  if (!allowMissingExpiry && !values[spec.expiryField]) {
    throw new Error('OpenWA credential expiry is required before writing');
  }
  return `${fields
    .filter((field) => values[field] !== undefined)
    .map((field) => `${field}=${values[field]}`)
    .join('\n')}\n`;
}

function durableTemporary(targetPath, body) {
  const temporaryPath = `${targetPath}.${process.pid}.${randomUUID()}.tmp`;
  let descriptor;
  try {
    descriptor = fs.openSync(temporaryPath, 'wx', 0o600);
    fs.writeFileSync(descriptor, body, { encoding: 'utf8' });
    fs.fsyncSync(descriptor);
    fs.closeSync(descriptor);
    return temporaryPath;
  } catch (error) {
    if (descriptor !== undefined) fs.closeSync(descriptor);
    fs.rmSync(temporaryPath, { force: true });
    throw error;
  }
}

function fsyncDirectory(directory) {
  if (process.platform === 'win32') return;
  const descriptor = fs.openSync(directory, 'r');
  try {
    fs.fsyncSync(descriptor);
  } finally {
    fs.closeSync(descriptor);
  }
}

function acquireBootstrapLock() {
  const parent = nodePath.dirname(bootstrapLockPath);
  const token = randomUUID();
  for (let attempt = 0; attempt < 3; attempt += 1) {
    try {
      fs.mkdirSync(bootstrapLockPath, { mode: 0o700 });
      try {
        fs.writeFileSync(
          nodePath.join(bootstrapLockPath, 'owner.json'),
          JSON.stringify({ token, createdAt: new Date().toISOString() }),
          { encoding: 'utf8', flag: 'wx', mode: 0o600 },
        );
        fsyncDirectory(bootstrapLockPath);
        fsyncDirectory(parent);
        return token;
      } catch (error) {
        fs.rmSync(bootstrapLockPath, { recursive: true, force: true });
        throw error;
      }
    } catch (error) {
      if (error?.code !== 'EEXIST') throw error;
      let metadata;
      try {
        metadata = fs.lstatSync(bootstrapLockPath);
      } catch (statError) {
        if (statError?.code === 'ENOENT') continue;
        throw statError;
      }
      if (!metadata.isDirectory() || metadata.isSymbolicLink()) {
        throw new Error('OpenWA bootstrap lock is invalid');
      }
      if (
        Date.now() - metadata.mtimeMs <=
        bootstrapLockStaleSeconds * 1000
      ) {
        throw new Error('OpenWA credential reconciliation is already running');
      }
      const stalePath = `${bootstrapLockPath}.stale.${token}`;
      try {
        fs.renameSync(bootstrapLockPath, stalePath);
        fs.rmSync(stalePath, { recursive: true, force: true });
        fsyncDirectory(parent);
      } catch (staleError) {
        if (!['ENOENT', 'EEXIST'].includes(staleError?.code)) throw staleError;
      }
    }
  }
  throw new Error('OpenWA bootstrap lock could not be acquired');
}

function releaseBootstrapLock(token) {
  if (!fs.existsSync(bootstrapLockPath)) return;
  let owner;
  try {
    owner = JSON.parse(
      fs.readFileSync(nodePath.join(bootstrapLockPath, 'owner.json'), 'utf8'),
    );
  } catch {
    return;
  }
  if (owner?.token !== token) return;
  const releasedPath = `${bootstrapLockPath}.released.${token}`;
  try {
    fs.renameSync(bootstrapLockPath, releasedPath);
    fs.rmSync(releasedPath, { recursive: true, force: true });
    fsyncDirectory(nodePath.dirname(bootstrapLockPath));
  } catch (error) {
    if (error?.code !== 'ENOENT') throw error;
  }
}

function replaceWithBody(targetPath, body) {
  const temporaryPath = durableTemporary(targetPath, body);
  try {
    fs.renameSync(temporaryPath, targetPath);
    fsyncDirectory(nodePath.dirname(targetPath));
  } catch (error) {
    fs.rmSync(temporaryPath, { force: true });
    throw error;
  }
}

function writeSecret(spec, values) {
  const previousPath = `${spec.path}.previous`;
  const current = fs.existsSync(spec.path) ? readSecret(spec) : null;
  const changedKey =
    current !== null && current[spec.idField] !== values[spec.idField];
  if (changedKey) {
    replaceWithBody(previousPath, secretBody(spec, current, true));
  }

  try {
    replaceWithBody(spec.path, secretBody(spec, values));
  } catch (error) {
    if (changedKey && fs.existsSync(previousPath)) {
      const previous = readSecretPath(spec, previousPath, true);
      replaceWithBody(spec.path, secretBody(spec, previous, true));
    }
    throw error;
  }
}

async function listKeys() {
  return request('/auth/api-keys');
}

async function deleteKey(id) {
  await request(`/auth/api-keys/${encodeURIComponent(id)}`, { method: 'DELETE' });
}

function namesFor(spec) {
  return new Set([spec.name, ...spec.legacyNames]);
}

async function deleteNamedKeys(spec) {
  const names = namesFor(spec);
  for (const key of await listKeys()) {
    if (names.has(key.name)) await deleteKey(key.id);
  }
}

function recordScopeMatches(record, spec, sessionId) {
  const allowedSessions = Array.isArray(record?.allowedSessions)
    ? record.allowedSessions
    : [];
  return (
    namesFor(spec).has(record?.name) &&
    record?.role === spec.role &&
    record?.isActive === true &&
    allowedSessions.length === 1 &&
    allowedSessions[0] === sessionId
  );
}

function recordMatches(record, spec, secret, sessionId) {
  return (
    record?.id === secret[spec.idField] &&
    record?.keyPrefix === secret[spec.keyField].slice(0, 12) &&
    recordScopeMatches(record, spec, sessionId)
  );
}

function rotationDue(record) {
  const expiry = record?.expiresAt ? Date.parse(record.expiresAt) : Number.NaN;
  return (
    !Number.isFinite(expiry) ||
    expiry <= Date.now() + rotateBeforeHours * 60 * 60 * 1000
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

async function cleanupRetiredKeys(spec, currentId, sessionId) {
  const names = namesFor(spec);
  const now = Date.now();
  const keys = await listKeys();
  const previousPath = `${spec.path}.previous`;
  const previous = readSecretPath(spec, previousPath, true);
  const previousId = previous?.[spec.idField];
  for (const key of keys) {
    if (!names.has(key.name) || key.id === currentId) continue;
    const expiry = key.expiresAt ? Date.parse(key.expiresAt) : Number.NaN;
    const safePrevious =
      key.id === previousId &&
      recordScopeMatches(key, spec, sessionId) &&
      Number.isFinite(expiry) &&
      expiry > now;
    if (!safePrevious) {
      await deleteKey(key.id);
    }
  }
  if (previous) {
    const record = keys.find((key) => key.id === previousId);
    const expiry = record?.expiresAt ? Date.parse(record.expiresAt) : Number.NaN;
    if (
      !previousId ||
      previousId === currentId ||
      !record ||
      !recordScopeMatches(record, spec, sessionId) ||
      !Number.isFinite(expiry) ||
      expiry <= now
    ) {
      fs.rmSync(previousPath, { force: true });
    }
  }
}

async function createCredential(spec, sessionId) {
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
    if (
      typeof created?.id !== 'string' ||
      !/^[A-Za-z0-9][A-Za-z0-9_-]{1,127}$/.test(created.id) ||
      typeof created?.apiKey !== 'string' ||
      !/^[A-Za-z0-9._~-]{32,256}$/.test(created.apiKey)
    ) {
      throw new Error(`OpenWA credential creation returned an invalid contract: ${spec.name}`);
    }
    const secret = {
      OPENWA_SESSION_ID: sessionId,
      [spec.idField]: created.id,
      [spec.keyField]: created.apiKey,
      [spec.expiryField]: expiresAt,
    };
    if (!(await rawCredentialIsValid(spec, secret, sessionId))) {
      throw new Error(`New OpenWA credential validation failed: ${spec.name}`);
    }
    writeSecret(spec, secret);
    return { secret, id: created.id };
  } catch (error) {
    if (created?.id) await deleteKey(created.id).catch(() => undefined);
    throw error;
  }
}

async function reconcileCredential(spec, existing, sessionId) {
  if (existing) {
    let record = (await listKeys()).find(
      (candidate) => candidate.id === existing[spec.idField],
    );
    if (
      recordMatches(record, spec, existing, sessionId) &&
      (await rawCredentialIsValid(spec, existing, sessionId))
    ) {
      if (record.name !== spec.name) {
        record = await request(
          `/auth/api-keys/${encodeURIComponent(record.id)}`,
          { method: 'PUT', body: JSON.stringify({ name: spec.name }) },
        );
      }
      if (!rotationDue(record)) {
        const expiry = new Date(record.expiresAt).toISOString();
        if (existing[spec.expiryField] !== expiry) {
          writeSecret(spec, { ...existing, [spec.expiryField]: expiry });
        }
        await cleanupRetiredKeys(spec, record.id, sessionId);
        return existing;
      }
    }
  }

  const created = await createCredential(spec, sessionId);
  await cleanupRetiredKeys(spec, created.id, sessionId);
  return created.secret;
}

async function resolveSession(secrets) {
  const hintedIds = new Set(
    secrets.filter(Boolean).map((secret) => secret.OPENWA_SESSION_ID),
  );
  if (hintedIds.size > 1) {
    throw new Error('OpenWA bootstrap secrets reference different sessions');
  }
  const hintedId = [...hintedIds][0];
  if (hintedId) {
    try {
      const session = await request(`/sessions/${encodeURIComponent(hintedId)}`);
      if (session.name !== sessionName) {
        throw new Error('OpenWA bootstrap secret references an unexpected session');
      }
      return session;
    } catch (error) {
      if (!(error instanceof HttpRequestError) || error.status !== 404) throw error;
      for (const spec of credentialSpecs) {
        await deleteNamedKeys(spec);
        removeSecret(spec);
      }
    }
  }

  const sessions = await request('/sessions?limit=1000');
  if (!Array.isArray(sessions)) {
    throw new Error('OpenWA sessions response is invalid');
  }
  const matchingSessions = sessions.filter(
    (candidate) => candidate?.name === sessionName,
  );
  if (matchingSessions.length > 1) {
    throw new Error('OpenWA bootstrap found duplicate sessions with the configured name');
  }
  if (matchingSessions.length === 1) return matchingSessions[0];
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
  for (const spec of credentialSpecs) cleanupStaleTemps(spec.path);
  const secrets = credentialSpecs.map((spec) => readSecret(spec));
  const session = await resolveSession(secrets);

  for (let index = 0; index < credentialSpecs.length; index += 1) {
    const spec = credentialSpecs[index];
    const existing =
      secrets[index]?.OPENWA_SESSION_ID === session.id ? secrets[index] : null;
    await reconcileCredential(spec, existing, session.id);
  }
  await ensureStarted(session.id);
  process.stdout.write('OpenWA staging credential reconciliation completed.\n');
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

const bootstrapLockToken = acquireBootstrapLock();
try {
  await main();
} finally {
  releaseBootstrapLock(bootstrapLockToken);
}
