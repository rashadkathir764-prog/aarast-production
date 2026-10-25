import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import { AppRole, OnboardingPath, UserRole, UserStatus, type Prisma } from '@prisma/client';
import {
  ACTIVE_PLAN_IMPLEMENTATION,
  ASSISTANT_QUOTA_IMPLEMENTATION,
  IDENTITY_ADMIN_IMPLEMENTATION,
  IDENTITY_REALTIME_SESSION_IMPLEMENTATION,
  IdentityUserInternalModule,
  PROVIDER_ACCOUNT_IMPLEMENTATION,
  USER_READ_IMPLEMENTATION,
} from '../src/modules/identity/internal/identity-user.internal.module';
import { AssistantQuotaService } from '../src/modules/identity/infrastructure/assistant-quota.service';
import { IdentityAdminService } from '../src/modules/identity/infrastructure/identity-admin.service';
import { AssistantQuotaPublicModule } from '../src/modules/identity/public/assistant-quota-public.module';
import { ASSISTANT_QUOTA_PORT } from '../src/modules/identity/public/assistant-quota.port';
import { IdentityRealtimeSessionService } from '../src/modules/identity/infrastructure/identity-realtime-session.service';
import { IdentityUserPortService } from '../src/modules/identity/infrastructure/identity-user-port.service';
import { ActivePlanPublicModule } from '../src/modules/identity/public/active-plan-public.module';
import { ACTIVE_PLAN_PORT } from '../src/modules/identity/public/active-plan.port';
import { ProviderAccountPublicModule } from '../src/modules/identity/public/provider-account-public.module';
import { PROVIDER_ACCOUNT_PORT } from '../src/modules/identity/public/provider-account.port';
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

test('the user read port resolves an invited phone to its identity, exact number first', async () => {
  const calls: Array<[string, unknown]> = [];
  const byPhone = new Map<string, typeof userRow>([
    ['+967700000001', { ...userRow, id: 'canonical', phone: '+967700000001' }],
    ['700000002', { ...userRow, id: 'legacy', phone: '700000002' }],
  ]);
  const client = {
    user: {
      findUnique: async (args: { where: { phone: string } }) => {
        calls.push(['findUnique', args]);
        return byPhone.get(args.where.phone) ?? null;
      },
      findFirst: async (args: { where: { phone: { in: string[] } } }) => {
        calls.push(['findFirst', args]);
        return args.where.phone.in.map((phone) => byPhone.get(phone)).find(Boolean) ?? null;
      },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new IdentityUserPortService();

  const exact = await service.findAppIdentityByPhone(client, '+967700000001', ['700000001']);
  assert.equal(exact?.id, 'canonical');
  const variant = await service.findAppIdentityByPhone(client, '+967700000002', ['700000002']);
  assert.equal(variant?.id, 'legacy');
  const first = await service.findAppIdentityByPhoneVariants(client, ['+967700000002', '700000002']);
  assert.equal(first?.id, 'legacy');
  assert.equal(await service.findAppIdentityByPhoneVariants(client, ['+967700000009']), null);

  assert.deepEqual(calls, [
    ['findUnique', { where: { phone: '+967700000001' }, select: appIdentitySelect }],
    ['findUnique', { where: { phone: '+967700000002' }, select: appIdentitySelect }],
    ['findFirst', { where: { phone: { in: ['700000002'] } }, select: appIdentitySelect }],
    ['findFirst', { where: { phone: { in: ['+967700000002', '700000002'] } }, select: appIdentitySelect }],
    ['findFirst', { where: { phone: { in: ['+967700000009'] } }, select: appIdentitySelect }],
  ]);
});

test('the user read port decides the invite account setup state without exposing the credential columns', async () => {
  const accounts: Array<Record<string, unknown>> = [];
  let selected: unknown;
  const client = {
    user: {
      findFirst: async (args: { select: unknown }) => { selected = args.select; return accounts.shift() ?? null; },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new IdentityUserPortService();
  const account = (overrides: Record<string, unknown>) => ({
    id: 'user-1',
    role: UserRole.USER,
    phoneVerifiedAt: now,
    appPasswordHash: 'hash',
    appPasswordConfiguredAt: now,
    ...overrides,
  });

  accounts.push(
    account({}),
    account({ appPasswordConfiguredAt: null, appPasswordHash: null }),
    account({ phoneVerifiedAt: null }),
    account({ role: UserRole.ADMIN, phoneVerifiedAt: null }),
    account({ role: UserRole.ADMIN, appPasswordHash: null }),
  );
  const states = [];
  for (let index = 0; index < 5; index += 1) {
    states.push(await service.findInviteAccountByPhoneVariants(client, ['+967700000001']));
  }
  assert.deepEqual(states, [
    { id: 'user-1', appPasswordConfigured: true, accountSetupRequired: false },
    { id: 'user-1', appPasswordConfigured: false, accountSetupRequired: true },
    { id: 'user-1', appPasswordConfigured: true, accountSetupRequired: true },
    { id: 'user-1', appPasswordConfigured: true, accountSetupRequired: false },
    { id: 'user-1', appPasswordConfigured: true, accountSetupRequired: true },
  ]);
  assert.equal(await service.findInviteAccountByPhoneVariants(client, ['+967700000001']), null);
  assert.deepEqual(selected, {
    id: true,
    role: true,
    phoneVerifiedAt: true,
    appPasswordHash: true,
    appPasswordConfiguredAt: true,
  });
});

test('the active plan port clears the pointer only while it still points at the plan', async () => {
  const updates: unknown[] = [];
  const tx = {
    user: {
      updateMany: async (args: unknown) => { updates.push(args); return { count: 1 }; },
    },
  } as unknown as Prisma.TransactionClient;

  await new IdentityUserPortService().clearActivePlanPointerInTransaction(tx, 'user-1', 'plan-1');

  assert.deepEqual(updates, [
    { where: { id: 'user-1', activeWeddingPlanId: 'plan-1' }, data: { activeWeddingPlanId: null } },
  ]);
});

test('the active plan port writes the pointer and the onboarding columns identity owns', async () => {
  const updates: unknown[] = [];
  const tx = {
    user: {
      update: async (args: unknown) => { updates.push(args); return userRow; },
      findUniqueOrThrow: async () => ({ persona: null }),
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

test('B5: a plan made for someone else never replaces who the account is', async () => {
  const written: Array<{ data: { persona: unknown } }> = [];
  const txFor = (persona: string | null) =>
    ({
      user: {
        update: async (args: { data: { persona: unknown } }) => {
          written.push(args);
          return userRow;
        },
        findUniqueOrThrow: async () => ({ persona }),
      },
    }) as unknown as Prisma.TransactionClient;
  const service = new IdentityUserPortService();
  const input = (persona: 'GROOM' | 'BRIDE' | 'HELPER') => ({
    activeWeddingPlanId: 'plan-3',
    appRole: AppRole.WEDDING_USER,
    onboardingPath: OnboardingPath.USER,
    persona,
    onboardingCompletedAt: now,
  });
  // سلمى (a bride) makes a plan for her brother: she stays the bride.
  await service.completeOnboardingInTransaction(txFor('BRIDE'), 'user-1', input('HELPER') as never);
  // An account that knew nothing takes what it chose.
  await service.completeOnboardingInTransaction(txFor(null), 'user-1', input('HELPER') as never);
  // A groom or a bride always says who they are.
  await service.completeOnboardingInTransaction(txFor('HELPER'), 'user-1', input('GROOM') as never);
  assert.deepEqual(
    written.map((args) => args.data.persona),
    ['BRIDE', 'HELPER', 'GROOM'],
  );
});

// The provider application used to change the applicant's role columns
// itself. Identity decides eligibility and performs the promotion: an
// ordinary user or provider gains the PROVIDER roles; an admin keeps ADMIN
// and gains the PROVIDER app role only with an application password.
test('the provider account port promotes an eligible application identity and refuses the rest', async () => {
  const attempts: unknown[] = [];
  const outcomes = [1, 0, 1, 0, 0];
  const tx = {
    user: {
      updateMany: async (args: unknown) => { attempts.push(args); return { count: outcomes.shift() ?? 0 }; },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new IdentityUserPortService();

  assert.equal(await service.promoteToProviderInTransaction(tx, 'user-1'), true);
  assert.equal(await service.promoteToProviderInTransaction(tx, 'admin-1'), true);
  assert.equal(await service.promoteToProviderInTransaction(tx, 'user-9'), false);

  const userPromotion = (id: string) => ({
    where: { id, status: UserStatus.ACTIVE, role: { in: [UserRole.USER, UserRole.PROVIDER] } },
    data: { role: UserRole.PROVIDER, appRole: AppRole.PROVIDER },
  });
  const adminPromotion = (id: string) => ({
    where: { id, status: UserStatus.ACTIVE, role: UserRole.ADMIN, appPasswordHash: { not: null } },
    data: { appRole: AppRole.PROVIDER },
  });
  assert.deepEqual(attempts, [
    userPromotion('user-1'),
    userPromotion('admin-1'),
    adminPromotion('admin-1'),
    userPromotion('user-9'),
    adminPromotion('user-9'),
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
  assert.deepEqual(metadata(ProviderAccountPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: PROVIDER_ACCOUNT_PORT, useExisting: PROVIDER_ACCOUNT_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(ProviderAccountPublicModule, MODULE_METADATA.EXPORTS), [PROVIDER_ACCOUNT_PORT]);
  // The planning assistant's account quota (V1 checklist 4.12).
  assert.deepEqual(metadata(AssistantQuotaPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: ASSISTANT_QUOTA_PORT, useExisting: ASSISTANT_QUOTA_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(AssistantQuotaPublicModule, MODULE_METADATA.EXPORTS), [ASSISTANT_QUOTA_PORT]);
  assert.deepEqual(metadata(IdentityUserInternalModule, MODULE_METADATA.PROVIDERS), [
    IdentityUserPortService,
    IdentityRealtimeSessionService,
    IdentityAdminService,
    AssistantQuotaService,
    { provide: USER_READ_IMPLEMENTATION, useExisting: IdentityUserPortService },
    { provide: ACTIVE_PLAN_IMPLEMENTATION, useExisting: IdentityUserPortService },
    { provide: PROVIDER_ACCOUNT_IMPLEMENTATION, useExisting: IdentityUserPortService },
    { provide: IDENTITY_REALTIME_SESSION_IMPLEMENTATION, useExisting: IdentityRealtimeSessionService },
    // The back office's account administration (identity-admin.port.ts).
    { provide: IDENTITY_ADMIN_IMPLEMENTATION, useExisting: IdentityAdminService },
    { provide: ASSISTANT_QUOTA_IMPLEMENTATION, useExisting: AssistantQuotaService },
  ]);
});
