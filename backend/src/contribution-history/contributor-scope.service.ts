import { Injectable } from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  Prisma,
} from "@prisma/client";
import {
  ContributionHistoryService,
  contributorActorReference,
} from "./contribution-history.service";

@Injectable()
export class ContributorScopeService {
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
}
