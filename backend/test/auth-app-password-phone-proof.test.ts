import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ValidationPipe } from "@nestjs/common";
import { JwtService } from "@nestjs/jwt";
import { OtpPurpose } from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { AuthErrorCode } from "../src/modules/identity/public/auth-error";
import { resolveJwtSessionScope } from "../src/modules/identity/public/access-token-scope";
import { JwtAuthGuard } from "../src/modules/identity/public/jwt-auth.guard";
import { JwtStrategy } from "../src/modules/identity/internal/auth/jwt.strategy";
import { toSafeUser } from "../src/modules/identity/internal/safe-user.presenter";
import {
  isPhoneProofFor,
  PHONE_PROOF_AUDIENCE,
  PHONE_PROOF_TYPE,
} from "../src/modules/identity/internal/auth/phone-proof";
import { SetPasswordDto } from "../src/modules/identity/api/auth-dto/set-password.dto";
import { authService } from "./support/owner-ports";

const JWT_SECRET = "k3Jq9vX2mP7rT4wZ8nB5cL1dF6hG0sYaQe";
process.env.JWT_SECRET = JWT_SECRET;
process.env.AUTH_OTP_MODE = "dev";
process.env.AUTH_DEV_OTP_CODE = "123456";
process.env.NODE_ENV = "test";

const PHONE = "+967777123456";

/** Signs like the identity JwtModule: same secret, 15-minute default expiry. */
function moduleJwt() {
  return new JwtService({ secret: JWT_SECRET, signOptions: { expiresIn: "15m" } });
}

function createHarness() {
  const users: any[] = [];
  const otps: any[] = [];
  const refreshTokens: any[] = [];
  const outbox: any[] = [];
  const disconnectedSessions: string[] = [];
  const throttle = { reserved: 0, cleared: 0 };
  let sequence = 0;
  const jwt = moduleJwt();

  const matchesUser = (user: any, where: any) =>
    (where.id === undefined || where.id === user.id) &&
    (where.role === undefined || where.role === user.role) &&
    (where.status === undefined || where.status === user.status) &&
    (where.appAccountActivatedAt?.not !== null || user.appAccountActivatedAt !== null) &&
    (!("passwordHash" in where) || where.passwordHash === user.passwordHash) &&
    (!("appPasswordHash" in where) || where.appPasswordHash === user.appPasswordHash);

  const prisma: any = {
    user: {
      findUnique: async ({ where }: any) => users.find((u) => u.id === where.id) ?? null,
      findUniqueOrThrow: async ({ where }: any) => {
        const user = users.find((u) => u.id === where.id);
        assert.ok(user);
        return user;
      },
      findFirst: async ({ where }: any) =>
        users.find((u) =>
          typeof where.phone === "string"
            ? u.phone === where.phone
            : where.phone?.in?.includes(u.phone),
        ) ?? null,
      create: async ({ data }: any) => {
        const now = new Date();
        const user = {
          id: `user-${++sequence}`, role: "USER", adminRole: null,
          appRole: "WEDDING_USER", status: "ACTIVE", email: null,
          passwordHash: null, appPasswordHash: null, appAccountActivatedAt: null,
          appName: null, appEmail: null, appAvatarUrl: null, avatarUrl: null,
          locale: "ar", activeWeddingPlanId: null, onboardingPath: null,
          persona: null, onboardingCompletedAt: null, deletionRequestedAt: null,
          deletionScheduledFor: null, phoneVerifiedAt: null, lastLoginAt: null,
          createdAt: now, updatedAt: now, ...data,
        };
        users.push(user);
        return user;
      },
      update: async ({ where, data }: any) => {
        const user = users.find((u) => u.id === where.id);
        assert.ok(user);
        return Object.assign(user, data, { updatedAt: new Date() });
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const user of users) {
          if (!matchesUser(user, where)) continue;
          Object.assign(user, data, { updatedAt: new Date() });
          count += 1;
        }
        return { count };
      },
    },
    otpCode: {
      findFirst: async ({ where }: any) =>
        [...otps].reverse().find(
          (otp) =>
            otp.phone === where.phone && otp.purpose === where.purpose &&
            otp.planInviteId === where.planInviteId && otp.consumedAt === where.consumedAt,
        ) ?? null,
      findUnique: async ({ where }: any) => otps.find((otp) => otp.id === where.id) ?? null,
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const otp of otps) {
          if (where.id !== undefined && otp.id !== where.id) continue;
          if (where.consumedAt === null && otp.consumedAt !== null) continue;
          if (where.expiresAt?.gt && otp.expiresAt <= where.expiresAt.gt) continue;
          if (where.attempts?.lt !== undefined && otp.attempts >= where.attempts.lt) continue;
          Object.assign(otp, { ...data, attempts: otp.attempts + (data.attempts?.increment ?? 0) });
          count += 1;
        }
        return { count };
      },
    },
    refreshToken: {
      create: async ({ data }: any) => {
        const row = {
          id: `session-${++sequence}`, revokedAt: null, replacedById: null, ...data,
        };
        refreshTokens.push(row);
        return row;
      },
      findFirst: async ({ where }: any) =>
        refreshTokens.find(
          (row) =>
            row.id === where.id && row.userId === where.userId &&
            row.scope === where.scope && row.revokedAt === null &&
            row.expiresAt > where.expiresAt.gt,
        ) ?? null,
      findMany: async ({ where }: any) =>
        refreshTokens.filter(
          (row) =>
            row.userId === where.userId && row.scope === where.scope &&
            row.revokedAt === null && row.id !== where.id?.not,
        ),
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const row of refreshTokens) {
          if (row.id !== where.id || row.revokedAt !== null) continue;
          Object.assign(row, data);
          count += 1;
        }
        return { count };
      },
    },
    outboxEvent: { create: async ({ data }: any) => outbox.push(data) },
    $queryRaw: async () => users.map((u) => ({ id: u.id, status: u.status })),
    $transaction: async (action: any) => action(prisma),
  };

  const service = authService(
    prisma,
    jwt,
    {
      reserveAttempt: async () => { throttle.reserved += 1; },
      clear: async () => { throttle.cleared += 1; },
    },
    { consume: async () => undefined },
    {
      disconnectUser: () => undefined,
      disconnectSession: (id: string) => disconnectedSessions.push(id),
    },
  );
  const strategy = new JwtStrategy(prisma);

  return {
    service, strategy, jwt, users, otps, refreshTokens, outbox,
    disconnectedSessions, throttle,
    async addUser(overrides: Record<string, unknown> = {}) {
      return prisma.user.create({
        data: {
          name: "Existing", phone: PHONE, phoneVerifiedAt: new Date(),
          appAccountActivatedAt: new Date(), ...overrides,
        },
      });
    },
    async addSession(userId: string, scope: "APPLICATION" | "ADMIN" = "APPLICATION") {
      return prisma.refreshToken.create({
        data: {
          userId, scope, tokenHash: `hash-${sequence}`,
          expiresAt: new Date(Date.now() + 60_000),
        },
      });
    },
    async addOtp(purpose: OtpPurpose, phone = PHONE) {
      otps.push({
        id: `otp-${++sequence}`, phone, purpose, planInviteId: null,
        codeHash: await bcryptjs.hash("123456", 4), attempts: 0, maxAttempts: 5,
        consumedAt: null, expiresAt: new Date(Date.now() + 60_000),
        createdAt: new Date(), updatedAt: new Date(),
      });
    },
    /** The identity `JwtAuthGuard` hands a route for this session. */
    async identity(userId: string, sessionId: string, scope: "application" | "admin" = "application") {
      return strategy.validate({
        sub: userId, phone: PHONE, scope, sid: sessionId,
        ...(scope === "admin" ? { amr: "admin_mfa" as const } : {}),
      });
    },
  };
}

async function loginNotFoundProof(harness: ReturnType<typeof createHarness>, phone = PHONE) {
  await harness.addOtp(OtpPurpose.LOGIN, phone);
  let body: any;
  await assert.rejects(
    () => harness.service.verifyOtp({ phone, purpose: OtpPurpose.LOGIN, code: "123456" }),
    (error: any) => {
      body = error.getResponse();
      return error.getStatus() === 404;
    },
  );
  return body;
}

test("POST /auth/password sets a first password without the current one and keeps every session", async () => {
  const h = createHarness();
  const user = await h.addUser();
  const current = await h.addSession(user.id);
  const other = await h.addSession(user.id);

  const result = await h.service.setApplicationPassword(
    await h.identity(user.id, current.id),
    { newPassword: "first-pass" },
  );

  assert.deepEqual(result, { passwordSet: true });
  assert.ok(await bcryptjs.compare("first-pass", h.users[0].passwordHash));
  assert.equal(bcryptjs.getRounds(h.users[0].passwordHash), 10);
  assert.equal(other.revokedAt, null, "setting a first password revokes nothing");
  assert.equal(h.throttle.reserved, 0);
});

test("changing the password requires the current one and revokes only the other sessions", async () => {
  const h = createHarness();
  const user = await h.addUser({ passwordHash: await bcryptjs.hash("old-pass", 4) });
  const current = await h.addSession(user.id);
  const other = await h.addSession(user.id);
  const identity = await h.identity(user.id, current.id);

  for (const currentPassword of [undefined, "wrong-pass"]) {
    await assert.rejects(
      () => h.service.setApplicationPassword(identity, { newPassword: "new-pass", currentPassword }),
      (error: any) =>
        error.getStatus() === 401 &&
        error.getResponse().code === AuthErrorCode.INVALID_CREDENTIALS,
    );
  }
  assert.ok(await bcryptjs.compare("old-pass", h.users[0].passwordHash));
  assert.equal(h.throttle.reserved, 2, "failed checks count against the login throttle");
  assert.equal(h.throttle.cleared, 0);

  await h.service.setApplicationPassword(identity, {
    newPassword: "new-pass", currentPassword: "old-pass",
  });
  assert.ok(await bcryptjs.compare("new-pass", h.users[0].passwordHash));
  assert.equal(current.revokedAt, null, "the caller's own session stays");
  assert.ok(other.revokedAt, "every other session is revoked");
  assert.deepEqual(h.disconnectedSessions, [other.id]);
  assert.deepEqual(
    h.outbox.map((event) => [event.type, event.payload]),
    [
      ["SESSION_REVOKED", { sessionId: other.id }],
      // RA-BE-133: the phones signed out let go of their push registrations.
      ["PUSH_INSTALLATIONS_RELEASED", { userId: user.id }],
    ],
  );
  assert.equal(h.throttle.cleared, 1);
});

// D112 (Q-11), RA-BE-133: a new password signed the other phones out but left
// their push registrations bound, so a lost phone kept receiving the
// account's notification titles. They go now; the phone that changed the
// password names its own registration and keeps it.
test("a password change releases the other phones' push registrations and keeps the caller's", async () => {
  const h = createHarness();
  const user = await h.addUser({ passwordHash: await bcryptjs.hash("old-pass", 4) });
  const current = await h.addSession(user.id);
  await h.addSession(user.id);

  await h.service.setApplicationPassword(await h.identity(user.id, current.id), {
    newPassword: "new-pass",
    currentPassword: "old-pass",
    pushInstallationId: "this-phone-fid-1",
  });

  assert.deepEqual(
    h.outbox
      .filter((event) => event.type === "PUSH_INSTALLATIONS_RELEASED")
      .map((event) => [event.aggregateId, event.payload]),
    [[user.id, { userId: user.id, keepInstallationFid: "this-phone-fid-1" }]],
  );
  assert.equal(
    h.outbox.some((event) => event.type === "USER_SESSIONS_REVOKED"),
    false,
    "the caller's own sockets stay",
  );
});

test("a first password signs no phone out and releases no push registration", async () => {
  const h = createHarness();
  const user = await h.addUser();
  const current = await h.addSession(user.id);
  await h.addSession(user.id);

  await h.service.setApplicationPassword(await h.identity(user.id, current.id), {
    newPassword: "first-pass",
  });

  assert.deepEqual(h.outbox, []);
});

test("an administrator's application password is its appPasswordHash, never the admin password", async () => {
  const h = createHarness();
  const adminHash = await bcryptjs.hash("admin-pass", 4);
  const user = await h.addUser({
    role: "ADMIN", passwordHash: adminHash, appPasswordHash: await bcryptjs.hash("app-pass", 4),
  });
  const current = await h.addSession(user.id);
  const identity = await h.identity(user.id, current.id);

  await assert.rejects(
    () => h.service.setApplicationPassword(identity, {
      newPassword: "new-app-pass", currentPassword: "admin-pass",
    }),
    (error: any) => error.getResponse().code === AuthErrorCode.INVALID_CREDENTIALS,
  );
  await h.service.setApplicationPassword(identity, {
    newPassword: "new-app-pass", currentPassword: "app-pass",
  });
  assert.equal(h.users[0].passwordHash, adminHash);
  assert.ok(await bcryptjs.compare("new-app-pass", h.users[0].appPasswordHash));
});

test("an admin session cannot set the application password", async () => {
  const h = createHarness();
  const user = await h.addUser({ role: "ADMIN", passwordHash: await bcryptjs.hash("admin-pass", 4) });
  const adminSession = await h.addSession(user.id, "ADMIN");
  const identity = await h.identity(user.id, adminSession.id, "admin");

  const guard = new JwtAuthGuard();
  assert.throws(
    () => guard.handleRequest(null, identity, null, { getHandler: () => () => undefined } as any),
    /Application session is required/,
  );
  await assert.rejects(
    () => h.service.setApplicationPassword(identity, { newPassword: "new-pass" }),
    /Application session is required/,
  );
  assert.equal(h.users[0].appPasswordHash, null);
});

test("the set-password body enforces the password policy", async () => {
  const pipe = new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
  const metadata = { type: "body" as const, metatype: SetPasswordDto };
  await assert.rejects(() => pipe.transform({ newPassword: "12345" }, metadata));
  await assert.rejects(() => pipe.transform({ newPassword: "ب".repeat(37) }, metadata));
  await assert.rejects(() => pipe.transform({ newPassword: "secret1", currentPassword: "" }, metadata));
  const ok = await pipe.transform({ newPassword: "secret1", currentPassword: "old-pass" }, metadata);
  assert.equal(ok.newPassword, "secret1");
  // RA-BE-133: the phone's push registration, as the push route takes it.
  for (const pushInstallationId of ["short", "has space-in-it", "x".repeat(201)]) {
    await assert.rejects(
      () => pipe.transform({ newPassword: "secret1", pushInstallationId }, metadata),
      pushInstallationId,
    );
  }
  const withPhone = await pipe.transform(
    { newPassword: "secret1", pushInstallationId: "fid_ABC-123456" },
    metadata,
  );
  assert.equal(withPhone.pushInstallationId, "fid_ABC-123456");
});

test("GET /auth/me reports hasPassword for the session's realm", async () => {
  const h = createHarness();
  const passwordless = await h.addUser();
  const withPassword = await h.addUser({
    phone: "+967777000111", passwordHash: await bcryptjs.hash("secret1", 4),
  });
  const admin = await h.addUser({
    phone: "+967777000222", role: "ADMIN", passwordHash: await bcryptjs.hash("admin-pass", 4),
  });

  const me = async (userId: string, scope: "application" | "admin" = "application") => {
    const session = await h.addSession(userId, scope === "admin" ? "ADMIN" : "APPLICATION");
    return toSafeUser(await h.identity(userId, session.id, scope));
  };

  assert.equal((await me(passwordless.id)).hasPassword, false);
  assert.equal((await me(withPassword.id)).hasPassword, true);
  // An admin row without an app password: the app realm has none.
  assert.equal((await me(admin.id)).hasPassword, false);
  assert.equal((await me(admin.id, "admin")).hasPassword, true);
  const json = JSON.parse(JSON.stringify(await me(withPassword.id)));
  assert.equal(json.hasPassword, true);
  assert.equal("passwordHash" in json || "appPasswordHash" in json, false);
});

test("a LOGIN code for a number without an account answers with a phone proof", async () => {
  const h = createHarness();
  const body = await loginNotFoundProof(h);

  assert.equal(body.code, AuthErrorCode.ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF);
  assert.equal(body.statusCode, 404);
  assert.equal(typeof body.phoneProof, "string");
  const decoded: any = h.jwt.decode(body.phoneProof);
  assert.equal(decoded.typ, PHONE_PROOF_TYPE);
  assert.equal(decoded.phone, PHONE);
  assert.equal(decoded.aud, PHONE_PROOF_AUDIENCE);
  assert.equal(decoded.exp - decoded.iat, 600);
  assert.equal(decoded.sub, undefined);
  assert.ok(h.otps[0].consumedAt, "the code is consumed");
  assert.equal(h.users.length, 0);
});

test("a phone proof creates an account once and never signs in to it", async () => {
  const h = createHarness();
  const { phoneProof } = await loginNotFoundProof(h);

  const created = await h.service.completeRegistration({
    name: "New Person", phone: "777123456", phoneProof,
  });
  assert.equal(created.existingAccount, false);
  assert.equal(h.users.length, 1);
  assert.equal(h.users[0].name, "New Person");
  assert.equal(h.users[0].passwordHash, null);
  assert.ok(h.users[0].appAccountActivatedAt);
  assert.equal(resolveJwtSessionScope(h.jwt.verify(created.accessToken)), "application");

  // Replayed within its 10 minutes it opens nothing: signing in takes a code.
  await assert.rejects(
    () => h.service.completeRegistration({ name: "Other Name", phone: PHONE, phoneProof }),
    (error: any) => error.getResponse().code === AuthErrorCode.OTP_INVALID_OR_EXPIRED,
  );
  assert.equal(h.users[0].name, "New Person");
});

test("a phone proof keeps the disabled and admin answers of a REGISTER code", async () => {
  const h = createHarness();
  const { phoneProof } = await loginNotFoundProof(h);
  await h.addUser({ status: "DISABLED" });
  await assert.rejects(
    () => h.service.completeRegistration({ name: "X", phone: PHONE, phoneProof }),
    (error: any) => error.getResponse().code === AuthErrorCode.ACCOUNT_DISABLED_AFTER_PHONE_PROOF,
  );
  h.users[0].status = "ACTIVE";
  h.users[0].role = "ADMIN";
  h.users[0].appAccountActivatedAt = null;
  await assert.rejects(
    () => h.service.completeRegistration({ name: "X", phone: PHONE, phoneProof }),
    (error: any) => error.getResponse().code === AuthErrorCode.ADMIN_APP_PASSWORD_REQUIRED,
  );
});

test("register/complete rejects a proof for another phone, expired, of another type, or an access token", async () => {
  const h = createHarness();
  const { phoneProof } = await loginNotFoundProof(h, "+967777999888");
  const raw = new JwtService({ secret: JWT_SECRET });
  const expired = raw.sign(
    { typ: PHONE_PROOF_TYPE, phone: PHONE, exp: Math.floor(Date.now() / 1000) - 5 },
    { audience: PHONE_PROOF_AUDIENCE },
  );
  const wrongType = raw.sign(
    { typ: "password-reset", phone: PHONE },
    { audience: PHONE_PROOF_AUDIENCE, expiresIn: 600 },
  );
  const forged = new JwtService({ secret: "Zr8Lq2Wn5Xv1Pt7Hm4Kc9Bd3Fs6Gj0Ya" }).sign(
    { typ: PHONE_PROOF_TYPE, phone: PHONE },
    { audience: PHONE_PROOF_AUDIENCE, expiresIn: 600 },
  );
  const user = await h.addUser({ phone: "+967777000333" });
  const session = await h.addSession(user.id);
  const accessToken = h.jwt.sign({ sub: user.id, phone: PHONE, scope: "application", sid: session.id });

  for (const proof of [phoneProof, expired, wrongType, forged, accessToken]) {
    await assert.rejects(
      () => h.service.completeRegistration({ name: "X", phone: PHONE, phoneProof: proof }),
      (error: any) => error.getResponse().code === AuthErrorCode.OTP_INVALID_OR_EXPIRED,
    );
  }
  assert.equal(h.users.length, 1, "no account was created");

  await assert.rejects(
    () => h.service.completeRegistration({ name: "X", phone: PHONE }),
    /exactly one of otpCode or phoneProof/,
  );
  await assert.rejects(
    () => h.service.completeRegistration({
      name: "X", phone: "+967777999888", phoneProof, otpCode: "123456",
    }),
    /exactly one of otpCode or phoneProof/,
  );
});

test("a phone proof is never an access token", async () => {
  const h = createHarness();
  const { phoneProof } = await loginNotFoundProof(h);
  const payload: any = h.jwt.verify(phoneProof, { audience: PHONE_PROOF_AUDIENCE });

  assert.equal(resolveJwtSessionScope(payload), null);
  // Even a proof that also claimed a session's fields stays rejected.
  assert.equal(
    resolveJwtSessionScope({ ...payload, sub: "user-1", scope: "application", sid: "session-1" }),
    null,
  );
  await assert.rejects(() => h.strategy.validate(payload), /Session is invalid or expired/);
  assert.equal(isPhoneProofFor(h.jwt, phoneProof, PHONE), true);
});
