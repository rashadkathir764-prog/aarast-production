import type { AdminAuditPhase, AdminRole } from '@prisma/client';
import type { AdminAuditState } from './admin-audit-change';

export interface AdminAuditListQuery {
  action?: string;
  actorUserId?: string;
  phase?: AdminAuditPhase;
  from?: string;
  to?: string;
}

export const ADMIN_AUDIT_LOG_PORT = Symbol('ADMIN_AUDIT_LOG_PORT');

export interface AdminAuditAppendInput {
  eventId: string;
  actorUserId: string;
  actorAdminRole: AdminRole;
  action: string;
  method: string;
  route: string;
  targetId: string | null;
  requestId: string | undefined;
  phase: AdminAuditPhase;
  statusCode?: number;
  errorType?: string;
  /** RA-AD-23: the reason or note the admin gave. */
  reason: string | null;
  /** RA-AD-23: what the action changed, on its SUCCEEDED row. */
  before?: AdminAuditState | null;
  after?: AdminAuditState | null;
}

export interface AdminAuditLogPort {
  append(input: AdminAuditAppendInput): Promise<void>;
  list(query: AdminAuditListQuery, page: number, limit: number): Promise<{
    total: number;
    items: Array<{
      id: string;
      eventId: string;
      actorUserId: string;
      actorAdminRole: AdminRole;
      action: string;
      method: string;
      route: string;
      targetId: string | null;
      phase: AdminAuditPhase;
      statusCode: number | null;
      errorType: string | null;
      requestId: string | null;
      reason: string | null;
      before: AdminAuditState | null;
      after: AdminAuditState | null;
      createdAt: Date;
    }>;
  }>;
}
