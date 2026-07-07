import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { adminTokenKey, ApiError } from './client';
import { clearAdminToken, getAdminToken, loginAdmin } from './auth';

const fetchMock = vi.fn();

beforeEach(() => {
  vi.stubGlobal('fetch', fetchMock);
  fetchMock.mockReset();
  localStorage.clear();
});

afterEach(() => {
  vi.unstubAllGlobals();
});

function jsonResponse(status: number, body: unknown): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => JSON.stringify(body),
  } as Response;
}

describe('loginAdmin', () => {
  it('stores the token and returns the user for an ADMIN account', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        user: { id: 'u1', name: 'مشرف', role: 'ADMIN', status: 'ACTIVE' },
        accessToken: 'token-123',
      }),
    );

    const user = await loginAdmin('+967700000000', 'secret');

    expect(user.id).toBe('u1');
    expect(localStorage.getItem(adminTokenKey)).toBe('token-123');
  });

  it('rejects a valid login that is not an ADMIN and stores no token', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        user: { id: 'u2', name: 'مستخدم', role: 'USER', status: 'ACTIVE' },
        accessToken: 'token-xyz',
      }),
    );

    await expect(loginAdmin('+967700000001', 'secret')).rejects.toThrow(
      'ليس لديك صلاحية الدخول إلى لوحة الإدارة',
    );
    expect(localStorage.getItem(adminTokenKey)).toBeNull();
  });

  it('maps 401 to a credentials message', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(401, { message: 'Unauthorized' }),
    );

    await expect(loginAdmin('+967700000002', 'wrong')).rejects.toThrow(
      'بيانات الدخول غير صحيحة',
    );
    expect(localStorage.getItem(adminTokenKey)).toBeNull();
  });

  it('maps a server error to a connection message', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(500, { message: 'boom' }));

    await expect(loginAdmin('+967700000003', 'secret')).rejects.toThrow(
      'تعذر الاتصال بالخادم',
    );
  });

  it('sends the login request without an Authorization header', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        user: { id: 'u1', name: 'مشرف', role: 'ADMIN', status: 'ACTIVE' },
        accessToken: 'token-123',
      }),
    );
    localStorage.setItem(adminTokenKey, 'stale-token');

    await loginAdmin('+967700000000', 'secret');

    const [, init] = fetchMock.mock.calls[0];
    expect((init.headers as Record<string, string>).Authorization).toBeUndefined();
    expect(init.method).toBe('POST');
  });
});

describe('token helpers', () => {
  it('round-trips and clears the admin token', () => {
    expect(getAdminToken()).toBeNull();
    localStorage.setItem(adminTokenKey, 'abc');
    expect(getAdminToken()).toBe('abc');
    clearAdminToken();
    expect(getAdminToken()).toBeNull();
  });
});

describe('ApiError', () => {
  it('carries the HTTP status', () => {
    const err = new ApiError('nope', 404);
    expect(err.status).toBe(404);
    expect(err.name).toBe('ApiError');
  });
});
