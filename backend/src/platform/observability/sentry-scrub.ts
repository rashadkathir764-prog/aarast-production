import type { Breadcrumb, Event } from '@sentry/node';

/**
 * RA-BE-149: the last word on what reaches Sentry (`beforeSend`,
 * `beforeSendTransaction`, `beforeBreadcrumb`). The server's own reports
 * already carry only the route, the status and the error's type
 * (`safeTelemetryException`); this takes out what the SDK or a library adds
 * on its own: phone numbers, tokens, names and amounts.
 *
 * - Every text an event carries loses its tokens (a JWT, a `Bearer` value,
 *   a long random id or hex digest) and every number of four digits or more,
 *   in Latin or Arabic digits, grouped or not (a phone, an amount, a code).
 * - A field whose name says it holds a name, a phone, a token, a password or
 *   an amount is replaced whole, whatever it holds: a name cannot be told
 *   from other words, so it is taken out by where it is.
 * - The account and the host go, and the request keeps its method and its
 *   path only (no query, body, cookies or headers).
 */

const REDACTED = '[redacted]';

const JWT = /eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g;
const AUTH_SCHEME = /\b(Bearer|Basic)\s+\S+/gi;
const HEX_DIGEST = /\b[0-9a-fA-F]{32,}\b/g;
// A long run of id characters with a digit in it: a random token or id,
// never a word such as an error's type name.
const OPAQUE_ID = /[A-Za-z0-9_-]*\d[A-Za-z0-9_-]*/g;
const OPAQUE_ID_MIN_LENGTH = 20;
const DIGIT = '[0-9٠-٩۰-۹]';
const LONG_NUMBER = new RegExp(`\\+?${DIGIT}(?:[\\s,.\\-()٫٬]*${DIGIT}){3,}`, 'g');

/** Words a field's name is made of that say what it holds. */
const PERSONAL_FIELD_WORDS = new Set([
  'name', 'names', 'title', 'phone', 'phones', 'mobile', 'msisdn', 'whatsapp',
  'email', 'address', 'token', 'tokens', 'password', 'secret', 'otp', 'pin',
  'authorization', 'cookie', 'cookies', 'amount', 'amounts', 'price', 'budget',
  'total', 'paid', 'balance', 'cost', 'mahr', 'salary',
]);

/** The SDK's own descriptions of the process; no person's data is in them. */
const SDK_CONTEXTS = new Set(['app', 'os', 'device', 'runtime', 'culture', 'cloud_resource', 'trace', 'otel']);

export function scrubTelemetryText(text: string): string {
  return text
    .replace(JWT, '[token]')
    .replace(AUTH_SCHEME, '$1 [token]')
    .replace(HEX_DIGEST, '[token]')
    .replace(OPAQUE_ID, (run) => (run.length >= OPAQUE_ID_MIN_LENGTH ? '[token]' : run))
    .replace(LONG_NUMBER, '[number]');
}

function isPersonalField(key: string): boolean {
  return key
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .some((word) => PERSONAL_FIELD_WORDS.has(word));
}

/** A copy with every text scrubbed and, unless [byName] is false, personal fields replaced. */
function scrubValue(value: unknown, byName: boolean, depth = 0): unknown {
  if (typeof value === 'string') return scrubTelemetryText(value);
  if (typeof value === 'number') {
    return byName && Number.isFinite(value) && Math.abs(value) >= 1000 ? '[number]' : value;
  }
  if (value === null || typeof value !== 'object') return value;
  if (depth >= 8) return REDACTED;
  if (Array.isArray(value)) return value.map((item) => scrubValue(item, byName, depth + 1));
  const copy: Record<string, unknown> = {};
  for (const [key, item] of Object.entries(value)) {
    copy[key] = byName && isPersonalField(key) ? REDACTED : scrubValue(item, byName, depth + 1);
  }
  return copy;
}

function scrubRecord<T>(value: T | undefined, byName: boolean): T | undefined {
  return value === undefined ? undefined : (scrubValue(value, byName) as T);
}

function requestPath(url: string | undefined): string | undefined {
  if (!url) return undefined;
  try {
    return scrubTelemetryText(new URL(url, 'http://aarast.internal').pathname);
  } catch {
    return undefined;
  }
}

export function scrubSentryBreadcrumb(breadcrumb: Breadcrumb): Breadcrumb {
  return {
    ...breadcrumb,
    ...(breadcrumb.message === undefined ? {} : { message: scrubTelemetryText(breadcrumb.message) }),
    ...(breadcrumb.data === undefined ? {} : { data: scrubRecord(breadcrumb.data, true) }),
  };
}

export function scrubSentryEvent<T extends Event>(event: T): T {
  const scrubbed: T = { ...event };
  delete scrubbed.user;
  delete scrubbed.server_name;
  if (event.request) {
    const path = requestPath(event.request.url);
    scrubbed.request = {
      ...(event.request.method ? { method: event.request.method } : {}),
      ...(path ? { url: path } : {}),
    };
  }
  if (event.message !== undefined) scrubbed.message = scrubTelemetryText(event.message);
  if (event.transaction !== undefined) scrubbed.transaction = scrubTelemetryText(event.transaction);
  if (event.exception?.values) {
    scrubbed.exception = {
      ...event.exception,
      values: event.exception.values.map((exception) => ({
        ...exception,
        ...(exception.value === undefined ? {} : { value: scrubTelemetryText(exception.value) }),
        ...(exception.stacktrace?.frames
          ? {
              stacktrace: {
                ...exception.stacktrace,
                frames: exception.stacktrace.frames.map(({ vars: _vars, ...frame }) => frame),
              },
            }
          : {}),
      })),
    };
  }
  if (event.breadcrumbs) scrubbed.breadcrumbs = event.breadcrumbs.map(scrubSentryBreadcrumb);
  scrubbed.tags = scrubRecord(event.tags, false);
  scrubbed.extra = scrubRecord(event.extra, true);
  if (event.contexts) {
    const contexts: NonNullable<Event['contexts']> = {};
    for (const [name, context] of Object.entries(event.contexts)) {
      // An HTTP response's context holds its headers and body.
      if (name === 'response') continue;
      contexts[name] = scrubRecord(context, !SDK_CONTEXTS.has(name));
    }
    scrubbed.contexts = contexts;
  }
  if (event.spans) {
    scrubbed.spans = event.spans.map((span) => ({
      ...span,
      ...(span.description === undefined ? {} : { description: scrubTelemetryText(span.description) }),
      ...(span.data === undefined ? {} : { data: scrubRecord(span.data, false) }),
    }));
  }
  for (const key of ['tags', 'extra'] as const) {
    if (scrubbed[key] === undefined) delete scrubbed[key];
  }
  return scrubbed;
}
