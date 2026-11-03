import type {
  PlanEvent,
  Prisma,
  WeddingPlan,
  WeddingPlanStatus,
} from '@prisma/client';

export const PLAN_READ_PORT = Symbol('PLAN_READ_PORT');

export interface LockedWeddingPlanRow {
  id: string;
}

/** One of the plan's events (D65) as other contexts read it (D83: guests). */
export type ReadablePlanEvent = Pick<
  PlanEvent,
  | 'id'
  | 'weddingPlanId'
  | 'type'
  | 'title'
  | 'date'
  | 'timeSlot'
  | 'exactTime'
  | 'placeLabel'
>;

// Planning owns `WeddingPlan`. Every other context reads a plan row through
// this port instead of querying the table; the caller passes the client it
// is working with (its transaction, or the shared Prisma service) so the
// read participates in the caller's snapshot and lock scope exactly as the
// direct query did. The two lock methods are the plan lifecycle lock other
// contexts take before their plan-scoped writes (a concurrent archive or
// deletion either commits first and is observed, or waits); the statements
// are the ones the callers executed themselves.
export interface PlanReadPort {
  lockPlanRowForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<LockedWeddingPlanRow[]>;
  lockPlanRowForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<LockedWeddingPlanRow[]>;
  getPlan(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<WeddingPlan | null>;
  getPlans(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<WeddingPlan[]>;
  findOwnedPlan(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    ownerUserId: string,
  ): Promise<WeddingPlan | null>;
  listOwnedPlans(
    client: Prisma.TransactionClient,
    ownerUserId: string,
  ): Promise<WeddingPlan[]>;
  listOwnedPlanIds(
    client: Prisma.TransactionClient,
    ownerUserId: string,
  ): Promise<string[]>;
  /** The owner's current planning plan: the earliest wedding date, newest first among equals (the home dashboard). */
  findCurrentPlanningPlan(
    client: Prisma.TransactionClient,
    ownerUserId: string,
  ): Promise<WeddingPlan | null>;
  /** Every plan in the status (the reminder scan walks the planning plans). */
  listPlansInStatus(
    client: Prisma.TransactionClient,
    status: WeddingPlanStatus | readonly WeddingPlanStatus[],
  ): Promise<WeddingPlan[]>;
  /** Locks the plan rows for share in id order. */
  lockPlanRowsForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<LockedWeddingPlanRow[]>;
  /** Plans created in the window (the back-office counters); every plan without one. */
  countPlans(
    client: Prisma.TransactionClient,
    createdAt?: { gte?: Date; lte?: Date },
  ): Promise<number>;
  /** D83: the plan's events in creation order (the wedding row among them when saved). */
  listPlanEvents(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
  ): Promise<ReadablePlanEvent[]>;
}
