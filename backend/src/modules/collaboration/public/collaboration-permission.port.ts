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
  /** The plan's members; a contributor counts themself and the members they created. */
  countPlanMembers(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scope?: { userId: string; memberIds: readonly string[] } | null,
  ): Promise<number>;
  /** The plan's live pending invitations at `now`; `inviteIds` narrows to a contributor's invitations. */
  countLivePlanInvites(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    now: Date,
    inviteIds?: readonly string[] | null,
  ): Promise<number>;
  /** The user's membership row in the plan, if any. */
  getMembership(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
  ): Promise<SharedMember | null>;
  /** All of the user's membership rows. */
  listMemberships(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<SharedMember[]>;
  /** Every membership row of the given plans (a conversation's recipients and access are read from them). */
  listPlanMembers(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<SharedMember[]>;
  /** Locks every membership row of the given plans for share, in plan-id then id order. */
  lockPlanMembershipsForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void>;
  /** Locks the given users' membership rows in the plan for share, in user-id order. */
  lockMembershipsForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userIds: readonly string[],
  ): Promise<void>;
  /** Locks the user's membership row in the plan for share and returns it (an assignee is checked under it). */
  lockMembershipForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
  ): Promise<SharedMember | null>;
  /**
   * The live invitation an invite-OTP flow addresses: not declined, not
   * revoked, not expired at `now`, matching the token hash and phone;
   * `accepted` narrows to accepted (true) or pending (false) invitations.
   */
  findLivePlanInvite(
    client: Prisma.TransactionClient,
    lookup: LivePlanInviteLookup,
  ): Promise<LivePlanInviteSeed | null>;
  lockPlanInviteForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    planInviteId: string,
  ): Promise<boolean>;
}

export interface LivePlanInviteLookup {
  id?: string;
  tokenHash: string;
  normalizedPhone: string;
  now: Date;
  accepted?: boolean;
}

export interface LivePlanInviteSeed {
  id: string;
  acceptedAt: Date | null;
  weddingPlanId: string;
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
