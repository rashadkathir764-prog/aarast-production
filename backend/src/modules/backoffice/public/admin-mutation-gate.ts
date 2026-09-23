import { ForbiddenException } from '@nestjs/common';
import {
  AdminRole,
  Prisma,
  UserRole,
  UserStatus,
} from '@prisma/client';
import type { IdentityAdminPort } from '../../identity/public/identity-admin.port';
import type { AuthenticatedUser } from '../../identity/public/identity-session.types';
import {
  AdminPermission,
  hasAdminPermission,
} from '../domain/admin-permissions';
import { runSerializableTransaction } from '../../../platform/database/serializable-transaction';
import { PrismaService } from '../../../platform/database/prisma.service';

export interface AuthorizedAdminMutationActor {
  id: string;
  role: UserRole;
  adminRole: AdminRole | null;
  status: UserStatus;
}

/** The account lock the gate takes: the caller passes identity's admin port. */
type AdminAccountLocks = Pick<IdentityAdminPort, 'lockAccountsForUpdateInTransaction'>;

export async function authorizeAdminMutationActor(
  tx: Prisma.TransactionClient,
  accounts: AdminAccountLocks,
  currentUser: AuthenticatedUser,
  permission: AdminPermission,
): Promise<AuthorizedAdminMutationActor> {
  // Identity locks the actor's account row FOR UPDATE; the admin decision
  // is taken on the locked row.
  const [actor] = await accounts.lockAccountsForUpdateInTransaction(tx, [
    currentUser.id,
  ]);
  if (
    !actor ||
    actor.role !== UserRole.ADMIN ||
    actor.status !== UserStatus.ACTIVE ||
    !hasAdminPermission(actor.adminRole, permission)
  ) {
    throw new ForbiddenException('Admin permission is required');
  }
  return actor;
}

export async function runAuthorizedAdminMutation<T>(
  prisma: PrismaService,
  accounts: AdminAccountLocks,
  currentUser: AuthenticatedUser,
  permission: AdminPermission,
  mutation: (tx: Prisma.TransactionClient) => Promise<T>,
): Promise<T> {
  return runSerializableTransaction(prisma, async (tx) => {
    await authorizeAdminMutationActor(tx, accounts, currentUser, permission);
    return mutation(tx);
  });
}
