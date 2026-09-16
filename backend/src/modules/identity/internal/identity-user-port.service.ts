import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';
import type {
  ActivePlanPort,
  CompleteOnboardingInput,
} from '../public/active-plan.port';
import { type SafeUser, toSafeUser } from '../public/safe-user';
import {
  type AppIdentity,
  appIdentitySelect,
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
