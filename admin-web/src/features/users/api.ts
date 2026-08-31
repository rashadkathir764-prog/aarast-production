import type { AdminUser } from '../auth/api';
import { apiRequest } from '../../platform/api/client';
import { type Paginated, toQuery } from '../../platform/api/query';

export type UserProviderSummary = {
  id: string;
  businessName: string;
  status: string;
  city?: { nameAr: string } | null;
  primaryCategory?: { nameAr: string } | null;
};

export type AdminUserRecord = AdminUser & {
  provider?: UserProviderSummary | null;
};

type UserQueryParams = {
  status?: string;
  search?: string;
  page?: number;
  limit?: number;
};

export function getUsers(
  params?: UserQueryParams,
): Promise<Paginated<AdminUserRecord>> {
  return apiRequest<Paginated<AdminUserRecord>>(`/admin/users${toQuery(params ?? {})}`);
}

export function getUser(id: string): Promise<AdminUserRecord> {
  return apiRequest<AdminUserRecord>(`/admin/users/${id}`);
}

export function activateUser(id: string): Promise<AdminUserRecord> {
  return apiRequest<AdminUserRecord>(`/admin/users/${id}/activate`, {
    method: 'PATCH',
    body: {},
  });
}

export function disableUser(id: string): Promise<AdminUserRecord> {
  return apiRequest<AdminUserRecord>(`/admin/users/${id}/disable`, {
    method: 'PATCH',
    body: {},
  });
}
