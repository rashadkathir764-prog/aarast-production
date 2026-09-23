import "reflect-metadata";

import assert from "node:assert/strict";
import test from "node:test";
import { BadRequestException, ForbiddenException } from "@nestjs/common";
import {
  AdminRole,
  Prisma,
  UserRole,
  UserStatus,
} from "@prisma/client";
import { adminService } from "./support/owner-ports";

const currentUser = {
  id: "admin-actor",
  role: UserRole.ADMIN,
  adminRole: AdminRole.SUPER_ADMIN,
  status: UserStatus.ACTIVE,
} as any;

function sqlText(query: any): string {
  return query.strings?.join("") ?? String(query);
}

test("catalog mutation locks and reauthorizes the live actor before its target", async () => {
  const calls: string[] = [];
  const now = new Date("2026-07-26T00:00:00.000Z");
  const tx = {
    $queryRaw: async (query: any) => {
      const text = sqlText(query);
      if (text.includes('FROM "User"')) {
        calls.push("actor-lock");
        return [
          {
            id: currentUser.id,
            role: UserRole.ADMIN,
            adminRole: AdminRole.OPERATIONS,
            status: UserStatus.ACTIVE,
          },
        ];
      }
      if (text.includes('FROM "ProviderCategory"')) {
        calls.push("target-lock");
        return [{ id: "category-1" }];
      }
      throw new Error(`Unexpected query: ${text}`);
    },
    providerCategory: {
      findUnique: async () => {
        calls.push("target-read");
        return {
          showForGroom: true,
          showForBride: true,
          isActive: true,
        };
      },
      update: async () => {
        calls.push("target-write");
        return {
          id: "category-1",
          nameAr: "تصنيف",
          nameEn: null,
          slug: "category",
          icon: null,
          showForGroom: true,
          showForBride: true,
          isActive: true,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
          _count: { providers: 0, services: 0 },
        };
      },
    },
    // The category's provider and service counts are marketplace's now.
    provider: { groupBy: async () => [] },
    providerService: { groupBy: async () => [] },
  };
  let isolationLevel: Prisma.TransactionIsolationLevel | undefined;
  const prisma = {
    $transaction: async (operation: any, options: any) => {
      isolationLevel = options?.isolationLevel;
      return operation(tx);
    },
  };
  const service = adminService(prisma as any, {} as any, {
    createNotificationInTransaction: async () => null,
  } as any);

  const result = await service.updateCategory(currentUser, "category-1", {
    nameAr: "تصنيف",
  });

  assert.equal(isolationLevel, Prisma.TransactionIsolationLevel.Serializable);
  assert.deepEqual(calls, [
    "actor-lock",
    "target-lock",
    "target-read",
    "target-write",
  ]);
  assert.equal(result.id, "category-1");
});

test("active catalog categories require at least one wedding persona", async () => {
  let createWrites = 0;
  const createTx = {
    $queryRaw: async (query: any) => {
      const text = sqlText(query);
      if (text.includes('FROM "User"')) {
        return [
          {
            id: currentUser.id,
            role: UserRole.ADMIN,
            adminRole: AdminRole.OPERATIONS,
            status: UserStatus.ACTIVE,
          },
        ];
      }
      throw new Error(`Unexpected query: ${text}`);
    },
    providerCategory: {
      create: async () => {
        createWrites += 1;
        return {};
      },
    },
  };
  const createService = adminService(
    {
      $transaction: async (operation: any) => operation(createTx),
    } as any,
    {} as any,
    {
      createNotificationInTransaction: async () => null,
    } as any,
  );

  await assert.rejects(
    () =>
      createService.createCategory(currentUser, {
        nameAr: "Hidden active category",
        showForGroom: false,
        showForBride: false,
      }),
    BadRequestException,
  );
  assert.equal(createWrites, 0);

  let writes = 0;
  const tx = {
    $queryRaw: async (query: any) => {
      const text = sqlText(query);
      if (text.includes('FROM "User"')) {
        return [
          {
            id: currentUser.id,
            role: UserRole.ADMIN,
            adminRole: AdminRole.OPERATIONS,
            status: UserStatus.ACTIVE,
          },
        ];
      }
      if (text.includes('FROM "ProviderCategory"')) {
        return [{ id: "category-1" }];
      }
      throw new Error(`Unexpected query: ${text}`);
    },
    providerCategory: {
      findUnique: async () => ({
        showForGroom: true,
        showForBride: false,
        isActive: true,
      }),
      update: async () => {
        writes += 1;
        return {};
      },
    },
  };
  const updateService = adminService(
    {
      $transaction: async (operation: any) => operation(tx),
    } as any,
    {} as any,
    {
      createNotificationInTransaction: async () => null,
    } as any,
  );

  await assert.rejects(
    () =>
      updateService.updateCategory(currentUser, "category-1", {
        nameAr: "Still active",
        showForGroom: false,
        showForBride: false,
      }),
    BadRequestException,
  );
  assert.equal(writes, 0);
});

test("catalog mutation rejects a disabled or underprivileged live actor before writing", async () => {
  for (const actor of [
    {
      id: currentUser.id,
      role: UserRole.ADMIN,
      adminRole: AdminRole.OPERATIONS,
      status: UserStatus.DISABLED,
    },
    {
      id: currentUser.id,
      role: UserRole.ADMIN,
      adminRole: AdminRole.SUPPORT,
      status: UserStatus.ACTIVE,
    },
  ]) {
    let writes = 0;
    const tx = {
      $queryRaw: async () => [actor],
      providerCategory: {
        create: async () => {
          writes += 1;
          return {};
        },
      },
    };
    const prisma = {
      $transaction: async (operation: any) => operation(tx),
    };
    const service = adminService(prisma as any, {} as any, {
      createNotificationInTransaction: async () => null,
    } as any);

    await assert.rejects(
      () =>
        service.createCategory(currentUser, {
          nameAr: "يجب ألا ينشأ",
        }),
      ForbiddenException,
    );
    assert.equal(writes, 0);
  }
});

test("disabling a user persists session revocation in the same transaction", async () => {
  const calls: string[] = [];
  const outboxEvents: any[] = [];
  const disconnectedUsers: string[] = [];
  const now = new Date("2026-07-26T00:00:00.000Z");
  const targetId = "target-user";
  let revokedInviteWhere: any;
  let revokedInviteData: any;
  const tx = {
    $queryRaw: async (query: any) => {
      const lockedId = query.values?.[0];
      calls.push(`lock:${lockedId}`);
      if (lockedId === currentUser.id) {
        return [
          {
            id: currentUser.id,
            role: UserRole.ADMIN,
            adminRole: AdminRole.OPERATIONS,
            status: UserStatus.ACTIVE,
          },
        ];
      }
      if (lockedId === targetId) {
        return [
          {
            id: targetId,
            role: UserRole.USER,
            adminRole: null,
            status: UserStatus.ACTIVE,
          },
        ];
      }
      return [];
    },
    user: {
      update: async () => {
        calls.push("user-update");
        return {
          id: targetId,
          name: "Target",
          phone: null,
          email: null,
          role: UserRole.USER,
          status: UserStatus.DISABLED,
          avatarUrl: null,
          createdAt: now,
          updatedAt: now,
          providerProfile: null,
        };
      },
      count: async () => 2,
    },
    refreshToken: {
      updateMany: async () => {
        calls.push("refresh-revoke");
        return { count: 1 };
      },
    },
    planInvite: {
      updateMany: async ({ where, data }: any) => {
        calls.push("invite-revoke");
        revokedInviteWhere = where;
        revokedInviteData = data;
        return { count: 2 };
      },
    },
    outboxEvent: {
      create: async ({ data }: any) => {
        calls.push("outbox-create");
        outboxEvents.push(data);
        return data;
      },
    },
  };
  const prisma = {
    $transaction: async (operation: any, options: any) => {
      assert.equal(
        options?.isolationLevel,
        Prisma.TransactionIsolationLevel.Serializable,
      );
      return operation(tx);
    },
  };
  const service = adminService(prisma as any, {
    disconnectUser: (userId: string) => disconnectedUsers.push(userId),
  } as any, {
    createNotificationInTransaction: async () => null,
  } as any);

  const response = await service.disableUser(currentUser, targetId);

  assert.deepEqual(calls, [
    `lock:${currentUser.id}`,
    `lock:${targetId}`,
    "user-update",
    "invite-revoke",
    "refresh-revoke",
    "outbox-create",
  ]);
  assert.equal(response.status, UserStatus.DISABLED);
  assert.equal(revokedInviteWhere.inviterUserId, targetId);
  assert.equal(revokedInviteWhere.acceptedAt, null);
  assert.equal(revokedInviteWhere.declinedAt, null);
  assert.equal(revokedInviteWhere.revokedAt, null);
  assert.ok(revokedInviteWhere.expiresAt.gt instanceof Date);
  assert.equal(revokedInviteData.revokedAt, revokedInviteWhere.expiresAt.gt);
  assert.deepEqual(outboxEvents, [
    {
      type: "USER_SESSIONS_REVOKED",
      aggregateType: "user",
      aggregateId: targetId,
      payload: { userId: targetId },
    },
  ]);
  assert.deepEqual(disconnectedUsers, [targetId]);
});
