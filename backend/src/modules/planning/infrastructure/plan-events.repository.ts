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
  mapUrl: true,
  address: true,
  responsibleName: true,
  note: true,
  version: true,
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
  mapUrl: string | null;
  address: string | null;
  responsibleName: string | null;
  note: string | null;
}

/**
 * D116: what a guest was told of an occasion: its day, its time, its place
 * and its map link. A change to any of them raises the row's version.
 */
export function changesWhatGuestsWereTold(
  current: Pick<PlanEventRow, 'date' | 'timeSlot' | 'exactTime' | 'placeLabel' | 'mapUrl'>,
  next: Pick<PlanEventWrite, 'date' | 'timeSlot' | 'exactTime' | 'placeLabel' | 'mapUrl'>,
): boolean {
  const day = (value: Date | null) => (value ? value.toISOString().slice(0, 10) : null);
  return (
    day(current.date) !== day(next.date) ||
    current.timeSlot !== next.timeSlot ||
    (current.exactTime ?? null) !== (next.exactTime ?? null) ||
    (current.placeLabel ?? null) !== (next.placeLabel ?? null) ||
    (current.mapUrl ?? null) !== (next.mapUrl ?? null)
  );
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
  options: { raiseVersion?: boolean } = {},
): Promise<PlanEventRow> {
  return tx.planEvent.update({
    where: { id: eventId },
    data: options.raiseVersion ? { ...data, version: { increment: 1 } } : data,
    select: planEventSelect,
  });
}

/**
 * D116: the plan's wedding row, made if a plan from before it has none
 * (every plan gets one when it is made, and the migration gave one to the
 * plans before). Its id is fixed by the plan's, so two makers agree.
 */
export async function ensureWeddingEventRow(
  tx: Client,
  weddingPlanId: string,
): Promise<void> {
  await tx.$executeRaw`
    INSERT INTO "PlanEvent" ("id", "weddingPlanId", "type", "createdAt", "updatedAt")
    VALUES (${`wedding_${weddingPlanId}`}, ${weddingPlanId}, 'WEDDING', NOW(), NOW())
    ON CONFLICT DO NOTHING`;
}

/** D116: the wedding's day moved (it is the plan's): its row's version rises. */
export async function raiseWeddingEventVersion(
  tx: Client,
  weddingPlanId: string,
): Promise<void> {
  await ensureWeddingEventRow(tx, weddingPlanId);
  await tx.$executeRaw`
    UPDATE "PlanEvent"
    SET "version" = "version" + 1, "updatedAt" = NOW()
    WHERE "weddingPlanId" = ${weddingPlanId} AND "type" = 'WEDDING'`;
}

export async function deletePlanEventRow(tx: Client, eventId: string): Promise<void> {
  await tx.planEvent.delete({ where: { id: eventId } });
}

/**
 * RA-BE-72: the wedding moved by [days]; its dated events (السمرة، الغداء،
 * the day itself) move with it, as its tasks do. Returns how many moved.
 * D116: a moved event's guests hold the old day, so its version rises.
 * RA-BE-182 (Q-46): only the events from [fromDay] (today in Sana'a,
 * `YYYY-MM-DD`) on; one already past (the contract signed in March) stays
 * on its day.
 */
export function shiftPlanEventDates(
  tx: Client,
  weddingPlanId: string,
  days: number,
  fromDay: string,
): Promise<number> {
  return tx.$executeRaw`
    UPDATE "PlanEvent"
    SET "date" = "date" + ${days}::int, "version" = "version" + 1, "updatedAt" = NOW()
    WHERE "weddingPlanId" = ${weddingPlanId} AND "date" >= ${fromDay}::date`;
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
