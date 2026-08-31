import { apiRequest } from '../../platform/api/client';
import { type Paginated, toQuery } from '../../platform/api/query';

export type AdminAuditPhase = 'ATTEMPT' | 'SUCCEEDED' | 'FAILED';

export type AdminAuditLog = {
  id: string;
  eventId: string;
  actorUserId: string;
  actorAdminRole: 'SUPER_ADMIN' | 'OPERATIONS' | 'MODERATOR' | 'SUPPORT';
  action: string;
  method: string;
  route: string;
  targetId: string | null;
  phase: AdminAuditPhase;
  statusCode: number | null;
  errorType: string | null;
  requestId: string | null;
  createdAt: string;
};

type QueryParams = {
  page?: number;
  limit?: number;
  action?: string;
  actorUserId?: string;
  phase?: AdminAuditPhase;
};

export function getAdminAuditLogs(params: QueryParams = {}) {
  return apiRequest<Paginated<AdminAuditLog>>(
    `/admin/audit-logs${toQuery(params)}`,
  );
}
