import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import {
  AdminRole,
  ProviderStatus,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { AdminService } from "../src/admin/admin.service";
import { ProviderDashboardService } from "../src/provider-dashboard/provider-dashboard.service";
import { UsersService } from "../src/users/users.service";

test("an administrator app profile cannot overwrite the administrator identity", async () => {
  const now = new Date();
  const stored: any = {
    id: "admin-1",
    name: "Admin Identity",
    appName: "Wedding User",
    phone: "+967777123456",
    email: "admin@example.test",
    appEmail: null,
    passwordHash: "admin-hash",
    appPasswordHash: "app-hash",
    role: UserRole.ADMIN,
    adminRole: "SUPER_ADMIN",
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: now,
    lastLoginAt: now,
    avatarUrl: "https://media.test/admin.webp",
    appAvatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    createdAt: now,
    updatedAt: now,
  };
  const consumedTargets: unknown[] = [];
  const tx = {
    $queryRaw: async () => [{ id: stored.id, status: stored.status }],
    user: {
      findUniqueOrThrow: async () => ({
        role: stored.role,
        avatarUrl: stored.avatarUrl,
        appAvatarUrl: stored.appAvatarUrl,
      }),
      findFirst: async () => null,
      update: async ({ data }: any) => Object.assign(stored, data),
    },
  };
  const service = new UsersService(
    { $transaction: async (operation: any) => operation(tx) } as any,
    {} as any,
    {
      verifyPublicMediaUrl: async (_user: unknown, value: string) => value,
      scheduleTargetDeletion: async (target: unknown) => {
        consumedTargets.push(target);
      },
      consumePublicMediaUrl: async (
        _user: unknown,
        _value: string,
        _purpose: string,
        target: unknown,
      ) => {
        consumedTargets.push(target);
      },
    } as any,
  );

  const response = await service.updateMe(
    {
      id: stored.id,
      role: UserRole.USER,
      adminMfa: false,
    } as any,
    {
      name: "Wedding Profile",
      email: "wedding@example.test",
      avatarUrl: "https://media.test/wedding.webp",
    } as any,
  );

  assert.equal(stored.name, "Admin Identity");
  assert.equal(stored.email, "admin@example.test");
  assert.equal(stored.avatarUrl, "https://media.test/admin.webp");
  assert.equal(stored.appName, "Wedding Profile");
  assert.equal(stored.appEmail, "wedding@example.test");
  assert.equal(stored.appAvatarUrl, "https://media.test/wedding.webp");
  assert.equal(response.role, UserRole.USER);
  assert.equal(response.name, "Wedding Profile");
  assert.equal(response.adminRole, null);
  assert.deepEqual(consumedTargets, [
    { type: "USER_APP_AVATAR", id: stored.id },
    { type: "USER_APP_AVATAR", id: stored.id },
  ]);
});

test("an administrator app session can create a provider profile without changing the administrator role", async () => {
  let providerCreates = 0;
  const identityUpdates: any[] = [];
  const tx = {
    $queryRaw: async (query: any) => {
      const text = query.strings?.join("") ?? String(query);
      if (text.includes('FROM "User"')) {
        return [
          {
            id: "admin-1",
            role: UserRole.ADMIN,
            status: UserStatus.ACTIVE,
            appPasswordHash: "configured",
          },
        ];
      }
      if (text.includes('FROM "Provider"')) return [];
      if (text.includes('FROM "City"')) {
        return [{ id: "11111111-1111-4111-8111-111111111111" }];
      }
      if (text.includes('FROM "ProviderCategory"')) return [];
      throw new Error(`Unexpected provider-apply lock: ${text}`);
    },
    user: {
      updateMany: async (args: any) => {
        identityUpdates.push(args);
        return { count: identityUpdates.length === 2 ? 1 : 0 };
      },
    },
    provider: {
      create: async ({ data }: any) => {
        providerCreates += 1;
        const now = new Date();
        return {
          id: "provider-1",
          ...data,
          logoUrl: null,
          coverUrl: null,
          ownerName: null,
          whatsapp: null,
          email: null,
          address: null,
          latitude: null,
          longitude: null,
          reviewNote: null,
          reviewedAt: null,
          reviewedById: null,
          ratingAverage: 0,
          ratingCount: 0,
          isFeatured: false,
          createdAt: now,
          updatedAt: now,
          city: {
            id: data.cityId,
            nameAr: "صنعاء",
            nameEn: null,
            countryCode: "YE",
            sortOrder: 0,
            isActive: true,
          },
          primaryCategory: null,
        };
      },
    },
    city: {
      findFirst: async () => ({
        id: "11111111-1111-4111-8111-111111111111",
      }),
    },
    providerCategory: { count: async () => 0 },
  };
  const prisma = {
    provider: { findUnique: async () => null },
    city: {
      findFirst: async () => ({
        id: "11111111-1111-4111-8111-111111111111",
        nameAr: "صنعاء",
        isActive: true,
      }),
    },
    providerCategory: { count: async () => 0 },
    $transaction: async (operation: any) => operation(tx),
  };
  const service = new ProviderDashboardService(
    prisma as any,
    {} as any,
    {} as any,
  );

  await service.apply(
    { id: "admin-1", role: UserRole.USER, adminMfa: false } as any,
    {
      businessName: "Admin Provider",
      phone: "+967777123456",
      cityId: "11111111-1111-4111-8111-111111111111",
      categoryIds: [],
    },
  );
  assert.equal(providerCreates, 1);
  assert.equal(identityUpdates.length, 2);
  assert.equal(identityUpdates[1].where.role, UserRole.ADMIN);
  assert.equal(identityUpdates[1].data.role, undefined);
  assert.equal(identityUpdates[1].data.appRole, "PROVIDER");
});

test("provider approval preserves an administrator database role", () => {
  const source = readFileSync("src/admin/admin.service.ts", "utf8");
  assert.match(
    source,
    /role:\s*\{\s*in:\s*\[UserRole\.USER,\s*UserRole\.PROVIDER\]/,
  );
  assert.match(
    source,
    /role:\s*UserRole\.ADMIN,[\s\S]*?data:\s*\{\s*appRole:\s*AppRole\.PROVIDER\s*\}/,
  );
});

test("a provider owner cannot review their own provider application", async () => {
  let updates = 0;
  const prisma = {
    provider: {
      findUnique: async () => ({ id: "provider-1", userId: "admin-1" }),
    },
    $transaction: async (operation: any) =>
      operation({
        provider: {
          findUnique: async () => ({ id: "provider-1", userId: "admin-1" }),
          update: async () => {
            updates += 1;
            return {};
          },
        },
      }),
  };
  const service = new AdminService(
    prisma as any,
    { disconnectUser: () => undefined } as any,
    { createNotificationInTransaction: async () => null } as any,
  );
  const currentUser = {
    id: "admin-1",
    role: UserRole.ADMIN,
    adminMfa: true,
  } as any;

  for (const review of [
    () => service.approveProvider(currentUser, "provider-1"),
    () => service.rejectProvider(currentUser, "provider-1", { reason: "no" }),
    () =>
      service.requestProviderChanges(currentUser, "provider-1", {
        note: "fix",
      }),
    () =>
      service.suspendProvider(currentUser, "provider-1", { reason: "risk" }),
    () => service.activateProvider(currentUser, "provider-1"),
  ]) {
    await assert.rejects(review, BadRequestException);
  }

  assert.equal(updates, 0);
  assert.equal(ProviderStatus.ACTIVE, "ACTIVE");
});

test("a different administrator can review a provider application", async () => {
  const now = new Date();
  let persistedStatus: ProviderStatus | null = null;
  const revocations: Array<{ userId: string; conversationIds: string[] }> = [];
  const outboxEvents: any[] = [];
  const prisma = {
    $transaction: async (operation: any) =>
      operation({
        $queryRaw: async (query: any) => {
          const text = query.strings?.join("") ?? String(query);
          if (text.includes('FROM "User"')) {
            return [
              {
                id: "provider-owner",
                role: UserRole.PROVIDER,
                adminRole: null,
                status: UserStatus.ACTIVE,
              },
              {
                id: "reviewer-admin",
                role: UserRole.ADMIN,
                adminRole: AdminRole.OPERATIONS,
                status: UserStatus.ACTIVE,
              },
            ].sort((left, right) => left.id.localeCompare(right.id));
          }
          if (text.includes('FROM "Provider"')) {
            return [{ id: "provider-1" }];
          }
          throw new Error(`Unexpected provider-review lock: ${text}`);
        },
        provider: {
          findUnique: async () => ({
            userId: "provider-owner",
            status: ProviderStatus.PENDING,
          }),
          update: async ({ data }: any) => {
            persistedStatus = data.status;
            return {
              id: "provider-1",
              userId: "provider-owner",
              user: null,
              cityId: null,
              city: null,
              primaryCategoryId: null,
              primaryCategory: null,
              businessName: "Independent Provider",
              ownerName: null,
              phone: "+967777123456",
              whatsapp: null,
              email: null,
              description: null,
              address: null,
              logoUrl: null,
              coverUrl: null,
              status: data.status,
              reviewNote: data.reviewNote,
              reviewedAt: data.reviewedAt,
              reviewedBy: null,
              isFeatured: false,
              ratingAverage: 0,
              ratingCount: 0,
              _count: {
                services: 0,
                packages: 0,
                quoteRequests: 0,
                reviews: 0,
              },
              services: [],
              packages: [],
              createdAt: now,
              updatedAt: now,
            };
          },
        },
        conversation: {
          findMany: async () => [
            { id: "conversation-1" },
            { id: "conversation-2" },
          ],
        },
        outboxEvent: {
          create: async ({ data }: any) => {
            outboxEvents.push(data);
            return data;
          },
        },
      }),
  };
  const service = new AdminService(
    prisma as any,
    {
      disconnectUser: () => undefined,
      revokeConversationAccess: (userId: string, conversationIds: string[]) => {
        revocations.push({ userId, conversationIds });
      },
    } as any,
    { createNotificationInTransaction: async () => null } as any,
  );

  const response = await service.rejectProvider(
    { id: "reviewer-admin", role: UserRole.ADMIN, adminMfa: true } as any,
    "provider-1",
    { reason: "Incomplete evidence" },
  );

  assert.equal(persistedStatus, ProviderStatus.REJECTED);
  assert.equal(response.status, ProviderStatus.REJECTED);
  assert.deepEqual(revocations, [
    {
      userId: "provider-owner",
      conversationIds: ["conversation-1", "conversation-2"],
    },
  ]);
  assert.deepEqual(outboxEvents, [
    {
      type: "CONVERSATION_ACCESS_REVOKED",
      aggregateType: "user",
      aggregateId: "provider-owner",
      payload: {
        userId: "provider-owner",
        conversationIds: ["conversation-1", "conversation-2"],
      },
    },
  ]);
});
