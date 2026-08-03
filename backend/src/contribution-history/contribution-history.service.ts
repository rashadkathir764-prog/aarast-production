import { createHash } from "node:crypto";
import {
  ConflictException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionEvent,
  ContributionPermission,
  ContributionProvenance,
  ContributionSection,
  ContributorTenure,
  Prisma,
  SharedMember,
} from "@prisma/client";
import { AuthenticatedUser } from "../auth/authenticated-user.interface";
import { runRetryableTransaction } from "../common/prisma/serializable-transaction";
import { PrismaService } from "../prisma/prisma.service";
import {
  livePlanAuthorizationWhere,
  PlanAccessContext,
} from "../sharing/permission.service";
import {
  canonicalJson,
  hashContributionSnapshot,
  validateContributionSnapshot,
} from "./contribution-snapshot.builder";
import {
  ContributionHistoryPageResponse,
  ContributionHistorySummaryResponse,
} from "./contribution-history.contracts";
import { ListContributionsDto } from "./dto/list-contributions.dto";

const PERMISSION_POLICY_VERSION = 1;

export interface RecordContributionInput {
  weddingPlanId: string;
  actorUserId: string;
  section: ContributionSection;
  entityType: ContributionEntityType;
  entityId?: string | null;
  action: ContributionAction;
  snapshot: Prisma.JsonObject;
  dedupeKey: string;
  provenance?: ContributionProvenance;
  requiredPermission?: ContributionPermission | null;
  permissionPolicyVersion?: number;
  authorityVersion: number;
  occurredAt?: Date | null;
}

@Injectable()
export class ContributionHistoryService {
  constructor(private readonly prisma: PrismaService) {}

  async recordInTransaction(
    tx: Prisma.TransactionClient,
    input: RecordContributionInput,
  ): Promise<ContributionEvent> {
    validateContributionSnapshot(input.snapshot);
    const snapshotHash = hashContributionSnapshot(input.snapshot);
    const scope = await tx.contributorHistoryScope.findUnique({
      where: { weddingPlanId: input.weddingPlanId },
      select: { id: true },
    });
    if (!scope) throw new NotFoundException("Contribution history scope not found");

    const actorReference = contributorActorReference(input.actorUserId);
    const tenure = await tx.contributorTenure.findFirst({
      where: {
        historyScopeId: scope.id,
        actorReference,
        endedAt: null,
      },
      select: { id: true, actorReference: true },
    });
    if (!tenure) throw new NotFoundException("Active contributor tenure not found");

    const fingerprint = contributionFingerprint(
      input,
      snapshotHash,
      tenure.id,
      tenure.actorReference,
    );
    const inserted = await tx.contributionEvent.createManyAndReturn({
      data: [{
        historyScopeId: scope.id,
        contributorTenureId: tenure.id,
        section: input.section,
        entityType: input.entityType,
        entityId: input.entityId ?? null,
        action: input.action,
        snapshot: input.snapshot,
        snapshotHash,
        snapshotVersion: 1,
        dedupeKey: input.dedupeKey,
        eventFingerprint: fingerprint,
        provenance: input.provenance ?? ContributionProvenance.RUNTIME,
        requiredPermission: input.requiredPermission ?? null,
        permissionPolicyVersion:
          input.permissionPolicyVersion ?? PERMISSION_POLICY_VERSION,
        authorityVersion: input.authorityVersion,
        occurredAt: input.occurredAt ?? null,
      }],
      skipDuplicates: true,
    });
    const event = inserted[0] ?? await tx.contributionEvent.findUnique({
      where: {
        contributorTenureId_dedupeKey: {
          contributorTenureId: tenure.id,
          dedupeKey: input.dedupeKey,
        },
      },
    });
    if (!event) {
      throw new ConflictException("Contribution dedupe result missing");
    }
    if (!sameContribution(event, snapshotHash, fingerprint, tenure.id)) {
      throw new ConflictException("Contribution dedupe key conflict");
    }
    return event;
  }

  async recordForContextInTransaction(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    input: Omit<RecordContributionInput, "weddingPlanId" | "actorUserId" | "authorityVersion">,
  ): Promise<ContributionEvent | null> {
    if (context.isOwner || !context.sharedMember) return null;
    await this.ensureTenureInTransaction(tx, context.sharedMember);
    return this.recordInTransaction(tx, {
      ...input,
      weddingPlanId: context.plan.id,
      actorUserId: context.sharedMember.userId,
      authorityVersion: context.sharedMember.authorityVersion,
    });
  }

  async ensureTenureInTransaction(
    tx: Prisma.TransactionClient,
    member: SharedMember,
  ): Promise<ContributorTenure> {
    const scope = await tx.contributorHistoryScope.upsert({
      where: { weddingPlanId: member.weddingPlanId },
      create: {
        weddingPlanId: member.weddingPlanId,
        historyCoverageStartsAt: new Date(),
      },
      update: {},
    });
    const actorReference = contributorActorReference(member.userId);
    const existing = await tx.contributorTenure.findFirst({
      where: {
        historyScopeId: scope.id,
        actorReference,
        endedAt: null,
      },
    });
    if (existing) return existing;
    return tx.contributorTenure.create({
      data: {
        historyScopeId: scope.id,
        actorUserId: member.userId,
        actorReference,
        sharedMemberId: member.id,
        joinedAt: member.createdAt,
        trackingStartedAt: new Date(),
        roleAtTrackingStart: member.role,
      },
    });
  }

  async closeTenureInTransaction(
    tx: Prisma.TransactionClient,
    input: {
      weddingPlanId: string;
      actorUserId: string;
      reason: "MEMBER_LEFT" | "MEMBER_REMOVED" | "ACCOUNT_DELETED" | "PLAN_DELETED";
      roleAtEnd?: SharedMember["role"] | null;
      endedAt?: Date;
    },
  ): Promise<ContributorTenure | null> {
    const scope = await tx.contributorHistoryScope.findUnique({
      where: { weddingPlanId: input.weddingPlanId },
      select: { id: true },
    });
    if (!scope) return null;
    const tenure = await tx.contributorTenure.findFirst({
      where: {
        historyScopeId: scope.id,
        actorReference: contributorActorReference(input.actorUserId),
        endedAt: null,
      },
    });
    if (!tenure) return null;
    return tx.contributorTenure.update({
      where: { id: tenure.id },
      data: {
        endedAt: input.endedAt ?? new Date(),
        endReason: input.reason,
        roleAtEnd: input.roleAtEnd ?? null,
        sharedMemberId: null,
      },
    });
  }

  async qualifyingEntityIds(
    weddingPlanId: string,
    actorUserId: string,
    entityTypes: readonly ContributionEntityType[],
    actions: readonly ContributionAction[] = [
      ContributionAction.CREATED,
      ContributionAction.COMPLETED,
      ContributionAction.PAYMENT_RECORDED,
    ],
  ): Promise<string[]> {
    const actorReference = contributorActorReference(actorUserId);
    const events = await this.prisma.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId },
        contributorTenure: { actorReference },
        entityType: { in: [...entityTypes] },
        action: { in: [...actions] },
        entityId: { not: null },
      },
      select: { entityId: true },
      distinct: ["entityId"],
    });
    return events.flatMap((event) => (event.entityId ? [event.entityId] : []));
  }

  async list(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    query: Partial<ListContributionsDto>,
  ): Promise<ContributionHistoryPageResponse> {
    return runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const access = await this.historyAccess(
          currentUser,
          weddingPlanId,
          tx,
        );
        const contributorReference = access.isOwner
          ? query.contributorUserId
            ? contributorActorReference(query.contributorUserId)
            : undefined
          : contributorActorReference(currentUser.id);
        const livePlanWhere = livePlanAuthorizationWhere(
          access,
          currentUser.id,
        );
        const scope = await tx.contributorHistoryScope.findFirst({
          where: {
            weddingPlanId,
            weddingPlan: { is: livePlanWhere },
          },
        });
        if (!scope) {
          throw new NotFoundException("Contribution history not found");
        }

        const where: Prisma.ContributionEventWhereInput = {
          historyScope: {
            id: scope.id,
            weddingPlan: { is: livePlanWhere },
          },
          ...(contributorReference
            ? { contributorTenure: { actorReference: contributorReference } }
            : {}),
          ...(query.section ? { section: query.section } : {}),
        };
        const [events, total] = await Promise.all([
          tx.contributionEvent.findMany({
            where,
            orderBy: [{ capturedAt: "desc" }, { id: "desc" }],
            take: query.limit ?? 50,
            skip: query.offset ?? 0,
            include: {
              contributorTenure: { select: { actorReference: true } },
            },
          }),
          tx.contributionEvent.count({ where }),
        ]);

        return {
          historyCoverageStartsAt: scope.historyCoverageStartsAt.toISOString(),
          total,
          events: events.map((event) => ({
            id: event.id,
            contributorReference: event.contributorTenure.actorReference,
            section: event.section,
            entityType: event.entityType,
            action: event.action,
            snapshot: event.snapshot as Record<string, unknown>,
            provenance: event.provenance,
            occurredAt: event.occurredAt?.toISOString() ?? null,
            capturedAt: event.capturedAt.toISOString(),
          })),
        };
      },
      {
        isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead,
      },
    );
  }

  async summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    contributorUserId?: string,
  ): Promise<ContributionHistorySummaryResponse> {
    const access = await this.historyAccess(currentUser, weddingPlanId);
    const contributorReference = access.isOwner
      ? contributorUserId
        ? contributorActorReference(contributorUserId)
        : undefined
      : contributorActorReference(currentUser.id);
    const livePlanWhere = livePlanAuthorizationWhere(
      access,
      currentUser.id,
    );
    const events = await this.prisma.contributionEvent.findMany({
      where: {
        historyScope: {
          weddingPlanId,
          weddingPlan: { is: livePlanWhere },
        },
        ...(contributorReference
          ? { contributorTenure: { actorReference: contributorReference } }
          : {}),
        entityId: { not: null },
      },
      select: { section: true, entityId: true },
    });
    const sets = Object.fromEntries(
      Object.values(ContributionSection).map((section) => [section, new Set<string>()]),
    ) as Record<ContributionSection, Set<string>>;
    for (const event of events) {
      if (event.entityId) sets[event.section].add(event.entityId);
    }
    return Object.fromEntries(
      Object.entries(sets).map(([section, ids]) => [section, ids.size]),
    ) as ContributionHistorySummaryResponse;
  }

  private async historyAccess(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    client: PrismaService | Prisma.TransactionClient = this.prisma,
  ): Promise<PlanAccessContext> {
    const plan = await client.weddingPlan.findUnique({
      where: { id: weddingPlanId },
    });
    if (!plan) throw new NotFoundException("Wedding plan not found");
    if (plan.ownerUserId === currentUser.id) {
      return { plan, isOwner: true, sharedMember: null };
    }
    const member = await client.sharedMember.findUnique({
      where: {
        weddingPlanId_userId: { weddingPlanId, userId: currentUser.id },
      },
    });
    if (!member) throw new NotFoundException("Wedding plan not found");
    return { plan, isOwner: false, sharedMember: member };
  }

}

export function contributorActorReference(actorUserId: string): string {
  return createHash("sha256").update(actorUserId).digest("hex");
}

function contributionFingerprint(
  input: RecordContributionInput,
  snapshotHash: string,
  contributorTenureId: string,
  contributorReference: string,
): string {
  return createHash("sha256")
    .update(
      canonicalJson({
        contributorReference,
        contributorTenureId,
        section: input.section,
        entityType: input.entityType,
        entityId: input.entityId ?? null,
        action: input.action,
        snapshotHash,
        provenance: input.provenance ?? ContributionProvenance.RUNTIME,
        requiredPermission: input.requiredPermission ?? null,
        permissionPolicyVersion:
          input.permissionPolicyVersion ?? PERMISSION_POLICY_VERSION,
        authorityVersion: input.authorityVersion,
        occurredAt: input.occurredAt?.toISOString() ?? null,
      }),
    )
    .digest("hex");
}

function sameContribution(
  existing: ContributionEvent,
  snapshotHash: string,
  fingerprint: string,
  contributorTenureId: string,
): boolean {
  return existing.contributorTenureId === contributorTenureId &&
    existing.eventFingerprint === fingerprint &&
    existing.snapshotHash === snapshotHash;
}
