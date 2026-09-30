import { AuthSessionScope } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';

export function findJwtSessionRows(
  prisma: PrismaService,
  userId: string,
  sessionId: string,
  expectedSessionScope: AuthSessionScope,
) {
  return Promise.all([
    prisma.user.findUnique({ where: { id: userId } }),
    prisma.refreshToken.findFirst({
      where: {
        id: sessionId,
        userId,
        scope: expectedSessionScope,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      select: { id: true },
    }),
  ]);
}
