import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { PlanErasurePort } from '../public/plan-erasure.port';

@Injectable()
export class PlanErasureService implements PlanErasurePort {
  async lockOwnedPlanIdsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    ownerUserId: string,
  ): Promise<string[]> {
    const ownedPlans = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingPlan"
        WHERE "ownerUserId" = ${ownerUserId}
        ORDER BY "id" ASC
        FOR UPDATE
      `,
    );
    return ownedPlans.map((plan) => plan.id);
  }

  async deletePlansInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    if (weddingPlanIds.length === 0) return;
    await tx.weddingPlan.deleteMany({
      where: { id: { in: [...weddingPlanIds] } },
    });
  }
}
