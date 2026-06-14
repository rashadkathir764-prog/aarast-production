const fallbackBaseUrl = 'http://127.0.0.1:3115';

export const apiBaseUrl =
  import.meta.env.VITE_API_BASE_URL?.toString().replace(/\/$/, '') ??
  fallbackBaseUrl;

export const adminTokenKey = 'admin_token';

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

export async function apiRequest<T>(
  path: string,
  options: RequestOptions = {},
): Promise<T> {
  const token = localStorage.getItem(adminTokenKey);
  const response = await fetch(`${apiBaseUrl}${path}`, {
    method: options.method ?? 'GET',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      ...(options.auth !== false && token
        ? { Authorization: `Bearer ${token}` }
        : {}),
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });

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
