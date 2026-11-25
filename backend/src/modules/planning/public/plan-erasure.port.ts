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
  /**
   * Q-45 (D124): the plans whose owner asked to delete them and whose 30
   * days are over at `now`, the oldest due first, at most `take`.
   */
  listDuePlanDeletions(
    client: Prisma.TransactionClient,
    now: Date,
    take: number,
  ): Promise<Array<{ id: string; ownerUserId: string }>>;
  /**
   * Q-45 (D124): locks (`FOR UPDATE`) a plan still due for deletion at
   * `now`; false when it is gone or was taken back.
   */
  lockDuePlanForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    now: Date,
  ): Promise<boolean>;
  /**
   * RA-OP-32: the erasure of a plan writes its id on a re-deletion list (a
   * restored backup erases it again); ids older than 120 days, past the
   * oldest backup, leave it. The number removed.
   */
  removeOldErasedPlans(
    client: Prisma.TransactionClient,
    now: Date,
  ): Promise<number>;
}
