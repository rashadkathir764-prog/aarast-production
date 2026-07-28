import { NotFoundException } from "@nestjs/common";
import { Prisma, UserStatus } from "@prisma/client";

export interface LockedUserLifecycleRow {
  id: string;
  status: UserStatus;
}

export async function lockUserLifecycleRowsInTransaction(
  tx: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<LockedUserLifecycleRow[]> {
  const sortedUserIds = [...new Set(userIds)].sort();
  if (sortedUserIds.length === 0) return [];

  return tx.$queryRaw<LockedUserLifecycleRow[]>(
    Prisma.sql`
      SELECT "id", "status"
      FROM "User"
      WHERE "id" IN (${Prisma.join(sortedUserIds)})
      ORDER BY "id" ASC
      FOR SHARE
    `,
  );
}

export async function lockUserLifecycleRowsForUpdateInTransaction(
  tx: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<LockedUserLifecycleRow[]> {
  const sortedUserIds = [...new Set(userIds)].sort();
  if (sortedUserIds.length === 0) return [];

  return tx.$queryRaw<LockedUserLifecycleRow[]>(
    Prisma.sql`
      SELECT "id", "status"
      FROM "User"
      WHERE "id" IN (${Prisma.join(sortedUserIds)})
      ORDER BY "id" ASC
      FOR UPDATE
    `,
  );
}

export async function assertActiveMutationActorInTransaction(
  tx: Prisma.TransactionClient,
  userId: string,
): Promise<void> {
  const users = await lockUserLifecycleRowsInTransaction(tx, [userId]);
  if (users.length !== 1 || users[0]?.status !== UserStatus.ACTIVE) {
    throw new NotFoundException("User not found");
  }
}

export async function assertActiveMutationActorForUpdateInTransaction(
  tx: Prisma.TransactionClient,
  userId: string,
): Promise<void> {
  const users = await lockUserLifecycleRowsForUpdateInTransaction(tx, [userId]);
  if (users.length !== 1 || users[0]?.status !== UserStatus.ACTIVE) {
    throw new NotFoundException("User not found");
  }
}
