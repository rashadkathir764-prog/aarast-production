import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import {
  createOpaqueTokenValue,
  createRefreshTokenValue,
  hashRefreshToken,
  isRefreshTokenForScope,
  refreshTokenExpiry,
} from "../src/auth/refresh-token-policy";
import { AuthService } from "../src/auth/auth.service";

test("refresh token policy creates opaque hashed expiring tokens", () => {
  const applicationToken = createRefreshTokenValue();
  const adminToken = createRefreshTokenValue("admin");
  const opaqueToken = createOpaqueTokenValue();
  assert.match(applicationToken, /^aarast_app_[a-f0-9]{64}$/);
  assert.match(adminToken, /^aarast_admin_[a-f0-9]{64}$/);
  assert.match(opaqueToken, /^[a-f0-9]{64}$/);
  assert.equal(hashRefreshToken(applicationToken).length, 64);
  assert.notEqual(hashRefreshToken(applicationToken), applicationToken);
  assert.equal(
    isRefreshTokenForScope(applicationToken, "application"),
    true,
  );
  assert.equal(isRefreshTokenForScope(applicationToken, "admin"), false);
  assert.equal(isRefreshTokenForScope(adminToken, "admin"), true);
  assert.equal(isRefreshTokenForScope(adminToken, "application"), false);

  const now = new Date("2026-07-06T00:00:00.000Z");
  assert.equal(
    refreshTokenExpiry(now).toISOString(),
    "2026-08-05T00:00:00.000Z",
  );
});

test("an application refresh token can never be upgraded into an admin session", async () => {
  let transactionCalls = 0;
  const service = new AuthService(
    {
      $transaction: async () => {
        transactionCalls += 1;
        throw new Error("database lookup must not run");
      },
    } as any,
    {} as any,
    {} as any,
  );

  await assert.rejects(
    () => service.refreshAdmin(createRefreshTokenValue("application")),
    /Session is invalid or expired/,
  );
  assert.equal(transactionCalls, 0);
});

test("an admin refresh token cannot cross into the application refresh flow", async () => {
  let transactionCalls = 0;
  const service = new AuthService(
    {
      $transaction: async () => {
        transactionCalls += 1;
        throw new Error("database lookup must not run");
      },
    } as any,
    {} as any,
    {} as any,
  );

  await assert.rejects(
    () =>
      service.refresh({
        refreshToken: createRefreshTokenValue("admin"),
      }),
    /Session is invalid or expired/,
  );
  assert.equal(transactionCalls, 0);
});

test("admin MFA refresh rotates only into another admin-scoped session", async () => {
  const now = new Date();
  const adminToken = createRefreshTokenValue("admin");
  const createdTokens: any[] = [];
  const signedPayloads: any[] = [];
  const admin = {
    id: "admin-1",
    name: "Aarast Admin",
    phone: "+967777123456",
    email: null,
    role: "ADMIN",
    adminRole: "SUPER_ADMIN",
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: now,
    lastLoginAt: now,
    avatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    createdAt: now,
    updatedAt: now,
  };
  const existing = {
    id: "refresh-admin-old",
    userId: admin.id,
    tokenHash: hashRefreshToken(adminToken),
    revokedAt: null,
    replacedById: null,
    expiresAt: new Date(now.getTime() + 60_000),
    user: admin,
  };
  const tx = {
    refreshToken: {
      findUnique: async ({ where }: any) =>
        where.tokenHash === existing.tokenHash ? existing : null,
      create: async ({ data }: any) => {
        createdTokens.push(data);
        return { id: "refresh-admin-next", ...data };
      },
      updateMany: async () => ({ count: 1 }),
      update: async () => ({}),
    },
  };
  const service = new AuthService(
    { $transaction: async (fn: any) => fn(tx) } as any,
    {
      sign: (payload: any) => {
        signedPayloads.push(payload);
        return "admin-access-token";
      },
    } as any,
    {} as any,
  );

  const response = await service.refreshAdmin(adminToken);

  assert.equal(isRefreshTokenForScope(response.refreshToken, "admin"), true);
  assert.equal(createdTokens.length, 1);
  assert.equal(
    createdTokens[0].tokenHash,
    hashRefreshToken(response.refreshToken),
  );
  assert.equal(signedPayloads[0].amr, "admin_mfa");
  assert.equal(signedPayloads[0].sid, "refresh-admin-next");
  assert.equal(response.user.adminRole, "SUPER_ADMIN");
  assert.ok(response.user.adminPermissions.length > 0);
});

test("changing an application token prefix cannot recover its database session", async () => {
  const applicationToken = createRefreshTokenValue("application");
  const forgedAdminToken = applicationToken.replace(
    /^aarast_app_/,
    "aarast_admin_",
  );
  const storedHash = hashRefreshToken(applicationToken);
  let lookedUpHash = "";
  const service = new AuthService(
    {
      $transaction: async (fn: any) =>
        fn({
          refreshToken: {
            findUnique: async ({ where }: any) => {
              lookedUpHash = where.tokenHash;
              return where.tokenHash === storedHash ? { id: "unexpected" } : null;
            },
          },
        }),
    } as any,
    {} as any,
    {} as any,
  );

  await assert.rejects(
    () => service.refreshAdmin(forgedAdminToken),
    /Session is invalid or expired/,
  );
  assert.notEqual(lookedUpHash, storedHash);
});

test("refresh token schema and authenticated lifecycle stay wired", () => {
  const schema = readFileSync(
    join(process.cwd(), "prisma/schema.prisma"),
    "utf8",
  );
  const controller = readFileSync(
    join(process.cwd(), "src/auth/auth.controller.ts"),
    "utf8",
  );
  const service = readFileSync(
    join(process.cwd(), "src/auth/auth.service.ts"),
    "utf8",
  );
  const authModule = readFileSync(
    join(process.cwd(), "src/auth/auth.module.ts"),
    "utf8",
  );

  assert.match(schema, /model RefreshToken /);
  assert.match(schema, /refreshTokens\s+RefreshToken\[\]/);
  assert.match(controller, /@Post\(["']refresh["']\)/);
  assert.match(controller, /@Post\(["']logout["']\)/);
  assert.match(controller, /@Post\(["']logout-all["']\)/);
  assert.match(service, /refreshToken\.create/);
  assert.match(service, /refreshToken\.update/);
  assert.match(service, /refreshToken\.updateMany/);
  assert.match(authModule, /JWT_ACCESS_EXPIRES_IN/);
});

test("disabling an account revokes all active refresh sessions", () => {
  const adminService = readFileSync(
    join(process.cwd(), "src/admin/admin.service.ts"),
    "utf8",
  );
  const disableBlock = adminService.match(
    /async disableUser[\s\S]*?private async reviewProvider/,
  )?.[0];
  assert.ok(disableBlock);
  assert.match(disableBlock, /\$transaction/);
  assert.match(disableBlock, /refreshToken\.updateMany/);
  assert.match(disableBlock, /revokedAt/);
});

test("creating a wedding plan makes it the account active plan", () => {
  const service = readFileSync(
    join(process.cwd(), "src/wedding-plans/wedding-plans.service.ts"),
    "utf8",
  );
  const createBlock = service.match(
    /async create\([\s\S]*?async findMine/,
  )?.[0];

  assert.ok(createBlock);
  assert.match(createBlock, /\$transaction/);
  assert.match(createBlock, /weddingPlan\.create/);
  assert.match(createBlock, /user\.update/);
  assert.match(createBlock, /activeWeddingPlanId:\s*created\.id/);
});

test("reusing a rotated refresh token revokes the account token family", async () => {
  const now = new Date();
  const stolenOldToken = createRefreshTokenValue("application");
  const revokedToken = {
    id: "refresh-old",
    userId: "user-1",
    tokenHash: hashRefreshToken(stolenOldToken),
    revokedAt: new Date(now.getTime() - 1000),
    expiresAt: new Date(now.getTime() + 60_000),
    replacedById: "refresh-new",
    user: {
      id: "user-1",
      status: "ACTIVE",
      phoneVerifiedAt: now,
    },
  };
  const revocations: any[] = [];
  const tx = {
    refreshToken: {
      findUnique: async () => revokedToken,
      updateMany: async (args: any) => {
        revocations.push(args);
        return { count: 1 };
      },
    },
  };
  const service = new AuthService(
    { $transaction: async (fn: any) => fn(tx) } as any,
    {} as any,
    {} as any,
  );

  await assert.rejects(() =>
    service.refresh({ refreshToken: stolenOldToken }),
  );
  assert.equal(revocations.length, 1);
  assert.equal(revocations[0].where.userId, "user-1");
  assert.equal(revocations[0].where.revokedAt, null);
});
