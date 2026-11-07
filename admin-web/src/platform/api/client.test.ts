import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  ApiError,
  apiRequest,
  clearAdminAccessToken,
  getAdminAccessToken,
  setAdminSessionExpiredHandler,
  setAdminAccessToken,
} from './client';

const fetchMock = vi.fn();

beforeEach(() => {
  vi.stubGlobal('fetch', fetchMock);
  fetchMock.mockReset();
  clearAdminAccessToken();
  setAdminSessionExpiredHandler(null);
  localStorage.clear();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

function response(status: number, text: string): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => text,
  } as Response;
}

describe('apiRequest', () => {
  it('attaches the bearer token by default', async () => {
    setAdminAccessToken('tok');
    fetchMock.mockResolvedValueOnce(response(200, '{"ok":true}'));

    await apiRequest('/api/v1/auth/me');

    const [, init] = fetchMock.mock.calls[0];
    expect((init.headers as Record<string, string>).Authorization).toBe(
      'Bearer tok',
    );
    expect(init.credentials).toBe('include');
  });

  it('omits the bearer token when auth is false', async () => {
    setAdminAccessToken('tok');
    fetchMock.mockResolvedValueOnce(response(200, '{}'));

    await apiRequest('/api/v1/auth/login', {
      auth: false,
      method: 'POST',
      body: {},
    });

    const [, init] = fetchMock.mock.calls[0];
    expect((init.headers as Record<string, string>).Authorization).toBeUndefined();
  });

  it('adds one stable idempotency key to a mutating request', async () => {
    setAdminAccessToken('tok');
    fetchMock.mockResolvedValueOnce(response(200, '{"created":true}'));

    await apiRequest('/admin/services', { method: 'POST', body: { title: 'x' } });

    const headers = fetchMock.mock.calls[0][1].headers as Record<string, string>;
    expect(headers['X-Client-Request-Id']).toMatch(/^[A-Za-z0-9._:-]{1,128}$/);
  });

  it('keeps the access token in memory and never writes browser storage', () => {
    setAdminAccessToken('memory-only');
    expect(getAdminAccessToken()).toBe('memory-only');
    expect(localStorage.length).toBe(0);
    expect(sessionStorage.length).toBe(0);

    clearAdminAccessToken();
    expect(getAdminAccessToken()).toBeNull();
  });

  it('rotates the cookie session once and retries an expired authenticated request', async () => {
    setAdminAccessToken('expired');
    fetchMock
      .mockResolvedValueOnce(response(401, JSON.stringify({ message: 'expired' })))
      .mockResolvedValueOnce(
        response(
          200,
          JSON.stringify({
            user: { id: 'a1', role: 'ADMIN' },
            accessToken: 'fresh',
          }),
        ),
      )
      .mockResolvedValueOnce(response(200, JSON.stringify({ ok: true })));

    await expect(
      apiRequest('/admin/users/u1/disable', { method: 'PATCH', body: {} }),
    ).resolves.toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(fetchMock.mock.calls[1][0]).toContain('/api/v1/auth/admin/refresh');
    expect(fetchMock.mock.calls[1][1].credentials).toBe('include');
    expect(
      (fetchMock.mock.calls[0][1].headers as Record<string, string>)[
        'X-Client-Request-Id'
      ],
    ).toBe(
      (fetchMock.mock.calls[2][1].headers as Record<string, string>)[
        'X-Client-Request-Id'
      ],
    );
    expect(
      (fetchMock.mock.calls[2][1].headers as Record<string, string>).Authorization,
    ).toBe('Bearer fresh');
  });

  // RA-AD-05: only a refresh the server refused ends the session. A refresh
  // that never got an answer, a server error or a busy limit leaves it: the
  // refresh cookie is still good, and the open form must not be thrown away.
  it('keeps the session when the refresh never reached the server', async () => {
    setAdminAccessToken('expired');
    const onExpired = vi.fn();
    setAdminSessionExpiredHandler(onExpired);
    fetchMock
      .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
      .mockRejectedValueOnce(new TypeError('Failed to fetch'));

    await expect(apiRequest('/admin/users')).rejects.toThrow('تعذر الاتصال بالخادم');
    expect(onExpired).not.toHaveBeenCalled();
    expect(getAdminAccessToken()).toBe('expired');
  });

  for (const status of [429, 503]) {
    it(`keeps the session when the refresh answers ${status}`, async () => {
      setAdminAccessToken('expired');
      const onExpired = vi.fn();
      setAdminSessionExpiredHandler(onExpired);
      fetchMock
        .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
        .mockResolvedValueOnce(response(status, '{"message":"busy"}'));

      await expect(apiRequest('/admin/users')).rejects.toMatchObject({ status });
      expect(onExpired).not.toHaveBeenCalled();
      expect(getAdminAccessToken()).toBe('expired');
    });
  }

  // RA-AD-04: tabs of one browser share one cookie session. A refresh runs
  // under a lock all of them share, and a tab that waited behind another
  // tab's refresh uses the token that one got instead of spending the
  // cookie again (the server treats a reused one as theft and ends all).
  it('refreshes under the lock every tab of the browser shares', async () => {
    const names: string[] = [];
    vi.stubGlobal('navigator', {
      ...navigator,
      locks: {
        request: (name: string, work: () => Promise<unknown>) => {
          names.push(name);
          return work();
        },
      },
    });
    setAdminAccessToken('expired');
    fetchMock
      .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
      .mockResolvedValueOnce(
        response(200, JSON.stringify({ user: { id: 'a1', role: 'ADMIN' }, accessToken: 'fresh' })),
      )
      .mockResolvedValueOnce(response(200, '{"ok":true}'));

    await apiRequest('/admin/users');
    expect(names).toEqual(['aarast-admin-refresh']);
  });

  it('a tab that waited for the lock takes the token the other tab got', async () => {
    vi.stubGlobal('navigator', {
      ...navigator,
      locks: {
        request: async (_name: string, work: () => Promise<unknown>) => {
          // Another tab held the lock and rotated the session meanwhile.
          setAdminAccessToken('from-other-tab');
          return work();
        },
      },
    });
    setAdminAccessToken('expired');
    fetchMock
      .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
      .mockResolvedValueOnce(response(200, '{"ok":true}'));

    await expect(apiRequest('/admin/users')).resolves.toEqual({ ok: true });
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(fetchMock.mock.calls.map(([url]) => url as string)).not.toContainEqual(
      expect.stringContaining('/auth/admin/refresh'),
    );
    expect((fetchMock.mock.calls[1][1].headers as Record<string, string>).Authorization).toBe(
      'Bearer from-other-tab',
    );
  });

  it('tells the other tabs the token a refresh got, and takes theirs', async () => {
    const otherTab = new BroadcastChannel('aarast-admin-session');
    const heard = new Promise<unknown>((resolve) => {
      otherTab.onmessage = (event) => resolve(event.data);
    });
    setAdminAccessToken('expired');
    fetchMock
      .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
      .mockResolvedValueOnce(
        response(200, JSON.stringify({ user: { id: 'a1', role: 'ADMIN' }, accessToken: 'fresh' })),
      )
      .mockResolvedValueOnce(response(200, '{"ok":true}'));

    await apiRequest('/admin/users');
    await expect(heard).resolves.toEqual({ type: 'token', accessToken: 'fresh' });

    otherTab.postMessage({ type: 'token', accessToken: 'newer' });
    await vi.waitFor(() => expect(getAdminAccessToken()).toBe('newer'));
    otherTab.close();
  });

  it('a signed-out tab takes no token from another tab', async () => {
    const otherTab = new BroadcastChannel('aarast-admin-session');
    otherTab.postMessage({ type: 'token', accessToken: 'newer' });
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(getAdminAccessToken()).toBeNull();
    otherTab.close();
  });

  it('returns null for an empty body', async () => {
    fetchMock.mockResolvedValueOnce(response(200, ''));
    await expect(apiRequest('/x')).resolves.toBeNull();
  });

  it('notifies the authenticated UI once when concurrent refresh fails', async () => {
    setAdminAccessToken('expired');
    const onExpired = vi.fn();
    setAdminSessionExpiredHandler(onExpired);
    fetchMock
      .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
      .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
      .mockResolvedValueOnce(response(401, '{"message":"refresh expired"}'));

    await expect(
      Promise.allSettled([
        apiRequest('/admin/users'),
        apiRequest('/admin/providers'),
      ]),
    ).resolves.toEqual([
      expect.objectContaining({ status: 'rejected' }),
      expect.objectContaining({ status: 'rejected' }),
    ]);

    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(onExpired).toHaveBeenCalledTimes(1);
    expect(getAdminAccessToken()).toBeNull();
  });

  it('notifies expiry when the retry itself still returns 401', async () => {
    setAdminAccessToken('expired');
    const onExpired = vi.fn();
    setAdminSessionExpiredHandler(onExpired);
    fetchMock
      .mockResolvedValueOnce(response(401, '{"message":"expired"}'))
      .mockResolvedValueOnce(
        response(
          200,
          JSON.stringify({
            user: { id: 'a1', role: 'ADMIN' },
            accessToken: 'fresh',
          }),
        ),
      )
      .mockResolvedValueOnce(response(401, '{"message":"still expired"}'));

    await expect(apiRequest('/admin/users')).rejects.toMatchObject({
      status: 401,
    });

    expect(onExpired).toHaveBeenCalledTimes(1);
    expect(getAdminAccessToken()).toBeNull();
  });

  it('throws ApiError with status and array-message first element', async () => {
    fetchMock.mockResolvedValueOnce(
      response(400, JSON.stringify({ message: ['الحقل مطلوب', 'ثانوي'] })),
    );

    await expect(apiRequest('/x')).rejects.toMatchObject({
      status: 400,
      message: 'الحقل مطلوب',
    });
  });

  it('preserves a stable backend error code from the response envelope', async () => {
    fetchMock.mockResolvedValueOnce(
      response(
        503,
        JSON.stringify({
          statusCode: 503,
          code: 'OTP_DELIVERY_UNAVAILABLE',
          message: 'OTP delivery is temporarily unavailable',
        }),
      ),
    );

    await expect(apiRequest('/api/v1/auth/admin/login')).rejects.toMatchObject({
      status: 503,
      code: 'OTP_DELIVERY_UNAVAILABLE',
    });
  });

  it('preserves a stable backend error code from a nested message envelope', async () => {
    fetchMock.mockResolvedValueOnce(
      response(
        503,
        JSON.stringify({
          statusCode: 503,
          message: {
            code: 'OTP_DELIVERY_UNAVAILABLE',
            message: 'OTP delivery is temporarily unavailable',
          },
        }),
      ),
    );

    await expect(apiRequest('/api/v1/auth/admin/login')).rejects.toMatchObject({
      status: 503,
      code: 'OTP_DELIVERY_UNAVAILABLE',
    });
  });

  it('turns an English server detail into Arabic and keeps the code', async () => {
    fetchMock.mockResolvedValueOnce(
      response(
        404,
        JSON.stringify({ statusCode: 404, code: 'PROVIDER_MISSING', message: 'Provider not found' }),
      ),
    );
    const error = (await apiRequest('/x').catch((caught: unknown) => caught)) as ApiError;
    expect(error).toBeInstanceOf(ApiError);
    expect(error.message).toBe('العنصر غير موجود أو لم يعد متاحًا. حدّث الصفحة.');
    expect(error.message).not.toContain('Provider');
    expect(error.code).toBe('PROVIDER_MISSING');
    expect(error.status).toBe(404);
  });

  it('a route the server does not know is said as an older server (D88)', async () => {
    fetchMock.mockResolvedValueOnce(
      response(
        404,
        JSON.stringify({ statusCode: 404, error: 'Not Found', message: 'Cannot GET /api/v1/admin/photos' }),
      ),
    );
    const error = (await apiRequest('/api/v1/admin/photos').catch((caught: unknown) => caught)) as ApiError;
    expect(error).toBeInstanceOf(ApiError);
    expect(error.message).toBe(
      'الخادم على نسخة أقدم من اللوحة. هذه الشاشة تعمل بعد تحديث الخادم.',
    );
    expect(error.code).toBe('SERVER_OLDER_THAN_APP');
  });

  it('falls back to a generic Arabic message when body has none', async () => {
    fetchMock.mockResolvedValueOnce(response(500, ''));
    await expect(apiRequest('/x')).rejects.toBeInstanceOf(ApiError);
  });

  it('says in Arabic that the server was not reached instead of the browser text', async () => {
    fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'));
    const error = (await apiRequest('/admin/users').catch((caught: unknown) => caught)) as Error;
    expect(error).not.toBeInstanceOf(ApiError);
    expect(error.message).toBe('تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.');
    expect(error.message).not.toContain('fetch');
  });
});
