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
}
