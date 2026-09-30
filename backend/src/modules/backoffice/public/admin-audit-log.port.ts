import type { AdminAuditPhase, AdminRole } from '@prisma/client';

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
      createdAt: Date;
    }>;
  }>;
}
