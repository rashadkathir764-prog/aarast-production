import type {
  ContributionAction,
  ContributionEntityType,
  ContributionEvent,
  ContributionPermission,
  ContributionProvenance,
  ContributionSection,
  ContributorTenure,
  Prisma,
  SharedMember,
  WeddingPlan,
} from '@prisma/client';
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';
import type { PlanAccessContext } from './collaboration-permission.port';

export const COLLABORATION_HISTORY_PORT = Symbol('COLLABORATION_HISTORY_PORT');

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

export type ContributionHistorySummaryResponse = Record<
  ContributionSection,
  number
>;

export interface CollaborationHistoryPort {
  recordInTransaction(
    tx: Prisma.TransactionClient,
    input: RecordContributionInput,
  ): Promise<ContributionEvent>;
  recordForContextInTransaction(
    tx: Prisma.TransactionClient,
    context: PlanAccessContext,
    input: Omit<
      RecordContributionInput,
      'weddingPlanId' | 'actorUserId' | 'authorityVersion'
    >,
  ): Promise<ContributionEvent | null>;
  ensureTenureInTransaction(
    tx: Prisma.TransactionClient,
    member: SharedMember,
  ): Promise<ContributorTenure>;
  /** Opens the plan's history scope when planning creates the plan. */
  createHistoryScopeInTransaction(
    tx: Prisma.TransactionClient,
    plan: Pick<WeddingPlan, 'id' | 'createdAt'>,
  ): Promise<void>;
  /** Archives the plan's history scope when planning archives the plan (created archived when it never existed). */
  archiveHistoryScopeInTransaction(
    tx: Prisma.TransactionClient,
    plan: Pick<WeddingPlan, 'id' | 'updatedAt'>,
  ): Promise<void>;
  summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    contributorUserId?: string,
  ): Promise<ContributionHistorySummaryResponse>;
}
