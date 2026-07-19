import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  completeAdminLogin,
  confirmAdminPasswordReset,
  logoutAdmin,
  requestAdminPasswordReset,
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
        deliveryStatus: 'DELIVERED',
      }),
    );

    const challenge = await startAdminLogin('+967700000000', 'secret');

    expect(challenge.challengeToken).toHaveLength(64);
    expect(getAdminAccessToken()).toBeNull();
    expect(fetchMock.mock.calls[0][0]).toContain('/api/v1/auth/admin/login');
    expect(fetchMock.mock.calls[0][1].credentials).toBe('include');
  });

  it('rejects an MFA challenge that omits the delivery outcome', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        mfaRequired: true,
        challengeToken: 'a'.repeat(64),
        expiresAt: '2026-07-10T12:00:00.000Z',
        delivery: 'WHATSAPP',
      }),
    );

    await expect(
      startAdminLogin('+967700000000', 'secret'),
    ).rejects.toThrow('تعذر بدء التحقق بخطوتين');
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
      jsonResponse(503, {
        code: 'OTP_DELIVERY_UNAVAILABLE',
        message: 'OTP delivery is temporarily unavailable',
      }),
    );

    await expect(startAdminLogin('+967700000002', 'secret')).rejects.toThrow(
      'خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.',
    );
  });

  it('does not mislabel a generic service outage as an OTP failure', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(503, { message: 'Database unavailable' }),
    );

    await expect(startAdminLogin('+967700000002', 'secret')).rejects.toThrow(
      'حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.',
    );
  });

  it('uses the stable OTP code before a legacy login status mapping', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(400, {
        code: 'OTP_DELIVERY_UNAVAILABLE',
        message: 'OTP delivery is temporarily unavailable',
      }),
    );

    await expect(startAdminLogin('+967700000002', 'secret')).rejects.toThrow(
      'خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.',
    );
  });

  it('reports unavailable OTP during admin recovery as a service failure', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(503, {
        code: 'OTP_DELIVERY_UNAVAILABLE',
        message: 'OTP delivery is temporarily unavailable',
      }),
    );

    await expect(requestAdminPasswordReset('+967700000003')).rejects.toThrow(
      'خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.',
    );
  });

  it('reports unavailable OTP while completing MFA as a service failure', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(503, {
        code: 'OTP_DELIVERY_UNAVAILABLE',
        message: 'OTP delivery is temporarily unavailable',
      }),
    );

    await expect(
      completeAdminLogin('a'.repeat(64), '123456'),
    ).rejects.toThrow('خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.');
  });

  it('keeps an actual fetch failure as a connection error', async () => {
    fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'));

    await expect(startAdminLogin('+967700000002', 'secret')).rejects.toThrow(
      'تعذر الاتصال بالخادم',
    );
  });

  it('starts password recovery through a neutral opaque challenge', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        accepted: true,
        challengeToken: 'c'.repeat(64),
        expiresAt: '2026-07-17T12:10:00.000Z',
        retryAfterSeconds: 60,
        deliveryStatus: 'DELIVERED',
      }),
    );

    const challenge = await requestAdminPasswordReset('+967700000003');

    expect(challenge.accepted).toBe(true);
    expect(challenge.challengeToken).toHaveLength(64);
    expect(fetchMock.mock.calls[0][0]).toContain(
      '/api/v1/auth/admin/password-reset/request',
    );
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({
      phone: '+967700000003',
    });
  });

  it('rejects a malformed recovery response instead of retaining a fake challenge', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        accepted: true,
        challengeToken: 'not-opaque',
        expiresAt: 'invalid',
        retryAfterSeconds: 60,
      }),
    );

    await expect(requestAdminPasswordReset('+967700000003')).rejects.toThrow(
      'تعذر بدء استعادة كلمة المرور',
    );
  });

  it('confirms recovery without creating a session and clears any memory token', async () => {
    setAdminAccessToken('stale-admin-token');
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { reset: true }));

    await confirmAdminPasswordReset(
      'd'.repeat(64),
      '123456',
      'Aarast-admin-2026',
    );

    expect(getAdminAccessToken()).toBeNull();
    expect(fetchMock.mock.calls[0][0]).toContain(
      '/api/v1/auth/admin/password-reset/confirm',
    );
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({
      challengeToken: 'd'.repeat(64),
      code: '123456',
      newPassword: 'Aarast-admin-2026',
    });
    expect(localStorage.length).toBe(0);
    expect(sessionStorage.length).toBe(0);
  });

  it('maps every invalid recovery challenge to one generic message', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(401, { message: 'Unknown administrator' }),
    );

    await expect(
      confirmAdminPasswordReset('e'.repeat(64), '123456', 'Aarast-admin-2026'),
    ).rejects.toThrow(
      'رمز التحقق غير صحيح أو انتهت صلاحية طلب الاستعادة.',
    );
  });
});
