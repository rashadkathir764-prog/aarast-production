import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthSessionScope } from '@prisma/client';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../platform/database/prisma.service';
import { resolveJwtSessionScope } from '../modules/identity/public/access-token-scope';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { JwtPayload } from '../modules/identity/public/jwt-payload.interface';
import { toAuthenticatedUser } from '../modules/identity/public/safe-user';
import { getJwtSecret } from './jwt-secret';

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
    const [user, session] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: payload.sub },
      }),
      this.prisma.refreshToken.findFirst({
        where: {
          id: payload.sid!,
          userId: payload.sub,
          scope: expectedSessionScope,
          revokedAt: null,
          expiresAt: { gt: new Date() },
        },
        select: { id: true },
      }),
    ]);

    if (
      !user ||
      user.status === 'DISABLED' ||
      !user.phoneVerifiedAt ||
      (!isAdminSession && !user.appPasswordConfiguredAt) ||
      !session
    ) {
      throw new UnauthorizedException('User not found, disabled, or unverified');
    }

    return {
      ...toAuthenticatedUser(user, isAdminSession),
      adminMfa: isAdminSession,
      sessionScope,
    };
  }
}
