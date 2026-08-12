import fs from 'node:fs';
import path from 'node:path';

export interface OpenWaOtpConfig {
  baseUrl: string;
  sessionId: string;
  apiKey: string;
  timeoutMs: number;
}

const MAX_CREDENTIAL_FILE_BYTES = 16 * 1024;
const allowedCredentialFields = new Set([
  'OPENWA_SESSION_ID',
  'OPENWA_API_KEY_ID',
  'OPENWA_API_KEY',
  'OPENWA_API_KEY_EXPIRES_AT',
]);

export function loadOpenWaOtpConfig(
  environment: NodeJS.ProcessEnv = process.env,
): OpenWaOtpConfig {
  const credentialEnvironment = loadCredentialEnvironment(environment);
  const missing = ['OPENWA_BASE_URL', 'OPENWA_SESSION_ID', 'OPENWA_API_KEY'].filter(
    (name) =>
      !(name === 'OPENWA_BASE_URL' ? environment[name] : credentialEnvironment[name])?.trim(),
  );
  if (missing.length > 0) {
    throw new Error(
      `OpenWA OTP is missing required environment variables: ${missing.join(', ')}`,
    );
  }

  const rawBaseUrl = environment.OPENWA_BASE_URL!.trim();
  let parsed: URL;
  try {
    parsed = new URL(rawBaseUrl);
  } catch {
    throw new Error('OPENWA_BASE_URL must be a valid absolute URL');
  }
  if (parsed.username || parsed.password || parsed.search || parsed.hash) {
    throw new Error('OPENWA_BASE_URL must not contain credentials, query, or fragment');
  }
  if (parsed.pathname !== '/') {
    throw new Error('OPENWA_BASE_URL must not contain a path');
  }
  if (!isAllowedOpenWaUrl(parsed)) {
    throw new Error(
      'OPENWA_BASE_URL must use HTTPS or an internal HTTP service address',
    );
  }

  const sessionId = credentialEnvironment.OPENWA_SESSION_ID!.trim();
  const apiKey = credentialEnvironment.OPENWA_API_KEY!.trim();
  if (!/^[A-Za-z0-9][A-Za-z0-9_-]{1,63}$/.test(sessionId)) {
    throw new Error('OPENWA_SESSION_ID is invalid');
  }
  if (!/^[A-Za-z0-9._~-]{32,256}$/.test(apiKey) || /^<.*>$/.test(apiKey)) {
    throw new Error('OPENWA_API_KEY is not configured securely');
  }

  const configuredTimeout = Number(environment.OPENWA_OTP_TIMEOUT_MS ?? 15_000);
  if (
    !Number.isInteger(configuredTimeout) ||
    configuredTimeout < 1_000 ||
    configuredTimeout > 30_000
  ) {
    throw new Error('OPENWA_OTP_TIMEOUT_MS must be an integer from 1000 to 30000');
  }
  const timeoutMs = configuredTimeout;

  return {
    baseUrl: parsed.toString().replace(/\/$/, ''),
    sessionId,
    apiKey,
    timeoutMs,
  };
}

function loadCredentialEnvironment(environment: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const credentialFile = environment.OPENWA_CREDENTIAL_FILE?.trim();
  if (!credentialFile) return environment;

  try {
    if (environment.OPENWA_SESSION_ID?.trim() || environment.OPENWA_API_KEY?.trim()) {
      throw new Error('split credential sources');
    }
    if (!path.isAbsolute(credentialFile)) throw new Error('not absolute');
    const flags =
      process.platform === 'win32'
        ? fs.constants.O_RDONLY
        : fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW;
    const descriptor = fs.openSync(credentialFile, flags);
    let body: string;
    try {
      const metadata = fs.fstatSync(descriptor);
      if (!metadata.isFile()) throw new Error('not a regular file');
      if (process.platform !== 'win32' && (metadata.mode & 0o077) !== 0) {
        throw new Error('credential file permissions are too broad');
      }
      if (metadata.size <= 0 || metadata.size > MAX_CREDENTIAL_FILE_BYTES) {
        throw new Error('invalid size');
      }
      body = fs.readFileSync(descriptor, 'utf8');
    } finally {
      fs.closeSync(descriptor);
    }

    const values: NodeJS.ProcessEnv = {};
    for (const line of body.split(/\r?\n/)) {
      if (!line) continue;
      const separator = line.indexOf('=');
      if (separator <= 0) throw new Error('malformed line');
      const key = line.slice(0, separator);
      const value = line.slice(separator + 1);
      if (!allowedCredentialFields.has(key) || values[key] !== undefined || !value) {
        throw new Error('invalid field');
      }
      values[key] = value;
    }
    const expiry = values.OPENWA_API_KEY_EXPIRES_AT;
    if (
      !values.OPENWA_SESSION_ID ||
      !values.OPENWA_API_KEY_ID ||
      !values.OPENWA_API_KEY ||
      !expiry
    ) {
      throw new Error('credential file is incomplete');
    }
    if (!/^[A-Za-z0-9][A-Za-z0-9_-]{1,127}$/.test(values.OPENWA_API_KEY_ID)) {
      throw new Error('credential id is invalid');
    }
    const expiresAt = Date.parse(expiry);
    if (!Number.isFinite(expiresAt) || expiresAt <= Date.now()) {
      throw new Error('credential is expired');
    }
    return values;
  } catch {
    // Do not reveal the credential path, file contents, key prefix, or parser detail.
    throw new Error('OpenWA credential file is invalid or unavailable');
  }
}

function isAllowedOpenWaUrl(url: URL): boolean {
  if (url.protocol === 'https:') return true;
  if (url.protocol !== 'http:') return false;
  const hostname = url.hostname.toLowerCase();
  return (
    hostname === 'localhost' ||
    hostname === '127.0.0.1' ||
    hostname === '::1' ||
    isSingleLabelInternalHostname(hostname) ||
    hostname.endsWith('.internal') ||
    hostname.endsWith('.local') ||
    /^10\./.test(hostname) ||
    /^192\.168\./.test(hostname) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(hostname)
  );
}

function isSingleLabelInternalHostname(hostname: string): boolean {
  // Docker Compose service names are single-label DNS names and commonly contain hyphens. A dotted
  // public hostname is deliberately excluded, so plaintext HTTP remains limited to the local resolver
  // namespace or explicit private-address ranges.
  return /^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/.test(hostname);
}
