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
  WeddingPlan,
} from "@prisma/client";
import { assertWeddingPlanWritable } from "../modules/collaboration/public/collaboration-permission.port";
import { lockUserLifecycleRowsInTransaction } from "../users/user-lifecycle-lock";

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
  const rows =
    mode === "UPDATE"
      ? await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT "id"
            FROM "Provider"
            WHERE "id" = ${providerId}
            FOR UPDATE
          `,
        )
      : await tx.$queryRaw<Array<{ id: string }>>(
          Prisma.sql`
            SELECT "id"
            FROM "Provider"
            WHERE "id" = ${providerId}
            FOR SHARE
          `,
        );
  if (rows.length !== 1) {
    throw new NotFoundException("Provider not found");
  }

  const provider = await tx.provider.findUnique({
    where: { id: providerId },
    select: {
      id: true,
      userId: true,
      status: true,
      businessName: true,
    },
  });
  if (!provider) {
    throw new NotFoundException("Provider not found");
  }
  return provider;
}

export async function lockWritableMarketplacePlan(
  tx: Prisma.TransactionClient,
  weddingPlanId: string,
): Promise<WeddingPlan> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "WeddingPlan"
      WHERE "id" = ${weddingPlanId}
      FOR SHARE
    `,
  );
  if (rows.length !== 1) {
    throw new NotFoundException("Wedding plan not found");
  }
  const plan = await tx.weddingPlan.findUnique({
    where: { id: weddingPlanId },
  });
  if (!plan) {
    throw new NotFoundException("Wedding plan not found");
  }
  assertWeddingPlanWritable(plan);
  return plan;
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
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "ProviderService"
      WHERE "id" = ${serviceId}
      FOR SHARE
    `,
  );
  if (rows.length !== 1) {
    throw new BadRequestException(
      "serviceId must reference an active provider service",
    );
  }
  const service = await tx.providerService.findFirst({
    where: {
      id: serviceId,
      providerId,
      isActive: true,
      provider: { status: ProviderStatus.ACTIVE },
    },
  });
  if (!service) {
    throw new BadRequestException(
      "serviceId must reference an active provider service",
    );
  }
  return service;
}

export async function lockActiveMarketplaceCity(
  tx: Prisma.TransactionClient,
  cityId: string,
): Promise<City> {
  const rows = await tx.$queryRaw<Array<{ id: string }>>(
    Prisma.sql`
      SELECT "id"
      FROM "City"
      WHERE "id" = ${cityId}
      FOR SHARE
    `,
  );
  if (rows.length !== 1) {
    throw new BadRequestException("cityId must reference an active city");
  }
  const city = await tx.city.findFirst({
    where: { id: cityId, isActive: true },
  });
  if (!city) {
    throw new BadRequestException("cityId must reference an active city");
  }
  return city;
}
