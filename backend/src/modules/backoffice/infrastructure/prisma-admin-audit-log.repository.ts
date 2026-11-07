import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../platform/database/prisma.service';
import type { AdminAuditAppendInput, AdminAuditListQuery, AdminAuditLogPort } from '../public/admin-audit-log.port';

type AdminAuditLogRow = Awaited<ReturnType<AdminAuditLogPort['list']>>['items'][number];

/** `%`, `_` and `\` typed in the action filter are letters, not patterns. */
function likeLiteral(value: string): string {
  return value.replace(/[\\%_]/g, (character) => `\\${character}`);
}

@Injectable()
export class PrismaAdminAuditLogRepository implements AdminAuditLogPort {
  constructor(private readonly prisma: PrismaService) {}

  async append(input: AdminAuditAppendInput): Promise<void> {
    await this.prisma.adminAuditLog.create({ data: input });
  }

  /**
   * RA-AD-09: each action is two rows, its attempt and then its result
   * (`@@unique([eventId, phase])`). A page counts actions, not rows: an
   * attempt is listed only while no result came, so a pair that fell across
   * two pages no longer showed its attempt alone as «بدون نتيجة».
   */
  async list(query: AdminAuditListQuery, page: number, limit: number) {
    // Each filter is a parameter, null when not asked, so the SQL text is one
    // literal the ownership scan reads (no composed fragments).
    const trimmedAction = query.action?.trim();
    const action = trimmedAction ? `%${likeLiteral(trimmedAction)}%` : null;
    const actorUserId = query.actorUserId?.trim() || null;
    const phase = query.phase ?? null;
    // Stored as UTC without a zone (Prisma's DateTime); the bounds are read so.
    const from = query.from ? new Date(query.from).toISOString() : null;
    const to = query.to ? new Date(query.to).toISOString() : null;

    const [counted, items] = await this.prisma.$transaction([
      this.prisma.$queryRaw<Array<{ total: number }>>`
        SELECT count(*)::int AS total
        FROM "AdminAuditLog" log
        WHERE (log."phase" <> 'ATTEMPT' OR NOT EXISTS (
            SELECT 1 FROM "AdminAuditLog" result
            WHERE result."eventId" = log."eventId" AND result."phase" <> 'ATTEMPT'))
          AND (${action}::text IS NULL OR log."action" ILIKE ${action}::text ESCAPE '\\')
          AND (${actorUserId}::text IS NULL OR log."actorUserId" = ${actorUserId}::text)
          AND (${phase}::text IS NULL OR log."phase" = ${phase}::"AdminAuditPhase")
          AND (${from}::timestamp IS NULL OR log."createdAt" >= ${from}::timestamp)
          AND (${to}::timestamp IS NULL OR log."createdAt" <= ${to}::timestamp)`,
      this.prisma.$queryRaw<AdminAuditLogRow[]>`
        SELECT log."id", log."eventId", log."actorUserId", log."actorAdminRole",
               log."action", log."method", log."route", log."targetId", log."phase",
               log."statusCode", log."errorType", log."requestId", log."createdAt"
        FROM "AdminAuditLog" log
        WHERE (log."phase" <> 'ATTEMPT' OR NOT EXISTS (
            SELECT 1 FROM "AdminAuditLog" result
            WHERE result."eventId" = log."eventId" AND result."phase" <> 'ATTEMPT'))
          AND (${action}::text IS NULL OR log."action" ILIKE ${action}::text ESCAPE '\\')
          AND (${actorUserId}::text IS NULL OR log."actorUserId" = ${actorUserId}::text)
          AND (${phase}::text IS NULL OR log."phase" = ${phase}::"AdminAuditPhase")
          AND (${from}::timestamp IS NULL OR log."createdAt" >= ${from}::timestamp)
          AND (${to}::timestamp IS NULL OR log."createdAt" <= ${to}::timestamp)
        ORDER BY log."createdAt" DESC, log."id" DESC
        LIMIT ${limit} OFFSET ${(page - 1) * limit}`,
    ]);
    return { total: counted[0]?.total ?? 0, items };
  }
}
