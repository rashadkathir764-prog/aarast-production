import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { join } from "node:path";
import type { ExecutionContext } from "@nestjs/common";
import { readLivePrismaSchema } from './support/live-prisma-schema';
import { ForbiddenException, UnauthorizedException } from "@nestjs/common";
import { OtpPurpose, UserRole } from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { AdminGuard } from "../src/admin/admin.guard";
import { AuthService } from "../src/auth/auth.service";
import { JwtAuthGuard } from "../src/auth/jwt-auth.guard";
import { resolveJwtSessionScope } from "../src/auth/access-token-scope";
import {
  createOpaqueTokenValue,
  hashRefreshToken,
} from "../src/auth/refresh-token-policy";

const root = join(__dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("admin login requires a persisted password-bound MFA challenge", () => {
  const schema = readLivePrismaSchema();
  const service = read("src/auth/auth.service.ts");
  const controller = read("src/auth/auth.controller.ts");

  assert.match(schema, /model AdminLoginChallenge/);
  assert.match(schema, /otpId\s+String\s+@unique/);
  assert.match(schema, /tokenHash\s+String\s+@unique/);
  assert.match(schema, /expiresAt\s+DateTime/);
  assert.match(schema, /consumedAt\s+DateTime\?/);
  assert.match(service, /UserRole\.ADMIN/);
  assert.match(service, /adminLoginChallenge\.create/);
  assert.match(service, /OtpPurpose\.ADMIN_LOGIN/);
  assert.match(controller, /@Post\(["']admin\/login["']\)/);
  assert.match(controller, /@Post\(["']admin\/login\/complete["']\)/);
});

test("admin MFA can securely verify a pre-MFA administrator phone", () => {
  const service = read("src/auth/auth.service.ts");
  const startBlock = service.slice(
    service.indexOf("async startAdminLogin("),
    service.indexOf("async completeAdminLogin("),
  );
  const completeBlock = service.slice(
    service.indexOf("async completeAdminLogin("),
    service.indexOf("private async validatePasswordCredentials("),
  );
  const credentialsBlock = service.slice(
    service.indexOf("private async validatePasswordCredentials("),
    service.indexOf("async refresh("),
  );

  assert.match(startBlock, /allowUnverifiedPhone:\s*true/);
  assert.match(completeBlock, /claimOtpCodeInTransaction/);
  assert.match(completeBlock, /runSerializableTransaction/);
  assert.match(
    completeBlock,
    /phoneVerifiedAt:\s*challenge\.user\.phoneVerifiedAt\s*\?\?\s*now/,
  );
  assert.match(
    credentialsBlock,
    /!user\.phoneVerifiedAt\s*&&\s*!options\.allowUnverifiedPhone/,
  );
});

test("admin refresh is a rotating HttpOnly cookie session", () => {
  const controller = read("src/auth/auth.controller.ts");
  const main = read("src/main.ts");
  const corsOptions = read("src/platform/config/cors-options.ts");

  assert.match(controller, /@Post\(["']admin\/refresh["']\)/);
  assert.match(controller, /@Post\(["']admin\/logout["']\)/);
  assert.match(controller, /httpOnly:\s*true/);
  assert.match(controller, /sameSite:\s*["']strict["']/);
  assert.match(controller, /path:\s*["']\/api\/v1\/auth\/admin["']/);
  assert.match(controller, /secure:\s*isProductionEnvironment\(\)/);
  assert.match(main, /app\.enableCors\(getCorsOptions\(\)\)/);
  assert.match(corsOptions, /credentials:\s*true/);
});

function contextFor(user: {
  role: UserRole;
  adminMfa?: boolean;
  sessionScope?: "application" | "admin";
}): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
  } as unknown as ExecutionContext;
}

test("admin guard requires both the ADMIN role and MFA assurance", () => {
  const guard = new AdminGuard();

  assert.equal(
    guard.canActivate(
      contextFor({
        role: UserRole.ADMIN,
        adminMfa: true,
        sessionScope: "admin",
      }),
    ),
    true,
  );
  assert.throws(
    () => guard.canActivate(contextFor({ role: UserRole.ADMIN })),
    ForbiddenException,
  );
  assert.throws(
    () =>
      guard.canActivate(contextFor({ role: UserRole.USER, adminMfa: true })),
    ForbiddenException,
  );
  assert.throws(
    () =>
      guard.canActivate(
        contextFor({
          role: UserRole.ADMIN,
          adminMfa: true,
          sessionScope: "application",
        }),
      ),
    ForbiddenException,
  );
});

test("access-token scope is explicit, non-contradictory, and enforced by product routes", () => {
  assert.equal(
    resolveJwtSessionScope({
      sub: "user",
      phone: null,
      scope: "application",
      sid: "application-session",
    }),
    "application",
  );
  assert.equal(
    resolveJwtSessionScope({
      sub: "user",
      phone: null,
      scope: "application",
    }),
    null,
  );
  assert.equal(
    resolveJwtSessionScope({
      sub: "admin",
      phone: null,
      scope: "admin",
      amr: "admin_mfa",
      sid: "session",
    }),
    "admin",
  );
  assert.equal(
    resolveJwtSessionScope({
      sub: "admin",
      phone: null,
      scope: "application",
      amr: "admin_mfa",
      sid: "session",
    }),
    null,
  );
  assert.equal(
    resolveJwtSessionScope({
      sub: "admin",
      phone: null,
      scope: undefined as never,
    }),
    null,
  );

  const guard = new JwtAuthGuard();
  const context = {} as ExecutionContext;
  const applicationUser = { sessionScope: "application" };
  assert.equal(
    guard.handleRequest(null, applicationUser as any, null, context),
    applicationUser,
  );
  assert.throws(
    () =>
      guard.handleRequest(
        null,
        { sessionScope: "admin" } as any,
        null,
        context,
      ),
    UnauthorizedException,
  );
  assert.throws(
    () => guard.handleRequest(null, {} as any, null, context),
    UnauthorizedException,
  );
});

test("application and admin credentials stay separated and only admin MFA mints admin access", () => {
  const service = read("src/auth/auth.service.ts");
  const credentialsBlock = service.slice(
    service.indexOf("private async validatePasswordCredentials("),
    service.indexOf("async refresh("),
  );
  const loginBlock = service.slice(
    service.indexOf("async login(dto:"),
    service.indexOf("async startAdminLogin("),
  );
  const otpBlock = service.slice(
    service.indexOf("async verifyOtp("),
    service.indexOf("async requestPasswordReset("),
  );

  assert.match(credentialsBlock, /requiredRole === UserRole\.ADMIN/);
  assert.match(credentialsBlock, /user\.appPasswordHash/);
  assert.doesNotMatch(loginBlock, /createAuthResponse\([^)]*,\s*true/);
  assert.doesNotMatch(otpBlock, /createAuthResponse\([^)]*,\s*true/);
  assert.match(read("src/admin/admin.guard.ts"), /adminMfa !== true/);
  assert.match(read("src/admin/admin.guard.ts"), /sessionScope !== 'admin'/);
  assert.match(
    read("src/auth/jwt.strategy.ts"),
    /resolveJwtSessionScope\(payload\)/,
  );
});

test("application and administrator sessions are persisted and revoked by scope", () => {
  const schema = readLivePrismaSchema();
  const service = read("src/auth/auth.service.ts");
  const strategy = read("src/auth/jwt.strategy.ts");

  assert.match(schema, /enum AuthSessionScope/);
  assert.match(schema, /scope\s+AuthSessionScope\s+@default\(APPLICATION\)/);
  assert.match(service, /scope:\s*AuthSessionScope\.APPLICATION/);
  assert.match(service, /scope:\s*AuthSessionScope\.ADMIN/);
  assert.match(
    service,
    /logoutAdminRefreshToken[\s\S]*scope:\s*AuthSessionScope\.ADMIN/,
  );
  assert.match(strategy, /AuthSessionScope\.ADMIN/);
  assert.match(strategy, /AuthSessionScope\.APPLICATION/);
});

test("public OTP cannot mint or invalidate an administrator MFA code", () => {
  const requestDto = read("src/auth/dto/request-otp.dto.ts");
  const verifyDto = read("src/auth/dto/verify-otp.dto.ts");

  assert.doesNotMatch(requestDto, /OtpPurpose\.ADMIN_LOGIN/);
  assert.doesNotMatch(verifyDto, /OtpPurpose\.ADMIN_LOGIN/);
});

test("all access JWTs are bound to a live revocable server session", () => {
  const payload = read("src/auth/jwt-payload.interface.ts");
  const service = read("src/auth/auth.service.ts");
  const strategy = read("src/auth/jwt.strategy.ts");

  assert.match(payload, /sid\?: string/);
  assert.match(payload, /scope: JwtSessionScope/);
  assert.match(service, /sid: sessionId/);
  assert.match(service, /replacement\.id/);
  assert.match(strategy, /payload\.sid/);
  assert.match(strategy, /refreshToken\.findFirst/);
  assert.match(strategy, /AuthSessionScope\.APPLICATION/);
  assert.match(strategy, /AuthSessionScope\.ADMIN/);
  assert.match(strategy, /revokedAt: null/);
  assert.match(strategy, /expiresAt: \{ gt: new Date\(\) \}/);
});

test("admin login completion rollback preserves OTP and follows canonical lock order", async () => {
  const now = new Date();
  const challengeToken = createOpaqueTokenValue();
  const admin: any = {
    id: "admin-lock-order",
    name: "Administrator",
    phone: "+967777123456",
    email: null,
    passwordHash: "unused",
    appPasswordHash: null,
    appName: null,
    appEmail: null,
    appAvatarUrl: null,
    role: "ADMIN",
    adminRole: "SUPER_ADMIN",
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: now,
    lastLoginAt: null,
    avatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    createdAt: now,
    updatedAt: now,
  };
  const otp: any = {
    id: "otp-admin-login",
    phone: admin.phone,
    purpose: OtpPurpose.ADMIN_LOGIN,
    codeHash: await bcryptjs.hash("654321", 4),
    expiresAt: new Date(now.getTime() + 60_000),
    consumedAt: null,
    attempts: 0,
    maxAttempts: 5,
    createdAt: now,
    updatedAt: now,
  };
  const challenge: any = {
    id: "challenge-admin-login",
    userId: admin.id,
    otpId: otp.id,
    tokenHash: hashRefreshToken(challengeToken),
    expiresAt: new Date(now.getTime() + 60_000),
    consumedAt: null,
    createdAt: now,
  };
  const refreshTokens: any[] = [];
  const lockOrder: string[] = [];
  let failRefreshCreate = true;

  const prisma: any = {
    user: {
      updateMany: async ({ where, data }: any) => {
        if (
          where.id !== admin.id ||
          where.role !== admin.role ||
          where.status !== admin.status
        ) {
          return { count: 0 };
        }
        Object.assign(admin, data);
        return { count: 1 };
      },
      findUniqueOrThrow: async () => admin,
    },
    otpCode: {
      findUnique: async ({ where }: any) =>
        where.id === otp.id ? otp : null,
      updateMany: async ({ where, data }: any) => {
        if (where.id !== otp.id) return { count: 0 };
        if (where.consumedAt === null && otp.consumedAt !== null) {
          return { count: 0 };
        }
        if (data.updatedAt) lockOrder.push("OtpCode");
        if (data.attempts?.increment) {
          otp.attempts += data.attempts.increment;
        }
        Object.assign(otp, { ...data, attempts: otp.attempts });
        return { count: 1 };
      },
    },
    adminLoginChallenge: {
      findUnique: async ({ where }: any) => {
        if (
          where.tokenHash !== challenge.tokenHash &&
          where.id !== challenge.id
        ) {
          return null;
        }
        return {
          ...challenge,
          user: admin,
          otp,
        };
      },
      updateMany: async ({ where, data }: any) => {
        if (
          where.id !== challenge.id ||
          (where.consumedAt === null && challenge.consumedAt !== null)
        ) {
          return { count: 0 };
        }
        Object.assign(challenge, data);
        return { count: 1 };
      },
    },
    refreshToken: {
      create: async ({ data }: any) => {
        lockOrder.push("RefreshToken");
        if (failRefreshCreate) {
          failRefreshCreate = false;
          throw new Error("simulated admin session failure");
        }
        const stored = { id: "admin-session", ...data };
        refreshTokens.push(stored);
        return stored;
      },
    },
    $queryRaw: async (query: any) => {
      const sql = query?.strings?.join(" ") ?? "";
      if (sql.includes('FROM "User"')) {
        lockOrder.push("User");
        return [{ id: admin.id, status: admin.status }];
      }
      if (sql.includes('FROM "AdminLoginChallenge"')) {
        lockOrder.push("AdminLoginChallenge");
      }
      return [];
    },
    $transaction: async (operation: (tx: any) => Promise<unknown>) => {
      const adminSnapshot = structuredClone(admin);
      const otpSnapshot = structuredClone(otp);
      const challengeSnapshot = structuredClone(challenge);
      const refreshSnapshot = structuredClone(refreshTokens);
      try {
        return await operation(prisma);
      } catch (error) {
        Object.assign(admin, adminSnapshot);
        Object.assign(otp, otpSnapshot);
        Object.assign(challenge, challengeSnapshot);
        refreshTokens.splice(0, refreshTokens.length, ...refreshSnapshot);
        throw error;
      }
    },
  };
  const service = new AuthService(
    prisma,
    { sign: () => "admin-access-token" } as any,
    {} as any,
    { consume: async () => undefined } as any,
    {
      disconnectUser: () => undefined,
      disconnectSession: () => undefined,
    } as any,
  );

  await assert.rejects(
    () => service.completeAdminLogin(challengeToken, "654321"),
    /simulated admin session failure/,
  );
  assert.equal(otp.consumedAt, null);
  assert.equal(challenge.consumedAt, null);
  assert.equal(refreshTokens.length, 0);
  assert.deepEqual(lockOrder.slice(0, 4), [
    "User",
    "AdminLoginChallenge",
    "OtpCode",
    "RefreshToken",
  ]);

  const auth = await service.completeAdminLogin(challengeToken, "654321");
  assert.equal(auth.accessToken, "admin-access-token");
  assert.ok(otp.consumedAt);
  assert.ok(challenge.consumedAt);
});
