import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../platform/database/prisma.service';
import type {
  AssistantQuestionCost,
  AssistantQuotaPort,
  AssistantReservation,
  AssistantReservationRequest,
} from '../public/assistant-quota.port';

/**
 * RA-BE-165: every reservation takes this lock for its transaction, so a
 * question checks the month's spending only after every reservation before
 * it is written: two at once can never both pass a cap one alone reaches.
 */
const ASSISTANT_BUDGET_LOCK = [20261124, 2] as const;

@Injectable()
export class AssistantQuotaService implements AssistantQuotaPort {
  constructor(private readonly prisma: PrismaService) {}

  async reserveQuestion(
    userId: string,
    day: string,
    request: AssistantReservationRequest,
  ): Promise<AssistantReservation> {
    if (request.dailyLimit < 1) return { outcome: 'DAILY_LIMIT_REACHED' };
    return this.prisma.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT pg_advisory_xact_lock(${ASSISTANT_BUDGET_LOCK[0]}::int, ${ASSISTANT_BUDGET_LOCK[1]}::int)`;
      const [spent] = await tx.$queryRaw<Array<{ service: bigint; account: bigint }>>`
        SELECT COALESCE(SUM("costMicroUsd"), 0)::bigint AS "service",
               COALESCE(SUM("costMicroUsd") FILTER (WHERE "userId" = ${userId}), 0)::bigint AS "account"
        FROM "AssistantUsageDay"
        WHERE "day" >= ${request.monthStart}::date`;
      const service = spent?.service ?? 0n;
      if (service >= request.serviceMonthlyBudgetMicroUsd) {
        return { outcome: 'SERVICE_BUDGET_REACHED' };
      }
      if ((spent?.account ?? 0n) >= request.userMonthlyBudgetMicroUsd) {
        return { outcome: 'USER_BUDGET_REACHED' };
      }
      const counted = await tx.$queryRaw<Array<{ requests: number }>>`
        INSERT INTO "AssistantUsageDay" ("userId", "day", "requests", "costMicroUsd", "updatedAt")
        VALUES (${userId}, ${day}::date, 1, ${request.reserveMicroUsd}, NOW())
        ON CONFLICT ("userId", "day") DO UPDATE SET
          "requests" = "AssistantUsageDay"."requests" + 1,
          "costMicroUsd" = "AssistantUsageDay"."costMicroUsd" + ${request.reserveMicroUsd},
          "updatedAt" = NOW()
        WHERE "AssistantUsageDay"."requests" < ${request.dailyLimit}
        RETURNING "requests"`;
      return counted.length === 1
        ? { outcome: 'RESERVED', serviceSpentBefore: service }
        : { outcome: 'DAILY_LIMIT_REACHED' };
    });
  }

  async releaseQuestion(userId: string, day: string, refundMicroUsd: bigint): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE "AssistantUsageDay"
      SET "requests" = GREATEST("requests" - 1, 0),
          "costMicroUsd" = "costMicroUsd" - ${refundMicroUsd},
          "updatedAt" = NOW()
      WHERE "userId" = ${userId} AND "day" = ${day}::date`;
  }

  async settleQuestion(
    userId: string,
    day: string,
    reservedMicroUsd: bigint,
    cost: AssistantQuestionCost,
  ): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE "AssistantUsageDay"
      SET "inputTokens" = "inputTokens" + ${cost.inputTokens},
          "outputTokens" = "outputTokens" + ${cost.outputTokens},
          "costMicroUsd" = "costMicroUsd" - ${reservedMicroUsd} + ${cost.costMicroUsd},
          "updatedAt" = NOW()
      WHERE "userId" = ${userId} AND "day" = ${day}::date`;
  }

  async questionsOn(userId: string, day: string): Promise<number> {
    const [row] = await this.prisma.$queryRaw<Array<{ requests: number }>>`
      SELECT "requests" FROM "AssistantUsageDay"
      WHERE "userId" = ${userId} AND "day" = ${day}::date`;
    return row?.requests ?? 0;
  }
}
