import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpPurpose } from '@prisma/client';
import { AuthService } from '../src/auth/auth.service';

const safeOtpUnavailableMessage =
  'خدمة التحقق غير مفعلة حاليًا. حاول لاحقًا.';

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

function createService() {
  const otps: StoredOtp[] = [];
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
      findFirst: async () => null,
      update: async () => {
        throw new Error('user.update should not be called in this test');
      },
    },
  };
  const jwtService = { sign: () => 'test-token' };
  return new AuthService(prisma as any, jwtService as any);
}

async function withEnv(
  env: Record<string, string | undefined>,
  action: () => Promise<void>,
) {
  const previous = new Map<string, string | undefined>();
  for (const key of Object.keys(env)) {
    previous.set(key, process.env[key]);
    if (env[key] === undefined) {
      delete process.env[key];
    } else {
      process.env[key] = env[key];
    }
  }

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

test('dev OTP request succeeds without a WhatsApp provider', async () => {
  await withEnv(
    {
      AUTH_OTP_MODE: 'dev',
      AUTH_DEV_OTP_CODE: '123456',
      NODE_ENV: 'test',
    },
    async () => {
      const service = createService();
      const response = await service.requestOtp({
        phone: '777123456',
        purpose: OtpPurpose.VERIFY_PHONE,
      });

      assert.equal(response.delivery, 'LOCAL_DEV');
      assert.equal(response.code, '123456');
      assert.equal(
        response.message,
        'رمز التحقق مؤقت للتجربة المحلية: 123456',
      );
      assert.ok(response.expiresAt instanceof Date);
    },
  );
});

test('dev OTP verifies with the configured development code', async () => {
  await withEnv(
    {
      AUTH_OTP_MODE: 'dev',
      AUTH_DEV_OTP_CODE: '654321',
      NODE_ENV: 'test',
    },
    async () => {
      const service = createService();
      await service.requestOtp({
        phone: '777123456',
        purpose: OtpPurpose.VERIFY_PHONE,
      });

      const response = await service.verifyOtp({
        phone: '777123456',
        purpose: OtpPurpose.VERIFY_PHONE,
        code: '654321',
      });

      assert.equal(response.verified, true);
      assert.equal(response.purpose, OtpPurpose.VERIFY_PHONE);
    },
  );
});

test('development OTP code is rejected outside dev OTP mode', async () => {
  await withEnv(
    {
      AUTH_OTP_MODE: 'dev',
      AUTH_DEV_OTP_CODE: '123456',
      NODE_ENV: 'test',
    },
    async () => {
      const service = createService();
      await service.requestOtp({
        phone: '777123456',
        purpose: OtpPurpose.VERIFY_PHONE,
      });

      process.env.AUTH_OTP_MODE = 'whatsapp';
      await assert.rejects(
        () =>
          service.verifyOtp({
            phone: '777123456',
            purpose: OtpPurpose.VERIFY_PHONE,
            code: '123456',
          }),
        /OTP code is invalid or expired/,
      );
    },
  );
});

test('production with unconfigured OTP returns a safe user-facing error', async () => {
  await withEnv(
    {
      AUTH_OTP_MODE: undefined,
      AUTH_DEV_OTP_CODE: undefined,
      NODE_ENV: 'production',
    },
    async () => {
      const service = createService();
      await assert.rejects(
        () =>
          service.requestOtp({
            phone: '777123456',
            purpose: OtpPurpose.VERIFY_PHONE,
          }),
        (error: any) => error.message === safeOtpUnavailableMessage,
      );
    },
  );
});

test('production does not enable dev OTP even if AUTH_OTP_MODE is dev', async () => {
  await withEnv(
    {
      AUTH_OTP_MODE: 'dev',
      AUTH_DEV_OTP_CODE: '123456',
      NODE_ENV: 'production',
    },
    async () => {
      const service = createService();
      await assert.rejects(
        () =>
          service.requestOtp({
            phone: '777123456',
            purpose: OtpPurpose.VERIFY_PHONE,
          }),
        (error: any) => error.message === safeOtpUnavailableMessage,
      );
    },
  );
});
