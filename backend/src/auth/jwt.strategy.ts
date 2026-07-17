import { Injectable, UnauthorizedException } from '@nestjs/common';
import { AuthSessionScope } from '@prisma/client';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { PrismaService } from '../prisma/prisma.service';
import { AuthenticatedUser } from './authenticated-user.interface';
import { JwtPayload } from './jwt-payload.interface';
import { toAuthenticatedUser } from './safe-user';
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
    const [user, adminSession] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: payload.sub },
      }),
      payload.amr === 'admin_mfa' && payload.sid
        ? this.prisma.refreshToken.findFirst({
            where: {
              id: payload.sid,
              userId: payload.sub,
              scope: AuthSessionScope.ADMIN,
              revokedAt: null,
              expiresAt: { gt: new Date() },
            },
            select: { id: true },
          })
        : Promise.resolve(null),
    ]);

    if (
      !user ||
      user.status === 'DISABLED' ||
      !user.phoneVerifiedAt ||
      (payload.amr === 'admin_mfa' && !adminSession)
    ) {
      throw new UnauthorizedException('User not found, disabled, or unverified');
    }

    return {
      ...toAuthenticatedUser(user, payload.amr === 'admin_mfa'),
      adminMfa: payload.amr === 'admin_mfa',
    };
  }
}
