import { NotFoundException } from "@nestjs/common";
import { Prisma, UserStatus } from "@prisma/client";
import {
  findDeletionPendingUserIds,
  lockUserLifecycleRowsForShare,
  lockUserLifecycleRowsForUpdate,
} from "../infrastructure/user-lifecycle-lock.repository";

export interface LockedUserLifecycleRow {
  id: string;
  status: UserStatus;
  /** D63: the account is waiting out its 30 days before erasure. */
  deletionPending: boolean;
}

/**
 * D63: an account that takes part in the app: active and not waiting out its
 * deletion. A plan whose owner waits is closed to everyone (w06), and nobody
 * waiting is reminded of anything.
 */
export function isLiveAccount(row: LockedUserLifecycleRow): boolean {
  return row.status === UserStatus.ACTIVE && !row.deletionPending;
}

/** D63: which of these accounts wait out their deletion (a plain read, no lock). */
export function listDeletionPendingUserIds(
  client: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<Set<string>> {
  return findDeletionPendingUserIds(client, userIds);
}

export async function lockUserLifecycleRowsInTransaction(
  tx: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<LockedUserLifecycleRow[]> {
  return lockUserLifecycleRowsForShare(tx, userIds);
}

export async function lockUserLifecycleRowsForUpdateInTransaction(
  tx: Prisma.TransactionClient,
  userIds: readonly string[],
): Promise<LockedUserLifecycleRow[]> {
  return lockUserLifecycleRowsForUpdate(tx, userIds);
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
