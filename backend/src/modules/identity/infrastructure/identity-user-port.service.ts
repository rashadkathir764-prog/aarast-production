import { Injectable } from '@nestjs/common';
import {
  AppRole,
  type Prisma,
  UserRole,
  UserStatus,
  WeddingPersona,
} from '@prisma/client';
import type {
  ActivePlanPort,
  CompleteOnboardingInput,
} from '../public/active-plan.port';
import type { ProviderAccountPort } from '../public/provider-account.port';
import { type SafeUser } from '../public/safe-user';
import { toSafeUser } from '../internal/safe-user.presenter';
import {
  type AppIdentity,
  appIdentitySelect,
  type InviteAccountState,
  type UserReadPort,
} from '../public/user-read.port';

@Injectable()
export class IdentityUserPortService
  implements UserReadPort, ActivePlanPort, ProviderAccountPort
{
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
        appAccountActivatedAt: true,
      },
    });
    if (!account) return null;
    return {
      id: account.id,
      appAccountActivated: account.appAccountActivatedAt !== null,
      accountSetupRequired:
        !account.appAccountActivatedAt ||
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

  async promoteToProviderInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
  ): Promise<boolean> {
    let promoted = await tx.user.updateMany({
      where: {
        id: userId,
        status: UserStatus.ACTIVE,
        role: { in: [UserRole.USER, UserRole.PROVIDER] },
      },
      data: {
        role: UserRole.PROVIDER,
        appRole: AppRole.PROVIDER,
      },
    });
    if (promoted.count === 0) {
      promoted = await tx.user.updateMany({
        where: {
          id: userId,
          status: UserStatus.ACTIVE,
          role: UserRole.ADMIN,
          appPasswordHash: { not: null },
        },
        data: { appRole: AppRole.PROVIDER },
      });
    }
    return promoted.count === 1;
  }

  async completeOnboardingInTransaction(
    tx: Prisma.TransactionClient,
    userId: string,
    input: CompleteOnboardingInput,
  ): Promise<SafeUser> {
    // The account's persona is who the person is (the groom or the bride),
    // which is how the app and the server speak to them (B5). A plan made
    // for someone else (HELPER) says nothing about that, so it never
    // replaces a groom's or a bride's persona.
    const current = await tx.user.findUniqueOrThrow({
      where: { id: userId },
      select: { persona: true },
    });
    const isPerson = (value: WeddingPersona | null) =>
      value === WeddingPersona.GROOM || value === WeddingPersona.BRIDE;
    const persona =
      isPerson(input.persona) || !isPerson(current.persona)
        ? input.persona
        : current.persona;
    const user = await tx.user.update({
      where: { id: userId },
      data: {
        activeWeddingPlanId: input.activeWeddingPlanId,
        appRole: input.appRole,
        onboardingPath: input.onboardingPath,
        persona,
        onboardingCompletedAt: input.onboardingCompletedAt,
      },
    });
    return toSafeUser(user);
  }
}
