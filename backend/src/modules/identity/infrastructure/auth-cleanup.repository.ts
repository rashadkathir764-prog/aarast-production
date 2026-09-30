import { PrismaService } from '../../../platform/database/prisma.service';

const CHALLENGE_RETENTION_MS = 24 * 60 * 60 * 1_000;
const REFRESH_TOKEN_RETENTION_MS = 30 * 24 * 60 * 60 * 1_000;

export function removeExpiredLoginThrottleWindows(
  prisma: PrismaService,
  windowMs: number,
): Promise<number | null> {
  return prisma.$transaction(async (tx) => {
    const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
      SELECT pg_try_advisory_xact_lock(20260711, 5) AS locked
    `;
    if (!lock?.locked) return null;

    const now = new Date();
    const inactiveBefore = new Date(now.getTime() - windowMs);
    const result = await tx.loginThrottle.deleteMany({
      where: {
        OR: [
          { lockedUntil: { lt: now } },
          { lockedUntil: null, updatedAt: { lt: inactiveBefore } },
        ],
      },
    });
    return result.count;
  });
}

export function removeExpiredOtpQuotaWindows(
  prisma: PrismaService,
  retentionMs: number,
): Promise<number | null> {
  return prisma.$transaction(async (tx) => {
    const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
      SELECT pg_try_advisory_xact_lock(20260712, 7) AS locked
    `;
    if (!lock?.locked) return null;

    const inactiveBefore = new Date(Date.now() - retentionMs);
    return tx.$executeRaw`
      DELETE FROM "OtpDispatchQuota"
      WHERE "updatedAt" < ${inactiveBefore}
    `;
  });
}

export function removeExpiredAuthChallenges(
  prisma: PrismaService,
): Promise<number | null> {
  return prisma.$transaction(async (tx) => {
    const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
      SELECT pg_try_advisory_xact_lock(20260717, 1) AS locked
    `;
    if (!lock?.locked) return null;

    const now = Date.now();
    const retainedAfter = new Date(now - CHALLENGE_RETENTION_MS);
    const refreshRetainedAfter = new Date(now - REFRESH_TOKEN_RETENTION_MS);
    const [loginChallenges, resetChallenges] = await Promise.all([
      tx.adminLoginChallenge.deleteMany({ where: { expiresAt: { lt: retainedAfter } } }),
      tx.adminPasswordResetChallenge.deleteMany({ where: { expiresAt: { lt: retainedAfter } } }),
    ]);
    const otpCodes = await tx.otpCode.deleteMany({
      where: { expiresAt: { lt: retainedAfter } },
    });
    const refreshTokens = await tx.refreshToken.deleteMany({
      where: {
        OR: [
          { revokedAt: null, expiresAt: { lt: refreshRetainedAfter } },
          { revokedAt: { not: null, lt: refreshRetainedAfter } },
        ],
      },
    });
    return (
      loginChallenges.count +
      resetChallenges.count +
      otpCodes.count +
      refreshTokens.count
    );
  });
}
