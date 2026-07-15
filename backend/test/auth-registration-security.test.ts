import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { OtpPurpose } from '@prisma/client';
import * as bcryptjs from 'bcryptjs';
import { AuthService } from '../src/auth/auth.service';
import { JwtStrategy } from '../src/auth/jwt.strategy';

function createHarness() {
  const otps: any[] = [];
  const users: any[] = [];
  const refreshTokens: any[] = [];
  const lookupEvents: string[] = [];
  let otpSequence = 0;
  let userSequence = 0;
  let planInvite: any = null;

  const prisma: any = {
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
          id: `otp-${++otpSequence}`,
          attempts: 0,
          consumedAt: null,
          createdAt: new Date(Date.now() + otpSequence),
          updatedAt: new Date(),
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
    },
    user: {
      findFirst: async ({ where }: any) => {
        lookupEvents.push('user');
        const clauses: any[] = where.OR ?? [where];
        return (
          users.find((user) =>
            clauses.some(
              (clause) =>
                (typeof clause.phone === 'string'
                  ? clause.phone === user.phone
                  : clause.phone?.equals === user.phone ||
                    clause.phone?.in?.includes(user.phone)) ||
                (clause.email?.equals ?? clause.email) === user.email,
            ),
          ) ?? null
        );
      },
      create: async ({ data }: any) => {
        const now = new Date();
        const user = {
          id: `user-${++userSequence}`,
          role: 'USER',
          appRole: 'WEDDING_USER',
          status: 'ACTIVE',
          avatarUrl: null,
          locale: 'ar',
          activeWeddingPlanId: null,
          onboardingPath: null,
          persona: null,
          onboardingCompletedAt: null,
          createdAt: now,
          updatedAt: now,
          ...data,
        };
        users.push(user);
        return user;
      },
      update: async ({ where, data }: any) => {
        const user = users.find((candidate) => candidate.id === where.id);
        assert.ok(user);
        Object.assign(user, data, { updatedAt: new Date() });
        return user;
      },
    },
    refreshToken: {
      create: async ({ data }: any) => {
        const token = { id: `refresh-${refreshTokens.length + 1}`, ...data };
        refreshTokens.push(token);
        return token;
      },
    },
    planInvite: {
      findFirst: async ({ where }: any) => {
        if (!planInvite || planInvite.normalizedPhone !== where.normalizedPhone) {
          return null;
        }
        if (where.acceptedAt === null && planInvite.acceptedAt !== null) return null;
        if (where.declinedAt === null && planInvite.declinedAt !== null) return null;
        if (where.revokedAt === null && planInvite.revokedAt !== null) return null;
        if (where.expiresAt?.gt && planInvite.expiresAt <= where.expiresAt.gt) {
          return null;
        }
        return planInvite;
      },
    },
    $transaction: async (action: any) => action(prisma),
  };

  return {
    service: new AuthService(
      prisma,
      { sign: () => 'signed-access-token' } as any,
      {
        assertAllowed: async () => undefined,
        recordFailure: async () => undefined,
        clear: async () => undefined,
      } as any,
    ),
    users,
    otps,
    refreshTokens,
    lookupEvents,
    addUser: async (phone: string, verified: boolean, email: string | null = null) =>
      prisma.user.create({
        data: {
          name: 'Existing User',
          phone,
          email,
          passwordHash: await bcryptjs.hash('secret123', 4),
          phoneVerifiedAt: verified ? new Date() : null,
          lastLoginAt: null,
        },
      }),
    setPlanInvite: (value: any) => {
      planInvite = value;
    },
  };
}

async function withDevOtp(action: () => Promise<void>) {
  const previous = {
    mode: process.env.AUTH_OTP_MODE,
    code: process.env.AUTH_DEV_OTP_CODE,
    nodeEnv: process.env.NODE_ENV,
  };
  process.env.AUTH_OTP_MODE = 'dev';
  process.env.AUTH_DEV_OTP_CODE = '123456';
  process.env.NODE_ENV = 'test';
  try {
    await action();
  } finally {
    if (previous.mode === undefined) delete process.env.AUTH_OTP_MODE;
    else process.env.AUTH_OTP_MODE = previous.mode;
    if (previous.code === undefined) delete process.env.AUTH_DEV_OTP_CODE;
    else process.env.AUTH_DEV_OTP_CODE = previous.code;
    if (previous.nodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previous.nodeEnv;
  }
}

test('registration stays pending and sessionless until the REGISTER OTP is consumed', async () => {
  await withDevOtp(async () => {
    const { service, users, refreshTokens } = createHarness();
    const pending = await service.startRegistration({
      name: 'New User',
      phone: '777123456',
      password: 'secret123',
    });

    assert.equal('registrationPending' in pending, true);
    assert.equal(users.length, 0);
    assert.equal(refreshTokens.length, 0);

    await assert.rejects(
      () =>
        service.completeRegistration({
          name: 'New User',
          phone: '777123456',
          password: 'secret123',
          otpCode: '999999',
        }),
      /OTP code is invalid or expired/,
    );
    assert.equal(users.length, 0, 'an attacker must not pre-claim the phone');
    assert.equal(refreshTokens.length, 0);

    const completed = await service.completeRegistration({
      name: 'New User',
      phone: '777123456',
      password: 'secret123',
      otpCode: '123456',
    });
    assert.equal('accessToken' in completed, true);
    assert.ok(users[0].phoneVerifiedAt);
    assert.equal(refreshTokens.length, 1);
  });
});

test('password login never issues a session to an unverified legacy account', async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, addUser } = createHarness();
    await addUser('+967777123456', false);
    await assert.rejects(
      () => service.login({ phone: '777123456', password: 'secret123' }),
      /Phone verification is required/,
    );
    assert.equal(refreshTokens.length, 0);
  });
});

test('password login prefers the canonical phone row over a legacy duplicate', async () => {
  await withDevOtp(async () => {
    const { service, users, addUser } = createHarness();
    const legacy = await addUser('777123456', true);
    legacy.passwordHash = await bcryptjs.hash('different-password', 4);
    await addUser('+967777123456', true);

    const response = await service.login({
      phone: '777123456',
      password: 'secret123',
    });

    assert.equal('accessToken' in response, true);
    assert.equal(users.length, 2);
  });
});

test('registration start does not disclose an existing phone', async () => {
  await withDevOtp(async () => {
    const { service, addUser } = createHarness();
    await addUser('+967777123456', true);
    const response = await service.startRegistration({
      name: 'Probe',
      phone: '777123456',
      password: 'secret123',
    });
    assert.equal(response.registrationPending, true);
    assert.equal(response.purpose, OtpPurpose.REGISTER);
  });
});

test('invalid registration OTP does not disclose existing phone or email', async () => {
  await withDevOtp(async () => {
    const scenarios = [
      {
        existingPhone: '+967777123456',
        existingEmail: null,
        attemptedPhone: '777123456',
        attemptedEmail: undefined,
      },
      {
        existingPhone: '+967733333333',
        existingEmail: 'existing@example.com',
        attemptedPhone: '777123456',
        attemptedEmail: 'existing@example.com',
      },
      {
        existingPhone: null,
        existingEmail: null,
        attemptedPhone: '777123456',
        attemptedEmail: 'unknown@example.com',
      },
    ];

    const errors: Array<{ status: number; message: string }> = [];
    for (const scenario of scenarios) {
      const { service, addUser } = createHarness();
      if (scenario.existingPhone) {
        await addUser(
          scenario.existingPhone,
          true,
          scenario.existingEmail,
        );
      }
      await service.startRegistration({
        name: 'Probe',
        phone: scenario.attemptedPhone,
        email: scenario.attemptedEmail,
        password: 'secret123',
      });

      try {
        await service.completeRegistration({
          name: 'Probe',
          phone: scenario.attemptedPhone,
          email: scenario.attemptedEmail,
          password: 'secret123',
          otpCode: '999999',
        });
        assert.fail('invalid OTP must be rejected');
      } catch (error: any) {
        errors.push({ status: error.getStatus(), message: error.message });
      }
    }

    assert.deepEqual(errors, [
      { status: 400, message: 'OTP code is invalid or expired' },
      { status: 400, message: 'OTP code is invalid or expired' },
      { status: 400, message: 'OTP code is invalid or expired' },
    ]);
  });
});

test('registration verifies OTP before checking identifier conflicts', async () => {
  await withDevOtp(async () => {
    const { service, addUser, lookupEvents } = createHarness();
    await addUser('+967777123456', true, 'existing@example.com');
    await service.startRegistration({
      name: 'Probe',
      phone: '777123456',
      email: 'existing@example.com',
      password: 'secret123',
    });
    lookupEvents.length = 0;

    await assert.rejects(
      () =>
        service.completeRegistration({
          name: 'Probe',
          phone: '777123456',
          email: 'existing@example.com',
          password: 'secret123',
          otpCode: '999999',
        }),
      /OTP code is invalid or expired/,
    );

    assert.deepEqual(
      lookupEvents,
      [],
      'identifier lookup must not run until the phone OTP is valid',
    );

    await assert.rejects(
      () =>
        service.completeRegistration({
          name: 'Probe',
          phone: '777123456',
          email: 'existing@example.com',
          password: 'secret123',
          otpCode: '123456',
        }),
      /Phone or email already registered/,
    );
    assert.deepEqual(
      lookupEvents,
      ['user'],
      'identifier conflicts are checked only after valid phone proof',
    );
  });
});

test('one OTP can create at most one concurrent LOGIN session', async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, addUser } = createHarness();
    await addUser('+967777123456', false);
    await service.requestOtp({
      phone: '777123456',
      purpose: OtpPurpose.LOGIN,
    });

    const attempts = await Promise.allSettled([
      service.verifyOtp({
        phone: '777123456',
        purpose: OtpPurpose.LOGIN,
        code: '123456',
      }),
      service.verifyOtp({
        phone: '777123456',
        purpose: OtpPurpose.LOGIN,
        code: '123456',
      }),
    ]);

    assert.equal(attempts.filter((result) => result.status === 'fulfilled').length, 1);
    assert.equal(attempts.filter((result) => result.status === 'rejected').length, 1);
    assert.equal(refreshTokens.length, 1);
  });
});

test('LOGIN OTP provisions an invited participant only from a live pending invite', async () => {
  await withDevOtp(async () => {
    const { service, users, setPlanInvite } = createHarness();
    setPlanInvite({
      id: 'invite-active',
      normalizedPhone: '+967777123456',
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await service.requestOtp({
      phone: '777123456',
      purpose: OtpPurpose.LOGIN,
    });
    const result = await service.verifyOtp({
      phone: '777123456',
      purpose: OtpPurpose.LOGIN,
      code: '123456',
    });

    assert.equal('accessToken' in result, true);
    assert.equal(users.length, 1);
  });
});

test('historical invites cannot create a new participant account', async () => {
  await withDevOtp(async () => {
    const historicalStates = [
      { acceptedAt: new Date(), declinedAt: null, revokedAt: null, expiresAt: new Date(Date.now() + 60_000) },
      { acceptedAt: null, declinedAt: new Date(), revokedAt: null, expiresAt: new Date(Date.now() + 60_000) },
      { acceptedAt: null, declinedAt: null, revokedAt: new Date(), expiresAt: new Date(Date.now() + 60_000) },
      { acceptedAt: null, declinedAt: null, revokedAt: null, expiresAt: new Date(Date.now() - 60_000) },
    ];

    for (const [index, state] of historicalStates.entries()) {
      const { service, users, setPlanInvite } = createHarness();
      setPlanInvite({
        id: `invite-historical-${index}`,
        normalizedPhone: '+967777123456',
        ...state,
      });
      await service.requestOtp({
        phone: '777123456',
        purpose: OtpPurpose.LOGIN,
      });

      await assert.rejects(
        () =>
          service.verifyOtp({
            phone: '777123456',
            purpose: OtpPurpose.LOGIN,
            code: '123456',
          }),
        /OTP code is invalid or expired/,
      );
      assert.equal(users.length, 0);
    }
  });
});

test('an old JWT cannot access protected routes for an unverified account', async () => {
  const previousSecret = process.env.JWT_SECRET;
  process.env.JWT_SECRET = 'test-jwt-secret-with-sufficient-length';
  try {
    const strategy = new JwtStrategy({
      user: {
        findUnique: async () => ({
          id: 'legacy-user',
          status: 'ACTIVE',
          phoneVerifiedAt: null,
        }),
      },
    } as any);
    await assert.rejects(
      () => strategy.validate({ sub: 'legacy-user', phone: '+967777123456' }),
      /unverified/,
    );
  } finally {
    if (previousSecret === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previousSecret;
  }
});
