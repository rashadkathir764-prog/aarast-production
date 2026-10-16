import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../platform/database/prisma.service';
import type {
  AssistantQuestionCost,
  AssistantQuotaPort,
} from '../public/assistant-quota.port';

@Injectable()
export class AssistantQuotaService implements AssistantQuotaPort {
  constructor(private readonly prisma: PrismaService) {}

  async reserveQuestion(userId: string, day: string, dailyLimit: number): Promise<boolean> {
    if (dailyLimit < 1) return false;
    // One statement: a concurrent second question sees the first one's count.
    const rows = await this.prisma.$queryRaw<Array<{ requests: number }>>`
      INSERT INTO "AssistantUsageDay" ("userId", "day", "requests", "updatedAt")
      VALUES (${userId}, ${day}::date, 1, NOW())
      ON CONFLICT ("userId", "day") DO UPDATE SET
        "requests" = "AssistantUsageDay"."requests" + 1,
        "updatedAt" = NOW()
      WHERE "AssistantUsageDay"."requests" < ${dailyLimit}
      RETURNING "requests"`;
    return rows.length === 1;
  }

  async releaseQuestion(userId: string, day: string): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE "AssistantUsageDay"
      SET "requests" = GREATEST("requests" - 1, 0), "updatedAt" = NOW()
      WHERE "userId" = ${userId} AND "day" = ${day}::date`;
  }

  async recordQuestionCost(
    userId: string,
    day: string,
    cost: AssistantQuestionCost,
  ): Promise<void> {
    await this.prisma.$executeRaw`
      UPDATE "AssistantUsageDay"
      SET "inputTokens" = "inputTokens" + ${cost.inputTokens},
          "outputTokens" = "outputTokens" + ${cost.outputTokens},
          "costMicroUsd" = "costMicroUsd" + ${cost.costMicroUsd},
          "updatedAt" = NOW()
      WHERE "userId" = ${userId} AND "day" = ${day}::date`;
  }

  async questionsOn(userId: string, day: string): Promise<number> {
    const [row] = await this.prisma.$queryRaw<Array<{ requests: number }>>`
      SELECT "requests" FROM "AssistantUsageDay"
      WHERE "userId" = ${userId} AND "day" = ${day}::date`;
    return row?.requests ?? 0;
  }

  async spentSince(since: string): Promise<bigint> {
    const [row] = await this.prisma.$queryRaw<Array<{ spent: bigint | null }>>`
      SELECT SUM("costMicroUsd")::bigint AS "spent"
      FROM "AssistantUsageDay"
      WHERE "day" >= ${since}::date`;
    return row?.spent ?? 0n;
  }
}
