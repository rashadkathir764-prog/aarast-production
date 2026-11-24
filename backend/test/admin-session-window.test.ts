import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { AuthSessionScope } from "@prisma/client";
import {
  ADMIN_SESSION_LIFETIME_MS,
  createRefreshTokenValue,
  hashRefreshToken,
  refreshTokenExpiry,
} from "../src/modules/identity/internal/auth/refresh-token-policy";
import { authService } from "./support/owner-ports";

// RA-AD-26: an admin session is a fixed twelve hours from the sign-in that
// opened it. Refreshing rotates the token and never moves the end, so a tab
// left open does not keep an admin signed in for ever (it was 30 days,
// renewed by every refresh). The application session is unchanged.

test("an admin session lasts twelve hours; an application one thirty days", () => {
  const now = new Date("2026-11-24T08:00:00.000Z");
  assert.equal(ADMIN_SESSION_LIFETIME_MS, 12 * 60 * 60 * 1000);
  assert.equal(
    refreshTokenExpiry(now, "admin").toISOString(),
    "2026-11-24T20:00:00.000Z",
  );
  assert.equal(
    refreshTokenExpiry(now, "application").toISOString(),
    "2026-12-24T08:00:00.000Z",
  );
});

function refreshHarness(scope: AuthSessionScope, expiresAt: Date) {
  const now = new Date();
  const token = createRefreshTokenValue(
    scope === AuthSessionScope.ADMIN ? "admin" : "application",
  );
  const user = {
    id: "user-1",
    name: "Aarast",
    phone: "+967777123456",
    email: null,
    role: scope === AuthSessionScope.ADMIN ? "ADMIN" : "USER",
    adminRole: scope === AuthSessionScope.ADMIN ? "SUPER_ADMIN" : null,
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: now,
    appAccountActivatedAt: now,
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
    id: "refresh-old",
    userId: user.id,
    tokenHash: hashRefreshToken(token),
    scope,
    revokedAt: null,
    replacedById: null,
    expiresAt,
    user,
  };
  const created: any[] = [];
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = query?.strings?.join(" ") ?? "";
      if (sql.includes('FROM "User"')) return [{ id: user.id, status: "ACTIVE" }];
      if (sql.includes('WITH RECURSIVE "RefreshFamily"')) return [{ ...existing, depth: 1 }];
      return [];
    },
    outboxEvent: { create: async () => ({}) },
    refreshToken: {
      findUnique: async ({ where }: any) =>
        where.tokenHash === existing.tokenHash || where.id === existing.id ? existing : null,
      create: async ({ data }: any) => {
        created.push(data);
        return { id: "refresh-next", ...data };
      },
      updateMany: async () => ({ count: 1 }),
      update: async () => ({}),
    },
  };
  const service = authService(
    { $transaction: async (fn: any) => fn(tx) } as any,
    { sign: () => "access-token" } as any,
    {} as any,
    { consume: async () => undefined } as any,
    { disconnectUser: () => undefined, disconnectSession: () => undefined } as any,
  );
  return { service, token, created, now };
}

test("refreshing an admin session rotates the token and keeps its end", async () => {
  const end = new Date(Date.now() + 3 * 60 * 60 * 1000);
  const { service, token, created } = refreshHarness(AuthSessionScope.ADMIN, end);

  const response = await service.refreshAdmin(token);

  assert.equal(created.length, 1);
  assert.equal(created[0].expiresAt.getTime(), end.getTime());
  assert.equal(response.refreshTokenExpiresAt.getTime(), end.getTime());
});

test("refreshing an application session still renews its thirty days", async () => {
  const end = new Date(Date.now() + 60_000);
  const { service, token, created, now } = refreshHarness(AuthSessionScope.APPLICATION, end);

  await service.refresh({ refreshToken: token });

  assert.equal(created.length, 1);
  assert.ok(created[0].expiresAt.getTime() >= refreshTokenExpiry(now).getTime());
});
