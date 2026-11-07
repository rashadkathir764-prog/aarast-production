import { Injectable } from '@nestjs/common';
import { Prisma, type WeddingPlan, WeddingPlanStatus } from '@prisma/client';
import type {
  LockedWeddingPlanRow,
  PlanReadPort,
  ReadablePlanEvent,
} from '../public/plan-read.port';

@Injectable()
export class PlanReadService implements PlanReadPort {
  async lockPlanRowForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<LockedWeddingPlanRow[]> {
    return tx.$queryRaw<LockedWeddingPlanRow[]>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingPlan"
        WHERE "id" = ${weddingPlanId}
        FOR SHARE
      `,
    );
  }

  async lockPlanRowForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<LockedWeddingPlanRow[]> {
    return tx.$queryRaw<LockedWeddingPlanRow[]>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingPlan"
        WHERE "id" = ${weddingPlanId}
        FOR UPDATE
      `,
    );
  }

  async getPlan(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<WeddingPlan | null> {
    return client.weddingPlan.findUnique({ where: { id: weddingPlanId } });
  }

  async getPlans(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<WeddingPlan[]> {
    if (weddingPlanIds.length === 0) return [];
    return client.weddingPlan.findMany({
      where: { id: { in: [...weddingPlanIds] } },
    });
  }

  async findOwnedPlan(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    ownerUserId: string,
  ): Promise<WeddingPlan | null> {
    return client.weddingPlan.findFirst({
      where: { id: weddingPlanId, ownerUserId },
    });
  }

  async listOwnedPlans(
    client: Prisma.TransactionClient,
    ownerUserId: string,
  ): Promise<WeddingPlan[]> {
    return client.weddingPlan.findMany({ where: { ownerUserId } });
  }

  async listPlansInStatus(
    client: Prisma.TransactionClient,
    status: WeddingPlanStatus | readonly WeddingPlanStatus[],
  ): Promise<WeddingPlan[]> {
    return client.weddingPlan.findMany({
      where: { status: Array.isArray(status) ? { in: [...status] } : (status as WeddingPlanStatus) },
    });
  }

  async lockPlanRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<LockedWeddingPlanRow[]> {
    const sortedIds = [...new Set(weddingPlanIds)].sort();
    if (sortedIds.length === 0) return [];
    return tx.$queryRaw<LockedWeddingPlanRow[]>(
      Prisma.sql`
        SELECT "id"
        FROM "WeddingPlan"
        WHERE "id" = ANY(${sortedIds}::text[])
        ORDER BY "id" ASC
        FOR SHARE
      `,
    );
  }

  async listOwnedPlanIds(
    client: Prisma.TransactionClient,
    ownerUserId: string,
  ): Promise<string[]> {
    const plans = await client.weddingPlan.findMany({
      where: { ownerUserId },
      select: { id: true },
    });
    return plans.map((plan) => plan.id);
  }

  async countPlans(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<number> {
    return createdAt
      ? client.weddingPlan.count({ where: { createdAt } })
      : client.weddingPlan.count();
  }

  async listPlanEvents(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<ReadablePlanEvent[]> {
    return client.planEvent.findMany({
      where: { weddingPlanId },
      select: {
        id: true,
        weddingPlanId: true,
        type: true,
        title: true,
        date: true,
        timeSlot: true,
        exactTime: true,
        placeLabel: true,
      },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });
  }
}
