const fallbackBaseUrl = import.meta.env.DEV
  ? 'http://127.0.0.1:3115'
  : import.meta.env.VITE_AARAST_BUILD_TARGET === 'staging'
    ? ''
    : 'https://aarast-api.shadowgardn.com';

export const apiBaseUrl =
  import.meta.env.VITE_API_BASE_URL?.toString().trim().replace(/\/$/, '') ||
  fallbackBaseUrl;
if (import.meta.env.VITE_AARAST_BUILD_TARGET === 'staging' && !apiBaseUrl) {
  throw new Error('Staging Admin API origin is missing.');
}

let adminAccessToken: string | null = null;
type AdminSessionExpiredHandler = () => void;

let sessionExpiredHandler: AdminSessionExpiredHandler | null = null;
let sessionExpiryNotified = false;

export function setAdminSessionExpiredHandler(
  handler: AdminSessionExpiredHandler | null,
): void {
  sessionExpiredHandler = handler;
}

export function setAdminAccessToken(token: string): void {
  adminAccessToken = token;
  sessionExpiryNotified = false;
}

export function getAdminAccessToken(): string | null {
  return adminAccessToken;
}

export function clearAdminAccessToken(): void {
  adminAccessToken = null;
}

export class ApiError extends Error {
  constructor(
    message: string,
    public readonly status?: number,
    public readonly code?: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

type RequestOptions = {
  method?: string;
  body?: unknown;
  auth?: boolean;
};

export type AdminBrowserSession<TUser = unknown> = {
  user: TUser;
  accessToken: string;
  accessTokenExpiresIn?: string;
};

let refreshPromise: Promise<AdminBrowserSession> | null = null;

/**
 * RA-AD-04: the tabs of one browser share one cookie session, and the server
 * ends the whole session when a rotated refresh cookie comes back (theft). So
 * a refresh runs under a lock every tab shares, and a refresh's new token is
 * told to the other tabs, which take it: one rotation serves them all.
 */
const REFRESH_LOCK = 'aarast-admin-refresh';
const sessionChannel: BroadcastChannel | null =
  typeof BroadcastChannel === 'undefined' ? null : new BroadcastChannel('aarast-admin-session');
// Node (the tests) keeps a process alive for an open channel; a browser has no unref.
(sessionChannel as { unref?: () => void } | null)?.unref?.();
sessionChannel?.addEventListener('message', (event: MessageEvent) => {
  const data = event.data as { type?: unknown; accessToken?: unknown } | null;
  // A signed-out tab takes nothing: signing in is the person's own act.
  if (data?.type === 'token' && typeof data.accessToken === 'string' && adminAccessToken) {
    setAdminAccessToken(data.accessToken);
  }
});

function withRefreshLock<T>(work: () => Promise<T>): Promise<T> {
  const locks = (globalThis.navigator as { locks?: LockManager } | undefined)?.locks;
  return locks?.request ? (locks.request(REFRESH_LOCK, work) as Promise<T>) : work();
}

/** RA-AD-05: the server refused the session; anything else may pass. */
function sessionRefused(error: unknown): boolean {
  return error instanceof ApiError && (error.status === 401 || error.status === 403);
}

export async function apiRequest<T>(
  path: string,
  options: RequestOptions = {},
): Promise<T> {
  const tokenUsed = getAdminAccessToken();
  const method = (options.method ?? 'GET').toUpperCase();
  const requestId = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)
    ? globalThis.crypto.randomUUID()
    : undefined;
  let response = await send(path, options, requestId);
  if (
    response.status === 401 &&
    options.auth !== false &&
    tokenUsed
  ) {
    try {
      await refreshAdminAccessToken(tokenUsed);
    } catch (error) {
      // RA-AD-05: only a refusal ends the session. No answer, a server error
      // or a busy limit keeps it (the cookie is still good) and the page
      // shows why the action did not go.
      if (sessionRefused(error)) notifyAdminSessionExpired();
      throw error;
    }
    response = await send(path, options, requestId);
    if (response.status === 401) {
      notifyAdminSessionExpired();
    }
  }

  return parseResponse<T>(response);
}

function notifyAdminSessionExpired(): void {
  if (sessionExpiryNotified) return;
  sessionExpiryNotified = true;
  clearAdminAccessToken();
  sessionExpiredHandler?.();
}

/**
 * [staleToken]: the token a request was refused with. When another tab
 * replaced it while this one waited for the lock, that token is used and the
 * cookie is not spent again. Without it (restoring a page) the cookie is
 * always refreshed, since the caller needs the user it names.
 */
export async function refreshAdminAccessToken<TUser = unknown>(
  staleToken?: string,
): Promise<AdminBrowserSession<TUser>> {
  if (!refreshPromise) {
    refreshPromise = withRefreshLock(async () => {
      const current = getAdminAccessToken();
      if (staleToken && current && current !== staleToken) {
        return { accessToken: current } as AdminBrowserSession;
      }
      const response = await fetch(`${apiBaseUrl}/api/v1/auth/admin/refresh`, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        credentials: 'include',
      }).catch(() => {
        throw new Error(connectionError);
      });
      try {
        const session = await parseResponse<AdminBrowserSession>(response);
        if (!session.accessToken) throw new ApiError(fallbackError, 401);
        setAdminAccessToken(session.accessToken);
        sessionChannel?.postMessage({ type: 'token', accessToken: session.accessToken });
        return session;
      } catch (error) {
        // A refusal ends the token; a passing failure keeps it to try again.
        if (sessionRefused(error)) clearAdminAccessToken();
        throw error;
      }
    }).finally(() => {
      refreshPromise = null;
    });
  }
  return refreshPromise as Promise<AdminBrowserSession<TUser>>;
}

function send(
  path: string,
  options: RequestOptions,
  requestId?: string,
): Promise<Response> {
  const token = getAdminAccessToken();
  return fetch(`${apiBaseUrl}${path}`, {
    method: options.method ?? 'GET',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(options.auth !== false && token
        ? { Authorization: `Bearer ${token}` }
        : {}),
      ...(requestId ? { 'X-Client-Request-Id': requestId } : {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
    credentials: 'include',
  }).catch(() => {
    // The browser's own failure («Failed to fetch») is English and says
    // nothing to the team; every page shows this line instead. It stays a
    // plain Error, not an ApiError: the server never answered.
    throw new Error(connectionError);
  });
}

const connectionError = 'تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.';

async function parseResponse<T>(response: Response): Promise<T> {
  const payload = await readJson(response);
  if (!response.ok) {
    const message = cleanMessage(payload);
    throw new ApiError(
      arabicMessage(message, response.status),
      response.status,
      unknownRoute.test(message.trim()) ? serverOlderCode : extractErrorCode(payload),
    );
  }

  return payload as T;
}

async function readJson(response: Response): Promise<unknown> {
  const text = await response.text();
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function cleanMessage(payload: unknown): string {
  if (payload && typeof payload === 'object' && 'message' in payload) {
    const message = (payload as { message?: unknown }).message;
    if (Array.isArray(message)) return message[0]?.toString() ?? fallbackError;
    if (typeof message === 'string') return message;
    if (message && typeof message === 'object' && 'message' in message) {
      const nestedMessage = (message as { message?: unknown }).message;
      if (typeof nestedMessage === 'string' && nestedMessage.trim()) {
        return nestedMessage;
      }
    }
  }
  if (typeof payload === 'string' && payload.trim()) return payload;
  return fallbackError;
}

const arabicLetter = /[؀-ۿ]/;

/**
 * V1 checklist 5.4: the server's own Arabic messages reach the team as they
 * are; an English framework or validation detail becomes Arabic for its kind
 * of failure. The error code stays on the ApiError for pages that need it.
 */
/** D88: Nest answers «Cannot GET /path» for a route this server does not have. */
const unknownRoute = /^Cannot (GET|POST|PUT|PATCH|DELETE) /;
export const serverOlderCode = 'SERVER_OLDER_THAN_APP';
export const serverOlderMessage =
  'الخادم على نسخة أقدم من اللوحة. هذه الشاشة تعمل بعد تحديث الخادم.';

function arabicMessage(message: string, status: number): string {
  if (arabicLetter.test(message)) return message;
  if (unknownRoute.test(message.trim())) return serverOlderMessage;
  if (status === 400 || status === 422) return 'تعذّر الحفظ: راجع البيانات المدخلة ثم حاول مرة أخرى.';
  if (status === 401) return 'انتهت الجلسة أو بيانات الدخول غير صحيحة. سجّل الدخول من جديد.';
  if (status === 403) return 'لا تملك صلاحية لهذا الإجراء.';
  if (status === 404) return 'العنصر غير موجود أو لم يعد متاحًا. حدّث الصفحة.';
  if (status === 409) return 'تغيّرت البيانات قبل الحفظ. حدّث الصفحة ثم حاول مرة أخرى.';
  if (status === 429) return 'طلبات كثيرة في وقت قصير. انتظر قليلًا ثم حاول مرة أخرى.';
  if (status >= 500) return 'حدث خطأ في الخادم. حاول بعد قليل.';
  return fallbackError;
}

function extractErrorCode(payload: unknown): string | undefined {
  if (!payload || typeof payload !== 'object') return undefined;
  const directCode = (payload as { code?: unknown }).code;
  if (typeof directCode === 'string' && directCode.trim()) {
    return directCode.trim();
  }
  const message = (payload as { message?: unknown }).message;
  if (!message || typeof message !== 'object') return undefined;
  const nestedCode = (message as { code?: unknown }).code;
  return typeof nestedCode === 'string' && nestedCode.trim()
    ? nestedCode.trim()
    : undefined;
}

const fallbackError = 'تعذر تنفيذ الطلب. تأكد من تشغيل الخادم ثم حاول مرة أخرى.';
