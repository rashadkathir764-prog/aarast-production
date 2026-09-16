import type { Prisma } from '@prisma/client';

export const COLLABORATION_ERASURE_PORT = Symbol('COLLABORATION_ERASURE_PORT');

// The collaboration steps of account erasure, run by collaboration on the
// saga's transaction at the point the saga reaches them.
export interface CollaborationErasurePort {
  /**
   * Contribution history is retained independently from the live plan:
   * closes every active tenure of the plans (PLAN_DELETED) and marks their
   * history scopes DELETED at `at`.
   */
  markPlansDeletedInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    at: Date,
  ): Promise<void>;
  /** Closes the account's own active tenures (ACCOUNT_DELETED) at `at`. */
  closeActorTenuresInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    at: Date,
  ): Promise<void>;
  /** Deletes the plans' members, then their invitations. */
  deletePlanMembersAndInvitesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  /** The explicit equivalents of the User cascades/SetNulls for a retained administrator identity. */
  detachUserInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<void>;
}
