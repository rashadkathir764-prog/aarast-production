import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from "@nestjs/common";
import {
  City,
  Prisma,
  Provider,
  ProviderService,
  ProviderStatus,
  UserStatus,
} from "@prisma/client";
import type { CatalogReadPort } from "../modules/catalog/public/catalog-read.port";
import { lockUserLifecycleRowsInTransaction } from "../modules/identity/public/user-lifecycle-lock";
import * as writeLockRepository from "../modules/marketplace/infrastructure/marketplace-write-lock.repository";

export async function lockMarketplaceMutationUsers(
  tx: Prisma.TransactionClient,
  actorUserId: string,
  targetUserIds: readonly (string | null | undefined)[] = [],
): Promise<Set<string>> {
  const userIds = [
    actorUserId,
    ...targetUserIds.filter((id): id is string => Boolean(id)),
  ];
  const users = await lockUserLifecycleRowsInTransaction(tx, userIds);
  const lockedUserIds = new Set(users.map((user) => user.id));
  const actor = users.find((user) => user.id === actorUserId);
  if (!actor || actor.status !== UserStatus.ACTIVE) {
    throw new NotFoundException("User not found");
  }
  return lockedUserIds;
}

export async function lockMarketplaceProvider(
  tx: Prisma.TransactionClient,
  providerId: string,
  mode: "SHARE" | "UPDATE" = "SHARE",
): Promise<Pick<Provider, "id" | "userId" | "status" | "businessName">> {
  const rows = await writeLockRepository.lockProviderRow(tx, providerId, mode);
  if (rows.length !== 1) {
    throw new NotFoundException("Provider not found");
  }

  const provider = await writeLockRepository.findLockedProvider(tx, providerId);
  if (!provider) {
    throw new NotFoundException("Provider not found");
  }
  return provider;
}

export function assertMarketplaceProviderActive(
  provider: Pick<Provider, "status">,
): void {
  if (provider.status !== ProviderStatus.ACTIVE) {
    throw new NotFoundException("Provider not found");
  }
}

export function assertProviderAccountUnchanged(
  provider: Pick<Provider, "userId">,
  seededUserId: string | null,
  lockedUserIds: ReadonlySet<string>,
): void {
  if (provider.userId === seededUserId) return;
  if (provider.userId && !lockedUserIds.has(provider.userId)) {
    throw new ConflictException(
      "Provider account changed concurrently; retry the request",
    );
  }
}

export async function lockActiveProviderService(
  tx: Prisma.TransactionClient,
  serviceId: string,
  providerId: string,
): Promise<ProviderService> {
  const rows = await writeLockRepository.lockProviderServiceRow(tx, serviceId);
  if (rows.length !== 1) {
    throw new BadRequestException(
      "serviceId must reference an active provider service",
    );
  }
  const service = await writeLockRepository.findActiveProviderService(tx, serviceId, providerId);
  if (!service) {
    throw new BadRequestException(
      "serviceId must reference an active provider service",
    );
  }
  return service;
}

export async function lockActiveMarketplaceCity(
  tx: Prisma.TransactionClient,
  catalog: CatalogReadPort,
  cityId: string,
): Promise<City> {
  // The city row is catalog's: locked for share and confirmed active there.
  const city = await catalog.lockActiveCityForShareInTransaction(tx, cityId);
  if (!city) {
    throw new BadRequestException("cityId must reference an active city");
  }
  return city;
}
