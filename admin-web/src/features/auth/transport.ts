import {
  AdminBrowserSession,
  ApiError,
  apiRequest,
  clearAdminAccessToken,
  refreshAdminAccessToken,
  setAdminAccessToken,
} from '../../platform/api/client';
import { AdminPermission } from './adminPermissions';

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

export type OtpDeliveryStatus =
  | 'LOCAL_DEV'
  | 'DELIVERED'
  | 'PENDING'
  | 'UNCERTAIN';

export type AdminLoginChallenge = {
  mfaRequired: true;
  challengeToken: string;
  expiresAt: string;
  delivery: 'LOCAL_DEV' | 'WHATSAPP';
  deliveryStatus: OtpDeliveryStatus;
  /** Present only when the backend itself is in local development OTP mode. */
  code?: string;
};

export type AdminPasswordResetChallenge = {
  accepted: true;
  challengeToken: string;
  expiresAt: string;
  retryAfterSeconds: number;
  deliveryStatus: OtpDeliveryStatus;
};

type AdminPasswordResetResult = {
  reset: true;
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
      !/^[a-f0-9]{64}$/.test(response.challengeToken) ||
      !isOtpDeliveryStatus(response.deliveryStatus)
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

export async function requestAdminPasswordReset(
  phone: string,
): Promise<AdminPasswordResetChallenge> {
  try {
    const response = await apiRequest<AdminPasswordResetChallenge>(
      '/api/v1/auth/admin/password-reset/request',
      {
        method: 'POST',
        auth: false,
        body: { phone },
      },
    );
    if (
      response.accepted !== true ||
      !/^[a-f0-9]{64}$/.test(response.challengeToken) ||
      !Number.isFinite(Date.parse(response.expiresAt)) ||
      !Number.isInteger(response.retryAfterSeconds) ||
      response.retryAfterSeconds < 0 ||
      !isOtpDeliveryStatus(response.deliveryStatus)
    ) {
      throw new Error('تعذر بدء استعادة كلمة المرور');
    }
    return response;
  } catch (error) {
    throw mapPasswordResetRequestError(error);
  }
}

function isOtpDeliveryStatus(value: unknown): value is OtpDeliveryStatus {
  return (
    value === 'LOCAL_DEV' ||
    value === 'DELIVERED' ||
    value === 'PENDING' ||
    value === 'UNCERTAIN'
  );
}

export async function confirmAdminPasswordReset(
  challengeToken: string,
  code: string,
  newPassword: string,
): Promise<void> {
  try {
    const response = await apiRequest<AdminPasswordResetResult>(
      '/api/v1/auth/admin/password-reset/confirm',
      {
        method: 'POST',
        auth: false,
        body: { challengeToken, code, newPassword },
      },
    );
    if (response.reset !== true) {
      throw new Error('تعذر تغيير كلمة المرور');
    }
    clearAdminAccessToken();
  } catch (error) {
    throw mapPasswordResetConfirmError(error);
  }
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
    if (isOtpDeliveryUnavailable(error)) {
      return new Error(otpDeliveryUnavailableMessage);
    }
    if (error.status === 401 || error.status === 400) {
      return new Error('بيانات الدخول غير صحيحة');
    }
    if (error.status === 429) {
      return new Error('محاولات دخول كثيرة. انتظر قليلًا ثم حاول مرة أخرى.');
    }
    return new Error('حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.');
  }
  if (error instanceof Error && error.message === 'تعذر بدء التحقق بخطوتين') {
    return error;
  }
  return new Error('تعذر الاتصال بالخادم');
}

function mapMfaError(error: unknown): Error {
  if (error instanceof ApiError && isOtpDeliveryUnavailable(error)) {
    return new Error(otpDeliveryUnavailableMessage);
  }
  if (error instanceof ApiError && [400, 401, 409].includes(error.status ?? 0)) {
    return new Error('رمز التحقق غير صحيح أو انتهت صلاحيته');
  }
  if (error instanceof ApiError && error.status === 429) {
    return new Error('محاولات تحقق كثيرة. انتظر قليلًا ثم حاول مرة أخرى.');
  }
  return new Error('تعذر إكمال التحقق. حاول مرة أخرى.');
}

function mapPasswordResetRequestError(error: unknown): Error {
  if (error instanceof ApiError && isOtpDeliveryUnavailable(error)) {
    return new Error(otpDeliveryUnavailableMessage);
  }
  if (error instanceof ApiError && error.status === 429) {
    return new Error('طلبات استعادة كثيرة. انتظر قليلًا ثم حاول مرة أخرى.');
  }
  if (error instanceof ApiError && error.status === 400) {
    return new Error('تحقق من رقم الهاتف ثم حاول مرة أخرى.');
  }
  if (error instanceof ApiError) {
    return new Error('حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.');
  }
  if (
    error instanceof Error &&
    error.message === 'تعذر بدء استعادة كلمة المرور'
  ) {
    return error;
  }
  return new Error('تعذر الاتصال بالخادم');
}

function mapPasswordResetConfirmError(error: unknown): Error {
  if (error instanceof ApiError && isOtpDeliveryUnavailable(error)) {
    return new Error(otpDeliveryUnavailableMessage);
  }
  if (
    error instanceof ApiError &&
    [400, 401, 409].includes(error.status ?? 0)
  ) {
    return new Error('رمز التحقق غير صحيح أو انتهت صلاحية طلب الاستعادة.');
  }
  if (error instanceof ApiError && error.status === 429) {
    return new Error('محاولات تحقق كثيرة. انتظر قليلًا ثم ابدأ طلبًا جديدًا.');
  }
  if (error instanceof ApiError) {
    return new Error('حدث خطأ في الخادم. حاول مرة أخرى بعد قليل.');
  }
  if (
    error instanceof Error &&
    error.message === 'تعذر تغيير كلمة المرور'
  ) {
    return error;
  }
  return new Error('تعذر الاتصال بالخادم');
}

const otpDeliveryUnavailableMessage =
  'خدمة رمز التحقق غير متاحة حاليًا. حاول بعد قليل.';

function isOtpDeliveryUnavailable(error: ApiError): boolean {
  return error.code === 'OTP_DELIVERY_UNAVAILABLE';
}
