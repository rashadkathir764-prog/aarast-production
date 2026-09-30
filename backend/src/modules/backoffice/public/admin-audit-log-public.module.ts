import { Module } from '@nestjs/common';
import { ADMIN_AUDIT_LOG_IMPLEMENTATION, AdminAuditLogInternalModule } from '../internal/admin-audit-log.internal.module';
import { ADMIN_AUDIT_LOG_PORT } from './admin-audit-log.port';

@Module({
  imports: [AdminAuditLogInternalModule],
  providers: [
    { provide: ADMIN_AUDIT_LOG_PORT, useExisting: ADMIN_AUDIT_LOG_IMPLEMENTATION },
  ],
  exports: [ADMIN_AUDIT_LOG_PORT],
})
export class AdminAuditLogPublicModule {}
