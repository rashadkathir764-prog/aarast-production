import { ForbiddenException } from '@nestjs/common';
import {
  AdminRole,
  Prisma,
  UserRole,
  UserStatus,
} from '@prisma/client';
import { AuthenticatedUser } from '../modules/identity/public/identity-session.types';
import {
  AdminPermission,
  hasAdminPermission,
} from '../modules/backoffice/domain/admin-permissions';
import { runSerializableTransaction } from '../platform/database/serializable-transaction';
import { PrismaService } from '../platform/database/prisma.service';

export interface AuthorizedAdminMutationActor {
  id: string;
  role: UserRole;
  adminRole: AdminRole | null;
  status: UserStatus;
}

export async function authorizeAdminMutationActor(
  tx: Prisma.TransactionClient,
  currentUser: AuthenticatedUser,
  permission: AdminPermission,
): Promise<AuthorizedAdminMutationActor> {
  const rows = await tx.$queryRaw<AuthorizedAdminMutationActor[]>(
    Prisma.sql`
      SELECT "id", "role", "adminRole", "status"
      FROM "User"
      WHERE "id" = ${currentUser.id}
      FOR UPDATE
    `,
  );
  const actor = rows[0];
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
  currentUser: AuthenticatedUser,
  permission: AdminPermission,
  mutation: (tx: Prisma.TransactionClient) => Promise<T>,
): Promise<T> {
  return runSerializableTransaction(prisma, async (tx) => {
    await authorizeAdminMutationActor(tx, currentUser, permission);
    return mutation(tx);
  });
}
