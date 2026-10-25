import { NotFoundException } from "@nestjs/common";
import { Prisma, Provider, UserStatus } from "@prisma/client";
import { lockUserLifecycleRowsInTransaction } from "../modules/identity/public/user-lifecycle-lock";
import {
  assertProviderOperational,
  assertProviderProfileWritable,
} from "../modules/marketplace/public/provider-access-policy";
import { isProviderAwaitingApproval } from "../modules/marketplace/public/provider-review";
import {
  findProviderForMutation,
  lockOwnedProviderRow,
} from "../modules/marketplace/infrastructure/provider-mutation-lock.repository";

/**
 * OPERATIONAL: an approved provider. PROFILE: a provider whose profile is
 * writable. JOINING_SERVICE: an approved provider, or one waiting for
 * approval editing the service he joined with (B-10). LIFECYCLE: any
 * status; the caller checks the transition (resubmit, reopen).
 */
export type ProviderMutationAccess =
  | "OPERATIONAL"
  | "PROFILE"
  | "JOINING_SERVICE"
  | "LIFECYCLE";
export type ProviderMutationLockMode = "SHARE" | "UPDATE";

export async function lockProviderMutationUsersInTransaction(
  tx: Prisma.TransactionClient,
  userIds: readonly string[],
  actorUserId: string,
): Promise<void> {
  const expectedIds = [...new Set(userIds)].sort();
  const users = await lockUserLifecycleRowsInTransaction(tx, expectedIds);
  const actor = users.find((user) => user.id === actorUserId);
  if (
    users.length !== expectedIds.length ||
    !actor ||
    actor.status !== UserStatus.ACTIVE
  ) {
    throw new NotFoundException("User not found");
  }
}

export async function lockOwnedProviderAfterUsersInTransaction(
  tx: Prisma.TransactionClient,
  userId: string,
  access: ProviderMutationAccess,
  mode: ProviderMutationLockMode = "SHARE",
  expectedProviderId?: string,
): Promise<Provider> {
  const row = await lockOwnedProviderRow(tx, userId, mode);
  if (!row || (expectedProviderId && row.id !== expectedProviderId)) {
    throw new NotFoundException("Provider profile not found");
  }

  const provider = await findProviderForMutation(tx, row.id);
  if (
    !provider ||
    provider.userId !== userId ||
    (expectedProviderId && provider.id !== expectedProviderId)
  ) {
    throw new NotFoundException("Provider profile not found");
  }
  if (access === "PROFILE") {
    assertProviderProfileWritable(provider);
  } else if (access === "JOINING_SERVICE") {
    if (!isProviderAwaitingApproval(provider)) assertProviderOperational(provider);
  } else if (access === "OPERATIONAL") {
    assertProviderOperational(provider);
  }
  return provider;
}

export async function lockOwnedProviderForMutationInTransaction(
  tx: Prisma.TransactionClient,
  userId: string,
  access: ProviderMutationAccess,
  mode: ProviderMutationLockMode = "SHARE",
): Promise<Provider> {
  await lockProviderMutationUsersInTransaction(tx, [userId], userId);
  return lockOwnedProviderAfterUsersInTransaction(tx, userId, access, mode);
}
