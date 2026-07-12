import fs from 'node:fs';

const baseUrl = required('OPENWA_BASE_URL').replace(/\/$/, '');
const masterKey = required('OPENWA_MASTER_KEY');
const sessionName = process.env.OPENWA_SESSION_NAME || 'aarast-otp-mvp';
const secretPath = '/run/aarast/openwa.env';

const headers = {
  'X-API-Key': masterKey,
  'Content-Type': 'application/json',
};

async function request(path, options = {}, allowed = []) {
  const response = await fetch(`${baseUrl}/api${path}`, {
    ...options,
    headers: { ...headers, ...(options.headers || {}) },
    redirect: 'error',
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok && !allowed.includes(response.status)) {
    throw new Error(`OpenWA bootstrap request failed: ${response.status}`);
  }
  if (response.status === 204) return null;
  const text = await response.text();
  if (text.length > 64 * 1024) throw new Error('OpenWA bootstrap response exceeded 64 KiB');
  return text ? JSON.parse(text) : null;
}

function readExistingSecret() {
  if (!fs.existsSync(secretPath)) return null;
  const values = Object.fromEntries(
    fs
      .readFileSync(secretPath, 'utf8')
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => line.split(/=(.*)/s).slice(0, 2)),
  );
  if (!values.OPENWA_SESSION_ID || !values.OPENWA_API_KEY) {
    throw new Error('Existing OpenWA bootstrap secret is incomplete');
  }
  return values;
}

async function ensureStarted(sessionId) {
  await request(`/sessions/${encodeURIComponent(sessionId)}/start`, { method: 'POST' }, [400]);
}

async function main() {
  const existing = readExistingSecret();
  if (existing) {
    await ensureStarted(existing.OPENWA_SESSION_ID);
    process.stdout.write('OpenWA bootstrap ready (existing credentials).\n');
    return;
  }

  const sessions = await request('/sessions?limit=1000');
  let session = sessions.find((candidate) => candidate.name === sessionName);
  if (!session) {
    session = await request('/sessions', {
      method: 'POST',
      body: JSON.stringify({ name: sessionName, config: { autoReconnect: true } }),
    });
  }

  const credential = await request('/auth/api-keys', {
    method: 'POST',
    body: JSON.stringify({
      name: 'Aarast OTP transport',
      role: 'transient_sender',
      allowedSessions: [session.id],
    }),
  });

  const temporaryPath = `${secretPath}.tmp`;
  fs.writeFileSync(
    temporaryPath,
    `OPENWA_SESSION_ID=${session.id}\nOPENWA_API_KEY=${credential.apiKey}\n`,
    { encoding: 'utf8', mode: 0o400 },
  );
  fs.chownSync(temporaryPath, 1000, 1000);
  fs.renameSync(temporaryPath, secretPath);
  await ensureStarted(session.id);
  process.stdout.write('OpenWA bootstrap ready (new dedicated credentials).\n');
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) throw new Error(`${name} is required`);
  return value;
}

await main();
