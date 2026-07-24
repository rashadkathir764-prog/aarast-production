import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { join } from "node:path";
import type { ExecutionContext } from "@nestjs/common";
import { ForbiddenException, UnauthorizedException } from "@nestjs/common";
import { UserRole } from "@prisma/client";
import { AdminGuard } from "../src/admin/admin.guard";
import { JwtAuthGuard } from "../src/auth/jwt-auth.guard";
import { resolveJwtSessionScope } from "../src/auth/access-token-scope";

const root = join(__dirname, "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");

test("admin login requires a persisted password-bound MFA challenge", () => {
  const schema = read("prisma/schema.prisma");
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
  assert.match(completeBlock, /assertSpecificOtpCodeMatches/);
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

  assert.match(controller, /@Post\(["']admin\/refresh["']\)/);
  assert.match(controller, /@Post\(["']admin\/logout["']\)/);
  assert.match(controller, /httpOnly:\s*true/);
  assert.match(controller, /sameSite:\s*["']strict["']/);
  assert.match(controller, /path:\s*["']\/api\/v1\/auth\/admin["']/);
  assert.match(controller, /secure:\s*isProductionEnvironment\(\)/);
  assert.match(main, /credentials:\s*true/);
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
    }),
    "application",
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
  const schema = read("prisma/schema.prisma");
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
  assert.match(strategy, /scope:\s*AuthSessionScope\.ADMIN/);
});

test("public OTP cannot mint or invalidate an administrator MFA code", () => {
  const requestDto = read("src/auth/dto/request-otp.dto.ts");
  const verifyDto = read("src/auth/dto/verify-otp.dto.ts");

  assert.doesNotMatch(requestDto, /OtpPurpose\.ADMIN_LOGIN/);
  assert.doesNotMatch(verifyDto, /OtpPurpose\.ADMIN_LOGIN/);
});

test("admin access JWTs are bound to a live revocable server session", () => {
  const payload = read("src/auth/jwt-payload.interface.ts");
  const service = read("src/auth/auth.service.ts");
  const strategy = read("src/auth/jwt.strategy.ts");

  assert.match(payload, /sid\?: string/);
  assert.match(payload, /scope: JwtSessionScope/);
  assert.match(service, /sid: adminSessionId/);
  assert.match(service, /requiredRole === UserRole\.ADMIN \? replacement\.id/);
  assert.match(strategy, /payload\.sid/);
  assert.match(strategy, /refreshToken\.findFirst/);
  assert.match(strategy, /revokedAt: null/);
  assert.match(strategy, /expiresAt: \{ gt: new Date\(\) \}/);
});
