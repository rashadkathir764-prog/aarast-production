#!/usr/bin/env node
'use strict';

import assert from 'node:assert/strict';
import {
  AdminRole,
  AuthSessionScope,
  PrismaClient,
  UserRole,
  UserStatus,
} from '@prisma/client';
import { JwtService } from '@nestjs/jwt';
import { AdminService } from '../../src/admin/admin.service';
import { toAuthenticatedUser } from '../../src/auth/safe-user';

const { assertManagedSmokeEnvironment } = require('./smoke-utils.js') as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const {
  createSuperAdminPairFixture,
  withFixture,
} = require('../../test/support/phase0-postgres-support.js') as {
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
const service = new AdminService(prisma as any, realtime as any);

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
      const adminSession = await prisma.refreshToken.create({
        data: {
          userId: fixture.actingAdmin.id,
          tokenHash: `phase1-admin-${fixture.scope}`,
          scope: AuthSessionScope.ADMIN,
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
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

async function main(): Promise<void> {
  try {
    await assertOperationsCannotManageAdmin();
    await assertOperationsCanManageNonAdminAndRevokeSessions();
    await assertSelfDisableIsRejected();
    await assertConcurrentDisableKeepsOneSuperAdmin();
    await assertSignedAccessRealmsStaySeparated();
    console.log(
      'PASS - Phase 1 administrator hierarchy and signed access realms remain separated.',
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
