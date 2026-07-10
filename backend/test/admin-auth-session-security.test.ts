import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { join } from 'node:path';
import type { ExecutionContext } from '@nestjs/common';
import { ForbiddenException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { AdminGuard } from '../src/admin/admin.guard';

const root = join(__dirname, '..');
const read = (path: string) => readFileSync(join(root, path), 'utf8');

test('admin login requires a persisted password-bound MFA challenge', () => {
  const schema = read('prisma/schema.prisma');
  const service = read('src/auth/auth.service.ts');
  const controller = read('src/auth/auth.controller.ts');

  assert.match(schema, /model AdminLoginChallenge/);
  assert.match(schema, /tokenHash\s+String\s+@unique/);
  assert.match(schema, /expiresAt\s+DateTime/);
  assert.match(schema, /consumedAt\s+DateTime\?/);
  assert.match(service, /UserRole\.ADMIN/);
  assert.match(service, /adminLoginChallenge\.create/);
  assert.match(service, /OtpPurpose\.LOGIN/);
  assert.match(controller, /@Post\('admin\/login'\)/);
  assert.match(controller, /@Post\('admin\/login\/complete'\)/);
});

test('admin refresh is a rotating HttpOnly cookie session', () => {
  const controller = read('src/auth/auth.controller.ts');
  const main = read('src/main.ts');

  assert.match(controller, /@Post\('admin\/refresh'\)/);
  assert.match(controller, /@Post\('admin\/logout'\)/);
  assert.match(controller, /httpOnly:\s*true/);
  assert.match(controller, /sameSite:\s*'strict'/);
  assert.match(controller, /secure:\s*isProductionEnvironment\(\)/);
  assert.match(main, /credentials:\s*true/);
});

function contextFor(user: { role: UserRole; adminMfa?: boolean }): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => ({ user }) }),
  } as unknown as ExecutionContext;
}

test('admin guard requires both the ADMIN role and MFA assurance', () => {
  const guard = new AdminGuard();

  assert.equal(
    guard.canActivate(contextFor({ role: UserRole.ADMIN, adminMfa: true })),
    true,
  );
  assert.throws(
    () => guard.canActivate(contextFor({ role: UserRole.ADMIN })),
    ForbiddenException,
  );
  assert.throws(
    () => guard.canActivate(contextFor({ role: UserRole.USER, adminMfa: true })),
    ForbiddenException,
  );
});

test('legacy password and OTP login paths explicitly reject admin sessions', () => {
  const service = read('src/auth/auth.service.ts');
  const loginBlock = service.slice(
    service.indexOf('async login(dto:'),
    service.indexOf('async startAdminLogin('),
  );
  const otpBlock = service.slice(
    service.indexOf('async verifyOtp('),
    service.indexOf('async requestPasswordReset('),
  );

  assert.match(loginBlock, /user\.role === UserRole\.ADMIN/);
  assert.match(otpBlock, /user\?\.role === UserRole\.ADMIN/);
  assert.match(read('src/admin/admin.guard.ts'), /adminMfa !== true/);
  assert.match(read('src/auth/jwt.strategy.ts'), /payload\.amr === 'admin_mfa'/);
});

test('admin access JWTs are bound to a live revocable server session', () => {
  const payload = read('src/auth/jwt-payload.interface.ts');
  const service = read('src/auth/auth.service.ts');
  const strategy = read('src/auth/jwt.strategy.ts');

  assert.match(payload, /sid\?: string/);
  assert.match(service, /sid: adminSessionId/);
  assert.match(service, /requiredRole === UserRole\.ADMIN \? replacement\.id/);
  assert.match(strategy, /payload\.sid/);
  assert.match(strategy, /refreshToken\.findFirst/);
  assert.match(strategy, /revokedAt: null/);
  assert.match(strategy, /expiresAt: \{ gt: new Date\(\) \}/);
});
