import { Prisma, UserStatus } from '@prisma/client';

export interface LockedUserLifecycleRow {
  id: string;
  status: UserStatus;
}

export async function lockUserLifecycleRowsForShare(
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

export async function lockUserLifecycleRowsForUpdate(
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
