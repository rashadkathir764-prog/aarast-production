import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { adminTokenKey, ApiError, apiRequest } from './client';

const fetchMock = vi.fn();

beforeEach(() => {
  vi.stubGlobal('fetch', fetchMock);
  fetchMock.mockReset();
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
    localStorage.setItem(adminTokenKey, 'tok');
    fetchMock.mockResolvedValueOnce(response(200, '{"ok":true}'));

    await apiRequest('/auth/me');

    const [, init] = fetchMock.mock.calls[0];
    expect((init.headers as Record<string, string>).Authorization).toBe(
      'Bearer tok',
    );
  });

  it('omits the bearer token when auth is false', async () => {
    localStorage.setItem(adminTokenKey, 'tok');
    fetchMock.mockResolvedValueOnce(response(200, '{}'));

    await apiRequest('/auth/login', { auth: false, method: 'POST', body: {} });

    const [, init] = fetchMock.mock.calls[0];
    expect((init.headers as Record<string, string>).Authorization).toBeUndefined();
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
