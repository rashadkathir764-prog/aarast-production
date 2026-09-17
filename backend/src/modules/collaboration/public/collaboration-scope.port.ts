import type {
  ContributionAction,
  ContributionEntityType,
  Prisma,
} from '@prisma/client';

export const COLLABORATION_SCOPE_PORT = Symbol('COLLABORATION_SCOPE_PORT');

export interface CollaborationScopePort {
  qualifyingEntityIds(
    weddingPlanId: string,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions?: readonly ContributionAction[],
  ): Promise<string[]>;
  qualifyingEntityIdsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions?: readonly ContributionAction[],
  ): Promise<string[]>;
  /** The actor's qualifying entity ids across every plan (a user's own quote list spans plans). */
  qualifyingEntityIdsForActorInTransaction(
    tx: Prisma.TransactionClient,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions: readonly ContributionAction[],
    entityId?: string,
  ): Promise<string[]>;
}
