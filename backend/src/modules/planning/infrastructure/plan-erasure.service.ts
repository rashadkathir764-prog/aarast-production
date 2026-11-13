import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { PlanErasurePort } from '../public/plan-erasure.port';
import { deletePlanEventRowsOfPlans } from './plan-events.repository';

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
    // The plan's own children (its events, D65) go with it.
    await deletePlanEventRowsOfPlans(tx, weddingPlanIds);
    await tx.weddingPlan.deleteMany({
      where: { id: { in: [...weddingPlanIds] } },
    });
  }

  async listPlanOwnersInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<Array<{ weddingPlanId: string; ownerUserId: string }>> {
    if (weddingPlanIds.length === 0) return [];
    const plans = await tx.weddingPlan.findMany({
      where: { id: { in: [...weddingPlanIds] } },
      orderBy: { id: 'asc' },
      select: { id: true, ownerUserId: true },
    });
    return plans.map((plan) => ({
      weddingPlanId: plan.id,
      ownerUserId: plan.ownerUserId,
    }));
  }
}
