import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  completeAdminLogin,
  confirmAdminPasswordReset,
  logoutAdmin,
  requestAdminPasswordReset,
  restoreAdminSession,
  startAdminLogin,
  verifyAdminPasswordReset,
} from './transport';
import {
  clearAdminAccessToken,
  getAdminAccessToken,
  setAdminAccessToken,
} from '../../platform/api/client';

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

    expect('challengeToken' in challenge && challenge.challengeToken).toHaveLength(64);
    expect(getAdminAccessToken()).toBeNull();
    expect(fetchMock.mock.calls[0][0]).toContain('/api/v1/auth/admin/login');
    expect(fetchMock.mock.calls[0][1].credentials).toBe('include');
  });

  it('a remembered device signs in with the password alone', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        mfaRequired: false,
        user: { id: 'u1', name: 'مشرف', role: 'ADMIN', status: 'ACTIVE' },
        accessToken: 'remembered-device-token',
      }),
    );

    const result = await startAdminLogin('+967700000000', 'secret');

    expect('user' in result && result.user.id).toBe('u1');
    expect(getAdminAccessToken()).toBe('remembered-device-token');
    expect(localStorage.length).toBe(0);
  });

  it('a remembered-device answer for a non-admin is refused', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, {
        mfaRequired: false,
        user: { id: 'u2', name: 'مستخدم', role: 'USER', status: 'ACTIVE' },
        accessToken: 'wrong-role-token',
      }),
    );

    await expect(startAdminLogin('+967700000000', 'secret')).rejects.toThrow(
      'ليس لديك صلاحية الدخول إلى لوحة الإدارة',
    );
    expect(getAdminAccessToken()).toBeNull();
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

  // RA-AD-06: a logout the server never got leaves its cookie and session
  // on this browser; saying «out» would hand the panel to the next person.
  it('a logout that never reached the server fails and keeps the session', async () => {
    setAdminAccessToken('active-token');
    fetchMock.mockRejectedValueOnce(new TypeError('Failed to fetch'));

    await expect(logoutAdmin()).rejects.toThrow('تعذر الاتصال بالخادم');
    expect(getAdminAccessToken()).toBe('active-token');
  });

  it('a logout the server answers with an error fails and keeps the session', async () => {
    setAdminAccessToken('active-token');
    fetchMock.mockResolvedValueOnce(jsonResponse(503, { message: 'down' }));

    await expect(logoutAdmin()).rejects.toMatchObject({ status: 503 });
    expect(getAdminAccessToken()).toBe('active-token');
  });

  it('a session the server no longer knows is already out', async () => {
    setAdminAccessToken('active-token');
    fetchMock.mockResolvedValueOnce(jsonResponse(401, { message: 'Unauthorized' }));

    await expect(logoutAdmin()).resolves.toBeUndefined();
    expect(getAdminAccessToken()).toBeNull();
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
      'انتظر دقيقة ثم حاول مرة أخرى.',
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

  it('verifies the recovery code on its own, before any password', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(200, { verified: true, expiresAt: '2026-10-13T20:00:00.000Z' }),
    );

    await verifyAdminPasswordReset('d'.repeat(64), '123456');

    expect(fetchMock.mock.calls[0][0]).toContain(
      '/api/v1/auth/admin/password-reset/verify',
    );
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({
      challengeToken: 'd'.repeat(64),
      code: '123456',
    });
  });

  it('maps every rejected recovery code to one generic message', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(401, { message: 'Unknown administrator' }),
    );

    await expect(
      verifyAdminPasswordReset('e'.repeat(64), '123456'),
    ).rejects.toThrow('رمز الاستعادة غير صحيح أو انتهت صلاحيته.');
  });

  it('confirms recovery without creating a session and clears any memory token', async () => {
    setAdminAccessToken('stale-admin-token');
    fetchMock.mockResolvedValueOnce(jsonResponse(200, { reset: true }));

    await confirmAdminPasswordReset('d'.repeat(64), '123456');

    expect(getAdminAccessToken()).toBeNull();
    expect(fetchMock.mock.calls[0][0]).toContain(
      '/api/v1/auth/admin/password-reset/confirm',
    );
    expect(JSON.parse(fetchMock.mock.calls[0][1].body)).toEqual({
      challengeToken: 'd'.repeat(64),
      newPassword: '123456',
    });
    expect(localStorage.length).toBe(0);
    expect(sessionStorage.length).toBe(0);
  });

  it('an expired password window asks for a new recovery', async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse(401, { message: 'Unknown administrator' }),
    );

    await expect(
      confirmAdminPasswordReset('e'.repeat(64), '123456'),
    ).rejects.toThrow('انتهت مهلة تعيين كلمة المرور. ابدأ طلب استعادة جديدًا.');
  });
});
