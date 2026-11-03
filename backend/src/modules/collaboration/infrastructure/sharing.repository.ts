import {
  ContributionAction,
  ContributionEntityType,
  ContributionSection,
  PlanInviteDeliveryStatus,
  Prisma,
  SharedMemberRole,
  type PlanInvite,
} from '@prisma/client';
import type { PrismaService } from '../../../platform/database/prisma.service';
import type { LiveAuthorizationFilter } from '../public/collaboration-permission.port';
import type { PlanPermissionFlags } from '../internal/plan-permissions';

type Client = PrismaService | Prisma.TransactionClient;

export class SharingRepository {
  findMember(client: Client, weddingPlanId: string, userId: string) {
    return client.sharedMember.findUnique({
      where: { weddingPlanId_userId: { weddingPlanId, userId } },
    });
  }

  createMember(tx: Prisma.TransactionClient, weddingPlanId: string, userId: string, role: SharedMemberRole, permissions: PlanPermissionFlags) {
    return tx.sharedMember.create({
      data: { weddingPlanId, userId, role, ...permissions },
    });
  }

  listSharedPlans(client: Client, userId: string) {
    return client.sharedMember.findMany({
      where: { userId }, orderBy: { createdAt: 'desc' },
    });
  }

  listPlanMembersForOwner(tx: Prisma.TransactionClient, weddingPlanId: string, liveFilter: LiveAuthorizationFilter) {
    return tx.sharedMember.findMany({
      where: { weddingPlanId, ...liveFilter }, orderBy: { createdAt: 'asc' },
    });
  }

  listPlanMembersForContributor(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    userId: string,
    createdMemberIds: readonly string[],
    inviterAuthorityFilter: LiveAuthorizationFilter,
    liveMembershipFilter: LiveAuthorizationFilter,
  ) {
    return tx.sharedMember.findMany({
      where: {
        weddingPlanId,
        OR: [
          { userId },
          ...(createdMemberIds.length > 0
            ? [{ id: { in: [...createdMemberIds] }, ...inviterAuthorityFilter }]
            : []),
        ],
        ...liveMembershipFilter,
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  findPendingDuplicateInvite(
    tx: Prisma.TransactionClient,
    weddingPlanId: string,
    now: Date,
    target: { inviteeUserId: string | null; normalizedPhone: string | null; email: string | null },
  ) {
    return tx.planInvite.findFirst({
      where: {
        weddingPlanId,
        acceptedAt: null, declinedAt: null, revokedAt: null,
        expiresAt: { gt: now },
        OR: [
          ...(target.inviteeUserId ? [{ inviteeUserId: target.inviteeUserId }] : []),
          ...(target.normalizedPhone ? [{ normalizedPhone: target.normalizedPhone }] : []),
          ...(target.email ? [{ email: target.email }] : []),
        ],
      },
    });
  }

  createInvite(
    tx: Prisma.TransactionClient,
    fields: {
      weddingPlanId: string; inviterUserId: string; inviteeUserId: string | null;
      name: string | null; phone: string | null; normalizedPhone: string | null;
      email: string | null; role: SharedMemberRole; permissions: PlanPermissionFlags;
      expiresAt: Date; tokenHash: string; attemptedAt: Date;
    },
  ) {
    return tx.planInvite.create({
      data: {
        weddingPlanId: fields.weddingPlanId,
        inviterUserId: fields.inviterUserId,
        inviteeUserId: fields.inviteeUserId,
        name: fields.name,
        phone: fields.phone,
        normalizedPhone: fields.normalizedPhone,
        email: fields.email,
        role: fields.role,
        ...fields.permissions,
        expiresAt: fields.expiresAt,
        tokenHash: fields.tokenHash,
        deliveryStatus: PlanInviteDeliveryStatus.PENDING,
        deliveryAttemptedAt: fields.attemptedAt,
      },
    });
  }

  listCurrentUserInvites(client: Client, userId: string, normalizedPhone: string | null) {
    return client.planInvite.findMany({
      where: {
        OR: [
          { inviteeUserId: userId },
          ...(normalizedPhone ? [{ normalizedPhone }] : []),
        ],
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  liveMembershipPlanIds(client: Client, userId: string, planIds: readonly string[]) {
    return client.sharedMember.findMany({
      where: { userId, weddingPlanId: { in: [...planIds] } },
      select: { weddingPlanId: true },
    });
  }

  liveMembershipId(client: Client, weddingPlanId: string, userId: string) {
    return client.sharedMember.findUnique({
      where: { weddingPlanId_userId: { weddingPlanId, userId } }, select: { id: true },
    });
  }

  listPlanInvites(tx: Prisma.TransactionClient, weddingPlanId: string, userId: string, isOwner: boolean, liveFilter: LiveAuthorizationFilter) {
    return tx.planInvite.findMany({
      where: { weddingPlanId, ...(isOwner ? {} : { inviterUserId: userId }), ...liveFilter },
      orderBy: { createdAt: 'desc' },
    });
  }

  findPlanInvite(tx: Prisma.TransactionClient, inviteId: string, weddingPlanId: string) {
    return tx.planInvite.findFirst({ where: { id: inviteId, weddingPlanId } });
  }

  findInviteById(client: Client, inviteId: string) {
    return client.planInvite.findUnique({ where: { id: inviteId } });
  }

  findInviteByHash(client: Client, tokenHash: string) {
    return client.planInvite.findUnique({ where: { tokenHash } });
  }

  cancelPendingInvite(tx: Prisma.TransactionClient, invite: PlanInvite, weddingPlanId: string, now: Date) {
    return tx.planInvite.updateMany({
      where: {
        id: invite.id, weddingPlanId, tokenHash: invite.tokenHash,
        acceptedAt: null, declinedAt: null, revokedAt: null, expiresAt: { gt: now },
      },
      data: { revokedAt: now },
    });
  }

  rotatePendingInvite(
    tx: Prisma.TransactionClient, invite: PlanInvite, weddingPlanId: string,
    now: Date, tokenHash: string, role: SharedMemberRole | undefined,
    permissions: PlanPermissionFlags, expiresAt: Date,
  ) {
    return tx.planInvite.updateMany({
      where: {
        id: invite.id, weddingPlanId, tokenHash: invite.tokenHash,
        acceptedAt: null, declinedAt: null, revokedAt: null, expiresAt: { gt: now },
      },
      data: {
        tokenHash,
        deliveryStatus: PlanInviteDeliveryStatus.PENDING,
        deliveryAttemptedAt: now,
        expiresAt,
        ...(role !== undefined ? { role } : {}),
        ...permissions,
      },
    });
  }

  lockInvite(tx: Prisma.TransactionClient, inviteId: string) {
    return tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "PlanInvite" WHERE "id" = ${inviteId} FOR UPDATE`,
    );
  }

  claimInvite(
    tx: Prisma.TransactionClient, invite: PlanInvite, tokenHash: string | null,
    at: Date, userId: string, decision: 'ACCEPT' | 'DECLINE',
  ) {
    return tx.planInvite.updateMany({
      where: {
        id: invite.id,
        ...(tokenHash ? { tokenHash } : {}),
        acceptedAt: null, declinedAt: null, revokedAt: null,
        expiresAt: { gt: at },
      },
      data: decision === 'ACCEPT'
        ? { acceptedAt: at, inviteeUserId: userId }
        : { declinedAt: at, inviteeUserId: userId },
    });
  }

  upsertAcceptedMember(tx: Prisma.TransactionClient, invite: PlanInvite, userId: string) {
    return tx.sharedMember.upsert({
      where: { weddingPlanId_userId: { weddingPlanId: invite.weddingPlanId, userId } },
      update: {},
      create: {
        weddingPlanId: invite.weddingPlanId, userId, role: invite.role,
        canViewMoney: invite.canViewMoney,
        canEditPlan: invite.canEditPlan,
        canManageTasks: invite.canManageTasks,
        canManageGuests: invite.canManageGuests,
        canManageProviders: invite.canManageProviders,
        canInviteMembers: invite.canInviteMembers,
        canManageMoney: invite.canManageMoney,
        receiveNotifications: invite.receiveNotifications,
      },
    });
  }

  findMemberSeed(client: Client, weddingPlanId: string, memberId: string) {
    return client.sharedMember.findFirst({
      where: { id: memberId, weddingPlanId }, select: { userId: true },
    });
  }

  findMemberById(client: Client, weddingPlanId: string, memberId: string) {
    return client.sharedMember.findFirst({ where: { id: memberId, weddingPlanId } });
  }

  lockMemberById(tx: Prisma.TransactionClient, weddingPlanId: string, memberId: string) {
    return tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "SharedMember" WHERE "id" = ${memberId} AND "weddingPlanId" = ${weddingPlanId} FOR UPDATE`,
    );
  }

  lockMemberByUser(tx: Prisma.TransactionClient, weddingPlanId: string, userId: string) {
    return tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "SharedMember" WHERE "weddingPlanId" = ${weddingPlanId} AND "userId" = ${userId} FOR UPDATE`,
    );
  }

  lockDelegatedMemberForShare(tx: Prisma.TransactionClient, weddingPlanId: string, userId: string) {
    return tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`SELECT "id" FROM "SharedMember" WHERE "weddingPlanId" = ${weddingPlanId} AND "userId" = ${userId} FOR SHARE`,
    );
  }

  updateMember(
    tx: Prisma.TransactionClient, memberId: string,
    role: SharedMemberRole | undefined, permissions: PlanPermissionFlags,
    authorityVersion: number | undefined,
  ) {
    return tx.sharedMember.update({
      where: { id: memberId },
      data: {
        ...(role !== undefined ? { role } : {}),
        ...permissions,
        ...(authorityVersion !== undefined ? { authorityVersion } : {}),
      },
    });
  }

  deleteMember(tx: Prisma.TransactionClient, memberId: string) {
    return tx.sharedMember.delete({ where: { id: memberId } });
  }

  lockPendingInvitesForUser(
    tx: Prisma.TransactionClient, weddingPlanId: string,
    userId: string, normalizedPhone: string | null, at: Date,
  ) {
    const targetPredicate = normalizedPhone
      ? Prisma.sql`("inviterUserId" = ${userId} OR "inviteeUserId" = ${userId} OR "normalizedPhone" = ${normalizedPhone})`
      : Prisma.sql`("inviterUserId" = ${userId} OR "inviteeUserId" = ${userId})`;
    return tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id" FROM "PlanInvite"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "acceptedAt" IS NULL AND "declinedAt" IS NULL
          AND "revokedAt" IS NULL AND "expiresAt" > ${at}
          AND ${targetPredicate}
        ORDER BY "id" FOR UPDATE
      `,
    );
  }

  revokePendingInvitesForUser(
    tx: Prisma.TransactionClient, weddingPlanId: string,
    userId: string, normalizedPhone: string | null,
    inviteIds: readonly string[], at: Date,
  ) {
    return tx.planInvite.updateMany({
      where: {
        id: { in: [...inviteIds] }, weddingPlanId,
        acceptedAt: null, declinedAt: null, revokedAt: null, expiresAt: { gt: at },
        OR: [
          { inviterUserId: userId }, { inviteeUserId: userId },
          ...(normalizedPhone ? [{ normalizedPhone }] : []),
        ],
      },
      data: { revokedAt: at },
    });
  }

  lockPendingInvitesForInviter(
    tx: Prisma.TransactionClient, weddingPlanId: string, inviterUserId: string, at: Date,
  ) {
    return tx.$queryRaw<Array<
      Pick<PlanInvite, 'id' | 'canViewMoney' | 'canEditPlan' | 'canManageTasks' | 'canManageGuests' | 'canManageProviders' | 'canInviteMembers' | 'canManageMoney'>
    >>(
      Prisma.sql`
        SELECT "id", "canViewMoney", "canEditPlan", "canManageTasks",
               "canManageGuests", "canManageProviders", "canInviteMembers", "canManageMoney"
        FROM "PlanInvite"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "inviterUserId" = ${inviterUserId}
          AND "acceptedAt" IS NULL AND "declinedAt" IS NULL
          AND "revokedAt" IS NULL AND "expiresAt" > ${at}
        ORDER BY "id" FOR UPDATE
      `,
    );
  }

  revokePendingInvitesForInviter(
    tx: Prisma.TransactionClient, weddingPlanId: string,
    inviterUserId: string, inviteIds: readonly string[], at: Date,
  ) {
    return tx.planInvite.updateMany({
      where: {
        id: { in: [...inviteIds] }, weddingPlanId, inviterUserId,
        acceptedAt: null, declinedAt: null, revokedAt: null, expiresAt: { gt: at },
      },
      data: { revokedAt: at },
    });
  }

  persistInviteDelivery(
    tx: Prisma.TransactionClient,
    attempt: { inviteId: string; weddingPlanId: string; tokenHash: string; attemptedAt: Date },
    finalizedAt: Date,
    status: PlanInviteDeliveryStatus,
  ) {
    return tx.planInvite.updateMany({
      where: {
        id: attempt.inviteId,
        weddingPlanId: attempt.weddingPlanId,
        tokenHash: attempt.tokenHash,
        deliveryAttemptedAt: attempt.attemptedAt,
        deliveryStatus: PlanInviteDeliveryStatus.PENDING,
        acceptedAt: null, declinedAt: null, revokedAt: null,
        expiresAt: { gt: finalizedAt },
      },
      data: { deliveryStatus: status },
    });
  }

  contributedEntityIds(
    client: Client, weddingPlanId: string, actorUserId: string,
    entityType: ContributionEntityType, action: ContributionAction,
  ) {
    return client.contributionEvent.findMany({
      where: {
        historyScope: { weddingPlanId },
        contributorTenure: { actorUserId },
        entityType, action, entityId: { not: null },
      },
      select: { entityId: true }, distinct: ['entityId'],
    });
  }

  memberCreatedByActor(tx: Prisma.TransactionClient, weddingPlanId: string, actorUserId: string, memberId: string) {
    return tx.contributionEvent.findFirst({
      where: {
        historyScope: { weddingPlanId },
        contributorTenure: { actorUserId },
        section: ContributionSection.MEMBERS,
        entityType: ContributionEntityType.MEMBER_ITEM,
        entityId: memberId,
        action: ContributionAction.CREATED,
      },
      select: { id: true },
    });
  }

  getHistoryScopeId(tx: Prisma.TransactionClient, weddingPlanId: string) {
    return tx.contributorHistoryScope.findUnique({ where: { weddingPlanId }, select: { id: true } });
  }

  previousLeave(tx: Prisma.TransactionClient, historyScopeId: string, actorUserId: string) {
    return tx.contributorTenure.findFirst({
      where: { historyScopeId, actorUserId, endedAt: { not: null }, endReason: 'MEMBER_LEFT' },
      select: { id: true },
    });
  }
}
