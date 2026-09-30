import { BadRequestException, Inject, Injectable } from '@nestjs/common';
import {
  ADMIN_AUDIT_LOG_PORT,
  type AdminAuditLogPort,
} from '../modules/backoffice/public/admin-audit-log.port';
import { AdminAuditQueryDto } from './dto/admin-audit-query.dto';

@Injectable()
export class AdminAuditService {
  constructor(
    @Inject(ADMIN_AUDIT_LOG_PORT)
    private readonly auditLog: AdminAuditLogPort,
  ) {}

  async list(query: AdminAuditQueryDto) {
    const page = this.positiveInteger(query.page ?? '1', 'page');
    const limit = Math.min(
      this.positiveInteger(query.limit ?? '20', 'limit'),
      100,
    );
    const { total, items } = await this.auditLog.list(query, page, limit);

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
