const fallbackBaseUrl = 'http://127.0.0.1:3115';

export const apiBaseUrl =
  import.meta.env.VITE_API_BASE_URL?.toString().trim().replace(/\/$/, '') ||
  fallbackBaseUrl;

let adminAccessToken: string | null = null;

export function setAdminAccessToken(token: string): void {
  adminAccessToken = token;
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
    await refreshAdminAccessToken();
    response = await send(path, options, requestId);
  }

  return parseResponse<T>(response);
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
    throw new ApiError(cleanMessage(payload), response.status);
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
  }
  if (typeof payload === 'string' && payload.trim()) return payload;
  return fallbackError;
}

const fallbackError = 'تعذر تنفيذ الطلب. تأكد من تشغيل الخادم ثم حاول مرة أخرى.';
