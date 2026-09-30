import {
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import {
  Prisma,
  SharedMember,
  UserStatus,
} from "@prisma/client";
import { AuthenticatedUser } from "../../identity/public/identity-session.types";
import {
  PLAN_READ_PORT,
  PlanReadPort,
} from "../../planning/public/plan-read.port";
import {
  assertWeddingPlanWritable,
  CollaborationPermissionPort,
  LiveAuthorizationFilter,
  LivePlanInviteLookup,
  LivePlanInviteSeed,
  livePlanAuthorizationWhere,
  LivePlanPermission,
  NEVER_MATCHING_ROW_FILTER,
  PlanAccessContext,
  TASK_PERMISSION_REVOKED,
  TASK_PERMISSION_REVOKED_MESSAGE,
} from "../public/collaboration-permission.port";
import { PrismaService } from "../../../platform/database/prisma.service";
import { PermissionRepository } from "../infrastructure/permission.repository";
import {
  lockUserLifecycleRowsForUpdateInTransaction,
  lockUserLifecycleRowsInTransaction,
} from "../../identity/public/user-lifecycle-lock";

@Injectable()
export class PermissionService implements CollaborationPermissionPort {
  private readonly repository = new PermissionRepository();
  constructor(
    private readonly prisma: PrismaService,
    @Inject(PLAN_READ_PORT) private readonly plans: PlanReadPort,
  ) {}

  async getPlanAccessContext(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    return this.getPlanAccessContextWithClient(
      this.prisma,
      weddingPlanId,
      currentUser,
    );
  }

  private async getPlanAccessContextWithClient(
    client: PrismaService | Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const plan = await this.plans.getPlan(client, weddingPlanId);

    if (!plan) {
      throw new NotFoundException("Wedding plan not found");
    }

    const isOwner = plan.ownerUserId === currentUser.id;
    const sharedMember = isOwner
      ? null
      : await this.repository.getMembership(client, weddingPlanId, currentUser.id);

    return { plan, isOwner, sharedMember };
  }

  async assertPlanReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getPlanAccessContext(weddingPlanId, currentUser);
    if (!context.isOwner && !context.sharedMember) {
      throw new NotFoundException("Wedding plan not found");
    }
    return context;
  }

  async assertPlanReadableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (!context.isOwner && !context.sharedMember) {
      throw new NotFoundException("Wedding plan not found");
    }
    return context;
  }

  async assertPlanReadableForUserUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
      [],
      true,
    );
    if (!context.isOwner && !context.sharedMember) {
      throw new NotFoundException("Wedding plan not found");
    }
    return context;
  }

  async assertPlanManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (!this.canManagePlan(context)) {
      throw new NotFoundException("Wedding plan not found");
    }
    assertWeddingPlanWritable(context.plan);
    return context;
  }

  async assertPlanManageableForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getPlanUpdateLockedAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (!this.canManagePlan(context)) {
      throw new NotFoundException("Wedding plan not found");
    }
    assertWeddingPlanWritable(context.plan);
    return context;
  }

  async assertTaskManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }

    if (this.canManageTasks(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }

    throw taskPermissionRevoked();
  }

  async assertTaskManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canManageTasks(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    if (context.sharedMember) {
      throw taskPermissionRevoked();
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertGuestManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (this.canManageGuests(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertGuestManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canManageGuests(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMoneyReadable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) return context;
    if (this.canViewMoney(context)) return context;
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMoneyReadableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadableInTransaction(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canViewMoney(context)) return context;
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMoneyManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (context.isOwner) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }

    if (this.canManageMoney(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }

    throw new NotFoundException("Wedding plan not found");
  }

  async assertMoneyManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canManageMoney(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMoneyManageableForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getPlanUpdateLockedAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canManageMoney(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertProviderManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (this.canManageProviders(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertProviderManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canManageProviders(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertProviderAndMoneyManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
    );
    if (this.canManageProviders(context) && this.canManageMoney(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMemberManageable(
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const context = await this.assertPlanReadable(weddingPlanId, currentUser);
    if (this.canManageMembers(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  async assertMemberManageableInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
    additionalLifecycleUserIds: readonly string[] = [],
  ): Promise<PlanAccessContext> {
    const context = await this.getLockedPlanAccessContext(
      tx,
      weddingPlanId,
      currentUser,
      additionalLifecycleUserIds,
    );
    if (this.canManageMembers(context)) {
      assertWeddingPlanWritable(context.plan);
      return context;
    }
    throw new NotFoundException("Wedding plan not found");
  }

  canViewMoney(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canViewMoney);
  }

  canManageTasks(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canManageTasks);
  }

  canManageGuests(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canManageGuests);
  }

  canManageMoney(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canManageMoney);
  }

  canManagePlan(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canEditPlan);
  }

  canManageProviders(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canManageProviders);
  }

  canManageMembers(context: PlanAccessContext): boolean {
    if (context.isOwner) return true;
    return Boolean(context.sharedMember?.canInviteMembers);
  }

  /**
   * Database predicate for the final live-domain read. The earlier access
   * lookup chooses response semantics; this predicate makes current stored
   * membership and flags part of the same SQL statement that returns data.
   * A removed member or a committed permission revocation therefore cannot
   * pass on a stale role/default cached by application code.
   */
  livePlanAuthorizationWhere(
    context: PlanAccessContext,
    currentUserId: string,
    requiredPermissions: readonly LivePlanPermission[] = [],
  ): Prisma.WeddingPlanWhereInput {
    return livePlanAuthorizationWhere(
      context,
      currentUserId,
      requiredPermissions,
    );
  }

  /**
   * The same predicate, evaluated now by the owners of the rows it reads:
   * planning still records the plan under this owner, or collaboration still
   * holds the same membership row for this user with every required flag.
   * The caller applies the result to its own table right before its final
   * read, so a removed member or a committed revocation still cannot pass on
   * a stale role/default cached by application code.
   */
  async liveAuthorizationFilter(
    client: Prisma.TransactionClient,
    context: PlanAccessContext,
    currentUserId: string,
    requiredPermissions: readonly LivePlanPermission[] = [],
  ): Promise<LiveAuthorizationFilter> {
    if (context.isOwner) {
      const plan = await this.plans.findOwnedPlan(
        client,
        context.plan.id,
        currentUserId,
      );
      return plan ? {} : NEVER_MATCHING_ROW_FILTER;
    }
    const member = context.sharedMember;
    if (!member || member.userId !== currentUserId) {
      throw new NotFoundException("Wedding plan not found");
    }
    const live = await this.repository.findLiveMembershipWithPermissions(
      client,
      member.id,
      context.plan.id,
      currentUserId,
      requiredPermissions,
    );
    return live ? {} : NEVER_MATCHING_ROW_FILTER;
  }

  async listMemberPlanIds(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<string[]> {
    const memberships = await this.repository.listMemberPlanIds(client, userId);
    return memberships.map((membership) => membership.weddingPlanId);
  }

  async getMembership(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
  ): Promise<SharedMember | null> {
    return this.repository.getMembership(client, weddingPlanId, userId);
  }

  async listMemberships(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<SharedMember[]> {
    return this.repository.listMemberships(client, userId);
  }

  async countPlanMembers(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    scope?: { userId: string; memberIds: readonly string[] } | null,
  ): Promise<number> {
    return this.repository.countPlanMembers(client, weddingPlanId, scope);
  }

  async countLivePlanInvites(
    client: Prisma.TransactionClient,
    weddingPlanId: string,
    now: Date,
    inviteIds?: readonly string[] | null,
  ): Promise<number> {
    return this.repository.countLivePlanInvites(client, weddingPlanId, now, inviteIds);
  }

  async listPlanMembers(
    client: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<SharedMember[]> {
    if (weddingPlanIds.length === 0) return [];
    return this.repository.listPlanMembers(client, weddingPlanIds);
  }

  async lockPlanMembershipsForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanIds: readonly string[],
  ): Promise<void> {
    const sortedPlanIds = [...new Set(weddingPlanIds)].sort();
    if (sortedPlanIds.length === 0) return;
    await this.repository.lockPlanMembershipsForShare(tx, sortedPlanIds);
  }

  async lockMembershipsForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userIds: readonly string[],
  ): Promise<void> {
    const sortedUserIds = [...new Set(userIds)].sort();
    if (sortedUserIds.length === 0) return;
    await this.repository.lockMembershipsForShare(tx, weddingPlanId, sortedUserIds);
  }

  async lockMembershipForShareInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
  ): Promise<SharedMember | null> {
    await this.repository.lockMembershipForShare(tx, weddingPlanId, userId);
    return this.getMembership(tx, weddingPlanId, userId);
  }

  async findLivePlanInvite(
    client: Prisma.TransactionClient,
    lookup: LivePlanInviteLookup,
  ): Promise<LivePlanInviteSeed | null> {
    return this.repository.findLivePlanInvite(client, lookup);
  }

  async lockPlanInviteForUpdateInTransaction(
    tx: Prisma.TransactionClient,
    planInviteId: string,
  ): Promise<boolean> {
    return this.repository.lockPlanInviteForUpdate(tx, planInviteId);
  }

  async revokeLivePlanInvitesInTransaction(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    revokedAt: Date,
  ): Promise<void> {
    await this.repository.revokeLivePlanInvites(tx, weddingPlanId, revokedAt);
  }

  async revokeLiveInvitesIssuedByUserInTransaction(
    tx: Prisma.TransactionClient,
    inviterUserId: string,
    revokedAt: Date,
  ): Promise<void> {
    await this.repository.revokeLiveInvitesIssuedByUser(tx, inviterUserId, revokedAt);
  }

  private async getLockedPlanAccessContext(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
    additionalLifecycleUserIds: readonly string[] = [],
    lockLifecycleUsersForUpdate = false,
  ): Promise<PlanAccessContext> {
    // Account lifecycle mutations take User before WeddingPlan. Match that
    // order here so a disabled/deleted actor cannot finish an in-flight plan
    // write and so account deletion cannot deadlock with plan children.
    const ownerUserId = await this.lockPlanMutationUsers(
      tx,
      weddingPlanId,
      currentUser,
      additionalLifecycleUserIds,
      lockLifecycleUsersForUpdate,
    );

    // Take the plan lifecycle lock before any permission or domain-row lock.
    // A concurrent archive either commits first and is observed below, or
    // waits until the authorized transaction has finished.
    const planLock = await this.plans.lockPlanRowForShareInTransaction(
      tx,
      weddingPlanId,
    );
    if (planLock.length !== 1) {
      throw new NotFoundException("Wedding plan not found");
    }
    const plan = await this.plans.getPlan(tx, weddingPlanId);
    if (!plan || plan.ownerUserId !== ownerUserId) {
      throw new NotFoundException("Wedding plan not found");
    }
    if (plan.ownerUserId === currentUser.id) {
      return { plan, isOwner: true, sharedMember: null };
    }

    // FOR SHARE conflicts with permission updates/deletes. If revocation
    // commits first, this transaction sees the revoked row; if this lock wins,
    // the authorized quote transition serializes before the revocation.
    await this.repository.lockMembershipForShare(tx, weddingPlanId, currentUser.id);
    const sharedMember = await this.repository.getMembership(tx, weddingPlanId, currentUser.id);
    return { plan, isOwner: false, sharedMember };
  }

  private async getPlanUpdateLockedAccessContext(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
  ): Promise<PlanAccessContext> {
    const ownerUserId = await this.lockPlanMutationUsers(
      tx,
      weddingPlanId,
      currentUser,
    );

    // Plan mutations need an UPDATE lock from the start. Taking SHARE and then
    // upgrading would allow a lock-order inversion with other plan writers.
    const planLock = await this.plans.lockPlanRowForUpdateInTransaction(
      tx,
      weddingPlanId,
    );
    if (planLock.length !== 1) {
      throw new NotFoundException("Wedding plan not found");
    }
    const plan = await this.plans.getPlan(tx, weddingPlanId);
    if (!plan || plan.ownerUserId !== ownerUserId) {
      throw new NotFoundException("Wedding plan not found");
    }
    if (plan.ownerUserId === currentUser.id) {
      return { plan, isOwner: true, sharedMember: null };
    }

    await this.repository.lockMembershipForShare(tx, weddingPlanId, currentUser.id);
    const sharedMember = await this.repository.getMembership(tx, weddingPlanId, currentUser.id);
    return { plan, isOwner: false, sharedMember };
  }

  private async lockPlanMutationUsers(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    currentUser: AuthenticatedUser,
    additionalLifecycleUserIds: readonly string[] = [],
    forUpdate = false,
  ): Promise<string> {
    const seed = await this.plans.getPlan(tx, weddingPlanId);
    if (!seed) {
      throw new NotFoundException("Wedding plan not found");
    }

    // Every account row that can own or authorize this mutation is locked in
    // deterministic order before WeddingPlan. Besides blocking a disabled
    // actor, this prevents a member write from holding the owner's plan while
    // account deletion holds the owner row and waits in the opposite order.
    const lifecycleUserIds = [
      currentUser.id,
      seed.ownerUserId,
      ...additionalLifecycleUserIds,
    ];
    const users = forUpdate
      ? await lockUserLifecycleRowsForUpdateInTransaction(
          tx,
          lifecycleUserIds,
        )
      : await lockUserLifecycleRowsInTransaction(tx, lifecycleUserIds);
    const actor = users.find((user) => user.id === currentUser.id);
    const owner = users.find((user) => user.id === seed.ownerUserId);
    const allAdditionalUsersExist = additionalLifecycleUserIds.every(
      (userId) => users.some((user) => user.id === userId),
    );
    if (
      !actor ||
      actor.status !== UserStatus.ACTIVE ||
      !owner ||
      !allAdditionalUsersExist
    ) {
      throw new NotFoundException("Wedding plan not found");
    }
    return seed.ownerUserId;
  }
}

function taskPermissionRevoked(): ForbiddenException {
  return new ForbiddenException({
    statusCode: 403,
    code: TASK_PERMISSION_REVOKED,
    message: TASK_PERMISSION_REVOKED_MESSAGE,
  });
}
