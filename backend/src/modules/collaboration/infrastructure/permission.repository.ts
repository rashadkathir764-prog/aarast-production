import { Prisma } from '@prisma/client';
import type { LivePlanInviteLookup, LivePlanPermission } from '../public/collaboration-permission.port';

type Client = Prisma.TransactionClient;

export class PermissionRepository {
  getMembership(client: Client, weddingPlanId: string, userId: string) {
    return client.sharedMember.findUnique({
      where: { weddingPlanId_userId: { weddingPlanId, userId } },
    });
  }

  findLiveMembershipWithPermissions(
    client: Client,
    memberId: string,
    weddingPlanId: string,
    userId: string,
    requiredPermissions: readonly LivePlanPermission[],
  ) {
    return client.sharedMember.findFirst({
      where: {
        id: memberId,
        weddingPlanId,
        userId,
        ...(requiredPermissions.includes('canViewMoney') ? { canViewMoney: true } : {}),
        ...(requiredPermissions.includes('canManageMoney') ? { canManageMoney: true } : {}),
        ...(requiredPermissions.includes('canManageTasks') ? { canManageTasks: true } : {}),
        ...(requiredPermissions.includes('canManageGuests') ? { canManageGuests: true } : {}),
        ...(requiredPermissions.includes('canManageProviders') ? { canManageProviders: true } : {}),
        ...(requiredPermissions.includes('canInviteMembers') ? { canInviteMembers: true } : {}),
        ...(requiredPermissions.includes('canEditPlan') ? { canEditPlan: true } : {}),
      },
      select: { id: true },
    });
  }

  listMemberPlanIds(client: Client, userId: string) {
    return client.sharedMember.findMany({
      where: { userId },
      select: { weddingPlanId: true },
    });
  }

  listMemberships(client: Client, userId: string) {
    return client.sharedMember.findMany({ where: { userId } });
  }

  countPlanMembers(
    client: Client,
    weddingPlanId: string,
    scope?: { userId: string; memberIds: readonly string[] } | null,
  ) {
    return client.sharedMember.count({
      where: {
        weddingPlanId,
        ...(scope
          ? { OR: [{ userId: scope.userId }, { id: { in: [...scope.memberIds] } }] }
          : {}),
      },
    });
  }

  countLivePlanInvites(
    client: Client,
    weddingPlanId: string,
    now: Date,
    inviteIds?: readonly string[] | null,
  ) {
    return client.planInvite.count({
      where: {
        weddingPlanId,
        ...(inviteIds ? { id: { in: [...inviteIds] } } : {}),
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: now },
      },
    });
  }

  listPlanMembers(client: Client, weddingPlanIds: readonly string[]) {
    return client.sharedMember.findMany({
      where: { weddingPlanId: { in: [...weddingPlanIds] } },
    });
  }

  lockPlanMembershipsForShare(tx: Client, sortedPlanIds: readonly string[]) {
    return tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ANY(${[...sortedPlanIds]}::text[])
        ORDER BY "weddingPlanId" ASC, "id" ASC
        FOR SHARE
      `,
    );
  }

  lockMembershipsForShare(tx: Client, weddingPlanId: string, sortedUserIds: readonly string[]) {
    return tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "userId" = ANY(${[...sortedUserIds]}::text[])
        ORDER BY "userId" ASC
        FOR SHARE
      `,
    );
  }

  lockMembershipForShare(tx: Client, weddingPlanId: string, userId: string) {
    return tx.$queryRaw(
      Prisma.sql`
        SELECT "id"
        FROM "SharedMember"
        WHERE "weddingPlanId" = ${weddingPlanId}
          AND "userId" = ${userId}
        FOR SHARE
      `,
    );
  }

  findLivePlanInvite(client: Client, lookup: LivePlanInviteLookup) {
    return client.planInvite.findFirst({
      where: {
        ...(lookup.id === undefined ? {} : { id: lookup.id }),
        tokenHash: lookup.tokenHash,
        normalizedPhone: lookup.normalizedPhone,
        ...(lookup.accepted === undefined
          ? {}
          : { acceptedAt: lookup.accepted ? { not: null } : null }),
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: lookup.now },
      },
      select: { id: true, acceptedAt: true, weddingPlanId: true },
    });
  }

  async lockPlanInviteForUpdate(tx: Client, planInviteId: string): Promise<boolean> {
    const rows = await tx.$queryRaw<Array<{ id: string }>>(
      Prisma.sql`
        SELECT "id"
        FROM "PlanInvite"
        WHERE "id" = ${planInviteId}
        FOR UPDATE
      `,
    );
    return rows.length === 1;
  }

  revokeLivePlanInvites(tx: Client, weddingPlanId: string, revokedAt: Date) {
    return tx.planInvite.updateMany({
      where: {
        weddingPlanId,
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: revokedAt },
      },
      data: { revokedAt },
    });
  }

  revokeLiveInvitesIssuedByUser(tx: Client, inviterUserId: string, revokedAt: Date) {
    return tx.planInvite.updateMany({
      where: {
        inviterUserId,
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: { gt: revokedAt },
      },
      data: { revokedAt },
    });
  }
}
