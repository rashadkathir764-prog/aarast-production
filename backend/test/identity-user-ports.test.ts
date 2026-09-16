import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import { AppRole, OnboardingPath, UserRole, UserStatus, type Prisma } from '@prisma/client';
import {
  ACTIVE_PLAN_IMPLEMENTATION,
  IdentityUserInternalModule,
  USER_READ_IMPLEMENTATION,
} from '../src/modules/identity/internal/identity-user.internal.module';
import { IdentityUserPortService } from '../src/modules/identity/internal/identity-user-port.service';
import { ActivePlanPublicModule } from '../src/modules/identity/public/active-plan-public.module';
import { ACTIVE_PLAN_PORT } from '../src/modules/identity/public/active-plan.port';
import { UserReadPublicModule } from '../src/modules/identity/public/user-read-public.module';
import { appIdentitySelect, USER_READ_PORT } from '../src/modules/identity/public/user-read.port';

const now = new Date('2026-09-17T08:00:00.000Z');
const userRow = {
  id: 'user-1',
  name: 'Admin Person',
  phone: '+967700000000',
  email: 'admin@example.com',
  passwordHash: 'secret-hash',
  appPasswordHash: null,
  appPasswordConfiguredAt: null,
  appName: 'App Name',
  appEmail: null,
  appAvatarUrl: 'app-avatar',
  role: UserRole.ADMIN,
  adminRole: 'OWNER',
  appRole: AppRole.WEDDING_USER,
  status: UserStatus.ACTIVE,
  phoneVerifiedAt: null,
  lastLoginAt: null,
  avatarUrl: 'avatar',
  locale: 'ar',
  activeWeddingPlanId: 'plan-1',
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: null,
  createdAt: now,
  updatedAt: now,
};

test('the user read port projects users to the application identity, never a credential', async () => {
  const calls: Array<[string, unknown]> = [];
  const client = {
    user: {
      findUnique: async (args: unknown) => { calls.push(['findUnique', args]); return userRow; },
      findMany: async (args: unknown) => { calls.push(['findMany', args]); return [userRow]; },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new IdentityUserPortService();

  const safe = await service.getSafeUser(client, 'user-1');
  assert.ok(safe);
  // The application view of an admin account, exactly as `toSafeUser` renders it.
  assert.equal(safe.name, 'App Name');
  assert.equal(safe.role, UserRole.USER);
  assert.equal(safe.adminRole, null);
  assert.equal(safe.avatarUrl, 'app-avatar');
  assert.equal('passwordHash' in safe, false);

  assert.deepEqual(await service.getAppIdentity(client, 'user-1'), userRow);
  assert.deepEqual(await service.getAppIdentities(client, ['user-1']), [userRow]);
  assert.deepEqual(await service.getAppIdentities(client, []), []);
  assert.equal(await service.getActivePlanPointer(client, 'user-1'), 'plan-1');

  assert.deepEqual(calls, [
    ['findUnique', { where: { id: 'user-1' } }],
    ['findUnique', { where: { id: 'user-1' }, select: appIdentitySelect }],
    ['findMany', { where: { id: { in: ['user-1'] } }, select: appIdentitySelect }],
    ['findUnique', { where: { id: 'user-1' }, select: { activeWeddingPlanId: true } }],
  ]);
  assert.deepEqual(Object.keys(appIdentitySelect).sort(), [
    'appAvatarUrl', 'appName', 'appRole', 'avatarUrl', 'id', 'name', 'phone', 'role', 'status',
  ]);
});

test('the active plan port writes the pointer and the onboarding columns identity owns', async () => {
  const updates: unknown[] = [];
  const tx = {
    user: {
      update: async (args: unknown) => { updates.push(args); return userRow; },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new IdentityUserPortService();

  await service.setActivePlanPointerInTransaction(tx, 'user-1', 'plan-2');
  await service.setActivePlanPointerInTransaction(tx, 'user-1', null);
  const safe = await service.completeOnboardingInTransaction(tx, 'user-1', {
    activeWeddingPlanId: 'plan-3',
    appRole: AppRole.PROVIDER,
    onboardingPath: OnboardingPath.PROVIDER,
    persona: null,
    onboardingCompletedAt: now,
  });
  assert.equal(safe.id, 'user-1');
  assert.equal('passwordHash' in safe, false);

  assert.deepEqual(updates, [
    { where: { id: 'user-1' }, data: { activeWeddingPlanId: 'plan-2' } },
    { where: { id: 'user-1' }, data: { activeWeddingPlanId: null } },
    {
      where: { id: 'user-1' },
      data: {
        activeWeddingPlanId: 'plan-3',
        appRole: AppRole.PROVIDER,
        onboardingPath: OnboardingPath.PROVIDER,
        persona: null,
        onboardingCompletedAt: now,
      },
    },
  ]);
});

test('the identity user public modules expose only their port tokens bound to the internal implementation', () => {
  const metadata = (module: unknown, key: string) => Reflect.getMetadata(key, module as object);
  assert.deepEqual(metadata(UserReadPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: USER_READ_PORT, useExisting: USER_READ_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(UserReadPublicModule, MODULE_METADATA.EXPORTS), [USER_READ_PORT]);
  assert.deepEqual(metadata(ActivePlanPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: ACTIVE_PLAN_PORT, useExisting: ACTIVE_PLAN_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(ActivePlanPublicModule, MODULE_METADATA.EXPORTS), [ACTIVE_PLAN_PORT]);
  assert.deepEqual(metadata(IdentityUserInternalModule, MODULE_METADATA.PROVIDERS), [
    IdentityUserPortService,
    { provide: USER_READ_IMPLEMENTATION, useExisting: IdentityUserPortService },
    { provide: ACTIVE_PLAN_IMPLEMENTATION, useExisting: IdentityUserPortService },
  ]);
});
