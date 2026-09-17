import { Injectable } from '@nestjs/common';
import { type Prisma, UserRole } from '@prisma/client';
import type {
  ActivePlanPort,
  CompleteOnboardingInput,
} from '../public/active-plan.port';
import { type SafeUser, toSafeUser } from '../public/safe-user';
import {
  type AppIdentity,
  appIdentitySelect,
  type InviteAccountState,
  type UserReadPort,
} from '../public/user-read.port';

@Injectable()
export class IdentityUserPortService implements UserReadPort, ActivePlanPort {
  async getSafeUser(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<SafeUser | null> {
    const user = await client.user.findUnique({ where: { id: userId } });
    return user ? toSafeUser(user) : null;
  }

  async getAppIdentity(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<AppIdentity | null> {
    return client.user.findUnique({
      where: { id: userId },
      select: appIdentitySelect,
    });
  }

  async getAppIdentities(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<AppIdentity[]> {
    if (userIds.length === 0) return [];
    return client.user.findMany({
      where: { id: { in: [...userIds] } },
      select: appIdentitySelect,
    });
  }

  async getActivePlanPointer(
    client: Prisma.TransactionClient,
    userId: string,
  ): Promise<string | null> {
    const user = await client.user.findUnique({
      where: { id: userId },
      select: { activeWeddingPlanId: true },
    });
    return user?.activeWeddingPlanId ?? null;
  }

  async findAppIdentityByPhone(
    client: Prisma.TransactionClient,
    phone: string,
    otherVariants: readonly string[],
  ): Promise<AppIdentity | null> {
    return (
      (await client.user.findUnique({
        where: { phone },
        select: appIdentitySelect,
      })) ??
      (await this.findAppIdentityByPhoneVariants(client, otherVariants))
    );
  }

  async findAppIdentityByPhoneVariants(
    client: Prisma.TransactionClient,
    variants: readonly string[],
  ): Promise<AppIdentity | null> {
    return client.user.findFirst({
      where: { phone: { in: [...variants] } },
      select: appIdentitySelect,
    });
  }

  async findInviteAccountByPhoneVariants(
    client: Prisma.TransactionClient,
    variants: readonly string[],
  ): Promise<InviteAccountState | null> {
    const account = await client.user.findFirst({
      where: { phone: { in: [...variants] } },
      select: {
        id: true,
        role: true,
        phoneVerifiedAt: true,
        appPasswordHash: true,
        appPasswordConfiguredAt: true,
      },
    });
    if (!account) return null;
    return {
      id: account.id,
      appPasswordConfigured: account.appPasswordConfiguredAt !== null,
      accountSetupRequired:
        !account.appPasswordConfiguredAt ||
        (!account.phoneVerifiedAt && account.role !== UserRole.ADMIN) ||
        (account.role === UserRole.ADMIN && !account.appPasswordHash),
    };
  }

  async clearActivePlanPointerInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    weddingPlanId: string,
  ): Promise<void> {
    await tx.user.updateMany({
      where: { id: userId, activeWeddingPlanId: weddingPlanId },
      data: { activeWeddingPlanId: null },
    });
  }

  async setActivePlanPointerInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    weddingPlanId: string | null,
  ): Promise<void> {
    await tx.user.update({
      where: { id: userId },
      data: { activeWeddingPlanId: weddingPlanId },
    });
  }

  async completeOnboardingInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    input: CompleteOnboardingInput,
  ): Promise<SafeUser> {
    const user = await tx.user.update({
      where: { id: userId },
      data: {
        activeWeddingPlanId: input.activeWeddingPlanId,
        appRole: input.appRole,
        onboardingPath: input.onboardingPath,
        persona: input.persona,
        onboardingCompletedAt: input.onboardingCompletedAt,
      },
    });
    return toSafeUser(user);
  }
}
