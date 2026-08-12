import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../platform/database/prisma.service';
import { AdminAuditQueryDto } from './dto/admin-audit-query.dto';

@Injectable()
export class AdminAuditService {
  constructor(private readonly prisma: PrismaService) {}

  async list(query: AdminAuditQueryDto) {
    const page = this.positiveInteger(query.page ?? '1', 'page');
    const limit = Math.min(
      this.positiveInteger(query.limit ?? '20', 'limit'),
      100,
    );
    const createdAt = {
      ...(query.from ? { gte: new Date(query.from) } : {}),
      ...(query.to ? { lte: new Date(query.to) } : {}),
    };
    const where: Prisma.AdminAuditLogWhereInput = {
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

    return {
      items,
      page,
      limit,
      total,
      totalPages: Math.max(Math.ceil(total / limit), 1),
    };
  }

  private positiveInteger(value: string, field: string): number {
    const parsed = Number(value);
    if (!Number.isSafeInteger(parsed) || parsed < 1) {
      throw new BadRequestException(`${field} must be a positive integer`);
    }
    return parsed;
  }
}
