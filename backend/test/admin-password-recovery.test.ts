import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AuthSessionScope, OtpPurpose } from '@prisma/client';
import * as bcryptjs from 'bcryptjs';
import { AuthService } from '../src/auth/auth.service';

type StoredUser = ReturnType<typeof userFixture>;

function userFixture(overrides: Record<string, unknown> = {}) {
  const now = new Date();
  return {
    id: 'admin-1',
    name: 'Administrator',
    phone: '+967777123456',
    email: null,
    passwordHash: 'old-admin-hash',
    appPasswordHash: 'separate-app-hash',
    appName: 'Application user',
    appEmail: null,
    appAvatarUrl: null,
    role: 'ADMIN',
    adminRole: 'SUPER_ADMIN',
    appRole: 'WEDDING_USER',
    status: 'ACTIVE',
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
    ...overrides,
  };
}

function createHarness(candidate: StoredUser | null) {
  const users = candidate ? [candidate] : [];
  const otps: any[] = [];
  const resetChallenges: any[] = [];
  const adminLoginChallenges = [
    { id: 'login-challenge-1', userId: candidate?.id, consumedAt: null },
  ];
  const refreshTokens = [
    {
      id: 'refresh-1',
      userId: candidate?.id,
      scope: AuthSessionScope.ADMIN,
      revokedAt: null,
    },
    {
      id: 'refresh-app-1',
      userId: candidate?.id,
      scope: AuthSessionScope.APPLICATION,
      revokedAt: null,
    },
  ];
  const loginThrottles = [{ subjectHash: 'placeholder' }];
  let otpSequence = 0;
  let challengeSequence = 0;

  const prisma: any = {
    user: {
      findFirst: async ({ where }: any) => {
        const direct = typeof where.phone === 'string' ? where.phone : null;
        const variants: string[] = where.phone?.in ?? [];
        return (
          users.find(
            (user) => user.phone === direct || variants.includes(user.phone),
          ) ?? null
        );
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const user of users) {
          if (where.id !== undefined && where.id !== user.id) continue;
          if (where.role !== undefined && where.role !== user.role) continue;
          if (where.status !== undefined && where.status !== user.status) continue;
          Object.assign(user, data, { updatedAt: new Date() });
          count += 1;
        }
        return { count };
      },
    },
    otpCode: {
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const otp of otps) {
          if (where.id !== undefined && where.id !== otp.id) continue;
          if (where.phone !== undefined && where.phone !== otp.phone) continue;
          if (
            where.purpose !== undefined &&
            typeof where.purpose === 'string' &&
            where.purpose !== otp.purpose
          ) continue;
          if (where.purpose?.in && !where.purpose.in.includes(otp.purpose)) {
            continue;
          }
          if (where.consumedAt !== undefined && where.consumedAt !== otp.consumedAt) {
            continue;
          }
          if (where.expiresAt?.gt && otp.expiresAt <= where.expiresAt.gt) continue;
          if (where.attempts?.lt !== undefined && otp.attempts >= where.attempts.lt) {
            continue;
          }
          if (data.attempts?.increment) otp.attempts += data.attempts.increment;
          Object.assign(otp, { ...data, attempts: otp.attempts });
          count += 1;
        }
        return { count };
      },
      create: async ({ data }: any) => {
        const otp = {
          id: `otp-${++otpSequence}`,
          attempts: 0,
          consumedAt: null,
          createdAt: new Date(Date.now() + otpSequence),
          ...data,
        };
        otps.push(otp);
        return otp;
      },
      findFirst: async ({ where }: any) =>
        [...otps]
          .reverse()
          .find(
            (otp) =>
              otp.phone === where.phone &&
              otp.purpose === where.purpose &&
              otp.consumedAt === where.consumedAt,
          ) ?? null,
      findUniqueOrThrow: async ({ where }: any) => {
        const otp = otps.find((item) => item.id === where.id);
        if (!otp) throw new Error('OTP not found');
        return otp;
      },
    },
    adminPasswordResetChallenge: {
      create: async ({ data }: any) => {
        const challenge = {
          id: `reset-${++challengeSequence}`,
          attempts: 0,
          maxAttempts: 5,
          consumedAt: null,
          createdAt: new Date(),
          ...data,
        };
        resetChallenges.push(challenge);
        return challenge;
      },
      findUnique: async ({ where }: any) => {
        const challenge = resetChallenges.find(
          (item) => item.tokenHash === where.tokenHash,
        );
        if (!challenge) return null;
        return {
          ...challenge,
          user: users.find((user) => user.id === challenge.userId) ?? null,
          otp: otps.find((otp) => otp.id === challenge.otpId) ?? null,
        };
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const challenge of resetChallenges) {
          if (where.id !== undefined && where.id !== challenge.id) continue;
          if (where.userId !== undefined && where.userId !== challenge.userId) continue;
          if (
            where.subjectHash !== undefined &&
            where.subjectHash !== challenge.subjectHash
          ) {
            continue;
          }
          if (
            where.consumedAt !== undefined &&
            where.consumedAt !== challenge.consumedAt
          ) {
            continue;
          }
          if (where.expiresAt?.gt && challenge.expiresAt <= where.expiresAt.gt) {
            continue;
          }
          if (
            where.attempts?.lt !== undefined &&
            challenge.attempts >= where.attempts.lt
          ) {
            continue;
          }
          if (
            where.attempts?.gte !== undefined &&
            challenge.attempts < where.attempts.gte
          ) {
            continue;
          }
          if (data.attempts?.increment) {
            challenge.attempts += data.attempts.increment;
          }
          Object.assign(challenge, { ...data, attempts: challenge.attempts });
          count += 1;
        }
        return { count };
      },
    },
    refreshToken: {
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const token of refreshTokens) {
          if (token.userId !== where.userId) continue;
          if (where.scope !== undefined && token.scope !== where.scope) continue;
          if (where.revokedAt === null && token.revokedAt !== null) continue;
          Object.assign(token, data);
          count += 1;
        }
        return { count };
      },
    },
    adminLoginChallenge: {
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const challenge of adminLoginChallenges) {
          if (challenge.userId !== where.userId) continue;
          if (where.consumedAt === null && challenge.consumedAt !== null) continue;
          Object.assign(challenge, data);
          count += 1;
        }
        return { count };
      },
    },
    loginThrottle: {
      deleteMany: async () => {
        const count = loginThrottles.length;
        loginThrottles.length = 0;
        return { count };
      },
    },
    $transaction: async (action: any) => action(prisma),
  };

  const service = new AuthService(
    prisma,
    { sign: () => 'unused-token' } as any,
    { clear: async () => undefined } as any,
    { consume: async () => undefined } as any,
  );
  return {
    service,
    users,
    otps,
    resetChallenges,
    refreshTokens,
    adminLoginChallenges,
    loginThrottles,
  };
}

async function withOtpEnv(
  mode: 'dev' | 'openwa' | 'disabled',
  action: () => Promise<void>,
) {
  const keys = [
    'AUTH_OTP_MODE',
    'AUTH_DEV_OTP_CODE',
    'NODE_ENV',
    'OPENWA_BASE_URL',
    'OPENWA_SESSION_ID',
    'OPENWA_API_KEY',
  ];
  const previous = new Map(keys.map((key) => [key, process.env[key]]));
  process.env.AUTH_OTP_MODE = mode;
  process.env.AUTH_DEV_OTP_CODE = '123456';
  process.env.NODE_ENV = 'test';
  process.env.OPENWA_BASE_URL = 'http://openwa:3000';
  process.env.OPENWA_SESSION_ID = 'aarast-otp';
  process.env.OPENWA_API_KEY = 'secure-openwa-test-key-with-32-characters';
  try {
    await action();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

test('admin recovery request is neutral for admin, user, disabled and unknown phones', async () => {
  await withOtpEnv('dev', async () => {
    const candidates = [
      userFixture(),
      userFixture({ id: 'user-1', role: 'USER', adminRole: null }),
      userFixture({ id: 'disabled-1', status: 'DISABLED' }),
      null,
    ];

    for (const candidate of candidates) {
      const { service, otps, resetChallenges } = createHarness(candidate);
      const response = await service.requestAdminPasswordReset({
        phone: '777123456',
      });

      assert.equal(response.accepted, true);
      assert.match(response.challengeToken, /^[a-f0-9]{64}$/);
      assert.equal(response.retryAfterSeconds, 60);
      assert.equal(otps.length, 1);
      assert.equal('phone' in resetChallenges[0], false);
      assert.equal(
        resetChallenges[0].userId,
        candidate?.role === 'ADMIN' && candidate.status === 'ACTIVE'
          ? candidate.id
          : null,
      );
    }
  });
});

test('admin recovery changes only the admin password and revokes every admin session', async () => {
  await withOtpEnv('dev', async () => {
    const admin = userFixture();
    const originalAppHash = admin.appPasswordHash;
    const harness = createHarness(admin);
    const pending = await harness.service.requestAdminPasswordReset({
      phone: '777123456',
    });

    const result = await harness.service.confirmAdminPasswordReset({
      challengeToken: pending.challengeToken,
      code: '123456',
      newPassword: 'New-admin-password-2026',
    });

    assert.deepEqual(result, { reset: true });
    assert.ok(await bcryptjs.compare('New-admin-password-2026', admin.passwordHash));
    assert.equal(admin.appPasswordHash, originalAppHash);
    assert.ok(
      harness.refreshTokens
        .filter((token) => token.scope === AuthSessionScope.ADMIN)
        .every((token) => token.revokedAt),
    );
    assert.ok(
      harness.refreshTokens
        .filter((token) => token.scope === AuthSessionScope.APPLICATION)
        .every((token) => token.revokedAt === null),
    );
    assert.ok(harness.adminLoginChallenges.every((item) => item.consumedAt));
    assert.ok(harness.otps.every((otp) => otp.consumedAt));
    assert.equal(harness.loginThrottles.length, 0);

    await assert.rejects(
      () =>
        harness.service.confirmAdminPasswordReset({
          challengeToken: pending.challengeToken,
          code: '123456',
          newPassword: 'Another-admin-password-2026',
        }),
      (error: any) => error.getResponse?.().code === 'ADMIN_RESET_INVALID_OR_EXPIRED',
    );
  });
});

test('one admin recovery challenge succeeds at most once under concurrency', async () => {
  await withOtpEnv('dev', async () => {
    const harness = createHarness(userFixture());
    const pending = await harness.service.requestAdminPasswordReset({
      phone: '777123456',
    });
    const attempts = await Promise.allSettled([
      harness.service.confirmAdminPasswordReset({
        challengeToken: pending.challengeToken,
        code: '123456',
        newPassword: 'Concurrent-admin-password-1',
      }),
      harness.service.confirmAdminPasswordReset({
        challengeToken: pending.challengeToken,
        code: '123456',
        newPassword: 'Concurrent-admin-password-2',
      }),
    ]);

    assert.equal(attempts.filter((item) => item.status === 'fulfilled').length, 1);
    assert.equal(attempts.filter((item) => item.status === 'rejected').length, 1);
  });
});

test('a definitive transport failure is identical for admin and unknown phones', async () => {
  const originalFetch = globalThis.fetch;
  await withOtpEnv('openwa', async () => {
    globalThis.fetch = async () => new Response('', { status: 401 });
    try {
      for (const candidate of [userFixture(), null]) {
        const harness = createHarness(candidate);
        await assert.rejects(
          () =>
            harness.service.requestAdminPasswordReset({
              phone: '777123456',
            }),
          (error: any) =>
            error.getStatus?.() === 503 &&
            error.getResponse?.().code === 'OTP_DELIVERY_UNAVAILABLE',
        );
        assert.equal(harness.resetChallenges.length, 0);
        assert.equal(
          harness.otps.filter((otp) => otp.consumedAt === null).length,
          0,
        );
      }
    } finally {
      globalThis.fetch = originalFetch;
    }
  });
});

test('disabled OTP delivery returns the same stable 503 contract for admin recovery', async () => {
  await withOtpEnv('disabled', async () => {
    const harness = createHarness(userFixture());
    await assert.rejects(
      () =>
        harness.service.requestAdminPasswordReset({
          phone: '777123456',
        }),
      (error: any) =>
        error.getStatus?.() === 503 &&
        error.getResponse?.().code === 'OTP_DELIVERY_UNAVAILABLE',
    );
    assert.equal(harness.resetChallenges.length, 0);
    assert.equal(harness.otps.length, 0);
  });
});

test('the public OTP endpoint cannot request the private admin reset purpose', async () => {
  await withOtpEnv('dev', async () => {
    const { service, otps } = createHarness(userFixture());
    await assert.rejects(
      () =>
        service.requestOtp({
          phone: '777123456',
          purpose: OtpPurpose.ADMIN_RESET_PASSWORD,
        }),
      /Unsupported OTP purpose/,
    );
    assert.equal(otps.length, 0);
  });
});
