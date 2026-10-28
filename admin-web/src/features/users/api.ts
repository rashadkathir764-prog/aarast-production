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

/** n06 (D63): an account waiting out its 30 days before erasure. */
export type PendingDeletion = {
  userId: string;
  name: string;
  phone: string | null;
  kind: 'ACCOUNT_DELETION' | 'PROVIDER_ACCOUNT_DELETION';
  requestedAt: string;
  scheduledFor: string;
  daysLeft: number;
  purgeFailedAt: string | null;
  purgeFailure: string | null;
};

/** n06 (D63): one download of an account's own data; the link is never shown. */
export type DataExportRequest = {
  id: string;
  userId: string;
  name: string;
  phone: string | null;
  createdAt: string;
  expiresAt: string;
  downloadedAt: string | null;
  state: 'READY' | 'DOWNLOADED' | 'EXPIRED';
};

export type DataRequests = {
  deletions: PendingDeletion[];
  exports: DataExportRequest[];
};

export function getDataRequests(): Promise<DataRequests> {
  return apiRequest<DataRequests>('/admin/data-requests');
}

/** «رجّعه بطلبه»: the deletion taken back at the account's request. */
export function restoreAccountDeletion(userId: string): Promise<{ userId: string; status: 'NONE' }> {
  return apiRequest<{ userId: string; status: 'NONE' }>(
    `/admin/data-requests/${encodeURIComponent(userId)}/restore`,
    { method: 'POST', body: {} },
  );
}

export function disableUser(id: string): Promise<AdminUserRecord> {
  return apiRequest<AdminUserRecord>(`/admin/users/${id}/disable`, {
    method: 'PATCH',
    body: {},
  });
}
