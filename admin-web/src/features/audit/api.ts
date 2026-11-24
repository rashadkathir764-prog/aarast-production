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
  /** RA-AD-23: the reason or note the admin gave, when the action takes one. */
  reason: string | null;
  /** RA-AD-23: what the action changed on its target, before and after. */
  before: AdminAuditState | null;
  after: AdminAuditState | null;
  createdAt: string;
};

export type AdminAuditState = Record<string, string | number | boolean | null>;

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
