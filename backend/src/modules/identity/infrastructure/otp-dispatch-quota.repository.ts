import { HttpException, HttpStatus } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';

export interface OtpQuotaPolicy {
  scope: string;
  subject: string;
  limit: number;
  windowMs: number;
}

interface QuotaRow {
  count: number;
}

/**
 * How many codes a quota counted in its current window: none once the window
 * has passed, as the next consume would start it again.
 */
export async function readOtpDispatchQuotaCount(
  prisma: PrismaService,
  scope: string,
  subjectHash: string,
  windowMs: number,
  now: Date,
): Promise<number> {
  const row = await prisma.otpDispatchQuota.findUnique({
    where: { scope_subjectHash: { scope, subjectHash } },
    select: { count: true, windowStartedAt: true },
  });
  if (!row) return 0;
  return row.windowStartedAt.getTime() <= now.getTime() - windowMs ? 0 : row.count;
}

export function consumeOtpDispatchQuotaAttempt(
  prisma: PrismaService,
  policies: readonly OtpQuotaPolicy[],
  now: () => Date,
  subjectHash: (scope: string, subject: string) => string,
): Promise<void> {
  return prisma.$transaction(
    async (tx) => {
      const current = now();
      for (const policy of policies) {
        const resetBefore = new Date(current.getTime() - policy.windowMs);
        const hash = subjectHash(policy.scope, policy.subject);
        const [row] = await tx.$queryRawUnsafe<QuotaRow[]>(
          `
            INSERT INTO "OtpDispatchQuota"
              ("scope", "subjectHash", "count", "windowStartedAt", "updatedAt")
            VALUES ($1, $2, 1, $3, $3)
            ON CONFLICT ("scope", "subjectHash") DO UPDATE SET
              "count" = CASE
                WHEN "OtpDispatchQuota"."windowStartedAt" <= $4 THEN 1
                ELSE "OtpDispatchQuota"."count" + 1
              END,
              "windowStartedAt" = CASE
                WHEN "OtpDispatchQuota"."windowStartedAt" <= $4 THEN $3
                ELSE "OtpDispatchQuota"."windowStartedAt"
              END,
              "updatedAt" = $3
            RETURNING "count"
          `,
          policy.scope,
          hash,
          current,
          resetBefore,
        );
        if (!row || row.count > policy.limit) {
          throw new HttpException(
            'طلبات رمز التحقق كثيرة. حاول لاحقًا.',
            HttpStatus.TOO_MANY_REQUESTS,
          );
        }
      }
    },
    { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
  );
}
