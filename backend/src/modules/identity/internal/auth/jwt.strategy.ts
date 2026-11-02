import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthSessionScope } from '@prisma/client';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../../../../platform/database/prisma.service';
import { resolveJwtSessionScope } from '../../public/access-token-scope';
import { AuthenticatedUser } from '../../public/identity-session.types';
import { JwtPayload } from '../../public/jwt-payload.interface';
import { toAuthenticatedUser } from '../../public/safe-user';
import { getJwtSecret } from './jwt-secret';
import { findJwtSessionRows } from '../../infrastructure/jwt-session.repository';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly prisma: PrismaService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: getJwtSecret(),
    });
  }

  async validate(payload: JwtPayload): Promise<AuthenticatedUser> {
    const sessionScope = resolveJwtSessionScope(payload);
    if (!sessionScope) {
      throw new UnauthorizedException('Session is invalid or expired');
    }
    const isAdminSession = sessionScope === 'admin';
    const expectedSessionScope = isAdminSession
      ? AuthSessionScope.ADMIN
      : AuthSessionScope.APPLICATION;
    const [user, session] = await findJwtSessionRows(
      this.prisma,
      payload.sub,
      payload.sid!,
      expectedSessionScope,
    );

    if (
      !user ||
      user.status === 'DISABLED' ||
      !user.phoneVerifiedAt ||
      (!isAdminSession && !user.appAccountActivatedAt) ||
      !session
    ) {
      throw new UnauthorizedException('User not found, disabled, or unverified');
    }

    return {
      ...toAuthenticatedUser(user, isAdminSession),
      adminMfa: isAdminSession,
      sessionScope,
      sessionId: payload.sid,
    };
  }
}
