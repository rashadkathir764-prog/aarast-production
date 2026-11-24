import {
  ContributionAction,
  ContributionEntityType,
  ContributionProvenance,
  ContributionScopeStatus,
  ContributionSection,
  Prisma,
  SharedMember,
  WeddingPlan,
} from '@prisma/client';
import type { RecordContributionInput } from '../public/collaboration-history.port';
import type { LiveAuthorizationFilter } from '../public/collaboration-permission.port';
import type { ListContributionsDto } from '../api/dto/list-contributions.dto';
import { PrismaService } from '../../../platform/database/prisma.service';

type Client = Prisma.TransactionClient;

// RA-BE-39: the `section` filter. The sections a reader may not see are left
// out, the one they asked for included (it then matches nothing). Only the
// field's value is computed, so the query shape stays literal for the
// ownership scan.
function sectionFilter(
  requested: ContributionSection | undefined,
  hidden: readonly ContributionSection[],
): ContributionSection | Prisma.EnumContributionSectionFilter | undefined {
  if (requested) {
    return hidden.includes(requested) ? { in: [] } : requested;
  }
  return hidden.length > 0 ? { notIn: [...hidden] } : undefined;
}

/**
 * RA-BE-176: one contributor's history: the tenures still linked to the
 * account, and those of an erased account, which keep only its keyed
 * reference.
 */
export interface HistoryContributor {
  userId: string;
  reference: string;
}

export class ContributionHistoryRepository {
  getHistoryScopeId(tx: Client, weddingPlanId: string) {
    return tx.contributorHistoryScope.findUnique({
      where: { weddingPlanId },
      select: { id: true },
    });
  }

  // RA-BE-176: a living actor's tenure is found by its link to the account;
  // tenures written before the keyed reference keep their old reference.
  findActiveTenureId(tx: Client, historyScopeId: string, actorUserId: string) {
    return tx.contributorTenure.findFirst({
      where: { historyScopeId, actorUserId, endedAt: null },
      select: { id: true, actorReference: true },
    });
  }

  insertContributionEvent(
    tx: Client,
    input: RecordContributionInput,
    historyScopeId: string,
    contributorTenureId: string,
    snapshotHash: string,
    eventFingerprint: string,
    defaultPolicyVersion: number,
  ) {
    return tx.contributionEvent.createManyAndReturn({
      data: [{
        historyScopeId,
        contributorTenureId,
        section: input.section,
        entityType: input.entityType,
        entityId: input.entityId ?? null,
        action: input.action,
        snapshot: input.snapshot,
        snapshotHash,
        snapshotVersion: 1,
        dedupeKey: input.dedupeKey,
        eventFingerprint,
        provenance: input.provenance ?? ContributionProvenance.RUNTIME,
        requiredPermission: input.requiredPermission ?? null,
        permissionPolicyVersion: input.permissionPolicyVersion ?? defaultPolicyVersion,
        authorityVersion: input.authorityVersion,
        occurredAt: input.occurredAt ?? null,
      }],
      skipDuplicates: true,
    });
  }

  findContributionByDedupeKey(tx: Client, contributorTenureId: string, dedupeKey: string) {
    return tx.contributionEvent.findUnique({
      where: { contributorTenureId_dedupeKey: { contributorTenureId, dedupeKey } },
    });
  }

  createHistoryScope(tx: Client, plan: Pick<WeddingPlan, 'id' | 'createdAt'>) {
    return tx.contributorHistoryScope.create({
      data: {
        weddingPlanId: plan.id,
        status: ContributionScopeStatus.ACTIVE,
        historyCoverageStartsAt: plan.createdAt,
      },
    });
  }

  archiveHistoryScope(tx: Client, plan: Pick<WeddingPlan, 'id' | 'updatedAt'>) {
    return tx.contributorHistoryScope.upsert({
      where: { weddingPlanId: plan.id },
      create: {
        weddingPlanId: plan.id,
        status: ContributionScopeStatus.ARCHIVED,
        archivedAt: plan.updatedAt,
        historyCoverageStartsAt: plan.updatedAt,
      },
      update: {
        status: ContributionScopeStatus.ARCHIVED,
        archivedAt: plan.updatedAt,
      },
    });
  }

  ensureHistoryScope(tx: Client, weddingPlanId: string) {
    return tx.contributorHistoryScope.upsert({
      where: { weddingPlanId },
      create: { weddingPlanId, historyCoverageStartsAt: new Date() },
      update: {},
    });
  }

  findOpenTenure(tx: Client, historyScopeId: string, actorUserId: string) {
    return tx.contributorTenure.findFirst({
      where: { historyScopeId, actorUserId, endedAt: null },
    });
  }

  createTenure(tx: Client, historyScopeId: string, actorReference: string, member: SharedMember) {
    return tx.contributorTenure.create({
      data: {
        historyScopeId,
        actorUserId: member.userId,
        actorReference,
        sharedMemberId: member.id,
        joinedAt: member.createdAt,
        trackingStartedAt: new Date(),
        roleAtTrackingStart: member.role,
      },
    });
  }

  closeTenure(
    tx: Client,
    tenureId: string,
    endedAt: Date,
    reason: 'MEMBER_LEFT' | 'MEMBER_REMOVED' | 'ACCOUNT_DELETED' | 'PLAN_DELETED',
    roleAtEnd: SharedMember['role'] | null,
  ) {
    return tx.contributorTenure.update({
      where: { id: tenureId },
      data: { endedAt, endReason: reason, roleAtEnd, sharedMemberId: null },
    });
  }

  qualifyingEntityIds(
    client: PrismaService,
    weddingPlanId: string,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions: readonly ContributionAction[],
  ) {
    return client.contributionEvent.findMany({
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

  findVisibleHistoryScope(tx: Client, weddingPlanId: string, liveFilter: LiveAuthorizationFilter) {
    return tx.contributorHistoryScope.findFirst({
      where: {
        weddingPlanId,
        ...(liveFilter.id ? { id: { in: liveFilter.id.in } } : {}),
      },
    });
  }

  listPageEvents(
    tx: Client,
    historyScopeId: string,
    contributor: HistoryContributor | undefined,
    query: Partial<ListContributionsDto>,
    liveFilter: LiveAuthorizationFilter,
    hiddenSections: readonly ContributionSection[] = [],
  ) {
    const section = sectionFilter(query.section, hiddenSections);
    const where = {
      historyScope: { id: historyScopeId },
      ...(contributor
        ? {
            contributorTenure: {
              OR: [
                { actorUserId: contributor.userId },
                { actorReference: contributor.reference },
              ],
            },
          }
        : {}),
      ...(section !== undefined ? { section } : {}),
      ...(liveFilter.id ? { id: { in: liveFilter.id.in } } : {}),
    } satisfies Prisma.ContributionEventWhereInput;
    return Promise.all([
      tx.contributionEvent.findMany({
        where,
        orderBy: [{ capturedAt: 'desc' }, { id: 'desc' }],
        take: query.limit ?? 50,
        skip: query.offset ?? 0,
        include: { contributorTenure: { select: { actorReference: true } } },
      }),
      tx.contributionEvent.count({ where }),
    ]);
  }

  summaryEvents(
    tx: Client,
    weddingPlanId: string,
    contributor: HistoryContributor | undefined,
    liveFilter: LiveAuthorizationFilter,
    hiddenSections: readonly ContributionSection[] = [],
  ) {
    const section = sectionFilter(undefined, hiddenSections);
    return tx.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId },
        ...(contributor
          ? {
              contributorTenure: {
                OR: [
                  { actorUserId: contributor.userId },
                  { actorReference: contributor.reference },
                ],
              },
            }
          : {}),
        ...(section !== undefined ? { section } : {}),
        entityId: { not: null },
        ...(liveFilter.id ? { id: { in: liveFilter.id.in } } : {}),
      },
      select: { section: true, entityId: true },
    });
  }

  getHistoryMember(client: Client | PrismaService, weddingPlanId: string, userId: string) {
    return client.sharedMember.findUnique({
      where: { weddingPlanId_userId: { weddingPlanId, userId } },
    });
  }
}
