import { Module } from '@nestjs/common';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { PrismaAdminAuditLogRepository } from '../infrastructure/prisma-admin-audit-log.repository';
import { AdminAuditRetentionScheduler } from '../infrastructure/admin-audit-retention.scheduler';

export const ADMIN_AUDIT_LOG_IMPLEMENTATION = Symbol('ADMIN_AUDIT_LOG_IMPLEMENTATION');

@Module({
  imports: [PrismaModule],
  providers: [
    PrismaAdminAuditLogRepository,
    { provide: ADMIN_AUDIT_LOG_IMPLEMENTATION, useExisting: PrismaAdminAuditLogRepository },
    // RA-BE-179: the audit rows go after two years.
    AdminAuditRetentionScheduler,
  ],
  exports: [ADMIN_AUDIT_LOG_IMPLEMENTATION],
})
export class AdminAuditLogInternalModule {}
