import { adminTokenKey, apiRequest } from './client';

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
  const response = await apiRequest<LoginResponse>('/auth/login', {
    method: 'POST',
    auth: false,
    body: { phone, password },
  });

  if (response.user.role !== 'ADMIN') {
    throw new Error('هذا الحساب لا يملك صلاحية الدخول للوحة الإدارة.');
  }

  localStorage.setItem(adminTokenKey, response.accessToken);
  return response.user;
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
