import {
  CallHandler,
  ExecutionContext,
  Inject,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { AdminAuditPhase } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import {
  Observable,
  catchError,
  from,
  map,
  of,
  switchMap,
  throwError,
} from 'rxjs';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  requestRouteTemplate,
  safeClientRequestId,
} from '../platform/observability/sanitize-request-target';
import {
  ADMIN_AUDIT_LOG_PORT,
  type AdminAuditLogPort,
} from '../modules/backoffice/public/admin-audit-log.port';

interface AdminAuditRequest {
  baseUrl?: string;
  method?: string;
  params?: Record<string, unknown>;
  requestId?: string;
  route?: { path?: unknown };
  user?: AuthenticatedUser;
}

const mutatingMethods = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

@Injectable()
export class AdminAuditInterceptor implements NestInterceptor {
  private readonly logger = new Logger(AdminAuditInterceptor.name);

  constructor(
    @Inject(ADMIN_AUDIT_LOG_PORT)
    private readonly auditLog: AdminAuditLogPort,
  ) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    const request = context.switchToHttp().getRequest<AdminAuditRequest>();
    const method = (request.method ?? '').toUpperCase();
    const route = requestRouteTemplate(request);
    const actor = request.user;
    if (
      !mutatingMethods.has(method) ||
      !route.startsWith('/admin') ||
      !actor?.adminRole
    ) {
      return next.handle();
    }

    const eventId = randomUUID();
    const action = `${method} ${route}`;
    const targetId = this.safeTargetId(request.params?.id);
    const requestId = safeClientRequestId(request.requestId);
    const base = {
      eventId,
      actorUserId: actor.id,
      actorAdminRole: actor.adminRole,
      action,
      method,
      route,
      targetId,
      requestId,
    };

    // Fail closed before the mutation: if the ATTEMPT cannot be persisted,
    // no privileged write is allowed to proceed without audit evidence.
    return from(
      this.auditLog.append({ ...base, phase: AdminAuditPhase.ATTEMPT }),
    ).pipe(
      switchMap(() =>
        next.handle().pipe(
          switchMap((response) =>
            from(
              this.auditLog.append({
                ...base,
                phase: AdminAuditPhase.SUCCEEDED,
                statusCode: this.responseStatus(context, 200),
              }),
            ).pipe(
              map(() => response),
              // ATTEMPT remains durable if the terminal write fails after the
              // domain mutation; do not turn a committed write into a retry.
              catchError(() => {
                this.logger.error(`Missing SUCCEEDED audit phase event=${eventId}`);
                return of(response);
              }),
            ),
          ),
          catchError((error) =>
            from(
              this.auditLog.append({
                ...base,
                phase: AdminAuditPhase.FAILED,
                statusCode: this.errorStatus(error),
                errorType: this.safeErrorType(error),
              }),
            ).pipe(
              catchError(() => {
                this.logger.error(`Missing FAILED audit phase event=${eventId}`);
                return of(undefined);
              }),
              switchMap(() => throwError(() => error)),
            ),
          ),
        ),
      ),
    );
  }

  private safeTargetId(value: unknown): string | null {
    return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value)
      ? value
      : null;
  }

  private safeErrorType(error: unknown): string {
    const name = error instanceof Error ? error.constructor.name : 'UnknownError';
    return /^[A-Za-z][A-Za-z0-9]{0,63}$/.test(name) ? name : 'UnknownError';
  }

  private errorStatus(error: unknown): number {
    if (
      error &&
      typeof error === 'object' &&
      'getStatus' in error &&
      typeof error.getStatus === 'function'
    ) {
      const status = error.getStatus();
      if (Number.isInteger(status) && status >= 400 && status <= 599) return status;
    }
    return 500;
  }

  private responseStatus(context: ExecutionContext, fallback: number): number {
    const response = context.switchToHttp().getResponse<{ statusCode?: number }>();
    return Number.isInteger(response.statusCode) ? response.statusCode! : fallback;
  }
}
