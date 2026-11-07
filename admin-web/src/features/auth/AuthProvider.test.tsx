import { act, render, screen, waitFor } from '@testing-library/react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AuthProvider, useAuth } from './AuthProvider';
import {
  apiRequest,
  clearAdminAccessToken,
  setAdminAccessToken,
  setAdminSessionExpiredHandler,
} from '../../platform/api/client';
import * as authApi from './transport';

vi.mock('./transport', () => ({
  completeAdminLogin: vi.fn(),
  logoutAdmin: vi.fn(),
  restoreAdminSession: vi.fn(),
  startAdminLogin: vi.fn(),
}));

function response(status: number, text: string): Response {
  return {
    ok: status >= 200 && status < 300,
    status,
    text: async () => text,
  } as Response;
}

function Harness() {
  const { error, user } = useAuth();
  return (
    <>
      <span>{user?.name ?? 'signed-out'}</span>
      <span>{error ?? 'no-error'}</span>
    </>
  );
}

describe('AuthProvider session expiry', () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    vi.stubGlobal('fetch', fetchMock);
    fetchMock.mockReset();
    clearAdminAccessToken();
    setAdminSessionExpiredHandler(null);
    vi.mocked(authApi.restoreAdminSession).mockResolvedValue({
      id: 'admin-1',
      name: 'Admin',
      phone: null,
      email: null,
      role: 'ADMIN',
      adminRole: 'SUPER_ADMIN',
      adminPermissions: [],
      status: 'ACTIVE',
    });
  });

  afterEach(() => {
    vi.unstubAllGlobals();
    vi.clearAllMocks();
  });

  it('clears the authenticated UI after refresh failure', async () => {
    render(
      <AuthProvider>
        <Harness />
      </AuthProvider>,
    );

    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument());

    setAdminAccessToken('expired-token');
    fetchMock
      .mockResolvedValueOnce(response(401, '{}'))
      .mockResolvedValueOnce(response(401, '{}'));

    await expect(apiRequest('/admin/users')).rejects.toMatchObject({
      status: 401,
    });

    await waitFor(() =>
      expect(screen.getByText('signed-out')).toBeInTheDocument(),
    );
    expect(
      screen.getByText('انتهت جلسة الإدارة. سجّل الدخول مرة أخرى.'),
    ).toBeInTheDocument();
  });

  // RA-AD-06: the panel never looks signed out while its session is open.
  it('stays signed in when the logout did not go through', async () => {
    let logout: (() => Promise<void>) | undefined;
    function LogoutHarness() {
      const auth = useAuth();
      logout = auth.logout;
      return <span>{auth.user?.name ?? 'signed-out'}</span>;
    }
    vi.mocked(authApi.logoutAdmin).mockRejectedValueOnce(
      new Error('تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.'),
    );
    render(
      <AuthProvider>
        <LogoutHarness />
      </AuthProvider>,
    );
    await waitFor(() => expect(screen.getByText('Admin')).toBeInTheDocument());

    await act(async () => {
      await expect(logout?.()).rejects.toThrow('تعذر الاتصال بالخادم');
    });
    expect(screen.getByText('Admin')).toBeInTheDocument();
  });

  // RA-AD-05: a page that cannot reach the server on opening says so; it is
  // not a session that ended.
  it('says the server was not reached when the session cannot be restored', async () => {
    vi.mocked(authApi.restoreAdminSession).mockRejectedValueOnce(
      new Error('تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.'),
    );
    render(
      <AuthProvider>
        <Harness />
      </AuthProvider>,
    );
    await waitFor(() => expect(screen.getByText('signed-out')).toBeInTheDocument());
    expect(
      screen.getByText('تعذر الاتصال بالخادم. تأكد من الإنترنت ثم حاول مرة ثانية.'),
    ).toBeInTheDocument();
  });

  it('opens signed out without a word when there is no session', async () => {
    const { ApiError } = await import('../../platform/api/client');
    vi.mocked(authApi.restoreAdminSession).mockRejectedValueOnce(
      new ApiError('انتهت الجلسة', 401),
    );
    render(
      <AuthProvider>
        <Harness />
      </AuthProvider>,
    );
    await waitFor(() => expect(screen.getByText('signed-out')).toBeInTheDocument());
    expect(screen.getByText('no-error')).toBeInTheDocument();
  });
});
