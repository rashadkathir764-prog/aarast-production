import { adminTokenKey, ApiError, apiRequest } from './client';

export type AdminUser = {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: string;
  status: string;
  avatarUrl?: string | null;
  createdAt?: string;
  updatedAt?: string;
};

type LoginResponse = {
  user: AdminUser;
  accessToken: string;
};

export async function loginAdmin(phone: string, password: string) {
  let response: LoginResponse;
  try {
    response = await apiRequest<LoginResponse>('/auth/login', {
      method: 'POST',
      auth: false,
      body: { phone, password },
    });
  } catch (error) {
    throw mapLoginError(error);
  }

  if (response.user.role !== 'ADMIN') {
    throw new Error('ليس لديك صلاحية الدخول إلى لوحة الإدارة');
  }

  if (!response.accessToken) {
    throw new Error('تعذر الاتصال بالخادم');
  }

  localStorage.setItem(adminTokenKey, response.accessToken);
  return response.user;
}

function mapLoginError(error: unknown): Error {
  if (error instanceof ApiError) {
    if (error.status === 401 || error.status === 400) {
      return new Error('بيانات الدخول غير صحيحة');
    }

    return new Error('تعذر الاتصال بالخادم');
  }

  return new Error('تعذر الاتصال بالخادم');
}

export async function fetchMe() {
  return apiRequest<AdminUser>('/auth/me');
}

export function getAdminToken() {
  return localStorage.getItem(adminTokenKey);
}

export function clearAdminToken() {
  localStorage.removeItem(adminTokenKey);
}
