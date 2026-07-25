import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { ValidationPipe } from "@nestjs/common";
import { OtpPurpose, Prisma } from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { AuthService } from "../src/auth/auth.service";
import { RegisterDto } from "../src/auth/dto/register.dto";
import { JwtStrategy } from "../src/auth/jwt.strategy";

const { registerVerified } = require("../scripts/smoke/verified-registration");
const TEST_INVITE_TOKEN = "a".repeat(43);

function createHarness() {
  const otps: any[] = [];
  const users: any[] = [];
  const refreshTokens: any[] = [];
  const signedPayloads: any[] = [];
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
      findUnique: async ({ where }: any) =>
        otps.find((otp) => otp.id === where.id) ?? null,
    },
    user: {
      findFirst: async ({ where }: any) => {
        lookupEvents.push("user");
        const clauses: any[] = where.OR ?? [where];
        return (
          users.find((user) =>
            clauses.some(
              (clause) =>
                (typeof clause.phone === "string"
                  ? clause.phone === user.phone
                  : clause.phone?.equals === user.phone ||
                    clause.phone?.in?.includes(user.phone)) ||
                (clause.email?.equals ?? clause.email) === user.email,
            ),
          ) ?? null
        );
      },
      findUniqueOrThrow: async ({ where }: any) => {
        const user = users.find((candidate) => candidate.id === where.id);
        assert.ok(user);
        return user;
      },
      create: async ({ data }: any) => {
        const now = new Date();
        const user = {
          id: `user-${++userSequence}`,
          role: "USER",
          adminRole: null,
          appRole: "WEDDING_USER",
          status: "ACTIVE",
          appPasswordHash: null,
          appName: null,
          appEmail: null,
          appAvatarUrl: null,
          avatarUrl: null,
          locale: "ar",
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
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const user of users) {
          const roleMatches =
            where.role === undefined ||
            where.role === user.role ||
            where.role?.in?.includes(user.role);
          const matches =
            (where.id === undefined || where.id === user.id) &&
            roleMatches &&
            (where.status === undefined || where.status === user.status) &&
            (where.phoneVerifiedAt === undefined ||
              where.phoneVerifiedAt === user.phoneVerifiedAt) &&
            (where.appPasswordHash === undefined ||
              where.appPasswordHash === user.appPasswordHash);
          if (!matches) continue;
          Object.assign(user, data, { updatedAt: new Date() });
          count += 1;
        }
        return { count };
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
        if (
          !planInvite ||
          planInvite.normalizedPhone !== where.normalizedPhone
        ) {
          return null;
        }
        if (where.tokenHash && planInvite.tokenHash !== where.tokenHash) {
          return null;
        }
        if (where.acceptedAt === null && planInvite.acceptedAt !== null)
          return null;
        if (where.declinedAt === null && planInvite.declinedAt !== null)
          return null;
        if (where.revokedAt === null && planInvite.revokedAt !== null)
          return null;
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
      {
        sign: (payload: any) => {
          signedPayloads.push(payload);
          return 'signed-access-token';
        },
      } as any,
      {
        assertAllowed: async () => undefined,
        reserveAttempt: async () => undefined,
        clear: async () => undefined,
      } as any,
      { consume: async () => undefined } as any,
      { disconnectUser: () => undefined } as any,
    ),
    users,
    otps,
    refreshTokens,
    signedPayloads,
    prisma,
    lookupEvents,
    addUser: async (
      phone: string,
      verified: boolean,
      email: string | null = null,
    ) =>
      prisma.user.create({
        data: {
          name: "Existing User",
          phone,
          email,
          passwordHash: await bcryptjs.hash("secret123", 4),
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
  process.env.AUTH_OTP_MODE = "dev";
  process.env.AUTH_DEV_OTP_CODE = "123456";
  process.env.NODE_ENV = "test";
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

test("registration accepts only phone-owned fields and rejects an email claim", async () => {
  const pipe = new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true,
  });

  await assert.rejects(
    () =>
      pipe.transform(
        {
          name: "New User",
          phone: "777123456",
          password: "secret123",
          email: "unverified@example.com",
        },
        { type: "body", metatype: RegisterDto },
      ),
    (error: any) =>
      error
        .getResponse?.()
        .message?.includes("property email should not exist") === true,
  );
});

test("registration stays pending and sessionless until the REGISTER OTP is consumed", async () => {
  await withDevOtp(async () => {
    const { service, users, refreshTokens } = createHarness();
    const pending = await service.startRegistration({
      name: "New User",
      phone: "777123456",
    });

    assert.equal("registrationPending" in pending, true);
    assert.equal(users.length, 0);
    assert.equal(refreshTokens.length, 0);

    await assert.rejects(
      () =>
        service.completeRegistration({
          name: "New User",
          phone: "777123456",
          password: "secret123",
          otpCode: "999999",
        }),
      /OTP code is invalid or expired/,
    );
    assert.equal(users.length, 0, "an attacker must not pre-claim the phone");
    assert.equal(refreshTokens.length, 0);

    const completed = await service.completeRegistration({
      name: "New User",
      phone: "777123456",
      password: "secret123",
      otpCode: "123456",
    });
    assert.equal("accessToken" in completed, true);
    assert.ok(users[0].phoneVerifiedAt);
    assert.equal(refreshTokens.length, 1);
  });
});

test("correct password exposes only the verification challenge and LOGIN OTP recovers the legacy account", async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, addUser } = createHarness();
    const legacy = await addUser("+967777123456", false);
    await assert.rejects(
      () => service.login({ phone: "777123456", password: "secret123" }),
      (error: any) =>
        error.getStatus?.() === 401 &&
        error.getResponse?.().code === "PHONE_VERIFICATION_REQUIRED",
    );
    assert.equal(refreshTokens.length, 0);

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    const recovered = await service.verifyOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
      code: "123456",
    });

    assert.ok(legacy.phoneVerifiedAt);
    assert.ok(recovered.accessToken);
    assert.ok(recovered.refreshToken);
    assert.equal(recovered.user?.id, legacy.id);
    assert.equal(refreshTokens.length, 1);
  });
});

test("an admin needs a separate application password for a wedding-app bearer", async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, addUser } = createHarness();
    const admin = await addUser("+967777123456", true);
    admin.role = "ADMIN";
    admin.adminRole = "SUPER_ADMIN";

    await assert.rejects(
      () =>
        service.login({
          phone: "777123456",
          password: "secret123",
        }),
      /Invalid credentials/,
    );
    assert.equal(refreshTokens.length, 0);

    admin.appPasswordHash = await bcryptjs.hash("application-secret", 4);
    const response = await service.login({
      phone: "777123456",
      password: "application-secret",
    });
    assert.equal(response.user.adminRole, null);
    assert.deepEqual(response.user.adminPermissions, []);
    assert.match(response.refreshToken, /^aarast_app_/);
    assert.equal(refreshTokens.length, 1);
  });
});

test("general OTP login gives an admin only a standard wedding-app session", async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, signedPayloads, addUser } = createHarness();
    const admin = await addUser('+967777123456', true);
    admin.role = 'ADMIN';
    admin.adminRole = 'SUPER_ADMIN';
    admin.appPasswordHash = await bcryptjs.hash('application-secret', 4);
    admin.appName = 'Wedding App Admin';

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });

    const response = await service.verifyOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
      code: "123456",
    });

    assert.ok(response.accessToken);
    assert.ok(response.refreshToken);
    assert.equal(response.user?.adminRole, null);
    assert.equal(response.user?.role, "USER");
    assert.equal(response.user?.name, "Wedding App Admin");
    assert.deepEqual(response.user?.adminPermissions, []);
    assert.match(response.refreshToken, /^aarast_app_/);
    assert.equal(refreshTokens.length, 1);
    assert.equal(signedPayloads[0]?.scope, 'application');
    assert.equal(signedPayloads[0]?.amr, undefined);
    assert.equal(signedPayloads[0]?.sid, undefined);
  });
});

test("password login prefers the canonical phone row over a legacy duplicate", async () => {
  await withDevOtp(async () => {
    const { service, users, addUser } = createHarness();
    const legacy = await addUser("777123456", true);
    legacy.passwordHash = await bcryptjs.hash("different-password", 4);
    await addUser("+967777123456", true);

    const response = await service.login({
      phone: "777123456",
      password: "secret123",
    });

    assert.equal("accessToken" in response, true);
    assert.equal(users.length, 2);
  });
});

test("OTP login prefers the canonical phone row over a legacy duplicate", async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, addUser } = createHarness();
    const legacy = await addUser("777123456", true);
    const canonical = await addUser("+967777123456", true);

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    const response = await service.verifyOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
      code: "123456",
    });

    assert.equal(response.user?.id, canonical.id);
    assert.notEqual(response.user?.id, legacy.id);
    assert.equal(refreshTokens.length, 1);
  });
});

test("registration start does not disclose an existing phone", async () => {
  await withDevOtp(async () => {
    const { service, addUser } = createHarness();
    await addUser("+967777123456", true);
    const response = await service.startRegistration({
      name: "Probe",
      phone: "777123456",
    });
    assert.equal(response.registrationPending, true);
    assert.equal(response.purpose, OtpPurpose.REGISTER);
  });
});

test("invalid registration OTP does not disclose whether the phone exists", async () => {
  await withDevOtp(async () => {
    const scenarios = [
      {
        existingPhone: "+967777123456",
        attemptedPhone: "777123456",
      },
      {
        existingPhone: "+967733333333",
        attemptedPhone: "777123456",
      },
      {
        existingPhone: null,
        attemptedPhone: "777123456",
      },
    ];

    const errors: Array<{ status: number; message: string }> = [];
    for (const scenario of scenarios) {
      const { service, addUser } = createHarness();
      if (scenario.existingPhone) {
        await addUser(scenario.existingPhone, true);
      }
      await service.startRegistration({
        name: "Probe",
        phone: scenario.attemptedPhone,
      });

      try {
        await service.completeRegistration({
          name: "Probe",
          phone: scenario.attemptedPhone,
          password: "secret123",
          otpCode: "999999",
        });
        assert.fail("invalid OTP must be rejected");
      } catch (error: any) {
        errors.push({ status: error.getStatus(), message: error.message });
      }
    }

    assert.deepEqual(errors, [
      { status: 400, message: "OTP code is invalid or expired" },
      { status: 400, message: "OTP code is invalid or expired" },
      { status: 400, message: "OTP code is invalid or expired" },
    ]);
  });
});

test("registration verifies OTP before checking a phone conflict", async () => {
  await withDevOtp(async () => {
    const { service, addUser, lookupEvents } = createHarness();
    await addUser("+967777123456", true);
    await service.startRegistration({
      name: "Probe",
      phone: "777123456",
    });
    lookupEvents.length = 0;

    await assert.rejects(
      () =>
        service.completeRegistration({
          name: "Probe",
          phone: "777123456",
          password: "secret123",
          otpCode: "999999",
        }),
      /OTP code is invalid or expired/,
    );

    assert.deepEqual(
      lookupEvents,
      [],
      "identifier lookup must not run until the phone OTP is valid",
    );

    await assert.rejects(
      () =>
        service.completeRegistration({
          name: "Probe",
          phone: "777123456",
          password: "secret123",
          otpCode: "123456",
        }),
      /An account already exists for this phone/,
    );
    assert.deepEqual(
      lookupEvents,
      ["user"],
      "identifier conflicts are checked only after valid phone proof",
    );
  });
});

test("a valid REGISTER OTP claims an unverified legacy account without replacing its identity", async () => {
  await withDevOtp(async () => {
    const { service, users, refreshTokens, addUser } = createHarness();
    const legacy = await addUser("+967777123456", false);
    legacy.role = "PROVIDER";
    legacy.providerProfile = { id: "provider-profile-1" };
    const originalId = legacy.id;

    await service.startRegistration({
      name: "Recovered Provider",
      phone: "777123456",
    });
    const response = await service.completeRegistration({
      name: "Recovered Provider",
      phone: "777123456",
      password: "new-application-password",
      otpCode: "123456",
    });

    assert.equal(users.length, 1);
    assert.equal(response.user.id, originalId);
    assert.equal(response.user.role, "PROVIDER");
    assert.equal(legacy.providerProfile.id, "provider-profile-1");
    assert.equal(legacy.name, "Recovered Provider");
    assert.ok(legacy.phoneVerifiedAt);
    assert.ok(
      await bcryptjs.compare("new-application-password", legacy.passwordHash),
    );
    assert.equal(refreshTokens.length, 1);
  });
});

test("an admin can enroll a separate app password without changing admin credentials", async () => {
  await withDevOtp(async () => {
    const { service, users, refreshTokens, addUser } = createHarness();
    const admin = await addUser("+967777123456", true);
    admin.role = "ADMIN";
    admin.adminRole = "SUPER_ADMIN";
    const originalAdminHash = admin.passwordHash;
    const originalName = admin.name;

    await service.startRegistration({
      name: "Wedding App Name",
      phone: "777123456",
    });
    const response = await service.completeRegistration({
      name: "Wedding App Name",
      phone: "777123456",
      password: "application-password",
      otpCode: "123456",
    });

    assert.equal(users.length, 1);
    assert.equal(admin.passwordHash, originalAdminHash);
    assert.equal(admin.name, originalName);
    assert.equal(admin.appName, "Wedding App Name");
    assert.ok(
      await bcryptjs.compare("application-password", admin.appPasswordHash),
    );
    assert.equal(response.user.adminRole, null);
    assert.equal(response.user.role, "USER");
    assert.equal(response.user.name, "Wedding App Name");
    assert.deepEqual(response.user.adminPermissions, []);
    assert.match(response.refreshToken, /^aarast_app_/);
    assert.equal(refreshTokens.length, 1);
  });
});

test("an admin OTP cannot open the consumer app before explicit app enrollment", async () => {
  await withDevOtp(async () => {
    const { service, addUser, refreshTokens } = createHarness();
    const admin = await addUser("+967777123456", true);
    admin.role = "ADMIN";
    admin.adminRole = "SUPER_ADMIN";

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    await assert.rejects(
      () =>
        service.verifyOtp({
          phone: "777123456",
          purpose: OtpPurpose.LOGIN,
          code: "123456",
        }),
      (error: any) =>
        error.getResponse?.().code === "ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF",
    );
    assert.equal(refreshTokens.length, 0);
  });
});

test("one OTP can create at most one concurrent LOGIN session", async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, addUser } = createHarness();
    await addUser("+967777123456", false);
    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });

    const attempts = await Promise.allSettled([
      service.verifyOtp({
        phone: "777123456",
        purpose: OtpPurpose.LOGIN,
        code: "123456",
      }),
      service.verifyOtp({
        phone: "777123456",
        purpose: OtpPurpose.LOGIN,
        code: "123456",
      }),
    ]);

    assert.equal(
      attempts.filter((result) => result.status === "fulfilled").length,
      1,
    );
    assert.equal(
      attempts.filter((result) => result.status === "rejected").length,
      1,
    );
    assert.equal(refreshTokens.length, 1);
  });
});

test("general LOGIN OTP never creates an invited participant account", async () => {
  await withDevOtp(async () => {
    const { service, users, setPlanInvite } = createHarness();
    setPlanInvite({
      id: "invite-active",
      normalizedPhone: "+967777123456",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    await assert.rejects(
      () =>
        service.verifyOtp({
          phone: "777123456",
          purpose: OtpPurpose.LOGIN,
          code: "123456",
        }),
      /No account exists for this verified phone/,
    );
    assert.equal(users.length, 0);
  });
});

test("private invite OTP creates a participant with their chosen password and one session", async () => {
  await withDevOtp(async () => {
    const token = TEST_INVITE_TOKEN;
    const { service, users, refreshTokens, setPlanInvite } = createHarness();
    setPlanInvite({
      id: "invite-active",
      tokenHash: createHash("sha256").update(token).digest("hex"),
      normalizedPhone: "+967777123456",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    const result = await service.verifyInviteOtp({
      token,
      phone: "777123456",
      code: "123456",
      name: "المساهم أحمد",
      password: "contributor-secret",
    });

    assert.equal(result.user?.name, "المساهم أحمد");
    assert.equal(users.length, 1);
    assert.ok(
      await bcryptjs.compare("contributor-secret", users[0].passwordHash),
    );
    assert.equal(refreshTokens.length, 1);
    assert.match(result.refreshToken ?? "", /^aarast_app_/);
  });
});

test("private invite setup can reuse the same unconsumed OTP after credentials are requested", async () => {
  await withDevOtp(async () => {
    const token = TEST_INVITE_TOKEN;
    const { service, users, otps, setPlanInvite } = createHarness();
    setPlanInvite({
      id: "invite-active",
      tokenHash: createHash("sha256").update(token).digest("hex"),
      normalizedPhone: "+967777123456",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    await assert.rejects(
      () =>
        service.verifyInviteOtp({
          token,
          phone: "777123456",
          code: "123456",
        }),
      (error: any) =>
        error.getResponse?.().code === "INVITE_ACCOUNT_SETUP_REQUIRED",
    );
    assert.equal(otps[0].consumedAt, null);

    await service.verifyInviteOtp({
      token,
      phone: "777123456",
      code: "123456",
      name: "المساهم أحمد",
      password: "contributor-secret",
    });
    assert.equal(users.length, 1);
    assert.ok(otps[0].consumedAt);
  });
});

test("historical invites cannot create a new participant account", async () => {
  await withDevOtp(async () => {
    const historicalStates = [
      {
        acceptedAt: new Date(),
        declinedAt: null,
        revokedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
      },
      {
        acceptedAt: null,
        declinedAt: new Date(),
        revokedAt: null,
        expiresAt: new Date(Date.now() + 60_000),
      },
      {
        acceptedAt: null,
        declinedAt: null,
        revokedAt: new Date(),
        expiresAt: new Date(Date.now() + 60_000),
      },
      {
        acceptedAt: null,
        declinedAt: null,
        revokedAt: null,
        expiresAt: new Date(Date.now() - 60_000),
      },
    ];

    for (const [index, state] of historicalStates.entries()) {
      const { service, users, setPlanInvite } = createHarness();
      setPlanInvite({
        id: `invite-historical-${index}`,
        normalizedPhone: "+967777123456",
        ...state,
      });
      await service.requestOtp({
        phone: "777123456",
        purpose: OtpPurpose.LOGIN,
      });

      await assert.rejects(
        () =>
          service.verifyOtp({
            phone: "777123456",
            purpose: OtpPurpose.LOGIN,
            code: "123456",
          }),
        /No account exists for this verified phone/,
      );
      assert.equal(users.length, 0);
    }
  });
});

test("an old JWT cannot access protected routes for an unverified account", async () => {
  const previousSecret = process.env.JWT_SECRET;
  process.env.JWT_SECRET = "test-jwt-secret-with-sufficient-length";
  try {
    const strategy = new JwtStrategy({
      user: {
        findUnique: async () => ({
          id: "legacy-user",
          status: "ACTIVE",
          phoneVerifiedAt: null,
        }),
      },
    } as any);
    await assert.rejects(
      () =>
        strategy.validate({
          sub: 'legacy-user',
          phone: '+967777123456',
          scope: 'application',
        }),
      /unverified/,
    );
  } finally {
    if (previousSecret === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previousSecret;
  }
});

test("verified registration smoke never sends an unverified password in the initial request", async () => {
  const calls: Array<{ path: string; body: Record<string, unknown> }> = [];
  const request = async (
    _method: string,
    path: string,
    body: Record<string, unknown>,
  ) => {
    calls.push({ path, body });
    if (path === "/api/v1/auth/register") {
      return {
        status: 201,
        body: { registrationPending: true, code: "123456" },
      };
    }
    return { status: 201, body: { accessToken: "token", user: {} } };
  };

  await registerVerified(request, {
    name: "Smoke User",
    phone: "+967777123456",
    password: "SmokePassword123!",
  });

  assert.deepEqual(calls[0], {
    path: "/api/v1/auth/register",
    body: { name: "Smoke User", phone: "+967777123456" },
  });
  assert.equal(calls[1].path, "/api/v1/auth/register/complete");
  assert.equal(calls[1].body.password, "SmokePassword123!");
  assert.equal(calls[1].body.otpCode, "123456");
});

test("concurrent OTP serialization loss returns a stable invalid-code response instead of HTTP 500", async () => {
  await withDevOtp(async () => {
    const { service, prisma, addUser } = createHarness();
    await addUser("+967777123456", true);
    await service.requestOtp({
      phone: "+967777123456",
      purpose: OtpPurpose.LOGIN,
    });
    prisma.$transaction = async () => {
      throw new Prisma.PrismaClientKnownRequestError("serialization conflict", {
        code: "P2034",
        clientVersion: "test",
      });
    };

    await assert.rejects(
      () =>
        service.verifyOtp({
          phone: "+967777123456",
          purpose: OtpPurpose.LOGIN,
          code: "123456",
        }),
      (error: any) =>
        error?.getStatus?.() === 400 &&
        error?.getResponse?.()?.code === "OTP_INVALID_OR_EXPIRED",
    );
  });
});
