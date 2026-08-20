import {
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { AuthenticatedUser } from './identity-session.types';
import { JwtSessionGuard } from './jwt-session.guard';

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
    return authenticated as TUser;
  }
}
