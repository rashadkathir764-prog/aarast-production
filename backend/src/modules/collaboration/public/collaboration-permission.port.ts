import { ConflictException, NotFoundException } from '@nestjs/common';
import {
  Prisma,
  SharedMember,
  WeddingPlan,
  WeddingPlanStatus,
} from '@prisma/client';
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';

export const COLLABORATION_PERMISSION_PORT = Symbol(
  'COLLABORATION_PERMISSION_PORT',
);

export interface PlanAccessContext {
  plan: WeddingPlan;
  isOwner: boolean;
  sharedMember: SharedMember | null;
}

export type LivePlanPermission =
  | 'canViewMoney'
  | 'canManageMoney'
  | 'canManageTasks'
  | 'canManageGuests'
  | 'canManageProviders'
  | 'canInviteMembers'
  | 'canEditPlan';

export const PLAN_ARCHIVED_READ_ONLY = 'PLAN_ARCHIVED_READ_ONLY';
export const TASK_PERMISSION_REVOKED = 'TASK_PERMISSION_REVOKED';
export const TASK_PERMISSION_REVOKED_MESSAGE =
  'لم تعد لديك صلاحية لتنفيذ هذه المهمة';

export function livePlanAuthorizationWhere(
  context: PlanAccessContext,
  currentUserId: string,
  requiredPermissions: readonly LivePlanPermission[] = [],
): Prisma.WeddingPlanWhereInput {
  if (context.isOwner) return { ownerUserId: currentUserId };
  const member = context.sharedMember;
  if (!member || member.userId !== currentUserId) {
    throw new NotFoundException('Wedding plan not found');
  }
  return {
    sharedMembers: {
      some: {
        id: member.id,
        userId: currentUserId,
        ...Object.fromEntries(
          requiredPermissions.map((permission) => [permission, true]),
        ),
      },
    },
  };
}

export function isWeddingPlanWritable(
  plan: Pick<WeddingPlan, 'status'>,
): boolean {
  return plan.status !== WeddingPlanStatus.ARCHIVED;
}

export function assertWeddingPlanWritable(
  plan: Pick<WeddingPlan, 'status'>,
): void {
  if (!isWeddingPlanWritable(plan)) {
    throw new ConflictException({
      code: PLAN_ARCHIVED_READ_ONLY,
      message: 'Archived wedding plans are read-only',
    });
  }
}

export interface CollaborationPermissionPort {
  assertPlanReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertPlanReadableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertPlanReadableForUserUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertPlanManageableForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertTaskManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertGuestManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertMoneyReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertMoneyReadableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertMoneyManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertMoneyManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertMoneyManageableForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertProviderManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertProviderManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertProviderAndMoneyManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertMemberManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext>;
  assertMemberManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
    additionalLifecycleUserIds?: readonly string[],
  ): Promise<PlanAccessContext>;
  canViewMoney(context: PlanAccessContext): boolean;
  canManageTasks(context: PlanAccessContext): boolean;
  canManageGuests(context: PlanAccessContext): boolean;
  canManageMoney(context: PlanAccessContext): boolean;
  canManagePlan(context: PlanAccessContext): boolean;
  canManageProviders(context: PlanAccessContext): boolean;
  canManageMembers(context: PlanAccessContext): boolean;
  livePlanAuthorizationWhere(
    context: PlanAccessContext,
    currentUserId: string,
    requiredPermissions?: readonly LivePlanPermission[],
  ): Prisma.WeddingPlanWhereInput;
  liveAuthorizationFilter(
    client: Prisma.TransactionClient,
    context: PlanAccessContext,
    currentUserId: string,
    requiredPermissions?: readonly LivePlanPermission[],
  ): Promise<LiveAuthorizationFilter>;
  /** Ids of the plans the user is a shared member of. */
  listMemberPlanIds(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]>;
  /** Revokes the plan's live pending invitations (planning archives the plan under its UPDATE lock). */
  revokeLivePlanInvitesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    revokedAt: Date,
  ): Promise<void>;
}

/**
 * Result of the owners' live re-check for a caller's final read. `{}` keeps
 * the caller's own-table query as it is; the never-matching filter makes the
 * same statement return nothing — exactly what the embedded
 * `weddingPlan: { is: ... }` join returned once ownership or membership was
 * gone. Every Prisma model here has a string `id`, and an empty `in` list is
 * a false predicate.
 */
export type LiveAuthorizationFilter = { id?: { in: string[] } };

export const NEVER_MATCHING_ROW_FILTER: Readonly<LiveAuthorizationFilter> =
  Object.freeze({ id: Object.freeze({ in: [] as string[] }) });
