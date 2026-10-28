import {
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedUser } from './identity-session.types';
import { JwtSessionGuard } from './jwt-session.guard';

const ALLOWED_WHILE_DELETION_PENDING = 'aarast:allowed-while-deletion-pending';

/**
 * D63: the few application routes an account waiting out its deletion may
 * call (w06): read itself, read or take back the request, and sign out.
 * Every other application route answers `403 ACCOUNT_DELETION_PENDING`.
 */
export const AllowedWhileDeletionPending = () =>
  SetMetadata(ALLOWED_WHILE_DELETION_PENDING, true);

@Injectable()
export class JwtAuthGuard extends JwtSessionGuard {
  handleRequest<TUser = AuthenticatedUser>(
    error: unknown,
    user: AuthenticatedUser | false | null,
    info: unknown,
    context: ExecutionContext,
    status?: unknown,
  ): TUser {
    const authenticated = super.handleRequest<AuthenticatedUser>(
      error,
      user,
      info,
      context,
      status,
    );
    if (authenticated.sessionScope !== 'application') {
      throw new UnauthorizedException('Application session is required');
    }
    if (
      authenticated.deletionScheduledFor &&
      Reflect.getMetadata(ALLOWED_WHILE_DELETION_PENDING, context.getHandler()) !== true
    ) {
      throw new ForbiddenException({
        statusCode: 403,
        code: 'ACCOUNT_DELETION_PENDING',
        message: 'This account is waiting to be deleted',
        scheduledFor: authenticated.deletionScheduledFor,
      });
    }
    return authenticated as TUser;
  }
}
