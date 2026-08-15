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
  summary(
    currentUser: AuthenticatedUser,
    weddingPlanId: string,
    contributorUserId?: string,
  ): Promise<ContributionHistorySummaryResponse>;
}
