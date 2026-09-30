import { NotFoundException } from "@nestjs/common";
import { Prisma, UserStatus } from "@prisma/client";
import {
  lockUserLifecycleRowsForShare,
  lockUserLifecycleRowsForUpdate,
} from "../infrastructure/user-lifecycle-lock.repository";

export interface LockedUserLifecycleRow {
  id: string;
  status: UserStatus;
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
