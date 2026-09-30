import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { PrismaAdminAuditLogRepository } from '../infrastructure/prisma-admin-audit-log.repository';

export const ADMIN_AUDIT_LOG_IMPLEMENTATION = Symbol('ADMIN_AUDIT_LOG_IMPLEMENTATION');

@Module({
  imports: [PrismaModule],
  providers: [
    PrismaAdminAuditLogRepository,
    { provide: ADMIN_AUDIT_LOG_IMPLEMENTATION, useExisting: PrismaAdminAuditLogRepository },
  ],
  exports: [ADMIN_AUDIT_LOG_IMPLEMENTATION],
})
export class AdminAuditLogInternalModule {}
