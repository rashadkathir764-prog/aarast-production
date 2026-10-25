import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { Prisma, UserRole, UserStatus } from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  AdminPermission,
  hasAdminPermission,
} from '../modules/backoffice/domain/admin-permissions';
import type { AdminOwners } from './admin-owners';

/**
 * Locks the acting administrator's account and the provider-side account a
 * review touches (the provider's owner, or the account claiming a listing),
 * FOR UPDATE, and re-checks the administrator may still write providers.
 * Returns the locked provider-side account, or null when there is none.
 */
export async function lockProviderReviewAccountsInTransaction(
  tx: Prisma.TransactionClient,
  owners: AdminOwners,
  currentUser: AuthenticatedUser,
  providerSideUserId: string | null,
  notFoundMessage: string,
) {
  const userIds = [
    ...new Set(
      [currentUser.id, providerSideUserId].filter(
        (userId): userId is string => Boolean(userId),
      ),
    ),
  ];
  const users = await owners.accounts.lockAccountsForUpdateInTransaction(
    tx,
    userIds,
  );
  if (users.length !== userIds.length) {
    throw new NotFoundException(notFoundMessage);
  }
  const actor = users.find((user) => user.id === currentUser.id);
  if (
    !actor ||
    actor.role !== UserRole.ADMIN ||
    actor.status !== UserStatus.ACTIVE ||
    !hasAdminPermission(actor.adminRole, AdminPermission.PROVIDERS_WRITE)
  ) {
    throw new ForbiddenException('Admin permission is required');
  }
  return providerSideUserId
    ? (users.find((user) => user.id === providerSideUserId) ?? null)
    : null;
}
