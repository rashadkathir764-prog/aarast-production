import { Injectable } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  Prisma,
} from "@prisma/client";
import {
  CollaborationScopePort,
  type QualifyingContribution,
  type QualifyingContributionRule,
} from "../public/collaboration-scope.port";
import {
  ContributionHistoryService,
  contributorActorReference,
} from "./contribution-history.service";
import {
  findActorContributorEvents,
  findPlanContributorEvents,
  findQualifyingContributorEvents,
} from '../infrastructure/contributor-scope.repository';

@Injectable()
export class ContributorScopeService implements CollaborationScopePort {
  constructor(private readonly history: ContributionHistoryService) {}

  qualifyingEntityIds(
    weddingPlanId: string,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions?: readonly ContributionAction[],
  ): Promise<string[]> {
    return this.history.qualifyingEntityIds(
      weddingPlanId,
      actorUserId,
      entityTypes,
      actions,
    );
  }

  async qualifyingEntityIdsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions: readonly ContributionAction[] = [
      ContributionAction.CREATED,
      ContributionAction.COMPLETED,
      ContributionAction.PAYMENT_RECORDED,
    ],
  ): Promise<string[]> {
    const events = await findPlanContributorEvents(
      tx,
      weddingPlanId,
      contributorActorReference(actorUserId),
      entityTypes,
      actions,
    );
    return events.flatMap((event) =>
      event.entityId ? [event.entityId] : [],
    );
  }

  async listQualifyingContributionsInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
    actorUserIds: readonly string[],
    rules: readonly QualifyingContributionRule[],
  ): Promise<QualifyingContribution[]> {
    if (weddingPlanIds.length === 0 || actorUserIds.length === 0 || rules.length === 0) {
      return [];
    }
    const events = await findQualifyingContributorEvents(
      tx,
      weddingPlanIds,
      actorUserIds,
      rules,
    );
    return events.flatMap((event) =>
      event.entityId &&
      event.historyScope.weddingPlanId &&
      event.contributorTenure.actorUserId
        ? [
            {
              entityId: event.entityId,
              entityType: event.entityType,
              weddingPlanId: event.historyScope.weddingPlanId,
              actorUserId: event.contributorTenure.actorUserId,
            },
          ]
        : [],
    );
  }

  async qualifyingEntityIdsForActorInTransaction(
    tx: Prisma.TransactionClient,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions: readonly ContributionAction[],
    entityId?: string,
  ): Promise<string[]> {
    const events = await findActorContributorEvents(
      tx,
      contributorActorReference(actorUserId),
      entityTypes,
      actions,
      entityId,
    );
    return events.flatMap((event) =>
      event.entityId ? [event.entityId] : [],
    );
  }
}
