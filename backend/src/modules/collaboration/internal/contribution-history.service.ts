import { createHash } from "node:crypto";
import {
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  ContributionAction,
  ContributionEntityType,
  ContributionEvent,
  ContributionPermission,
  ContributionProvenance,
  ContributionScopeStatus,
  ContributionSection,
  ContributorTenure,
  Prisma,
  SharedMember,
  WeddingPlan,
} from "@prisma/client";
import { AuthenticatedUser } from "../../identity/public/identity-session.types";
import {
  CollaborationHistoryPort,
  ContributionHistorySummaryResponse,
  RecordContributionInput,
} from "../public/collaboration-history.port";
import { PlanAccessContext } from "../public/collaboration-permission.port";
import { runRetryableTransaction } from "../../../platform/database/serializable-transaction";
import { PrismaService } from "../../../platform/database/prisma.service";
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from "../../planning/public/plan-read.port";
import { PermissionService } from "./permission.service";
import {
  canonicalJson,
  hashContributionSnapshot,
  validateContributionSnapshot,
} from "../public/contribution-snapshot.builder";
import {
  ContributionHistoryPageResponse,
} from "./contribution-history.contracts";
import { ListContributionsDto } from "../api/dto/list-contributions.dto";
import { ContributionHistoryRepository } from "../infrastructure/contribution-history.repository";

const PERMISSION_POLICY_VERSION = 1;

@Injectable()
export class ContributionHistoryService implements CollaborationHistoryPort {
  private readonly repository = new ContributionHistoryRepository();
  constructor(
    private readonly prisma: PrismaService,
    @Inject(PLAN_READ_PORT) private readonly plans: PlanReadPort,
    private readonly permissions: PermissionService,
  ) {}

  async recordInTransaction(
    tx: Prisma.TransactionClient,
    input: RecordContributionInput,
  ): Promise<ContributionEvent> {
    validateContributionSnapshot(input.snapshot);
    const snapshotHash = hashContributionSnapshot(input.snapshot);
    const scope = await this.repository.getHistoryScopeId(tx, input.weddingPlanId);
    if (!scope) throw new NotFoundException("Contribution history scope not found");

    const actorReference = contributorActorReference(input.actorUserId);
    const tenure = await this.repository.findActiveTenureId(tx, scope.id, actorReference);
    if (!tenure) throw new NotFoundException("Active contributor tenure not found");

    const fingerprint = contributionFingerprint(
      input,
      snapshotHash,
      tenure.id,
      tenure.actorReference,
    );
    const inserted = await this.repository.insertContributionEvent(
      tx, input, scope.id, tenure.id, snapshotHash, fingerprint, PERMISSION_POLICY_VERSION,
    );
    const event = inserted[0] ?? await this.repository.findContributionByDedupeKey(
      tx, tenure.id, input.dedupeKey,
    );
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

  async createHistoryScopeInTransaction(
    tx: Prisma.TransactionClient,
    plan: Pick<WeddingPlan, "id" | "createdAt">,
  ): Promise<void> {
    await this.repository.createHistoryScope(tx, plan);
  }

  async archiveHistoryScopeInTransaction(
    tx: Prisma.TransactionClient,
    plan: Pick<WeddingPlan, "id" | "updatedAt">,
  ): Promise<void> {
    await this.repository.archiveHistoryScope(tx, plan);
  }

  async ensureTenureInTransaction(
    tx: Prisma.TransactionClient,
    member: SharedMember,
  ): Promise<ContributorTenure> {
    const scope = await this.repository.ensureHistoryScope(tx, member.weddingPlanId);
    const actorReference = contributorActorReference(member.userId);
    const existing = await this.repository.findOpenTenure(tx, scope.id, actorReference);
    if (existing) return existing;
    return this.repository.createTenure(tx, scope.id, actorReference, member);
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
    const scope = await this.repository.getHistoryScopeId(tx, input.weddingPlanId);
    if (!scope) return null;
    const tenure = await this.repository.findOpenTenure(
      tx, scope.id, contributorActorReference(input.actorUserId),
    );
    if (!tenure) return null;
    return this.repository.closeTenure(
      tx, tenure.id, input.endedAt ?? new Date(), input.reason, input.roleAtEnd ?? null,
    );
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
    const events = await this.repository.qualifyingEntityIds(
      this.prisma, weddingPlanId, actorReference, entityTypes, actions,
    );
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
        // The final reads re-check current ownership/membership through
        // the owners and apply the result to the history tables themselves.
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
        );
        const scope = await this.repository.findVisibleHistoryScope(
          tx, weddingPlanId, liveFilter,
        );
        if (!scope) {
          throw new NotFoundException("Contribution history not found");
        }

        const [events, total] = await this.repository.listPageEvents(
          tx, scope.id, contributorReference, query, liveFilter,
        );

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
    // The live re-check and the history read share one snapshot.
    const events = await runRetryableTransaction(
      this.prisma,
      async (tx) => {
        const liveFilter = await this.permissions.liveAuthorizationFilter(
          tx,
          access,
          currentUser.id,
        );
        return this.repository.summaryEvents(
          tx, weddingPlanId, contributorReference, liveFilter,
        );
      },
      { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead },
    );
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
    const plan = await this.plans.getPlan(client, weddingPlanId);
    if (!plan) throw new NotFoundException("Wedding plan not found");
    if (plan.ownerUserId === currentUser.id) {
      return { plan, isOwner: true, sharedMember: null };
    }
    const member = await this.repository.getHistoryMember(client, weddingPlanId, currentUser.id);
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
