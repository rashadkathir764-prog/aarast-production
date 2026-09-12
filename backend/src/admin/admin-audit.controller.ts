import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtSessionGuard } from '../modules/identity/public/jwt-session.guard';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { AdminAuditService } from './admin-audit.service';
import { AdminGuard } from '../modules/backoffice/public/admin.guard';
import { RequireAdminPermission } from '../modules/backoffice/public/admin-permission.decorator';
import { AdminPermissionGuard } from '../modules/backoffice/public/admin-permission.guard';
import { AdminAuditQueryDto } from './dto/admin-audit-query.dto';

@Controller('admin/audit-logs')
@UseGuards(JwtSessionGuard, AdminGuard, AdminPermissionGuard)
export class AdminAuditController {
  constructor(private readonly auditService: AdminAuditService) {}

  @Get()
  @RequireAdminPermission(AdminPermission.AUDIT_READ)
  list(@Query() query: AdminAuditQueryDto) {
    return this.auditService.list(query);
  }
}
