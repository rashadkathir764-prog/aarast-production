import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  ApiError,
  apiRequest,
  clearAdminAccessToken,
  getAdminAccessToken,
  setAdminAccessToken,
} from './client';

const fetchMock = vi.fn();

beforeEach(() => {
  vi.stubGlobal('fetch', fetchMock);
  fetchMock.mockReset();
  clearAdminAccessToken();
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

  it('returns null for an empty body', async () => {
    fetchMock.mockResolvedValueOnce(response(200, ''));
    await expect(apiRequest('/x')).resolves.toBeNull();
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

  it('falls back to a generic Arabic message when body has none', async () => {
    fetchMock.mockResolvedValueOnce(response(500, ''));
    await expect(apiRequest('/x')).rejects.toBeInstanceOf(ApiError);
  });
});
