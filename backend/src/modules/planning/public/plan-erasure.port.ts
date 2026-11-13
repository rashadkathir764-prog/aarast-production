import type { Prisma } from '@prisma/client';

export const PLAN_ERASURE_PORT = Symbol('PLAN_ERASURE_PORT');

// Account erasure (identity's saga) locks the plans the account owns before
// any child row is purged and deletes them last; planning runs both steps
// on the saga's transaction, in the saga's order.
export interface PlanErasurePort {
  /** `SELECT id FROM WeddingPlan WHERE ownerUserId = ? ORDER BY id FOR UPDATE` — the ids, locked. */
  lockOwnedPlanIdsForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    ownerUserId: string,
  ): Promise<string[]>;
  deletePlansInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  /**
   * D112 (Q-22): who owns each of these plans. What an erased account
   * recorded in another person's plan stays in it, and passes to that
   * plan's owner; a plan that no longer exists is not returned.
   */
  listPlanOwnersInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<Array<{ weddingPlanId: string; ownerUserId: string }>>;
}
