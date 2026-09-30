import { Injectable } from '@nestjs/common';
import type { AdminAuditPhase } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';
import type { AdminAuditAppendInput, AdminAuditListQuery, AdminAuditLogPort } from '../public/admin-audit-log.port';

interface AdminAuditLogWhere {
  action?: { contains: string; mode: 'insensitive' };
  actorUserId?: string;
  phase?: AdminAuditPhase;
  createdAt?: { gte?: Date; lte?: Date };
}

@Injectable()
export class PrismaAdminAuditLogRepository implements AdminAuditLogPort {
  constructor(private readonly prisma: PrismaService) {}

  async append(input: AdminAuditAppendInput): Promise<void> {
    await this.prisma.adminAuditLog.create({ data: input });
  }

  async list(query: AdminAuditListQuery, page: number, limit: number) {
    const createdAt = {
      ...(query.from ? { gte: new Date(query.from) } : {}),
      ...(query.to ? { lte: new Date(query.to) } : {}),
    };
    const where: AdminAuditLogWhere = {
      ...(query.action
        ? { action: { contains: query.action.trim(), mode: 'insensitive' } }
        : {}),
      ...(query.actorUserId ? { actorUserId: query.actorUserId.trim() } : {}),
      ...(query.phase ? { phase: query.phase } : {}),
      ...(Object.keys(createdAt).length ? { createdAt } : {}),
    };

    const [total, items] = await this.prisma.$transaction([
      this.prisma.adminAuditLog.count({ where }),
      this.prisma.adminAuditLog.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * limit,
        take: limit,
        select: {
          id: true,
          eventId: true,
          actorUserId: true,
          actorAdminRole: true,
          action: true,
          method: true,
          route: true,
          targetId: true,
          phase: true,
          statusCode: true,
          errorType: true,
          requestId: true,
          createdAt: true,
        },
      }),
    ]);
    return { total, items };
  }
}
