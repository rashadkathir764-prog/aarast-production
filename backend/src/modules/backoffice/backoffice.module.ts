import { Module } from '@nestjs/common';
import { AdminAuditController } from '../../admin/admin-audit.controller';
import { AdminController } from '../../admin/admin.controller';
import { BackofficeServicesInternalModule } from './internal/backoffice-services.internal.module';

@Module({
  imports: [BackofficeServicesInternalModule],
  controllers: [AdminController, AdminAuditController],
})
export class BackofficeModule {}
