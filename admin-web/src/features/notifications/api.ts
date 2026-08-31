import { apiRequest } from '../../platform/api/client';
import { type Paginated, toQuery } from '../../platform/api/query';

export type AdminNotification = {
  id: string;
  userId: string;
  user?: {
    id: string;
    name: string;
    phoneMasked: string | null;
  };
  weddingPlanId: string | null;
  weddingPlan?: { id: string; title: string; city: string | null } | null;
  type: string;
  priority: string;
  title: string;
  body: string;
  entityType: string | null;
  entityId: string | null;
  routeTarget: string | null;
  data: unknown;
  financialDetailsRedacted: boolean;
  readAt: string | null;
  archivedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

type QueryParams = {
  search?: string;
  page?: number;
  limit?: number;
  type?: string;
  priority?: string;
  unreadOnly?: boolean;
};

export function getAdminNotifications(params: QueryParams = {}) {
  return apiRequest<Paginated<AdminNotification>>(
    `/admin/notifications${toQuery(params)}`,
  );
}

export function getAdminUnreadNotificationCount() {
  return apiRequest<{ count: number }>('/admin/notifications/unread-count');
}

export function markAdminNotificationRead(id: string) {
  return apiRequest<AdminNotification>(`/admin/notifications/${id}/read`, {
    method: 'PATCH',
    body: {},
  });
}

export function archiveAdminNotification(id: string) {
  return apiRequest<AdminNotification>(`/admin/notifications/${id}/archive`, {
    method: 'PATCH',
    body: {},
  });
}

export function deleteAdminNotification(id: string) {
  return apiRequest<{ id: string; deleted: true }>(
    `/admin/notifications/${id}`,
    { method: 'DELETE' },
  );
}
