import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { AdminRole, Prisma, UserRole, UserStatus } from '@prisma/client';
import { AuthenticatedUser } from '../auth/authenticated-user.interface';

export async function authorizeAdminUserStatusChange(
  tx: Prisma.TransactionClient,
  currentUser: AuthenticatedUser,
  targetId: string,
) {
  const [actor, target] = await Promise.all([
    tx.user.findUnique({
      where: { id: currentUser.id },
      select: {
        id: true,
        role: true,
        adminRole: true,
        status: true,
      },
    }),
    tx.user.findUnique({
      where: { id: targetId },
      select: {
        id: true,
        role: true,
        adminRole: true,
        status: true,
      },
    }),
  ]);
  if (!target) {
    throw new NotFoundException('User not found');
  }
  if (
    !actor ||
    actor.role !== UserRole.ADMIN ||
    actor.status !== UserStatus.ACTIVE
  ) {
    throw new ForbiddenException('Admin access is required');
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
