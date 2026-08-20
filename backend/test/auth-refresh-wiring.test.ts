import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { AuthSessionScope } from "@prisma/client";
import { readLivePrismaSchema } from './support/live-prisma-schema';
import {
  createOpaqueTokenValue,
  createRefreshTokenValue,
  hashRefreshToken,
  isRefreshTokenForScope,
  refreshTokenExpiry,
} from "../src/modules/identity/internal/auth/refresh-token-policy";
import { AuthService } from "../src/modules/identity/internal/auth/auth.service";

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
    { consume: async () => undefined } as any,
    {
      disconnectUser: () => undefined,
      disconnectSession: () => undefined,
    } as any,
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
    { consume: async () => undefined } as any,
    {
      disconnectUser: () => undefined,
      disconnectSession: () => undefined,
    } as any,
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
  const disconnectedSessions: string[] = [];
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
    scope: AuthSessionScope.ADMIN,
    revokedAt: null,
    replacedById: null,
    expiresAt: new Date(now.getTime() + 60_000),
    user: admin,
  };
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = query?.strings?.join(" ") ?? "";
      if (sql.includes('FROM "User"')) {
        return [{ id: admin.id, status: "ACTIVE" }];
      }
      if (sql.includes('WITH RECURSIVE "RefreshFamily"')) {
        return [{ ...existing, depth: 1 }];
      }
      return [];
    },
    outboxEvent: { create: async () => ({}) },
    refreshToken: {
      findUnique: async ({ where }: any) =>
        where.tokenHash === existing.tokenHash || where.id === existing.id
          ? existing
          : null,
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
    { consume: async () => undefined } as any,
    {
      disconnectUser: () => undefined,
      disconnectSession: (sessionId: string) =>
        disconnectedSessions.push(sessionId),
    } as any,
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
  assert.equal(signedPayloads[0].scope, "admin");
  assert.deepEqual(disconnectedSessions, []);
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
    { consume: async () => undefined } as any,
    {
      disconnectUser: () => undefined,
      disconnectSession: () => undefined,
    } as any,
  );

  await assert.rejects(
    () => service.refreshAdmin(forgedAdminToken),
    /Session is invalid or expired/,
  );
  assert.notEqual(lookedUpHash, storedHash);
});

test("refresh token schema and authenticated lifecycle stay wired", () => {
  const schema = readLivePrismaSchema();
  const controller = readFileSync(
    join(process.cwd(), "src/modules/identity/api/auth.controller.ts"),
    "utf8",
  );
  const service = readFileSync(
    join(process.cwd(), "src/modules/identity/internal/auth/auth.service.ts"),
    "utf8",
  );
  const identityAuthInternalModule = readFileSync(
    join(
      process.cwd(),
      "src/modules/identity/internal/identity-auth.internal.module.ts",
    ),
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
  assert.match(identityAuthInternalModule, /JWT_ACCESS_EXPIRES_IN/);
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
  assert.match(disableBlock, /runSerializableTransaction\(this\.prisma/);
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
  assert.match(createBlock, /runSerializableTransaction/);
  assert.match(createBlock, /weddingPlan\.create/);
  assert.match(createBlock, /user\.update/);
  assert.match(createBlock, /activeWeddingPlanId:\s*created\.id/);
});

test("reusing a rotated refresh token outside grace revokes its descendant", async () => {
  const now = new Date();
  const stolenOldToken = createRefreshTokenValue("application");
  const revokedToken = {
    id: "refresh-old",
    userId: "user-1",
    tokenHash: hashRefreshToken(stolenOldToken),
    revokedAt: new Date(now.getTime() - 10_000),
    expiresAt: new Date(now.getTime() + 60_000),
    replacedById: "refresh-new",
    scope: AuthSessionScope.APPLICATION,
    user: {
      id: "user-1",
      status: "ACTIVE",
      phoneVerifiedAt: now,
    },
  };
  const descendant = {
    ...revokedToken,
    id: "refresh-new",
    tokenHash: hashRefreshToken(createRefreshTokenValue("application")),
    revokedAt: null,
    replacedById: null,
  };
  const revocations: any[] = [];
  const disconnectedSessions: string[] = [];
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = query?.strings?.join(" ") ?? "";
      if (sql.includes('FROM "User"')) {
        return [{ id: "user-1", status: "ACTIVE" }];
      }
      if (sql.includes('WITH RECURSIVE "RefreshFamily"')) {
        return [
          { ...revokedToken, depth: 1 },
          { ...descendant, depth: 2 },
        ];
      }
      return [];
    },
    outboxEvent: { create: async () => ({}) },
    refreshToken: {
      findUnique: async ({ where }: any) => {
        if (where.tokenHash === revokedToken.tokenHash) return revokedToken;
        if (where.id === revokedToken.id) return revokedToken;
        if (where.id === descendant.id) return descendant;
        return null;
      },
      updateMany: async (args: any) => {
        revocations.push(args);
        if (args.where.id === descendant.id) {
          descendant.revokedAt = args.data.revokedAt;
        }
        return { count: 1 };
      },
    },
  };
  const service = new AuthService(
    { $transaction: async (fn: any) => fn(tx) } as any,
    {} as any,
    {} as any,
    { consume: async () => undefined } as any,
    {
      disconnectUser: () => undefined,
      disconnectSession: (sessionId: string) =>
        disconnectedSessions.push(sessionId),
    } as any,
  );

  await assert.rejects(() =>
    service.refresh({ refreshToken: stolenOldToken }),
  );
  assert.equal(revocations.length, 1);
  assert.equal(revocations[0].where.id, "refresh-new");
  assert.equal(revocations[0].where.revokedAt, null);
  assert.deepEqual(disconnectedSessions, ["refresh-new"]);
});

test("reusing an admin refresh token does not disconnect application sockets", async () => {
  const now = new Date();
  const stolenOldToken = createRefreshTokenValue("admin");
  const revokedToken = {
    id: "admin-refresh-old",
    userId: "admin-1",
    tokenHash: hashRefreshToken(stolenOldToken),
    revokedAt: new Date(now.getTime() - 1000),
    expiresAt: new Date(now.getTime() + 60_000),
    replacedById: "admin-refresh-new",
    scope: AuthSessionScope.ADMIN,
    user: {
      id: "admin-1",
      role: "ADMIN",
      status: "ACTIVE",
      phoneVerifiedAt: now,
    },
  };
  const descendant = {
    ...revokedToken,
    id: "admin-refresh-new",
    tokenHash: hashRefreshToken(createRefreshTokenValue("admin")),
    revokedAt: null,
    replacedById: null,
  };
  let outboxEvents = 0;
  const disconnectedUsers: string[] = [];
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = query?.strings?.join(" ") ?? "";
      if (sql.includes('FROM "User"')) {
        return [{ id: "admin-1", status: "ACTIVE" }];
      }
      if (sql.includes('WITH RECURSIVE "RefreshFamily"')) {
        return [
          { ...revokedToken, depth: 1 },
          { ...descendant, depth: 2 },
        ];
      }
      return [];
    },
    outboxEvent: {
      create: async () => {
        outboxEvents += 1;
        return {};
      },
    },
    refreshToken: {
      findUnique: async () => revokedToken,
      updateMany: async () => ({ count: 1 }),
    },
  };
  const service = new AuthService(
    { $transaction: async (fn: any) => fn(tx) } as any,
    {} as any,
    {} as any,
    { consume: async () => undefined } as any,
    {
      disconnectUser: (userId: string) => disconnectedUsers.push(userId),
      disconnectSession: () => undefined,
    } as any,
  );

  await assert.rejects(() => service.refreshAdmin(stolenOldToken));
  assert.equal(outboxEvents, 0);
  assert.deepEqual(disconnectedUsers, []);
});

test("logging out one application session disconnects only that realtime session", async () => {
  const refreshToken = createRefreshTokenValue("application");
  const disconnectedSessions: string[] = [];
  const service = new AuthService(
    {
      $transaction: async (operation: (tx: any) => Promise<unknown>) =>
        operation({
          $queryRaw: async (query: any) => {
            const sql = query?.strings?.join(" ") ?? "";
            if (sql.includes('FROM "User"')) {
              return [{ id: "user-1", status: "ACTIVE" }];
            }
            if (sql.includes('WITH RECURSIVE "RefreshFamily"')) {
              return [
                {
                  id: "application-session-1",
                  userId: "user-1",
                  scope: AuthSessionScope.APPLICATION,
                  expiresAt: new Date(Date.now() + 60_000),
                  revokedAt: null,
                  replacedById: null,
                  depth: 1,
                },
              ];
            }
            return [];
          },
          refreshToken: {
            findUnique: async () => ({
              id: "application-session-1",
              userId: "user-1",
              scope: AuthSessionScope.APPLICATION,
              expiresAt: new Date(Date.now() + 60_000),
              revokedAt: null,
              replacedById: null,
            }),
            updateMany: async () => ({ count: 1 }),
          },
          outboxEvent: { create: async () => ({}) },
        }),
      refreshToken: {
        findFirst: async () => ({ id: "application-session-1" }),
        updateMany: async () => ({ count: 1 }),
      },
    } as any,
    {} as any,
    {} as any,
    { consume: async () => undefined } as any,
    {
      disconnectUser: () => undefined,
      disconnectSession: (sessionId: string) =>
        disconnectedSessions.push(sessionId),
    } as any,
  );

  const result = await service.logout("user-1", { refreshToken });

  assert.deepEqual(result, { revoked: 1 });
  assert.deepEqual(disconnectedSessions, ["application-session-1"]);
});

type RefreshFamilyRow = {
  id: string;
  userId: string;
  tokenHash: string;
  scope: AuthSessionScope;
  expiresAt: Date;
  revokedAt: Date | null;
  replacedById: string | null;
  createdAt: Date;
};

function createRefreshFamilyHarness(rows: RefreshFamilyRow[]) {
  const now = new Date();
  const user = {
    id: "user-1",
    name: "User",
    phone: "+967777123456",
    email: null,
    role: "USER",
    adminRole: null,
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
  const outboxEvents: any[] = [];
  const disconnectedUsers: string[] = [];
  const disconnectedSessions: string[] = [];
  let refreshTokenLockQueries = 0;

  const project = (row: RefreshFamilyRow | null, args: any) => {
    if (!row) return null;
    const value: any = { ...row };
    if (args?.include?.user) value.user = user;
    if (!args?.select) return value;
    return Object.fromEntries(
      Object.entries(args.select)
        .filter(([, selected]) => selected)
        .map(([key]) => [key, value[key]]),
    );
  };
  const matches = (row: RefreshFamilyRow, where: any) => {
    if (where.id !== undefined) {
      if (typeof where.id === "string" && row.id !== where.id) return false;
      if (where.id?.in && !where.id.in.includes(row.id)) return false;
    }
    if (where.userId !== undefined && row.userId !== where.userId) return false;
    if (where.tokenHash !== undefined && row.tokenHash !== where.tokenHash) {
      return false;
    }
    if (where.scope !== undefined && row.scope !== where.scope) return false;
    if (where.revokedAt === null && row.revokedAt !== null) return false;
    if (where.expiresAt?.gt && row.expiresAt <= where.expiresAt.gt) return false;
    return true;
  };

  const refreshToken = {
    findUnique: async (args: any) => {
      const row =
        rows.find((candidate) =>
          args.where.tokenHash !== undefined
            ? candidate.tokenHash === args.where.tokenHash
            : candidate.id === args.where.id,
        ) ?? null;
      return project(row, args);
    },
    findFirst: async (args: any) =>
      project(rows.find((row) => matches(row, args.where)) ?? null, args),
    create: async ({ data }: any) => {
      const row: RefreshFamilyRow = {
        id: `session-created-${rows.length + 1}`,
        replacedById: null,
        revokedAt: null,
        createdAt: new Date(),
        ...data,
      };
      rows.push(row);
      return { ...row };
    },
    updateMany: async ({ where, data }: any) => {
      let count = 0;
      for (const row of rows) {
        if (!matches(row, where)) continue;
        Object.assign(row, data);
        count += 1;
      }
      return { count };
    },
    update: async ({ where, data }: any) => {
      const row = rows.find((candidate) => candidate.id === where.id);
      assert.ok(row);
      Object.assign(row, data);
      return { ...row };
    },
  };
  const tx: any = {
    refreshToken,
    outboxEvent: {
      create: async ({ data }: any) => {
        outboxEvents.push(data);
        return data;
      },
    },
    $queryRaw: async (query: any) => {
      const sql = query?.strings?.join(" ") ?? "";
      if (sql.includes('FROM "User"')) {
        return [{ id: user.id, status: user.status }];
      }
      if (sql.includes('FROM "RefreshToken"')) {
        refreshTokenLockQueries += 1;
        if (sql.includes('WITH RECURSIVE "RefreshFamily"')) {
          const startId = query.values?.find(
            (value: unknown) =>
              typeof value === "string" &&
              rows.some((candidate) => candidate.id === value),
          );
          const maxDepth =
            query.values?.find((value: unknown) => typeof value === "number") ??
            4_096;
          const traversed: Array<RefreshFamilyRow & { depth: number }> = [];
          let currentId = startId;
          for (let depth = 1; currentId && depth <= maxDepth + 1; depth += 1) {
            const row = rows.find((candidate) => candidate.id === currentId);
            if (!row) break;
            traversed.push({ ...row, depth });
            currentId = row.replacedById ?? undefined;
          }
          return traversed;
        }
        const id = query.values?.find(
          (value: unknown) =>
            typeof value === "string" &&
            rows.some((candidate) => candidate.id === value),
        );
        const row = rows.find((candidate) => candidate.id === id);
        return row ? [{ ...row }] : [];
      }
      return [];
    },
  };
  const prisma: any = {
    ...tx,
    $transaction: async (operation: (client: any) => Promise<unknown>) =>
      operation(tx),
  };
  const service = new AuthService(
    prisma,
    { sign: () => "access-token" } as any,
    {} as any,
    { consume: async () => undefined } as any,
    {
      disconnectUser: (userId: string) => disconnectedUsers.push(userId),
      disconnectSession: (sessionId: string) =>
        disconnectedSessions.push(sessionId),
    } as any,
  );
  return {
    service,
    rows,
    outboxEvents,
    disconnectedUsers,
    disconnectedSessions,
    get refreshTokenLockQueries() {
      return refreshTokenLockQueries;
    },
  };
}

function refreshFamilyRow(input: {
  id: string;
  token: string;
  scope?: AuthSessionScope;
  revokedAt?: Date | null;
  replacedById?: string | null;
}): RefreshFamilyRow {
  return {
    id: input.id,
    userId: "user-1",
    tokenHash: hashRefreshToken(input.token),
    scope: input.scope ?? AuthSessionScope.APPLICATION,
    expiresAt: new Date(Date.now() + 60_000),
    revokedAt: input.revokedAt ?? null,
    replacedById: input.replacedById ?? null,
    createdAt: new Date(),
  };
}

test("application logout follows a refresh-won replacement chain", async () => {
  const oldToken = createRefreshTokenValue("application");
  const rows = [
    refreshFamilyRow({
      id: "app-old",
      token: oldToken,
      revokedAt: new Date(),
      replacedById: "app-current",
    }),
    refreshFamilyRow({
      id: "app-current",
      token: createRefreshTokenValue("application"),
    }),
  ];
  const harness = createRefreshFamilyHarness(rows);

  const result = await harness.service.logout("user-1", {
    refreshToken: oldToken,
  });

  assert.deepEqual(result, { revoked: 1 });
  assert.ok(rows[1].revokedAt);
  assert.deepEqual(harness.disconnectedSessions, ["app-current"]);
});

test("admin logout follows a refresh-won replacement chain", async () => {
  const oldToken = createRefreshTokenValue("admin");
  const rows = [
    refreshFamilyRow({
      id: "admin-old",
      token: oldToken,
      scope: AuthSessionScope.ADMIN,
      revokedAt: new Date(),
      replacedById: "admin-current",
    }),
    refreshFamilyRow({
      id: "admin-current",
      token: createRefreshTokenValue("admin"),
      scope: AuthSessionScope.ADMIN,
    }),
  ];
  const harness = createRefreshFamilyHarness(rows);

  const result = await harness.service.logoutAdminRefreshToken(oldToken);

  assert.deepEqual(result, { revoked: 1 });
  assert.ok(rows[1].revokedAt);
  assert.deepEqual(harness.disconnectedSessions, []);
});

test("reusing a rotated application refresh token immediately revokes the winner", async () => {
  const oldToken = createRefreshTokenValue("application");
  const rows = [
    refreshFamilyRow({
      id: "grace-old",
      token: oldToken,
      revokedAt: new Date(Date.now() - 1_000),
      replacedById: "grace-winner",
    }),
    refreshFamilyRow({
      id: "grace-winner",
      token: createRefreshTokenValue("application"),
    }),
  ];
  const harness = createRefreshFamilyHarness(rows);

  await assert.rejects(
    () => harness.service.refresh({ refreshToken: oldToken }),
    /Session is invalid or expired/,
  );

  assert.ok(rows[1].revokedAt);
  assert.deepEqual(harness.disconnectedUsers, []);
  assert.deepEqual(harness.disconnectedSessions, ["grace-winner"]);
});

test("reusing a rotated admin refresh token immediately revokes the winner", async () => {
  const oldToken = createRefreshTokenValue("admin");
  const rows = [
    refreshFamilyRow({
      id: "admin-replay-old",
      token: oldToken,
      scope: AuthSessionScope.ADMIN,
      revokedAt: new Date(Date.now() - 1_000),
      replacedById: "admin-replay-winner",
    }),
    refreshFamilyRow({
      id: "admin-replay-winner",
      token: createRefreshTokenValue("admin"),
      scope: AuthSessionScope.ADMIN,
    }),
  ];
  const harness = createRefreshFamilyHarness(rows);

  await assert.rejects(
    () => harness.service.refreshAdmin(oldToken),
    /Session is invalid or expired/,
  );

  assert.ok(rows[1].revokedAt);
  assert.deepEqual(harness.disconnectedUsers, []);
  assert.deepEqual(harness.disconnectedSessions, []);
});

test("refresh family traversal uses one bounded database query regardless of chain length", async () => {
  const oldToken = createRefreshTokenValue("application");
  const rows = Array.from({ length: 128 }, (_, index) =>
    refreshFamilyRow({
      id: `bounded-family-${index}`,
      token:
        index === 0
          ? oldToken
          : createRefreshTokenValue("application"),
      revokedAt: index === 127 ? null : new Date(),
      replacedById:
        index === 127 ? null : `bounded-family-${index + 1}`,
    }),
  );
  const harness = createRefreshFamilyHarness(rows);

  await assert.rejects(
    () => harness.service.refresh({ refreshToken: oldToken }),
    /Session is invalid or expired/,
  );

  assert.ok(rows[127].revokedAt);
  assert.equal(harness.refreshTokenLockQueries, 1);
});

test("application refresh family overflow fails closed for the whole application realm", async () => {
  const oldToken = createRefreshTokenValue("application");
  const rows = [
    refreshFamilyRow({
      id: "app-overflow-old",
      token: oldToken,
      revokedAt: new Date(),
      replacedById: "app-overflow-middle",
    }),
    refreshFamilyRow({
      id: "app-overflow-middle",
      token: createRefreshTokenValue("application"),
      revokedAt: new Date(),
      replacedById: "app-overflow-current",
    }),
    refreshFamilyRow({
      id: "app-overflow-current",
      token: createRefreshTokenValue("application"),
    }),
    refreshFamilyRow({
      id: "app-independent",
      token: createRefreshTokenValue("application"),
    }),
    refreshFamilyRow({
      id: "admin-independent",
      token: createRefreshTokenValue("admin"),
      scope: AuthSessionScope.ADMIN,
    }),
  ];
  const harness = createRefreshFamilyHarness(rows);
  const originalLimit = (AuthService as any).maxRefreshFamilyDepth;
  (AuthService as any).maxRefreshFamilyDepth = 2;

  try {
    await assert.rejects(
      () => harness.service.refresh({ refreshToken: oldToken }),
      /Session is invalid or expired/,
    );
  } finally {
    (AuthService as any).maxRefreshFamilyDepth = originalLimit;
  }

  assert.ok(rows[2].revokedAt);
  assert.ok(rows[3].revokedAt);
  assert.equal(rows[4].revokedAt, null);
  assert.deepEqual(harness.disconnectedUsers, ["user-1"]);
  assert.deepEqual(harness.disconnectedSessions, []);
  assert.equal(harness.outboxEvents.length, 1);
});

test("admin refresh family overflow fails closed only for the admin realm", async () => {
  const oldToken = createRefreshTokenValue("admin");
  const rows = [
    refreshFamilyRow({
      id: "admin-overflow-old",
      token: oldToken,
      scope: AuthSessionScope.ADMIN,
      revokedAt: new Date(),
      replacedById: "admin-overflow-middle",
    }),
    refreshFamilyRow({
      id: "admin-overflow-middle",
      token: createRefreshTokenValue("admin"),
      scope: AuthSessionScope.ADMIN,
      revokedAt: new Date(),
      replacedById: "admin-overflow-current",
    }),
    refreshFamilyRow({
      id: "admin-overflow-current",
      token: createRefreshTokenValue("admin"),
      scope: AuthSessionScope.ADMIN,
    }),
    refreshFamilyRow({
      id: "admin-independent",
      token: createRefreshTokenValue("admin"),
      scope: AuthSessionScope.ADMIN,
    }),
    refreshFamilyRow({
      id: "app-independent",
      token: createRefreshTokenValue("application"),
    }),
  ];
  const harness = createRefreshFamilyHarness(rows);
  const originalLimit = (AuthService as any).maxRefreshFamilyDepth;
  (AuthService as any).maxRefreshFamilyDepth = 2;

  try {
    await assert.rejects(
      () => harness.service.refreshAdmin(oldToken),
      /Session is invalid or expired/,
    );
  } finally {
    (AuthService as any).maxRefreshFamilyDepth = originalLimit;
  }

  assert.ok(rows[2].revokedAt);
  assert.ok(rows[3].revokedAt);
  assert.equal(rows[4].revokedAt, null);
  assert.deepEqual(harness.disconnectedUsers, []);
  assert.deepEqual(harness.disconnectedSessions, []);
  assert.equal(harness.outboxEvents.length, 0);
});

test("repeated old-token replay revokes only its descendants, never a new login family", async () => {
  const oldToken = createRefreshTokenValue("application");
  const rows = [
    refreshFamilyRow({
      id: "replay-old",
      token: oldToken,
      revokedAt: new Date(Date.now() - 10_000),
      replacedById: "replay-descendant",
    }),
    refreshFamilyRow({
      id: "replay-descendant",
      token: createRefreshTokenValue("application"),
    }),
  ];
  const harness = createRefreshFamilyHarness(rows);

  await assert.rejects(() =>
    harness.service.refresh({ refreshToken: oldToken }),
  );
  assert.ok(rows[1].revokedAt);

  const independent = refreshFamilyRow({
    id: "independent-login",
    token: createRefreshTokenValue("application"),
  });
  rows.push(independent);
  await assert.rejects(() =>
    harness.service.refresh({ refreshToken: oldToken }),
  );

  assert.equal(independent.revokedAt, null);
  assert.deepEqual(harness.disconnectedUsers, []);
});
