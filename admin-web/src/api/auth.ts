import {
  AdminBrowserSession,
  ApiError,
  apiRequest,
  clearAdminAccessToken,
  refreshAdminAccessToken,
  setAdminAccessToken,
} from './client';
import { AdminPermission } from '../auth/adminPermissions';

export type AdminUser = {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: string;
  adminRole: 'SUPER_ADMIN' | 'OPERATIONS' | 'MODERATOR' | 'SUPPORT' | null;
  adminPermissions: AdminPermission[];
  status: string;
  avatarUrl?: string | null;
  createdAt?: string;
  updatedAt?: string;
};

export type AdminLoginChallenge = {
  mfaRequired: true;
  challengeToken: string;
  expiresAt: string;
  delivery: 'LOCAL_DEV' | 'WHATSAPP';
  /** Present only when the backend itself is in local development OTP mode. */
  code?: string;
};

type AdminSession = AdminBrowserSession<AdminUser>;

export async function startAdminLogin(phone: string, password: string) {
  try {
    const response = await apiRequest<AdminLoginChallenge>('/api/v1/auth/admin/login', {
      method: 'POST',
      auth: false,
      body: { phone, password },
    });
    if (
      response.mfaRequired !== true ||
      !/^[a-f0-9]{64}$/.test(response.challengeToken)
    ) {
      throw new Error('تعذر بدء التحقق بخطوتين');
    }
    return response;
  } catch (error) {
    throw mapLoginError(error);
  }
}

export async function completeAdminLogin(challengeToken: string, code: string) {
  let response: AdminSession;
  try {
    response = await apiRequest<AdminSession>('/api/v1/auth/admin/login/complete', {
      method: 'POST',
      auth: false,
      body: { challengeToken, code },
    });
  } catch (error) {
    throw mapMfaError(error);
  }

  return acceptAdminSession(response);
}

export async function restoreAdminSession(): Promise<AdminUser> {
  const response = await refreshAdminAccessToken<AdminUser>();
  return acceptAdminSession(response);
}

export async function logoutAdmin(): Promise<void> {
  try {
    await apiRequest('/api/v1/auth/admin/logout', { method: 'POST', auth: false });
  } finally {
    clearAdminAccessToken();
  }
}

function acceptAdminSession(response: AdminSession): AdminUser {
  if (response.user?.role !== 'ADMIN') {
    clearAdminAccessToken();
    throw new Error('ليس لديك صلاحية الدخول إلى لوحة الإدارة');
  }
  if (!response.accessToken) {
    clearAdminAccessToken();
    throw new Error('تعذر الاتصال بالخادم');
  }
  setAdminAccessToken(response.accessToken);
  return response.user;
}

function mapLoginError(error: unknown): Error {
  if (error instanceof ApiError) {
    if (error.status === 401 || error.status === 400) {
      return new Error('بيانات الدخول غير صحيحة');
    }
    return new Error('تعذر الاتصال بالخادم');
  }
  if (error instanceof Error && error.message === 'تعذر بدء التحقق بخطوتين') {
    return error;
  }
  return new Error('تعذر الاتصال بالخادم');
}

function mapMfaError(error: unknown): Error {
  if (error instanceof ApiError && [400, 401, 409].includes(error.status ?? 0)) {
    return new Error('رمز التحقق غير صحيح أو انتهت صلاحيته');
  }
  return new Error('تعذر إكمال التحقق. حاول مرة أخرى.');
}
