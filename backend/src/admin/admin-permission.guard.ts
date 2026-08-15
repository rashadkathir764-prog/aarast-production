import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  AdminPermission,
  hasAdminPermission,
} from '../modules/backoffice/domain/admin-permissions';
import { ADMIN_PERMISSIONS_KEY } from './admin-permission.decorator';

@Injectable()
export class AdminPermissionGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const required = this.reflector.getAllAndOverride<AdminPermission[]>(
      ADMIN_PERMISSIONS_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!required?.length) {
      throw new ForbiddenException('Admin permission is required');
    }

    const request = context.switchToHttp().getRequest<{
      user?: AuthenticatedUser;
    }>();
    if (
      !request.user?.adminRole ||
      !required.every((permission) =>
        hasAdminPermission(request.user?.adminRole, permission),
      )
    ) {
      throw new ForbiddenException('Admin permission is required');
    }
    return true;
  }
}
