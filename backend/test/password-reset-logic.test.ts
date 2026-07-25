import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AuthSessionScope, OtpPurpose } from '@prisma/client';
import * as bcryptjs from 'bcryptjs';
import { AuthService } from '../src/auth/auth.service';
import { otpVerificationsTotal } from '../src/common/observability/metrics';

async function otpOutcomeCount(outcome: string): Promise<number> {
  const metric = await otpVerificationsTotal.get();
  return (
    metric.values.find((row) => row.labels.outcome === outcome)?.value ?? 0
  );
}

type StoredOtp = {
  id: string;
  phone: string;
  purpose: OtpPurpose;
  codeHash: string;
  expiresAt: Date;
  maxAttempts: number;
  attempts: number;
  consumedAt: Date | null;
  createdAt: Date;
};

type StoredUser = {
  id: string;
  phone: string;
  passwordHash: string;
  appPasswordHash: string | null;
  role: string;
  status: string;
  phoneVerifiedAt: Date | null;
};

type StoredRefreshToken = {
  id: string;
  userId: string;
  scope: AuthSessionScope;
  revokedAt: Date | null;
};

function createHarness(options?: { user?: Partial<StoredUser> | null }) {
  const otps: StoredOtp[] = [];
  const refreshTokens: StoredRefreshToken[] = [
    {
      id: 'rt-app',
      userId: 'user-1',
      scope: AuthSessionScope.APPLICATION,
      revokedAt: null,
    },
    {
      id: 'rt-admin',
      userId: 'user-1',
      scope: AuthSessionScope.ADMIN,
      revokedAt: null,
    },
  ];
  const user: StoredUser | null =
    options?.user === null
      ? null
      : {
          id: 'user-1',
          phone: '',
          passwordHash: 'old-hash',
          appPasswordHash: null,
          role: 'USER',
          status: 'ACTIVE',
          phoneVerifiedAt: null,
          ...options?.user,
        };
  let sequence = 0;

  const prisma = {
    otpCode: {
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const otp of otps) {
          const matches =
            (where.id === undefined || otp.id === where.id) &&
            (where.phone === undefined || otp.phone === where.phone) &&
            (where.purpose === undefined || otp.purpose === where.purpose) &&
            (where.consumedAt === undefined ||
              otp.consumedAt === where.consumedAt) &&
            (where.expiresAt?.gt === undefined ||
              otp.expiresAt > where.expiresAt.gt) &&
            (where.attempts?.lt === undefined ||
              otp.attempts < where.attempts.lt);
          if (!matches) continue;
          if (data.attempts?.increment) {
            otp.attempts += data.attempts.increment;
          }
          Object.assign(otp, { ...data, attempts: otp.attempts });
          count += 1;
        }
        return { count };
      },
      create: async ({ data }: any) => {
        const otp = {
          id: `otp-${++sequence}`,
          phone: data.phone,
          purpose: data.purpose,
          codeHash: data.codeHash,
          expiresAt: data.expiresAt,
          maxAttempts: data.maxAttempts,
          attempts: 0,
          consumedAt: null,
          createdAt: new Date(Date.now() + sequence),
        };
        otps.push(otp);
        // Anchor the stored user to the exact normalized phone the service
        // uses, so variant lookup succeeds like in the real database.
        if (user && !user.phone) user.phone = data.phone;
        return otp;
      },
      findFirst: async ({ where }: any) => {
        return [...otps]
          .reverse()
          .find(
            (otp) =>
              otp.phone === where.phone &&
              otp.purpose === where.purpose &&
              otp.consumedAt === where.consumedAt,
          );
      },
      findUnique: async ({ where }: any) =>
        otps.find((otp) => otp.id === where.id) ?? null,
      update: async ({ where, data }: any) => {
        const otp = otps.find((item) => item.id === where.id);
        assert.ok(otp);
        Object.assign(otp, data);
        return otp;
      },
    },
    user: {
      findFirst: async ({ where }: any) => {
        if (!user) return null;
        const variants: string[] = where?.phone?.in ?? [];
        return variants.includes(user.phone) ? user : null;
      },
      update: ({ where, data }: any) => {
        assert.ok(user);
        assert.equal(where.id, user.id);
        Object.assign(user, data);
        return Promise.resolve(user);
      },
    },
    refreshToken: {
      updateMany: ({ where, data }: any) => {
        let count = 0;
        for (const token of refreshTokens) {
          if (
            token.userId === where.userId &&
            token.scope === where.scope &&
            token.revokedAt === null
          ) {
            Object.assign(token, data);
            count += 1;
          }
        }
        return Promise.resolve({ count });
      },
    },
    $transaction: async (input: any) =>
      typeof input === 'function' ? input(prisma) : Promise.all(input),
  };

  const jwtService = { sign: () => 'test-token' };
  const realtimeDisconnects: string[] = [];
  const service = new AuthService(prisma as any, jwtService as any, {
    clear: async () => undefined,
  } as any, { consume: async () => undefined } as any, {
    disconnectUser: (userId: string) => {
      realtimeDisconnects.push(userId);
    },
  } as any);
  return { service, otps, refreshTokens, user, realtimeDisconnects };
}

async function withDevOtpEnv(action: () => Promise<void>) {
  const previous = new Map<string, string | undefined>([
    ['AUTH_OTP_MODE', process.env.AUTH_OTP_MODE],
    ['AUTH_DEV_OTP_CODE', process.env.AUTH_DEV_OTP_CODE],
    ['NODE_ENV', process.env.NODE_ENV],
  ]);
  process.env.AUTH_OTP_MODE = 'dev';
  process.env.AUTH_DEV_OTP_CODE = '123456';
  process.env.NODE_ENV = 'test';
  try {
    await action();
  } finally {
    for (const [key, value] of previous) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
  }
}

test('reset request issues a RESET_PASSWORD OTP without probing accounts', async () => {
  await withDevOtpEnv(async () => {
    const { service, otps } = createHarness({ user: null });

    const response = await service.requestPasswordReset({
      phone: '777123456',
    });

    assert.equal(response.purpose, OtpPurpose.RESET_PASSWORD);
    assert.equal(response.delivery, 'LOCAL_DEV');
    assert.equal(otps.length, 1);
    assert.equal(otps[0].purpose, OtpPurpose.RESET_PASSWORD);
  });
});

test('reset confirm sets the new password and revokes only app sessions', async () => {
  await withDevOtpEnv(async () => {
    const { service, otps, refreshTokens, user, realtimeDisconnects } =
      createHarness();

    await service.requestPasswordReset({ phone: '777123456' });
    const response = await service.confirmPasswordReset({
      phone: '777123456',
      code: '123456',
      newPassword: 'new-secret-1',
    });

    assert.equal(response.reset, true);
    assert.deepEqual(
      realtimeDisconnects,
      ['user-1'],
      'a successful reset must sever the live realtime session',
    );
    assert.ok(user);
    assert.notEqual(user.passwordHash, 'old-hash');
    assert.ok(await bcryptjs.compare('new-secret-1', user.passwordHash));
    assert.ok(
      refreshTokens.find((token) => token.scope === AuthSessionScope.APPLICATION)
        ?.revokedAt,
    );
    assert.equal(
      refreshTokens.find((token) => token.scope === AuthSessionScope.ADMIN)
        ?.revokedAt,
      null,
    );
    assert.ok(otps[0].consumedAt, 'OTP must be consumed after the reset');
  });
});

test('reset confirm reveals a missing app account only after phone proof', async () => {
  await withDevOtpEnv(async () => {
    const { service, realtimeDisconnects } = createHarness({ user: null });

    const successBefore = await otpOutcomeCount('success');
    const rejectedBefore = await otpOutcomeCount('verified_then_rejected');

    await service.requestPasswordReset({ phone: '777123456' });
    await assert.rejects(
      () =>
        service.confirmPasswordReset({
          phone: '777123456',
          code: '123456',
          newPassword: 'new-secret-1',
        }),
      (error: any) =>
        error.getResponse?.().code === 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
    );

    // A proven-but-rejected reset must never inflate the success metric.
    assert.equal(await otpOutcomeCount('success'), successBefore);
    assert.equal(
      await otpOutcomeCount('verified_then_rejected'),
      rejectedBefore + 1,
    );
    // No password changed, so no live session may be torn down.
    assert.deepEqual(realtimeDisconnects, []);
  });
});

test('logging out everywhere severs the application realtime session', async () => {
  await withDevOtpEnv(async () => {
    const { service, realtimeDisconnects } = createHarness();

    await service.logoutAll('user-1');
    assert.deepEqual(realtimeDisconnects, ['user-1']);

    // An admin-scope logout must not tear down the user's application chat.
    await service.logoutAll('user-1', AuthSessionScope.ADMIN);
    assert.deepEqual(realtimeDisconnects, ['user-1']);
  });
});

test('reset confirm with a wrong code keeps the old password', async () => {
  await withDevOtpEnv(async () => {
    const { service, user, refreshTokens } = createHarness();

    await service.requestPasswordReset({ phone: '777123456' });
    await assert.rejects(
      () =>
        service.confirmPasswordReset({
          phone: '777123456',
          code: '999999',
          newPassword: 'new-secret-1',
        }),
      /OTP code is invalid or expired/,
    );

    assert.ok(user);
    assert.equal(user.passwordHash, 'old-hash');
    assert.ok(refreshTokens.every((token) => token.revokedAt === null));
  });
});

test('reset confirm identifies a disabled account only after phone proof', async () => {
  await withDevOtpEnv(async () => {
    const { service, user } = createHarness({ user: { status: 'DISABLED' } });

    await service.requestPasswordReset({ phone: '777123456' });
    await assert.rejects(
      () =>
        service.confirmPasswordReset({
          phone: '777123456',
          code: '123456',
          newPassword: 'new-secret-1',
        }),
      (error: any) =>
        error.getResponse?.().code === 'ACCOUNT_DISABLED_AFTER_PHONE_PROOF',
    );

    assert.ok(user);
    assert.equal(user.passwordHash, 'old-hash');
  });
});

test('general reset never changes an admin password when no app password exists', async () => {
  await withDevOtpEnv(async () => {
    const { service, user } = createHarness({
      user: { role: 'ADMIN', appPasswordHash: null },
    });

    await service.requestPasswordReset({ phone: '777123456' });
    await assert.rejects(
      () =>
        service.confirmPasswordReset({
          phone: '777123456',
          code: '123456',
          newPassword: 'new-application-secret',
        }),
      (error: any) =>
        error.getResponse?.().code === 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
    );

    assert.ok(user);
    assert.equal(user.passwordHash, 'old-hash');
    assert.equal(user.appPasswordHash, null);
  });
});

test('general reset changes only an enrolled admin app password', async () => {
  await withDevOtpEnv(async () => {
    const { service, user, refreshTokens } = createHarness({
      user: { role: 'ADMIN', appPasswordHash: 'old-app-hash' },
    });

    await service.requestPasswordReset({ phone: '777123456' });
    const response = await service.confirmPasswordReset({
      phone: '777123456',
      code: '123456',
      newPassword: 'new-application-secret',
    });

    assert.equal(response.reset, true);
    assert.ok(user);
    assert.equal(user.passwordHash, 'old-hash');
    assert.ok(
      await bcryptjs.compare(
        'new-application-secret',
        user.appPasswordHash!,
      ),
    );
    assert.ok(
      refreshTokens.find((token) => token.scope === AuthSessionScope.APPLICATION)
        ?.revokedAt,
    );
    assert.equal(
      refreshTokens.find((token) => token.scope === AuthSessionScope.ADMIN)
        ?.revokedAt,
      null,
    );
  });
});
