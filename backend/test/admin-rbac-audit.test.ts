import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import type { ExecutionContext } from '@nestjs/common';
import { readLivePrismaSchema } from './support/live-prisma-schema';
import { ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AdminRole } from '@prisma/client';
import { AdminPermissionGuard } from '../src/modules/backoffice/public/admin-permission.guard';
import {
  AdminPermission,
  hasAdminPermission,
} from '../src/modules/backoffice/domain/admin-permissions';

const root = join(__dirname, '..');
const read = (path: string) => readFileSync(join(root, path), 'utf8');

test('admin roles and route-level permissions are explicit', () => {
  const schema = readLivePrismaSchema();
  const controller = read('src/admin/admin.controller.ts');

  assert.match(
    schema,
    /enum AdminRole\s*{[\s\S]*SUPER_ADMIN[\s\S]*OPERATIONS[\s\S]*MODERATOR[\s\S]*SUPPORT/,
  );
  assert.match(schema, /adminRole\s+AdminRole\?/);
  assert.match(controller, /AdminPermissionGuard/);
  assert.ok(
    (controller.match(/@RequireAdminPermission\(/g) ?? []).length >= 30,
    'every admin route must declare a permission',
  );
});

test('admin mutations produce append-only redacted audit phases', () => {
  const schema = readLivePrismaSchema();
  const app = read('src/app.module.ts');
  const migration = read(
    'prisma/migrations/20260710183000_admin_rbac_audit/migration.sql',
  );

  assert.match(schema, /model AdminAuditLog/);
  assert.match(schema, /phase\s+AdminAuditPhase/);
  assert.match(schema, /@@unique\(\[eventId, phase\]\)/);
  assert.match(app, /AdminAuditInterceptor/);
  assert.match(migration, /BEFORE UPDATE OR DELETE ON "AdminAuditLog"/);
  assert.match(migration, /RAISE EXCEPTION 'AdminAuditLog is append-only'/);
});

test('audit read API is permission-gated and paginated', () => {
  const controller = read('src/admin/admin-audit.controller.ts');
  const service = read('src/admin/admin-audit.service.ts');

  assert.match(controller, /AdminPermission\.AUDIT_READ/);
  assert.match(controller, /@Get\(\)/);
  assert.match(service, /adminAuditLog\.count/);
  assert.match(service, /adminAuditLog\.findMany/);
  assert.match(service, /totalPages/);
});

test('role permission matrix preserves least privilege', () => {
  assert.equal(
    hasAdminPermission(AdminRole.SUPER_ADMIN, AdminPermission.AUDIT_READ),
    true,
  );
  assert.equal(
    hasAdminPermission(AdminRole.OPERATIONS, AdminPermission.PROVIDERS_WRITE),
    true,
  );
  assert.equal(
    hasAdminPermission(AdminRole.OPERATIONS, AdminPermission.AUDIT_READ),
    false,
  );
  assert.equal(
    hasAdminPermission(AdminRole.MODERATOR, AdminPermission.REVIEWS_WRITE),
    true,
  );
  assert.equal(
    hasAdminPermission(AdminRole.MODERATOR, AdminPermission.USERS_WRITE),
    false,
  );
  assert.equal(
    hasAdminPermission(AdminRole.SUPPORT, AdminPermission.USERS_READ),
    true,
  );
  assert.equal(
    hasAdminPermission(AdminRole.SUPPORT, AdminPermission.USERS_WRITE),
    false,
  );
});

test('admin account status changes require a live super administrator and preserve the last one', () => {
  const controller = read('src/admin/admin.controller.ts');
  const service = read('src/admin/admin.service.ts');
  const userStatus = read('src/admin/admin-user-status.ts');

  assert.match(
    controller,
    /activateUser\(\s*@CurrentUser\(\) currentUser: AuthenticatedUser/,
  );
  assert.match(userStatus, /actor\.adminRole !== AdminRole\.SUPER_ADMIN/);
  assert.match(service, /runSerializableTransaction\(this\.prisma/);
  assert.match(service, /activeSuperAdmins <= 1/);
  assert.match(service, /last active super administrator cannot be disabled/i);
  // The refresh tokens are identity's: the service asks identity's admin
  // port to revoke the target's live tokens at the same instant
  // (admin-owner-ports.test.ts pins the statement).
  assert.match(
    service,
    /revokeRefreshTokensInTransaction\(\s*tx,\s*target\.id,\s*now,?\s*\)/,
  );
});

test('permission guard denies missing metadata and insufficient roles', () => {
  const context = (adminRole: AdminRole) =>
    ({
      getHandler: () => function handler() {},
      getClass: () => class Controller {},
      switchToHttp: () => ({ getRequest: () => ({ user: { adminRole } }) }),
    }) as unknown as ExecutionContext;

  const missing = new AdminPermissionGuard({
    getAllAndOverride: () => undefined,
  } as unknown as Reflector);
  assert.throws(
    () => missing.canActivate(context(AdminRole.SUPER_ADMIN)),
    ForbiddenException,
  );

  const usersWrite = new AdminPermissionGuard({
    getAllAndOverride: () => [AdminPermission.USERS_WRITE],
  } as unknown as Reflector);
  assert.equal(usersWrite.canActivate(context(AdminRole.OPERATIONS)), true);
  assert.throws(
    () => usersWrite.canActivate(context(AdminRole.SUPPORT)),
    ForbiddenException,
  );
});

test('admin bootstrap has no fixed credential and creates an MFA-ready super admin', () => {
  const script = read('scripts/dev/create-admin.cjs');

  assert.doesNotMatch(script, /Aarast@123456|770579680/);
  assert.match(script, /DEV_ADMIN_PHONE/);
  assert.match(script, /DEV_ADMIN_PASSWORD/);
  assert.match(script, /adminRole: 'SUPER_ADMIN'/);
  assert.match(script, /phoneVerifiedAt/);
  assert.match(script, /NODE_ENV === 'production'/);
});
