#!/usr/bin/env node
'use strict';

import assert from 'node:assert/strict';
import {
  AdminRole,
  AuthSessionScope,
  OtpPurpose,
  PrismaClient,
  UserRole,
  UserStatus,
} from '@prisma/client';
import { JwtService } from '@nestjs/jwt';
import * as bcryptjs from 'bcryptjs';
import { AuthService } from '../../src/modules/identity/internal/auth/auth.service';
import { LoginThrottleService } from '../../src/modules/identity/internal/auth/login-throttle.service';
import { toAuthenticatedUser } from '../../src/modules/identity/public/safe-user';
import { PermissionService } from "../../src/modules/collaboration/internal/permission.service";
import { ownerPorts, adminService } from './support/owner-ports';

const { assertManagedSmokeEnvironment } = require('./smoke-utils.js') as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createOtpAttemptFixture,
  createSuperAdminPairFixture,
  withFixture,
} = require('../../test/support/phase0-postgres-support.js') as {
  createOtpAttemptFixture: (
    prisma: any,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
  createSuperAdminPairFixture: (
    prisma: any,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<any>;
  withFixture: (
    createFixture: (environment: NodeJS.ProcessEnv) => Promise<any>,
    callback: (fixture: any) => Promise<void>,
    environment?: NodeJS.ProcessEnv,
  ) => Promise<void>;
};

assertManagedSmokeEnvironment(process.env);

const prisma = new PrismaClient();
const realtime = { disconnectUser: () => undefined };
const service = adminService(prisma as any, realtime as any, {
  createNotificationInTransaction: async () => null,
} as any);
const loginThrottle = new LoginThrottleService(prisma as any);
const jwtService = new JwtService({ secret: process.env.JWT_SECRET });
const authService = new AuthService(
  prisma as any,
  jwtService,
  loginThrottle,
  { consume: async () => undefined } as any,
  realtime as any,
  new PermissionService(prisma as any, ownerPorts.plans),
);

function authenticatedAdmin(user: any) {
  return {
    ...toAuthenticatedUser(user, true),
    adminMfa: true,
  };
}

async function assertOperationsCannotManageAdmin(): Promise<void> {
  await withFixture(
    (environment) => createSuperAdminPairFixture(prisma, environment),
    async (fixture) => {
      const operations = await prisma.user.update({
        where: { id: fixture.actingAdmin.id },
        data: { adminRole: AdminRole.OPERATIONS },
      });
      const actor = authenticatedAdmin(operations);

      await assert.rejects(
        () => service.disableUser(actor, fixture.peerAdmin.id),
        (error: any) => error?.getStatus?.() === 403,
      );
      await assert.rejects(
        () => (service as any).activateUser(actor, fixture.peerAdmin.id),
        (error: any) => error?.getStatus?.() === 403,
      );

      const target = await prisma.user.findUniqueOrThrow({
        where: { id: fixture.peerAdmin.id },
        select: { status: true },
      });
      assert.equal(target.status, UserStatus.ACTIVE);
    },
  );
}

async function assertConcurrentDisableKeepsOneSuperAdmin(): Promise<void> {
  await withFixture(
    (environment) => createSuperAdminPairFixture(prisma, environment),
    async (fixture) => {
      const acting = authenticatedAdmin(fixture.actingAdmin);
      const peer = authenticatedAdmin(fixture.peerAdmin);
      const results = await Promise.allSettled([
        service.disableUser(acting, fixture.peerAdmin.id),
        service.disableUser(peer, fixture.actingAdmin.id),
      ]);
      assert.equal(
        results.filter((result) => result.status === 'fulfilled').length,
        1,
      );
      assert.equal(
        results.filter((result) => result.status === 'rejected').length,
        1,
      );
      const activeSuperAdmins = await prisma.user.count({
        where: {
          id: {
            in: [fixture.actingAdmin.id, fixture.peerAdmin.id],
          },
          role: 'ADMIN',
          adminRole: AdminRole.SUPER_ADMIN,
          status: UserStatus.ACTIVE,
        },
      });
      assert.equal(activeSuperAdmins, 1);
    },
  );
}

async function assertOperationsCanManageNonAdminAndRevokeSessions(): Promise<void> {
  await withFixture(
    (environment) => createSuperAdminPairFixture(prisma, environment),
    async (fixture) => {
      const [operations, regular] = await prisma.$transaction([
        prisma.user.update({
          where: { id: fixture.actingAdmin.id },
          data: { adminRole: AdminRole.OPERATIONS },
        }),
        prisma.user.update({
          where: { id: fixture.peerAdmin.id },
          data: {
            role: UserRole.USER,
            adminRole: null,
          },
        }),
      ]);
      const refresh = await prisma.refreshToken.create({
        data: {
          userId: regular.id,
          tokenHash: `phase1-${fixture.scope}`,
          scope: AuthSessionScope.APPLICATION,
          expiresAt: new Date(Date.now() + 60_000),
        },
      });

      const disabled = await service.disableUser(
        authenticatedAdmin(operations),
        regular.id,
      );
      assert.equal(disabled.status, UserStatus.DISABLED);
      const revoked = await prisma.refreshToken.findUniqueOrThrow({
        where: { id: refresh.id },
        select: { revokedAt: true },
      });
      assert.ok(revoked.revokedAt);

      const activated = await service.activateUser(
        authenticatedAdmin(operations),
        regular.id,
      );
      assert.equal(activated.status, UserStatus.ACTIVE);
    },
  );
}

async function assertSelfDisableIsRejected(): Promise<void> {
  await withFixture(
    (environment) => createSuperAdminPairFixture(prisma, environment),
    async (fixture) => {
      await assert.rejects(
        () =>
          service.disableUser(
            authenticatedAdmin(fixture.actingAdmin),
            fixture.actingAdmin.id,
          ),
        (error: any) => error?.getStatus?.() === 400,
      );
    },
  );
}

async function accessStatus(
  path: string,
  accessToken: string,
): Promise<number> {
  const response = await fetch(`${process.env.SMOKE_BASE_URL}${path}`, {
    headers: { authorization: `Bearer ${accessToken}` },
  });
  await response.arrayBuffer();
  return response.status;
}

async function assertSignedAccessRealmsStaySeparated(): Promise<void> {
  await withFixture(
    (environment) => createSuperAdminPairFixture(prisma, environment),
    async (fixture) => {
      const secret = process.env.JWT_SECRET;
      assert.ok(secret);
      const jwt = new JwtService({ secret });
      await prisma.user.update({
        where: { id: fixture.actingAdmin.id },
        data: {
          appPasswordHash: await bcryptjs.hash('Phase1 application password', 4),
          appAccountActivatedAt: new Date(),
        },
      });
      const [adminSession, applicationSession] = await prisma.$transaction([
        prisma.refreshToken.create({
          data: {
            userId: fixture.actingAdmin.id,
            tokenHash: `phase1-admin-${fixture.scope}`,
            scope: AuthSessionScope.ADMIN,
            expiresAt: new Date(Date.now() + 60_000),
          },
        }),
        prisma.refreshToken.create({
          data: {
            userId: fixture.actingAdmin.id,
            tokenHash: `phase1-application-${fixture.scope}`,
            scope: AuthSessionScope.APPLICATION,
            expiresAt: new Date(Date.now() + 60_000),
          },
        }),
      ]);
      const basePayload = {
        sub: fixture.actingAdmin.id,
        phone: fixture.actingAdmin.phone,
      };
      const adminToken = jwt.sign({
        ...basePayload,
        scope: 'admin',
        amr: 'admin_mfa',
        sid: adminSession.id,
      });
      const applicationToken = jwt.sign({
        ...basePayload,
        scope: 'application',
        sid: applicationSession.id,
      });
      const realmLessToken = jwt.sign(basePayload);
      const contradictoryToken = jwt.sign({
        ...basePayload,
        scope: 'application',
        amr: 'admin_mfa',
        sid: adminSession.id,
      });

      assert.equal(await accessStatus('/api/v1/me', adminToken), 401);
      assert.equal(
        await accessStatus('/admin/dashboard/stats', adminToken),
        200,
      );
      assert.equal(await accessStatus('/api/v1/me', applicationToken), 200);
      assert.equal(
        await accessStatus('/admin/dashboard/stats', applicationToken),
        403,
      );
      assert.equal(await accessStatus('/api/v1/me', realmLessToken), 401);
      assert.equal(await accessStatus('/api/v1/me', contradictoryToken), 401);
    },
  );
}

async function assertConcurrentWrongOtpAttemptsRespectCeiling(): Promise<void> {
  await withFixture(
    (environment) => createOtpAttemptFixture(prisma, environment),
    async (fixture) => {
      const otp = await prisma.otpCode.update({
        where: { id: fixture.otp.id },
        data: { codeHash: await bcryptjs.hash('654321', 4) },
      });
      const results = await Promise.allSettled(
        Array.from({ length: 20 }, () =>
          authService.verifyOtp({
            phone: fixture.user.phone,
            purpose: OtpPurpose.LOGIN,
            code: '000000',
          }),
        ),
      );

      assert.equal(
        results.filter((result) => result.status === 'rejected').length,
        20,
      );
      for (const result of results) {
        assert.equal(result.status, 'rejected');
        assert.equal((result as PromiseRejectedResult).reason?.getStatus?.(), 400);
      }
      const persisted = await prisma.otpCode.findUniqueOrThrow({
        where: { id: otp.id },
        select: { attempts: true, maxAttempts: true, consumedAt: true },
      });
      assert.equal(persisted.maxAttempts, 5);
      assert.equal(
        persisted.attempts,
        persisted.maxAttempts,
        'concurrent comparisons must never be admitted beyond maxAttempts',
      );
      assert.ok(
        persisted.consumedAt,
        'an OTP must be terminal after its attempt ceiling is reached',
      );
    },
  );
}

async function assertCorrectAndWrongOtpRaceHasOneWinner(): Promise<void> {
  await withFixture(
    (environment) => createOtpAttemptFixture(prisma, environment),
    async (fixture) => {
      await prisma.user.update({
        where: { id: fixture.user.id },
        data: {
          appPasswordHash: await bcryptjs.hash('Phase1 OTP application password', 4),
          appAccountActivatedAt: new Date(),
        },
      });
      const otp = await prisma.otpCode.update({
        where: { id: fixture.otp.id },
        data: { codeHash: await bcryptjs.hash('654321', 4) },
      });
      const [correct, wrong] = await Promise.allSettled([
        authService.verifyOtp({
          phone: fixture.user.phone,
          purpose: OtpPurpose.LOGIN,
          code: '654321',
        }),
        authService.verifyOtp({
          phone: fixture.user.phone,
          purpose: OtpPurpose.LOGIN,
          code: '000000',
        }),
      ]);

      assert.equal(correct.status, 'fulfilled');
      assert.equal(wrong.status, 'rejected');
      const persisted = await prisma.otpCode.findUniqueOrThrow({
        where: { id: otp.id },
        select: { attempts: true, consumedAt: true },
      });
      assert.ok(persisted.consumedAt);
      assert.ok(persisted.attempts === 0 || persisted.attempts === 1);
      await assert.rejects(
        () =>
          authService.verifyOtp({
            phone: fixture.user.phone,
            purpose: OtpPurpose.LOGIN,
            code: '654321',
          }),
        (error: any) => error?.getStatus?.() === 400,
      );
    },
  );
}

async function assertConcurrentLoginFailuresCannotBypassLock(): Promise<void> {
  await withFixture(
    (environment) => createOtpAttemptFixture(prisma, environment),
    async (fixture) => {
      await prisma.user.update({
        where: { id: fixture.user.id },
        data: {
          passwordHash: await bcryptjs.hash('correct-password', 4),
        },
      });
      const results = await Promise.allSettled(
        Array.from({ length: 20 }, () =>
          authService.login({
            phone: fixture.user.phone,
            password: 'definitely-wrong-password',
          }),
        ),
      );
      assert.equal(
        results.filter(
          (result) =>
            result.status === 'rejected' &&
            result.reason?.getStatus?.() === 401,
        ).length,
        LoginThrottleService.maxAttempts,
        'only the configured number of password comparisons may be admitted',
      );
      assert.equal(
        results.filter(
          (result) =>
            result.status === 'rejected' &&
            result.reason?.getStatus?.() === 429,
        ).length,
        20 - LoginThrottleService.maxAttempts,
        'the remaining concurrent attempts must be rejected before comparison',
      );
      await assert.rejects(
        () => loginThrottle.assertAllowed(fixture.user.phone, 'application'),
        (error: any) => error?.getStatus?.() === 429,
      );
      const persisted = await prisma.loginThrottle.findUniqueOrThrow({
        where: {
          subjectHash: LoginThrottleService.subjectHash(
            fixture.user.phone,
            'application',
          ),
        },
        select: { lockedUntil: true },
      });
      assert.ok(persisted.lockedUntil && persisted.lockedUntil > new Date());
    },
  );
}

async function main(): Promise<void> {
  try {
    await assertOperationsCannotManageAdmin();
    await assertOperationsCanManageNonAdminAndRevokeSessions();
    await assertSelfDisableIsRejected();
    await assertConcurrentDisableKeepsOneSuperAdmin();
    await assertSignedAccessRealmsStaySeparated();
    await assertConcurrentWrongOtpAttemptsRespectCeiling();
    await assertCorrectAndWrongOtpRaceHasOneWinner();
    await assertConcurrentLoginFailuresCannotBypassLock();
    console.log(
      'PASS - Phase 1 hierarchy, token realms, OTP ceilings, and login lockouts remain safe.',
    );
  } finally {
    await prisma.$disconnect();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}
