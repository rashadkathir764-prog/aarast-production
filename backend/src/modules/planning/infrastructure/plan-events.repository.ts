import { Prisma, type PlanEventTimeSlot, type PlanEventType } from '@prisma/client';

// Planning-owned rows of the wedding's events (D65).

type Client = Prisma.TransactionClient;

const planEventSelect = {
  id: true,
  weddingPlanId: true,
  type: true,
  title: true,
  date: true,
  timeSlot: true,
  exactTime: true,
  placeLabel: true,
  responsibleName: true,
  note: true,
  updatedAt: true,
} satisfies Prisma.PlanEventSelect;

export type PlanEventRow = Prisma.PlanEventGetPayload<{
  select: typeof planEventSelect;
}>;

export interface PlanEventWrite {
  title: string | null;
  date: Date | null;
  timeSlot: PlanEventTimeSlot | null;
  exactTime: string | null;
  placeLabel: string | null;
  responsibleName: string | null;
  note: string | null;
}

export function listPlanEventRows(
  client: Client,
  weddingPlanId: string,
): Promise<PlanEventRow[]> {
  return client.planEvent.findMany({
    where: { weddingPlanId },
    select: planEventSelect,
    orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
  });
}

export function findPlanEventRow(
  client: Client,
  weddingPlanId: string,
  eventId: string,
): Promise<PlanEventRow | null> {
  return client.planEvent.findFirst({
    where: { id: eventId, weddingPlanId },
    select: planEventSelect,
  });
}

export function countPlanEventRows(
  client: Client,
  weddingPlanId: string,
): Promise<number> {
  return client.planEvent.count({ where: { weddingPlanId } });
}

export function createPlanEventRow(
  tx: Client,
  weddingPlanId: string,
  type: PlanEventType,
  data: PlanEventWrite,
): Promise<PlanEventRow> {
  return tx.planEvent.create({
    data: { weddingPlanId, type, ...data },
    select: planEventSelect,
  });
}

export function updatePlanEventRow(
  tx: Client,
  eventId: string,
  data: PlanEventWrite,
): Promise<PlanEventRow> {
  return tx.planEvent.update({
    where: { id: eventId },
    data,
    select: planEventSelect,
  });
}

export async function deletePlanEventRow(tx: Client, eventId: string): Promise<void> {
  await tx.planEvent.delete({ where: { id: eventId } });
}

/**
 * RA-BE-72: the wedding moved by [days]; its dated events (السمرة، الغداء،
 * the day itself) move with it, as its tasks do. Returns how many moved.
 */
export function shiftPlanEventDates(
  tx: Client,
  weddingPlanId: string,
  days: number,
): Promise<number> {
  return tx.$executeRaw`
    UPDATE "PlanEvent"
    SET "date" = "date" + ${days}::int, "updatedAt" = NOW()
    WHERE "weddingPlanId" = ${weddingPlanId} AND "date" IS NOT NULL`;
}

/** Account erasure: the erased plans' events go before the plans. */
export async function deletePlanEventRowsOfPlans(
  tx: Client,
  weddingPlanIds: readonly string[],
): Promise<void> {
  if (weddingPlanIds.length === 0) return;
  await tx.planEvent.deleteMany({
    where: { weddingPlanId: { in: [...weddingPlanIds] } },
  });
}

export function isUniqueViolation(error: unknown): boolean {
  return (
    error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002'
  );
}
