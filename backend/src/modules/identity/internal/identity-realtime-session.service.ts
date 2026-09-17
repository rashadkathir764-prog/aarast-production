import { Injectable } from '@nestjs/common';
import { AuthSessionScope, UserStatus } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';
import type { IdentityRealtimeSessionPort } from '../public/identity-realtime-session.port';
import type { AuthenticatedUser } from '../public/identity-session.types';
import { toAuthenticatedUser } from '../public/safe-user';

@Injectable()
export class IdentityRealtimeSessionService
  implements IdentityRealtimeSessionPort
{
  constructor(private readonly prisma: PrismaService) {}

  async findRealtimeSessionUser(
    userId: string,
    sessionId: string,
  ): Promise<AuthenticatedUser | null> {
    const [user, live] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId } }),
      this.isApplicationSessionLive(userId, sessionId),
    ]);
    if (
      !user ||
      user.status === UserStatus.DISABLED ||
      !user.phoneVerifiedAt ||
      !live
    ) {
      return null;
    }
    return toAuthenticatedUser(user);
  }

  async isApplicationSessionLive(
    userId: string,
    sessionId: string,
  ): Promise<boolean> {
    const session = await this.prisma.refreshToken.findFirst({
      where: {
        id: sessionId,
        userId,
        scope: AuthSessionScope.APPLICATION,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true },
    });
    return session !== null;
  }
}
