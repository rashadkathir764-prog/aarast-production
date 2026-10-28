const sensitiveQueryKey = /(token|code|phone|email|password|secret)/i;
const safeClientRequestIdPattern = /^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$/;

export interface RequestRouteLike {
  baseUrl?: string;
  originalUrl?: string;
  route?: { path?: unknown };
  url?: string;
}

export function sanitizeRequestTarget(value: string | undefined): string {
  if (!value) return '';
  try {
    const parsed = new URL(value, 'http://aarast.internal');
    const pathname = parsed.pathname
      .replace(/(\/invites\/)(?!mine(?:\/|$))[^/?]+/gi, '$1:token')
      // D63: a data download link's token is its only credential.
      .replace(/(\/data-exports\/)[^/?]+/gi, '$1:token');
    for (const key of [...parsed.searchParams.keys()]) {
      if (sensitiveQueryKey.test(key)) {
        parsed.searchParams.set(key, 'REDACTED');
      }
    }
    return `${pathname}${parsed.search}`;
  } catch {
    return 'redacted-request-target';
  }
}

/**
 * Returns the framework route template, never a concrete resource id or query.
 * Unmatched routes deliberately collapse to a constant to prevent 404 probes
 * from writing attacker-controlled paths into logs or telemetry.
 */
export function requestRouteTemplate(request: RequestRouteLike): string {
  const routePath = request.route?.path;
  if (typeof routePath !== 'string' || !routePath.trim()) return 'unmatched';
  return `${request.baseUrl ?? ''}${routePath}`;
}

/** Accept only short, log-safe correlation ids supplied by clients. */
export function safeClientRequestId(value: string | undefined): string | undefined {
  const candidate = value?.trim();
  return candidate && safeClientRequestIdPattern.test(candidate)
    ? candidate
    : undefined;
}
