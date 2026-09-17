import type {
  ContributionAction,
  ContributionEntityType,
  Prisma,
} from '@prisma/client';

export const COLLABORATION_SCOPE_PORT = Symbol('COLLABORATION_SCOPE_PORT');

/** One entity type with the actions that make a contribution qualify. */
export interface QualifyingContributionRule {
  entityType: ContributionEntityType;
  actions: readonly ContributionAction[];
}

/** A qualifying contribution: the entity, its plan and the live actor (a detached tenure names no actor). */
export interface QualifyingContribution {
  entityId: string;
  entityType: ContributionEntityType;
  weddingPlanId: string;
  actorUserId: string;
}

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
  /**
   * The qualifying contributions of the given live actors in the given
   * plans, one row per (entity, actor); notifications derive who is told
   * about a task or a payment from them.
   */
  listQualifyingContributionsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    actorUserIds: readonly string[],
    rules: readonly QualifyingContributionRule[],
  ): Promise<QualifyingContribution[]>;
  /** The actor's qualifying entity ids across every plan (a user's own quote list spans plans). */
  qualifyingEntityIdsForActorInTransaction(
    tx: Prisma.TransactionClient,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions: readonly ContributionAction[],
    entityId?: string,
  ): Promise<string[]>;
}
