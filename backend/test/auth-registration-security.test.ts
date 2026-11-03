import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { ValidationPipe } from "@nestjs/common";
import { OtpPurpose, Prisma } from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { AuthErrorCode } from "../src/modules/identity/public/auth-error";
import { authService } from "./support/owner-ports";
import { RegisterDto } from "../src/modules/identity/api/auth-dto/register.dto";
import { JwtStrategy } from "../src/modules/identity/internal/auth/jwt.strategy";

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
  let planInvites: any[] = [];
  const sharedMembers: any[] = [];
  let failNextRefreshCreate = false;

  const prisma: any = {
    otpCode: {
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const otp of otps) {
          const matches =
            (where.id === undefined || otp.id === where.id) &&
            (where.phone === undefined || otp.phone === where.phone) &&
            (where.purpose === undefined || otp.purpose === where.purpose) &&
            (where.planInviteId === undefined ||
              otp.planInviteId === where.planInviteId) &&
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
          planInviteId: data.planInviteId ?? null,
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
              (where.planInviteId === undefined ||
                otp.planInviteId === where.planInviteId) &&
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
      findUnique: async ({ where }: any) =>
        users.find((candidate) => candidate.id === where.id) ?? null,
      create: async ({ data }: any) => {
        const now = new Date();
        const user = {
          id: `user-${++userSequence}`,
          role: "USER",
          adminRole: null,
          appRole: "WEDDING_USER",
          status: "ACTIVE",
          appPasswordHash: null,
          appAccountActivatedAt: null,
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
            (where.phone === undefined || where.phone === user.phone) &&
            roleMatches &&
            (where.status === undefined || where.status === user.status) &&
            (where.phoneVerifiedAt === undefined ||
              (where.phoneVerifiedAt?.not === null
                ? user.phoneVerifiedAt !== null
                : where.phoneVerifiedAt === user.phoneVerifiedAt)) &&
            (where.passwordHash === undefined ||
              where.passwordHash === user.passwordHash) &&
            (where.appPasswordHash === undefined ||
              where.appPasswordHash === user.appPasswordHash) &&
            (where.appAccountActivatedAt === undefined ||
              (where.appAccountActivatedAt?.not === null
                ? user.appAccountActivatedAt !== null
                : where.appAccountActivatedAt ===
                  user.appAccountActivatedAt));
          if (!matches) continue;
          Object.assign(user, data, { updatedAt: new Date() });
          count += 1;
        }
        return { count };
      },
    },
    refreshToken: {
      create: async ({ data }: any) => {
        if (failNextRefreshCreate) {
          failNextRefreshCreate = false;
          throw new Error("simulated refresh session failure");
        }
        const token = { id: `refresh-${refreshTokens.length + 1}`, ...data };
        refreshTokens.push(token);
        return token;
      },
    },
    sharedMember: {
      findUnique: async ({ where }: any) =>
        sharedMembers.find(
          (member) =>
            member.weddingPlanId ===
              where.weddingPlanId_userId?.weddingPlanId &&
            member.userId === where.weddingPlanId_userId?.userId,
        ) ?? null,
    },
    planInvite: {
      findFirst: async ({ where }: any) =>
        planInvites.find((planInvite) => {
          if (where.id && planInvite.id !== where.id) return false;
          if (
            where.normalizedPhone &&
            planInvite.normalizedPhone !== where.normalizedPhone
          ) {
            return false;
          }
          if (where.tokenHash && planInvite.tokenHash !== where.tokenHash) {
            return false;
          }
          if (where.acceptedAt === null && planInvite.acceptedAt !== null) {
            return false;
          }
          if (where.declinedAt === null && planInvite.declinedAt !== null) {
            return false;
          }
          if (where.revokedAt === null && planInvite.revokedAt !== null) {
            return false;
          }
          if (
            where.expiresAt?.gt &&
            planInvite.expiresAt <= where.expiresAt.gt
          ) {
            return false;
          }
          return true;
        }) ?? null,
    },
    $queryRaw: async (query: any) => {
      const sql = String(query?.sql ?? query?.text ?? "");
      if (sql.includes('"PlanInvite"')) {
        const inviteId = query?.values?.[0];
        return planInvites
          .filter((invite) => invite.id === inviteId)
          .map((invite) => ({ id: invite.id }));
      }
      return users.map((user) => ({ id: user.id, status: user.status }));
    },
    $transaction: async (action: any) => {
      const rollbackEnabled = failNextRefreshCreate;
      if (!rollbackEnabled) return action(prisma);

      const otpSnapshot = structuredClone(otps);
      const userSnapshot = structuredClone(users);
      const refreshSnapshot = structuredClone(refreshTokens);
      try {
        return await action(prisma);
      } catch (error) {
        otps.splice(0, otps.length, ...otpSnapshot);
        users.splice(0, users.length, ...userSnapshot);
        refreshTokens.splice(0, refreshTokens.length, ...refreshSnapshot);
        throw error;
      }
    },
  };

  return {
    service: authService(
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
      {
        disconnectUser: () => undefined,
        disconnectSession: () => undefined,
      } as any,
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
          appAccountActivatedAt: new Date(),
          phoneVerifiedAt: verified ? new Date() : null,
          lastLoginAt: null,
        },
      }),
    setPlanInvite: (value: any) => {
      planInvites = [value];
    },
    setPlanInvites: (values: any[]) => {
      planInvites = values;
    },
    addSharedMember: (weddingPlanId: string, userId: string) => {
      sharedMembers.push({
        id: `member-${sharedMembers.length + 1}`,
        weddingPlanId,
        userId,
      });
    },
    failNextRefreshCreate: () => {
      failNextRefreshCreate = true;
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

test("registration rollback preserves its OTP when session creation fails", async () => {
  await withDevOtp(async () => {
    const harness = createHarness();
    await harness.service.startRegistration({
      name: "Retry User",
      phone: "777123456",
    });
    harness.failNextRefreshCreate();

    await assert.rejects(
      () =>
        harness.service.completeRegistration({
          name: "Retry User",
          phone: "777123456",
          password: "secret123",
          otpCode: "123456",
        }),
      /simulated refresh session failure/,
    );
    assert.equal(harness.otps[0].consumedAt, null);
    assert.equal(harness.users.length, 0);

    const completed = await harness.service.completeRegistration({
      name: "Retry User",
      phone: "777123456",
      password: "secret123",
      otpCode: "123456",
    });
    assert.ok(completed.accessToken);
  });
});

test("OTP login rollback preserves its OTP when session creation fails", async () => {
  await withDevOtp(async () => {
    const harness = createHarness();
    await harness.addUser("+967777123456", true);
    await harness.service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    harness.failNextRefreshCreate();

    await assert.rejects(
      () =>
        harness.service.verifyOtp({
          phone: "777123456",
          purpose: OtpPurpose.LOGIN,
          code: "123456",
        }),
      /simulated refresh session failure/,
    );
    assert.equal(harness.otps[0].consumedAt, null);
    assert.equal(harness.refreshTokens.length, 0);

    const verified = await harness.service.verifyOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
      code: "123456",
    });
    assert.ok(verified.accessToken);
  });
});

test("invite OTP rollback preserves its OTP when session creation fails", async () => {
  await withDevOtp(async () => {
    const harness = createHarness();
    await harness.addUser("+967777123456", true);
    harness.setPlanInvite({
      id: "invite-rollback",
      tokenHash: createHash("sha256")
        .update(TEST_INVITE_TOKEN)
        .digest("hex"),
      normalizedPhone: "+967777123456",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });
    await harness.service.requestInviteOtp(
      "+967777123456",
      "invite-rollback",
      createHash("sha256").update(TEST_INVITE_TOKEN).digest("hex"),
    );
    harness.failNextRefreshCreate();

    await assert.rejects(
      () =>
        harness.service.verifyInviteOtp({
          token: TEST_INVITE_TOKEN,
          phone: "777123456",
          code: "123456",
        }),
      /simulated refresh session failure/,
    );
    assert.equal(harness.otps[0].consumedAt, null);
    assert.equal(harness.refreshTokens.length, 0);

    const verified = await harness.service.verifyInviteOtp({
      token: TEST_INVITE_TOKEN,
      phone: "777123456",
      code: "123456",
    });
    assert.ok(verified.accessToken);
  });
});

test("invite OTP issuance rejects an expected token hash invalidated by reissue", async () => {
  await withDevOtp(async () => {
    const oldTokenHash = createHash("sha256")
      .update("e".repeat(43))
      .digest("hex");
    const { service, otps, setPlanInvite } = createHarness();
    setPlanInvite({
      id: "invite-reissued",
      tokenHash: createHash("sha256")
        .update("f".repeat(43))
        .digest("hex"),
      normalizedPhone: "+967777123456",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await assert.rejects(
      () =>
        service.requestInviteOtp(
          "+967777123456",
          "invite-reissued",
          oldTokenHash,
          { ip: "127.0.0.1" },
        ),
      (error: any) =>
        error?.getStatus?.() === 404 &&
        error?.getResponse?.().code ===
          AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE,
    );
    assert.equal(otps.length, 0, "a rotated bearer must not create an OTP");
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
    admin.appAccountActivatedAt = new Date();
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
    admin.appAccountActivatedAt = new Date();
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
    assert.equal(signedPayloads[0]?.sid, refreshTokens[0]?.id);
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

test("password login cannot create a session after a password reset wins the transaction boundary", async () => {
  await withDevOtp(async () => {
    const { service, addUser, prisma, refreshTokens } = createHarness();
    const user = await addUser("+967777123456", true);
    const resetHash = await bcryptjs.hash("new-password", 4);
    const findFirst = prisma.user.findFirst;
    prisma.user.findFirst = async (args: any) => {
      const found = await findFirst(args);
      return found ? { ...found } : null;
    };
    const transaction = prisma.$transaction;
    prisma.$transaction = async (action: any) => {
      user.passwordHash = resetHash;
      return transaction(action);
    };

    await assert.rejects(
      () =>
        service.login({
          phone: "777123456",
          password: "secret123",
        }),
      /Invalid credentials/,
    );
    assert.equal(refreshTokens.length, 0);
  });
});

test("password login cannot create a session after account disable wins the transaction boundary", async () => {
  await withDevOtp(async () => {
    const { service, addUser, prisma, refreshTokens } = createHarness();
    const user = await addUser("+967777123456", true);
    const transaction = prisma.$transaction;
    prisma.$transaction = async (action: any) => {
      user.status = "DISABLED";
      return transaction(action);
    };

    await assert.rejects(
      () =>
        service.login({
          phone: "777123456",
          password: "secret123",
        }),
      /Invalid credentials/,
    );
    assert.equal(refreshTokens.length, 0);
  });
});

test("admin password reset cannot leave an old-password MFA challenge", async () => {
  await withDevOtp(async () => {
    const { service, addUser, prisma } = createHarness();
    const admin = await addUser("+967777123456", true);
    admin.role = "ADMIN";
    admin.adminRole = "SUPER_ADMIN";
    admin.passwordHash = await bcryptjs.hash("old-admin-password", 4);

    // Prisma returns detached records. Preserve that property in this race
    // harness so changing the stored credential cannot mutate the snapshot
    // that passed bcrypt verification.
    const findFirst = prisma.user.findFirst;
    prisma.user.findFirst = async (args: any) => {
      const found = await findFirst(args);
      return found ? { ...found } : null;
    };
    prisma.user.findUnique = async ({ where }: any) =>
      where.id === admin.id ? admin : null;
    prisma.$queryRaw = async () => [
      { id: admin.id, status: admin.status },
    ];
    prisma.otpCode.findUniqueOrThrow = async () => ({ consumedAt: null });
    let createdChallenges = 0;
    prisma.adminLoginChallenge = {
      updateMany: async () => ({ count: 0 }),
      create: async () => {
        createdChallenges += 1;
        return {};
      },
    };
    (service as any).issueOtp = async () => ({
      otpId: "otp-admin-race",
      phone: admin.phone,
      purpose: OtpPurpose.ADMIN_LOGIN,
      expiresAt: new Date(Date.now() + 60_000),
      delivery: "LOCAL",
      deliveryStatus: "DELIVERED",
    });

    const resetHash = await bcryptjs.hash("new-admin-password", 12);
    const update = prisma.user.update;
    prisma.user.update = async (args: any) => {
      if (args.where.id === admin.id && args.data.passwordHash) {
        admin.passwordHash = resetHash;
      }
      const updated = await update(args);
      return { ...updated };
    };
    const updateMany = prisma.user.updateMany;
    prisma.user.updateMany = async (args: any) => {
      if (
        args.where.id === admin.id &&
        args.where.passwordHash !== undefined &&
        args.data.passwordHash
      ) {
        admin.passwordHash = resetHash;
      }
      return updateMany(args);
    };

    await assert.rejects(
      () =>
        service.startAdminLogin({
          phone: "777123456",
          password: "old-admin-password",
        }),
      /Invalid credentials/,
    );
    assert.equal(
      createdChallenges,
      0,
      "the stale password must not mint an MFA challenge",
    );
    assert.equal(
      admin.passwordHash,
      resetHash,
      "legacy hash upgrade must not overwrite the concurrently reset password",
    );
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

    // Owner decision (phone + code sign-up): a registered number with a valid
    // REGISTER code now signs in instead of answering 409.
    const response = await service.completeRegistration({
      name: "Probe",
      phone: "777123456",
      password: "secret123",
      otpCode: "123456",
    });
    assert.equal(response.existingAccount, true);
    assert.deepEqual(
      lookupEvents,
      ["user"],
      "the account is looked up only after valid phone proof",
    );
  });
});

test("a verified phone without an activated application account still answers 409", async () => {
  await withDevOtp(async () => {
    const { service, addUser } = createHarness();
    const existing = await addUser("+967777123456", true);
    existing.appAccountActivatedAt = null;
    await service.startRegistration({ name: "Probe", phone: "777123456" });
    await assert.rejects(
      () =>
        service.completeRegistration({
          name: "Probe",
          phone: "777123456",
          otpCode: "123456",
        }),
      (error: any) =>
        error.getResponse?.().code === AuthErrorCode.ACCOUNT_ALREADY_EXISTS,
    );
  });
});

test("registration without a password creates an activated passwordless account", async () => {
  await withDevOtp(async () => {
    const { service, users } = createHarness();
    await service.startRegistration({ name: "New Couple", phone: "777123456" });
    const response = await service.completeRegistration({
      name: "New Couple",
      phone: "777123456",
      otpCode: "123456",
    });

    assert.equal(response.existingAccount, false);
    assert.ok(response.accessToken);
    assert.ok(response.refreshToken);
    assert.equal(users.length, 1);
    assert.equal(users[0].passwordHash, null);
    assert.ok(users[0].appAccountActivatedAt);
    assert.ok(users[0].phoneVerifiedAt);
  });
});

test("password sign-in on a passwordless account fails like a wrong password", async () => {
  await withDevOtp(async () => {
    const { service } = createHarness();
    await service.startRegistration({ name: "New Couple", phone: "777123456" });
    await service.completeRegistration({
      name: "New Couple",
      phone: "777123456",
      otpCode: "123456",
    });

    const rejection = async (phone: string, password: string) => {
      try {
        await service.login({ phone, password });
      } catch (error: any) {
        return { status: error.getStatus?.(), body: error.getResponse?.() };
      }
      assert.fail("password sign-in must fail");
    };
    const passwordless = await rejection("777123456", "anything1");
    // Exactly what an unknown phone (dummy-hash comparison) answers.
    const unknown = await rejection("777999888", "anything1");
    assert.equal(passwordless.body.code, AuthErrorCode.INVALID_CREDENTIALS);
    assert.deepEqual(passwordless, unknown);
  });
});

test("a registered number with a valid REGISTER code signs in without changing name or password", async () => {
  await withDevOtp(async () => {
    const { service, users, addUser } = createHarness();
    const existing = await addUser("+967777123456", true);
    const originalHash = existing.passwordHash;
    await service.startRegistration({ name: "Other Name", phone: "777123456" });
    const before = Date.now();
    const response = await service.completeRegistration({
      name: "Other Name",
      phone: "777123456",
      password: "different-password",
      otpCode: "123456",
    });

    assert.equal(response.existingAccount, true);
    assert.equal(response.user.id, existing.id);
    assert.ok(response.accessToken);
    assert.equal(users.length, 1);
    assert.equal(existing.name, "Existing User");
    assert.equal(existing.passwordHash, originalHash);
    assert.ok(existing.lastLoginAt.getTime() >= before);
    assert.equal(await bcryptjs.compare("secret123", existing.passwordHash), true);
  });
});

test("J1-10: a registered number's answer names the account it signed in to, not the typed name", async () => {
  await withDevOtp(async () => {
    const { service, addUser } = createHarness();
    await addUser("+967777123456", true);
    await service.startRegistration({ name: "Other Name", phone: "777123456" });
    const response = await service.completeRegistration({
      name: "Other Name",
      phone: "777123456",
      otpCode: "123456",
    });

    // «هذا الرقم عليه حساب باسم X»: X is the existing account's own name.
    assert.equal(response.existingAccount, true);
    assert.equal(response.user.name, "Existing User");
  });
});

test("a registered but disabled number keeps its disabled answer on registration", async () => {
  await withDevOtp(async () => {
    const { service, addUser } = createHarness();
    const existing = await addUser("+967777123456", true);
    existing.status = "DISABLED";
    await service.startRegistration({ name: "Probe", phone: "777123456" });
    await assert.rejects(
      () =>
        service.completeRegistration({
          name: "Probe",
          phone: "777123456",
          otpCode: "123456",
        }),
      (error: any) =>
        error.getResponse?.().code ===
        AuthErrorCode.ACCOUNT_DISABLED_AFTER_PHONE_PROOF,
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

    await service.requestInviteOtp(
      "+967777123456",
      "invite-active",
      createHash("sha256").update(token).digest("hex"),
    );
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

test("private invite OTP creates a participant from the name alone, without a password", async () => {
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

    await service.requestInviteOtp(
      "+967777123456",
      "invite-active",
      createHash("sha256").update(token).digest("hex"),
    );
    const result = await service.verifyInviteOtp({
      token,
      phone: "777123456",
      code: "123456",
      name: "المساهم أحمد",
    });

    assert.equal(result.user?.name, "المساهم أحمد");
    assert.equal(users.length, 1);
    assert.equal(users[0].passwordHash, null);
    assert.ok(users[0].appAccountActivatedAt);
    assert.equal(refreshTokens.length, 1);
    assert.match(result.refreshToken ?? "", /^aarast_app_/);
  });
});

test("an admin cannot enroll an application account without its application password", async () => {
  await withDevOtp(async () => {
    const { service, refreshTokens, addUser } = createHarness();
    const admin = await addUser("+967777123456", true);
    admin.role = "ADMIN";
    admin.adminRole = "SUPER_ADMIN";
    const originalAdminHash = admin.passwordHash;

    await service.startRegistration({ name: "Wedding App Name", phone: "777123456" });
    await assert.rejects(
      () =>
        service.completeRegistration({
          name: "Wedding App Name",
          phone: "777123456",
          otpCode: "123456",
        }),
      (error: any) =>
        error.getResponse?.().code === AuthErrorCode.ADMIN_APP_PASSWORD_REQUIRED,
    );
    assert.equal(admin.appPasswordHash, null);
    assert.equal(admin.passwordHash, originalAdminHash);
    assert.equal(refreshTokens.length, 0);
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

    await service.requestInviteOtp(
      "+967777123456",
      "invite-active",
      createHash("sha256").update(token).digest("hex"),
    );
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

test("an accepted legacy invite replaces its generated password and restores a durable session", async () => {
  await withDevOtp(async () => {
    const token = TEST_INVITE_TOKEN;
    const {
      service,
      addUser,
      addSharedMember,
      refreshTokens,
      setPlanInvite,
    } = createHarness();
    const legacy = await addUser("+967777123456", true);
    legacy.name = "مشارك اعّرست";
    legacy.passwordHash = await bcryptjs.hash("unreachable-random-secret", 4);
    legacy.appAccountActivatedAt = null;
    addSharedMember("plan-legacy", legacy.id);
    setPlanInvite({
      id: "invite-accepted-legacy",
      weddingPlanId: "plan-legacy",
      inviteeUserId: legacy.id,
      tokenHash: createHash("sha256").update(token).digest("hex"),
      normalizedPhone: "+967777123456",
      acceptedAt: new Date(),
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    });

    await service.requestInviteOtp(
      "+967777123456",
      "invite-accepted-legacy",
      createHash("sha256").update(token).digest("hex"),
      {},
      true,
    );
    const result = await service.verifyInviteOtp({
      token,
      phone: "777123456",
      code: "123456",
      name: "المساهم أحمد",
      password: "chosen-contributor-password",
    });

    assert.equal(legacy.name, "المساهم أحمد");
    assert.ok(legacy.appAccountActivatedAt);
    assert.ok(
      await bcryptjs.compare(
        "chosen-contributor-password",
        legacy.passwordHash,
      ),
    );
    assert.match(result.refreshToken ?? "", /^aarast_app_/);
    assert.equal(refreshTokens.length, 1);
  });
});

test("invite OTP replacement never consumes a general LOGIN OTP and vice versa", async () => {
  await withDevOtp(async () => {
    const { service, otps, setPlanInvite } = createHarness();
    setPlanInvite({
      id: "invite-isolated",
      tokenHash: createHash("sha256").update(TEST_INVITE_TOKEN).digest("hex"),
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
    await service.requestInviteOtp(
      "+967777123456",
      "invite-isolated",
      createHash("sha256").update(TEST_INVITE_TOKEN).digest("hex"),
    );

    const firstLogin = otps.find(
      (otp) => otp.purpose === OtpPurpose.LOGIN,
    );
    const firstInvite = otps.find(
      (otp) => otp.purpose === "INVITE_ACCESS",
    );
    assert.equal(firstLogin?.consumedAt, null);
    assert.equal(firstLogin?.planInviteId, null);
    assert.equal(firstInvite?.consumedAt, null);
    assert.equal(firstInvite?.planInviteId, "invite-isolated");

    await service.requestOtp({
      phone: "777123456",
      purpose: OtpPurpose.LOGIN,
    });
    assert.ok(firstLogin?.consumedAt);
    assert.equal(
      firstInvite?.consumedAt,
      null,
      "normal LOGIN replacement must not consume invite access",
    );

    const currentLogin = [...otps]
      .reverse()
      .find(
        (otp) =>
          otp.purpose === OtpPurpose.LOGIN && otp.consumedAt === null,
      );
    await service.requestInviteOtp(
      "+967777123456",
      "invite-isolated",
      createHash("sha256").update(TEST_INVITE_TOKEN).digest("hex"),
    );
    assert.ok(firstInvite?.consumedAt);
    assert.equal(
      currentLogin?.consumedAt,
      null,
      "invite replacement must not consume normal LOGIN",
    );
  });
});

test("same-phone invitations keep independent OTP generations", async () => {
  await withDevOtp(async () => {
    const tokenA = "a".repeat(43);
    const tokenB = "b".repeat(43);
    const inviteA = {
      id: "invite-a",
      tokenHash: createHash("sha256").update(tokenA).digest("hex"),
      normalizedPhone: "+967777123456",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
    };
    const inviteB = {
      ...inviteA,
      id: "invite-b",
      tokenHash: createHash("sha256").update(tokenB).digest("hex"),
    };
    const { service, otps, setPlanInvites } = createHarness();
    setPlanInvites([inviteA, inviteB]);

    await service.requestInviteOtp(
      "+967777123456",
      inviteA.id,
      inviteA.tokenHash,
    );
    await service.requestInviteOtp(
      "+967777123456",
      inviteB.id,
      inviteB.tokenHash,
    );
    const firstA = otps.find((otp) => otp.planInviteId === inviteA.id);
    const firstB = otps.find((otp) => otp.planInviteId === inviteB.id);
    assert.equal(firstA?.consumedAt, null);
    assert.equal(firstB?.consumedAt, null);

    await service.requestInviteOtp(
      "+967777123456",
      inviteA.id,
      inviteA.tokenHash,
    );
    assert.ok(firstA?.consumedAt);
    assert.equal(
      firstB?.consumedAt,
      null,
      "reissuing invite A must not cancel invite B",
    );
  });
});

test("invite tokens cannot cross-use another invite OTP and cancellation makes its OTP unusable", async () => {
  await withDevOtp(async () => {
    const tokenA = "c".repeat(43);
    const tokenB = "d".repeat(43);
    const inviteA = {
      id: "invite-token-a",
      tokenHash: createHash("sha256").update(tokenA).digest("hex"),
      normalizedPhone: "+967777123456",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null as Date | null,
      expiresAt: new Date(Date.now() + 60_000),
    };
    const inviteB = {
      ...inviteA,
      id: "invite-token-b",
      tokenHash: createHash("sha256").update(tokenB).digest("hex"),
    };
    const {
      service,
      otps,
      refreshTokens,
      addUser,
      setPlanInvites,
    } = createHarness();
    await addUser("+967777123456", true);
    setPlanInvites([inviteA, inviteB]);

    await service.requestInviteOtp(
      "+967777123456",
      inviteA.id,
      inviteA.tokenHash,
    );
    await service.requestInviteOtp(
      "+967777123456",
      inviteB.id,
      inviteB.tokenHash,
    );
    const otpA = otps.find((otp) => otp.planInviteId === inviteA.id);
    const otpB = otps.find((otp) => otp.planInviteId === inviteB.id);
    assert.ok(otpA);
    assert.ok(otpB);
    otpA.codeHash = await bcryptjs.hash("111111", 4);
    otpB.codeHash = await bcryptjs.hash("222222", 4);

    await assert.rejects(
      () =>
        service.verifyInviteOtp({
          token: tokenB,
          phone: "777123456",
          code: "111111",
        }),
      (error: any) =>
        error.getResponse?.().code === "OTP_INVALID_OR_EXPIRED",
    );
    assert.equal(otpA.consumedAt, null);
    assert.equal(otpB.consumedAt, null);
    assert.equal(otpB.attempts, 1);
    assert.equal(refreshTokens.length, 0);

    const verifiedB = await service.verifyInviteOtp({
      token: tokenB,
      phone: "777123456",
      code: "222222",
    });
    assert.equal(verifiedB.purpose, "INVITE_ACCESS");
    assert.ok(otpB.consumedAt);
    assert.equal(otpA.consumedAt, null);
    assert.equal(refreshTokens.length, 1);

    inviteA.revokedAt = new Date();
    await assert.rejects(
      () =>
        service.verifyInviteOtp({
          token: tokenA,
          phone: "777123456",
          code: "111111",
        }),
      (error: any) =>
        error.getResponse?.().code === "INVITE_NOT_FOUND_FOR_PHONE",
    );
    assert.equal(
      otpA.consumedAt,
      null,
      "a cancelled invitation OTP may remain stored but must be unreachable",
    );
    assert.equal(refreshTokens.length, 1);
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
      refreshToken: {
        findFirst: async () => ({ id: "application-session" }),
      },
    } as any);
    await assert.rejects(
      () =>
        strategy.validate({
          sub: 'legacy-user',
          phone: '+967777123456',
          scope: 'application',
          sid: 'application-session',
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
