import { ContributionAction, ContributionEntityType, Prisma } from '@prisma/client';
import type { QualifyingContributionRule } from '../public/collaboration-scope.port';

// RA-BE-176: a living actor's contributions are found by the tenures' link
// to the account, which covers the tenures written before the keyed
// reference as well as those after.

export function findPlanContributorEvents(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
  actorUserId: string,
  entityTypes: readonly ContributionEntityType[],
  actions: readonly ContributionAction[],
) {
  return tx.contributionEvent.findMany({
    where: {
      historyScope: { weddingPlanId },
      contributorTenure: { actorUserId },
      entityType: { in: [...entityTypes] },
      action: { in: [...actions] },
      entityId: { not: null },
    },
    select: { entityId: true },
    distinct: ['entityId'],
  });
}

export function findQualifyingContributorEvents(
  tx: Prisma.TransactionClient,
  weddingPlanIds: readonly string[],
  actorUserIds: readonly string[],
  rules: readonly QualifyingContributionRule[],
) {
  return tx.contributionEvent.findMany({
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
}

export function findActorContributorEvents(
  tx: Prisma.TransactionClient,
  actorUserId: string,
  entityTypes: readonly ContributionEntityType[],
  actions: readonly ContributionAction[],
  entityId?: string,
) {
  return tx.contributionEvent.findMany({
    where: {
      contributorTenure: { actorUserId },
      entityType: { in: [...entityTypes] },
      action: { in: [...actions] },
      entityId: entityId ? entityId : { not: null },
    },
    select: { entityId: true },
    distinct: ['entityId'],
  });
}
