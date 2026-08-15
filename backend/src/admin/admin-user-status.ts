import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { AdminRole, Prisma, UserRole, UserStatus } from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { authorizeAdminMutationActor } from './admin-mutation-gate';

export async function authorizeAdminUserStatusChange(
  tx: Prisma.TransactionClient,
  currentUser: AuthenticatedUser,
  targetId: string,
) {
  const actor = await authorizeAdminMutationActor(
    tx,
    currentUser,
    AdminPermission.USERS_WRITE,
  );
  const targetRows =
    targetId === actor.id
      ? [actor]
      : await tx.$queryRaw<
          Array<{
            id: string;
            role: UserRole;
            adminRole: AdminRole | null;
            status: UserStatus;
          }>
        >(
          Prisma.sql`
            SELECT "id", "role", "adminRole", "status"
            FROM "User"
            WHERE "id" = ${targetId}
            FOR UPDATE
          `,
        );
  const target = targetRows[0];
  if (!target) {
    throw new NotFoundException('User not found');
  }
  if (
    target.role === UserRole.ADMIN &&
    actor.adminRole !== AdminRole.SUPER_ADMIN
  ) {
    throw new ForbiddenException(
      'Only a super administrator can manage an administrator account',
    );
  }
  return target;
}

export async function revokePendingInvitesIssuedByUserInTransaction(
  tx: Prisma.TransactionClient,
  userId: string,
  revokedAt: Date,
): Promise<void> {
  await tx.planInvite.updateMany({
    where: {
      inviterUserId: userId,
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: { gt: revokedAt },
    },
    data: { revokedAt },
  });
}
