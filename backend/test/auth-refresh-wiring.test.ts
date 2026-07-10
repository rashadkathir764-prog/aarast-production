import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import {
  createRefreshTokenValue,
  hashRefreshToken,
  refreshTokenExpiry,
} from "../src/auth/refresh-token-policy";
import { AuthService } from "../src/auth/auth.service";

test("refresh token policy creates opaque hashed expiring tokens", () => {
  const token = createRefreshTokenValue();
  assert.match(token, /^[a-f0-9]{64}$/);
  assert.equal(hashRefreshToken(token).length, 64);
  assert.notEqual(hashRefreshToken(token), token);

  const now = new Date("2026-07-06T00:00:00.000Z");
  assert.equal(
    refreshTokenExpiry(now).toISOString(),
    "2026-08-05T00:00:00.000Z",
  );
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
  assert.match(controller, /@Post\('refresh'\)/);
  assert.match(controller, /@Post\('logout'\)/);
  assert.match(controller, /@Post\('logout-all'\)/);
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
  const revokedToken = {
    id: "refresh-old",
    userId: "user-1",
    tokenHash: hashRefreshToken("stolen-old-token"),
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
  );

  await assert.rejects(() =>
    service.refresh({ refreshToken: "stolen-old-token" }),
  );
  assert.equal(revocations.length, 1);
  assert.equal(revocations[0].where.userId, "user-1");
  assert.equal(revocations[0].where.revokedAt, null);
});
