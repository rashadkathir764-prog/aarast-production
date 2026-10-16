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

export async function apiRequest<T>(
  path: string,
  options: RequestOptions = {},
): Promise<T> {
  const hadAccessToken = Boolean(getAdminAccessToken());
  const method = (options.method ?? 'GET').toUpperCase();
  const requestId = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(method)
    ? globalThis.crypto.randomUUID()
    : undefined;
  let response = await send(path, options, requestId);
  if (
    response.status === 401 &&
    options.auth !== false &&
    hadAccessToken
  ) {
    try {
      await refreshAdminAccessToken();
    } catch (error) {
      notifyAdminSessionExpired();
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

export async function refreshAdminAccessToken<TUser = unknown>(): Promise<
  AdminBrowserSession<TUser>
> {
  if (!refreshPromise) {
    refreshPromise = (async () => {
      const response = await fetch(`${apiBaseUrl}/api/v1/auth/admin/refresh`, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'Content-Type': 'application/json',
        },
        credentials: 'include',
      });
      try {
        const session = await parseResponse<AdminBrowserSession>(response);
        if (!session.accessToken) throw new ApiError(fallbackError, 401);
        setAdminAccessToken(session.accessToken);
        return session;
      } catch (error) {
        clearAdminAccessToken();
        throw error;
      }
    })().finally(() => {
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
  });
}

async function parseResponse<T>(response: Response): Promise<T> {
  const payload = await readJson(response);
  if (!response.ok) {
    throw new ApiError(
      arabicMessage(cleanMessage(payload), response.status),
      response.status,
      extractErrorCode(payload),
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
function arabicMessage(message: string, status: number): string {
  if (arabicLetter.test(message)) return message;
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
