import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  completeAdminLogin,
  logoutAdmin,
  restoreAdminSession,
  startAdminLogin,
} from './auth';
import {
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
  sessionStorage.clear();
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

describe('secure admin browser session', () => {
  it('starts with password but returns only an MFA challenge', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        mfaRequired: true,
        challengeToken: 'a'.repeat(64),
        expiresAt: '2026-07-10T12:00:00.000Z',
        delivery: 'WHATSAPP',
      }),
    );

    const challenge = await startAdminLogin('+967700000000', 'secret');

    expect(challenge.challengeToken).toHaveLength(64);
    expect(getAdminAccessToken()).toBeNull();
    expect(fetchMock.mock.calls[0][0]).toContain('/api/v1/auth/admin/login');
    expect(fetchMock.mock.calls[0][1].credentials).toBe('include');
  });

  it('stores the MFA-completed access token in memory only', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        user: { id: 'u1', name: 'مشرف', role: 'ADMIN', status: 'ACTIVE' },
        accessToken: 'memory-token',
      }),
    );

    const user = await completeAdminLogin('a'.repeat(64), '123456');

    expect(user.id).toBe('u1');
    expect(getAdminAccessToken()).toBe('memory-token');
    expect(localStorage.length).toBe(0);
    expect(sessionStorage.length).toBe(0);
  });

  it('rejects a completed session that is not ADMIN', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        user: { id: 'u2', name: 'مستخدم', role: 'USER', status: 'ACTIVE' },
        accessToken: 'wrong-role-token',
      }),
    );

    await expect(
      completeAdminLogin('b'.repeat(64), '123456'),
    ).rejects.toThrow('ليس لديك صلاحية الدخول إلى لوحة الإدارة');
    expect(getAdminAccessToken()).toBeNull();
  });

  it('restores a reload only through the HttpOnly cookie refresh endpoint', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        user: { id: 'u1', name: 'مشرف', role: 'ADMIN', status: 'ACTIVE' },
        accessToken: 'rotated-token',
      }),
    );

    const user = await restoreAdminSession();

    expect(user.role).toBe('ADMIN');
    expect(getAdminAccessToken()).toBe('rotated-token');
    expect(fetchMock.mock.calls[0][0]).toContain('/api/v1/auth/admin/refresh');
    expect(fetchMock.mock.calls[0][1].credentials).toBe('include');
  });

  it('revokes the cookie session and clears memory on logout', async () => {
    setAdminAccessToken('active-token');
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { revoked: 1 }));

    await logoutAdmin();

    expect(getAdminAccessToken()).toBeNull();
    expect(fetchMock.mock.calls[0][0]).toContain('/api/v1/auth/admin/logout');
    expect(fetchMock.mock.calls[0][1].method).toBe('POST');
  });

  it('maps rejected password login to a generic credentials message', async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(401, { message: 'Unauthorized' }));

    await expect(startAdminLogin('+967700000002', 'wrong')).rejects.toThrow(
      'بيانات الدخول غير صحيحة',
    );
  });

  it('distinguishes login throttling from invalid credentials', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(429, { message: 'Too many failed login attempts' }),
    );

    await expect(startAdminLogin('+967700000002', 'secret')).rejects.toThrow(
      'محاولات دخول كثيرة. انتظر قليلًا ثم حاول مرة أخرى.',
    );
  });

  it('distinguishes an unavailable OTP transport from a network failure', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(503, { message: 'OTP delivery is temporarily unavailable' }),
    );

    await expect(startAdminLogin('+967700000002', 'secret')).rejects.toThrow(
      'خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.',
    );
  });

  it('keeps an actual fetch failure as a connection error', async () => {
    fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'));

    await expect(startAdminLogin('+967700000002', 'secret')).rejects.toThrow(
      'تعذر الاتصال بالخادم',
    );
  });
});
