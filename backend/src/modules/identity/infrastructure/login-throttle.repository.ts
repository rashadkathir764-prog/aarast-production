import { runRetryableTransaction } from '../../../platform/database/serializable-transaction';
import { PrismaService } from '../../../platform/database/prisma.service';

export function findLoginThrottleLock(
  prisma: PrismaService,
  subjectHash: string,
): Promise<{ lockedUntil: Date | null } | null> {
  return prisma.loginThrottle.findUnique({
    where: { subjectHash },
    select: { lockedUntil: true },
  });
}

export function reserveLoginThrottleAttempt(
  prisma: PrismaService,
  subjectHash: string,
  maxAttempts: number,
  windowMs: number,
): Promise<'admitted' | 'locked'> {
  return runRetryableTransaction(
    prisma,
    async (tx) => {
      const now = new Date();
      // The upsert holds the row lock until this transaction commits.
      const existing = await tx.loginThrottle.upsert({
        where: { subjectHash },
        create: { subjectHash, failedCount: 0, windowStartedAt: now },
        update: { updatedAt: now },
      });
      if (existing.lockedUntil && existing.lockedUntil > now) {
        return 'locked' as const;
      }

      const windowExpired =
        existing.lockedUntil !== null ||
        existing.windowStartedAt.getTime() <= now.getTime() - windowMs;
      const nextCount = windowExpired ? 1 : existing.failedCount + 1;
      const shouldLock = nextCount >= maxAttempts;
      await tx.loginThrottle.update({
        where: { subjectHash },
        data: {
          failedCount: shouldLock ? 0 : nextCount,
          windowStartedAt: windowExpired ? now : existing.windowStartedAt,
          lockedUntil: shouldLock ? new Date(now.getTime() + windowMs) : null,
        },
      });
      return 'admitted' as const;
    },
    { maxAttempts: 4 },
  );
}

export async function clearLoginThrottleAttempt(
  prisma: PrismaService,
  subjectHash: string,
): Promise<void> {
  await prisma.loginThrottle.deleteMany({ where: { subjectHash } });
}
