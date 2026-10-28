import { Prisma, UserStatus } from '@prisma/client';

export interface LockedUserLifecycleRow {
  id: string;
  status: UserStatus;
  /** D63: the account is waiting out its 30 days before erasure. */
  deletionPending: boolean;
}

export async function lockUserLifecycleRowsForShare(
  tx: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<LockedUserLifecycleRow[]> {
  const sortedUserIds = [...new Set(userIds)].sort();
  if (sortedUserIds.length === 0) return [];

  return tx.$queryRaw<LockedUserLifecycleRow[]>(
    Prisma.sql`
      SELECT "id", "status", ("deletionScheduledFor" IS NOT NULL) AS "deletionPending"
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
      SELECT "id", "status", ("deletionScheduledFor" IS NOT NULL) AS "deletionPending"
      FROM "User"
      WHERE "id" IN (${Prisma.join(sortedUserIds)})
      ORDER BY "id" ASC
      FOR UPDATE
    `,
  );
}

/** D63: which of these accounts wait out their deletion (a plain read, no lock). */
export async function findDeletionPendingUserIds(
  client: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<Set<string>> {
  const ids = [...new Set(userIds)];
  if (ids.length === 0) return new Set();
  const rows = await client.user.findMany({
    where: { id: { in: ids }, deletionScheduledFor: { not: null } },
    select: { id: true },
  });
  return new Set(rows.map((row) => row.id));
}
