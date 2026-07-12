export interface OpenWaOtpConfig {
  baseUrl: string;
  sessionId: string;
  apiKey: string;
  timeoutMs: number;
}

const requiredEnvironmentVariables = [
  'OPENWA_BASE_URL',
  'OPENWA_SESSION_ID',
  'OPENWA_API_KEY',
] as const;

export function loadOpenWaOtpConfig(
  environment: NodeJS.ProcessEnv = process.env,
): OpenWaOtpConfig {
  const missing = requiredEnvironmentVariables.filter(
    (name) => !environment[name]?.trim(),
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

  const sessionId = environment.OPENWA_SESSION_ID!.trim();
  const apiKey = environment.OPENWA_API_KEY!.trim();
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
