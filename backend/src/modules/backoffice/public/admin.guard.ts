import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';

@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<{
      user?: AuthenticatedUser;
    }>();

    if (
      request.user?.role !== UserRole.ADMIN ||
      request.user.adminMfa !== true ||
      request.user.sessionScope !== 'admin'
    ) {
      throw new ForbiddenException('Admin access is required');
    }

    return true;
  }
}
