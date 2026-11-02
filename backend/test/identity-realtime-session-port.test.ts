import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import { AuthSessionScope, UserRole, UserStatus } from '@prisma/client';
import { IdentityRealtimeSessionService } from '../src/modules/identity/infrastructure/identity-realtime-session.service';
import { IDENTITY_REALTIME_SESSION_IMPLEMENTATION } from '../src/modules/identity/internal/identity-user.internal.module';
import { IdentityRealtimeSessionPublicModule } from '../src/modules/identity/public/identity-realtime-session-public.module';
import { IDENTITY_REALTIME_SESSION_PORT } from '../src/modules/identity/public/identity-realtime-session.port';

// The chat gateway used to read the user and the refresh-token session
// itself. Identity decides whether an account may hold a realtime channel,
// mirroring the HTTP session strategy.

const now = new Date('2026-09-17T08:00:00.000Z');
const userRow = {
  id: 'user-1',
  name: 'Person',
  phone: '+967700000000',
  email: null,
  passwordHash: null,
  appPasswordHash: null,
  appAccountActivatedAt: null,
  appName: null,
  appEmail: null,
  appAvatarUrl: null,
  role: UserRole.USER,
  adminRole: null,
  appRole: 'WEDDING_USER',
  status: UserStatus.ACTIVE,
  phoneVerifiedAt: now,
  lastLoginAt: null,
  avatarUrl: null,
  locale: 'ar',
  activeWeddingPlanId: null,
  onboardingPath: null,
  persona: null,
  onboardingCompletedAt: null,
  createdAt: now,
  updatedAt: now,
};

function harness(user: Record<string, unknown> | null, session: { id: string } | null) {
  const calls: Array<[string, unknown]> = [];
  const prisma = {
    user: { findUnique: async (args: unknown) => { calls.push(['user.findUnique', args]); return user; } },
    refreshToken: { findFirst: async (args: unknown) => { calls.push(['refreshToken.findFirst', args]); return session; } },
  };
  return { calls, service: new IdentityRealtimeSessionService(prisma as any) };
}

test('an active, phone-verified account with a live application session gets its authenticated user', async () => {
  const { calls, service } = harness(userRow, { id: 'session-1' });
  const user = await service.findRealtimeSessionUser('user-1', 'session-1');
  assert.equal(user?.id, 'user-1');
  assert.equal('passwordHash' in (user ?? {}), false);
  assert.equal(calls[0]?.[0], 'user.findUnique');
  assert.deepEqual(calls[0]?.[1], { where: { id: 'user-1' } });
  const [, sessionArgs] = calls[1] as [string, { where: Record<string, unknown>; select: unknown }];
  assert.deepEqual({ ...sessionArgs.where, expiresAt: 'checked' }, {
    id: 'session-1',
    userId: 'user-1',
    scope: AuthSessionScope.APPLICATION,
    revokedAt: null,
    expiresAt: 'checked',
  });
  assert.ok((sessionArgs.where.expiresAt as { gt: Date }).gt instanceof Date);
  assert.deepEqual(sessionArgs.select, { id: true });
});

test('a disabled or unverified account, a missing account or a dead session holds no realtime channel', async () => {
  assert.equal(await harness({ ...userRow, status: UserStatus.DISABLED }, { id: 'session-1' }).service.findRealtimeSessionUser('user-1', 'session-1'), null);
  assert.equal(await harness({ ...userRow, phoneVerifiedAt: null }, { id: 'session-1' }).service.findRealtimeSessionUser('user-1', 'session-1'), null);
  assert.equal(await harness(null, { id: 'session-1' }).service.findRealtimeSessionUser('user-1', 'session-1'), null);
  assert.equal(await harness(userRow, null).service.findRealtimeSessionUser('user-1', 'session-1'), null);
  assert.equal(await harness(userRow, null).service.isApplicationSessionLive('user-1', 'session-1'), false);
  assert.equal(await harness(userRow, { id: 'session-1' }).service.isApplicationSessionLive('user-1', 'session-1'), true);
});

test('the realtime session public module exposes only its port token bound to the internal implementation', () => {
  const metadata = (module: unknown, key: string) => Reflect.getMetadata(key, module as object);
  assert.deepEqual(metadata(IdentityRealtimeSessionPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: IDENTITY_REALTIME_SESSION_PORT, useExisting: IDENTITY_REALTIME_SESSION_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(IdentityRealtimeSessionPublicModule, MODULE_METADATA.EXPORTS), [IDENTITY_REALTIME_SESSION_PORT]);
});
