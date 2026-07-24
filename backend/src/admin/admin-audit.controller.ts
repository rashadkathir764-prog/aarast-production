import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { JwtSessionGuard } from '../auth/jwt-session.guard';
import { AdminPermission } from '../common/admin/admin-permissions';
import { AdminAuditService } from './admin-audit.service';
import { AdminGuard } from './admin.guard';
import { RequireAdminPermission } from './admin-permission.decorator';
import { AdminPermissionGuard } from './admin-permission.guard';
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
