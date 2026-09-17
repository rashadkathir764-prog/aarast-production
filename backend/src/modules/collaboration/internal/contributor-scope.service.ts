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
    const events = await tx.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId },
        contributorTenure: {
          actorReference: contributorActorReference(actorUserId),
        },
        entityType: { in: [...entityTypes] },
        action: { in: [...actions] },
        entityId: { not: null },
      },
      select: { entityId: true },
      distinct: ["entityId"],
    });
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
    const events = await tx.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId: { in: [...weddingPlanIds] } },
        contributorTenure: { actorUserId: { in: [...actorUserIds] } },
        entityId: { not: null },
        OR: rules.map((rule) => ({
          entityType: rule.entityType,
          action: { in: [...rule.actions] },
        })),
      },
      select: {
        entityId: true,
        entityType: true,
        historyScope: { select: { weddingPlanId: true } },
        contributorTenure: { select: { actorUserId: true } },
      },
    });
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
    const events = await tx.contributionEvent.findMany({
      where: {
        contributorTenure: {
          actorReference: contributorActorReference(actorUserId),
        },
        entityType: { in: [...entityTypes] },
        action: { in: [...actions] },
        entityId: entityId ? entityId : { not: null },
      },
      select: { entityId: true },
      distinct: ["entityId"],
    });
    return events.flatMap((event) =>
      event.entityId ? [event.entityId] : [],
    );
  }
}
