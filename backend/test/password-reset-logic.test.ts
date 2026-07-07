import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpPurpose } from '@prisma/client';
import * as bcryptjs from 'bcryptjs';
import { AuthService } from '../src/auth/auth.service';

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
  status: string;
  phoneVerifiedAt: Date | null;
};

type StoredRefreshToken = {
  id: string;
  userId: string;
  revokedAt: Date | null;
};

function createHarness(options?: { user?: Partial<StoredUser> | null }) {
  const otps: StoredOtp[] = [];
  const refreshTokens: StoredRefreshToken[] = [
    { id: 'rt-1', userId: 'user-1', revokedAt: null },
    { id: 'rt-2', userId: 'user-1', revokedAt: null },
  ];
  const user: StoredUser | null =
    options?.user === null
      ? null
      : {
          id: 'user-1',
          phone: '',
          passwordHash: 'old-hash',
          status: 'ACTIVE',
          phoneVerifiedAt: null,
          ...options?.user,
        };
  let sequence = 0;

  const prisma = {
    otpCode: {
      updateMany: async ({ where, data }: any) => {
        for (const otp of otps) {
          if (
            otp.phone === where.phone &&
            otp.purpose === where.purpose &&
            otp.consumedAt === where.consumedAt &&
            otp.expiresAt > where.expiresAt.gt
          ) {
            Object.assign(otp, data);
          }
        }
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
          if (token.userId === where.userId && token.revokedAt === null) {
            Object.assign(token, data);
            count += 1;
          }
        }
        return Promise.resolve({ count });
      },
    },
    $transaction: async (operations: Promise<unknown>[]) =>
      Promise.all(operations),
  };

  const jwtService = { sign: () => 'test-token' };
  const service = new AuthService(prisma as any, jwtService as any);
  return { service, otps, refreshTokens, user };
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

test('reset confirm sets the new password and revokes all sessions', async () => {
  await withDevOtpEnv(async () => {
    const { service, otps, refreshTokens, user } = createHarness();

    await service.requestPasswordReset({ phone: '777123456' });
    const response = await service.confirmPasswordReset({
      phone: '777123456',
      code: '123456',
      newPassword: 'new-secret-1',
    });

    assert.equal(response.reset, true);
    assert.ok(user);
    assert.notEqual(user.passwordHash, 'old-hash');
    assert.ok(await bcryptjs.compare('new-secret-1', user.passwordHash));
    assert.ok(refreshTokens.every((token) => token.revokedAt !== null));
    assert.ok(otps[0].consumedAt, 'OTP must be consumed after the reset');
  });
});

test('reset confirm with an unknown phone fails with the generic OTP error', async () => {
  await withDevOtpEnv(async () => {
    const { service } = createHarness({ user: null });

    await service.requestPasswordReset({ phone: '777123456' });
    await assert.rejects(
      () =>
        service.confirmPasswordReset({
          phone: '777123456',
          code: '123456',
          newPassword: 'new-secret-1',
        }),
      /OTP code is invalid or expired/,
    );
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

test('reset confirm for a disabled account fails with the generic OTP error', async () => {
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
      /OTP code is invalid or expired/,
    );

    assert.ok(user);
    assert.equal(user.passwordHash, 'old-hash');
  });
});
