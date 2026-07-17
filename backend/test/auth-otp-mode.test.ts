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

function createService(otpDispatchQuota?: { consume: (...args: any[]) => Promise<void> }) {
  const otps: StoredOtp[] = [];
  let sequence = 0;
  const verifiedUser: any = {
    id: 'user-1',
    name: 'Verified User',
    phone: '+967777123456',
    email: null,
    passwordHash: 'unused',
    appPasswordHash: null,
    role: 'USER',
    adminRole: null,
    appRole: 'WEDDING_USER',
    status: 'ACTIVE',
    phoneVerifiedAt: new Date(),
    lastLoginAt: null,
    avatarUrl: null,
    locale: 'ar',
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  };
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
        const direct = typeof where.phone === 'string' ? where.phone : null;
        const variants: string[] = where.phone?.in ?? [];
        return direct === verifiedUser.phone || variants.includes(verifiedUser.phone)
          ? verifiedUser
          : null;
      },
      update: async ({ data }: any) => {
        Object.assign(verifiedUser, data);
        return verifiedUser;
      },
    },
    $transaction: async (action: any) => action(prisma),
  };
  const jwtService = { sign: () => 'test-token' };
  return new AuthService(
    prisma as any,
    jwtService as any,
    {} as any,
    otpDispatchQuota as any,
  );
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

test('OpenWA mode consumes the durable quota before delivering a code', async () => {
  const originalFetch = globalThis.fetch;
  const consumed: Array<{ phone: string; ip?: string | null }> = [];
  await withEnv(
    {
      AUTH_OTP_MODE: 'openwa',
      OPENWA_BASE_URL: 'http://openwa:3000',
      OPENWA_SESSION_ID: 'aarast-otp',
      OPENWA_API_KEY: 'a-secure-openwa-api-key-for-tests-only',
      NODE_ENV: 'test',
    },
    async () => {
      globalThis.fetch = async () =>
        new Response(
          JSON.stringify({
            messageId: 'wa-message-id',
            deliveryStatus: 'SENT',
          }),
          {
            status: 201,
            headers: { 'content-type': 'application/json' },
          },
        );
      const service = createService({
        consume: async (phone: string, context: { ip?: string | null }) => {
          consumed.push({ phone, ip: context.ip });
        },
      });

      try {
        const response = await service.requestOtp(
          { phone: '777123456', purpose: OtpPurpose.VERIFY_PHONE },
          { ip: '203.0.113.10' },
        );
        assert.equal(response.delivery, 'WHATSAPP');
        assert.equal(response.code, undefined);
        assert.deepEqual(consumed, [
          { phone: '+967777123456', ip: '203.0.113.10' },
        ]);
      } finally {
        globalThis.fetch = originalFetch;
      }
    },
  );
});

test('OpenWA uncertain delivery keeps the OTP active and returns a safe notice', async () => {
  const originalFetch = globalThis.fetch;
  await withEnv(
    {
      AUTH_OTP_MODE: 'openwa',
      OPENWA_BASE_URL: 'http://openwa:3000',
      OPENWA_SESSION_ID: 'aarast-otp',
      OPENWA_API_KEY: 'a-secure-openwa-api-key-for-tests-only',
      NODE_ENV: 'test',
    },
    async () => {
      globalThis.fetch = async () =>
        new Response(JSON.stringify({ code: 'DELIVERY_UNCERTAIN' }), {
          status: 503,
          headers: { 'content-type': 'application/json' },
        });
      const service = createService({ consume: async () => undefined });

      try {
        const response = await service.requestOtp({
          phone: '777123456',
          purpose: OtpPurpose.RESET_PASSWORD,
        });
        assert.equal(response.delivery, 'WHATSAPP');
        assert.equal(response.code, undefined);
        assert.match(response.message ?? '', /إذا وصلك الرمز/);

        const activeOtp = await (service as any).prisma.otpCode.findFirst({
          where: {
            phone: '+967777123456',
            purpose: OtpPurpose.RESET_PASSWORD,
            consumedAt: null,
          },
        });
        assert.ok(activeOtp, 'the possibly delivered OTP must remain active');
      } finally {
        globalThis.fetch = originalFetch;
      }
    },
  );
});

test('OpenWA gateway failures without a definitive code keep the OTP active', async () => {
  const originalFetch = globalThis.fetch;
  await withEnv(
    {
      AUTH_OTP_MODE: 'openwa',
      OPENWA_BASE_URL: 'http://openwa:3000',
      OPENWA_SESSION_ID: 'aarast-otp',
      OPENWA_API_KEY: 'a-secure-openwa-api-key-for-tests-only',
      NODE_ENV: 'test',
    },
    async () => {
      globalThis.fetch = async () =>
        new Response('<html>bad gateway</html>', {
          status: 502,
          headers: { 'content-type': 'text/html' },
        });
      const service = createService({ consume: async () => undefined });

      try {
        const response = await service.requestOtp({
          phone: '777123456',
          purpose: OtpPurpose.RESET_PASSWORD,
        });
        assert.equal(response.delivery, 'WHATSAPP');
        assert.equal(response.code, undefined);
        const activeOtp = await (service as any).prisma.otpCode.findFirst({
          where: {
            phone: '+967777123456',
            purpose: OtpPurpose.RESET_PASSWORD,
            consumedAt: null,
          },
        });
        assert.ok(activeOtp, 'an OTP behind an unknown gateway failure must remain active');
      } finally {
        globalThis.fetch = originalFetch;
      }
    },
  );
});

test('OpenWA definitive 5xx delivery failures consume the OTP and return 503', async () => {
  const originalFetch = globalThis.fetch;
  await withEnv(
    {
      AUTH_OTP_MODE: 'openwa',
      OPENWA_BASE_URL: 'http://openwa:3000',
      OPENWA_SESSION_ID: 'aarast-otp',
      OPENWA_API_KEY: 'a-secure-openwa-api-key-for-tests-only',
      NODE_ENV: 'test',
    },
    async () => {
      try {
        for (const code of ['NOT_ATTEMPTED', 'REJECTED']) {
          globalThis.fetch = async () =>
            new Response(JSON.stringify({ code }), {
              status: 503,
              headers: { 'content-type': 'application/json' },
            });
          const service = createService({ consume: async () => undefined });
          await assert.rejects(
            () =>
              service.requestOtp({
                phone: '777123456',
                purpose: OtpPurpose.RESET_PASSWORD,
              }),
            (error: any) => error.message === safeOtpUnavailableMessage,
          );
          const activeOtp = await (service as any).prisma.otpCode.findFirst({
            where: {
              phone: '+967777123456',
              purpose: OtpPurpose.RESET_PASSWORD,
              consumedAt: null,
            },
          });
          assert.equal(activeOtp, undefined);
        }
      } finally {
        globalThis.fetch = originalFetch;
      }
    },
  );
});

test('dev OTP mode never consumes the production delivery quota', async () => {
  await withEnv(
    {
      AUTH_OTP_MODE: 'dev',
      AUTH_DEV_OTP_CODE: '123456',
      NODE_ENV: 'test',
    },
    async () => {
      let consumed = false;
      const service = createService({
        consume: async () => {
          consumed = true;
        },
      });
      await service.requestOtp({
        phone: '777123456',
        purpose: OtpPurpose.VERIFY_PHONE,
      });
      assert.equal(consumed, false);
    },
  );
});
