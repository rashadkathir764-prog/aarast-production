import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { AdminRole, Prisma, UserRole } from '@prisma/client';
import type { IdentityAdminPort } from '../modules/identity/public/identity-admin.port';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import { AdminPermission } from '../modules/backoffice/domain/admin-permissions';
import { authorizeAdminMutationActor } from '../modules/backoffice/public/admin-mutation-gate';

export async function authorizeAdminUserStatusChange(
  tx: Prisma.TransactionClient,
  accounts: IdentityAdminPort,
  currentUser: AuthenticatedUser,
  targetId: string,
) {
  const actor = await authorizeAdminMutationActor(
    tx,
    accounts,
    currentUser,
    AdminPermission.USERS_WRITE,
  );
  const targetRows =
    targetId === actor.id
      ? [actor]
      : await accounts.lockAccountsForUpdateInTransaction(tx, [targetId]);
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
