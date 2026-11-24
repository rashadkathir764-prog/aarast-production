import assert from "node:assert/strict";
import { test } from "node:test";
import * as bcryptjs from "bcryptjs";
import {
  ADMIN_TRUSTED_DEVICE_TTL_MS,
  adminTrustedDeviceTokenHash,
  isAdminTrustedDeviceRecord,
  issueAdminTrustedDevice,
} from "../src/modules/identity/internal/auth/admin-trusted-device";
import { hashRefreshToken } from "../src/modules/identity/internal/auth/refresh-token-policy";
import { authService } from "./support/owner-ports";

// RA-AD-26: a remembered device is a row the server keeps, so it can be
// revoked, and a token the server never stored trusts nothing. The cookie
// is a random value; the row holds its digest, the admin, the expiry and a
// fingerprint of the password hash it was issued under.

const env = { JWT_SECRET: "k3Q9-zv8Lp2X_rT7mW4yN6bH1cJ5dF0g", NODE_ENV: "test" };
const admin = { id: "admin-1", passwordHash: "$2a$12$abcdefghijklmnopqrstuv" };
const now = new Date("2026-10-14T08:00:00.000Z");

test("the device cookie is an opaque random value whose digest the server keeps", () => {
  const first = issueAdminTrustedDevice(admin, now, env);
  const second = issueAdminTrustedDevice(admin, now, env);
  assert.match(first.token, /^[a-f0-9]{64}$/);
  assert.notEqual(first.token, second.token);
  assert.equal(first.record.userId, admin.id);
  assert.equal(first.record.tokenHash, hashRefreshToken(first.token));
  assert.equal(adminTrustedDeviceTokenHash(first.token), first.record.tokenHash);
  assert.equal(first.record.expiresAt.getTime(), first.expiresAt.getTime());
  assert.doesNotMatch(first.token, new RegExp(Buffer.from(admin.id).toString("hex")));
});

test("a remembered device signs the same admin in for 30 days", () => {
  const { record, expiresAt } = issueAdminTrustedDevice(admin, now, env);
  const stored = { ...record, revokedAt: null };
  assert.equal(expiresAt.getTime() - now.getTime(), ADMIN_TRUSTED_DEVICE_TTL_MS);
  assert.equal(isAdminTrustedDeviceRecord(stored, admin, now, env), true);
  const almost = new Date(expiresAt.getTime() - 1);
  assert.equal(isAdminTrustedDeviceRecord(stored, admin, almost, env), true);
  assert.equal(isAdminTrustedDeviceRecord(stored, admin, expiresAt, env), false);
});

test("changing the password forgets every remembered device", () => {
  const { record } = issueAdminTrustedDevice(admin, now, env);
  const afterReset = { ...admin, passwordHash: "$2a$12$zyxwvutsrqponmlkjihgfe" };
  assert.equal(
    isAdminTrustedDeviceRecord({ ...record, revokedAt: null }, afterReset, now, env),
    false,
  );
});

test("a device remembered for one admin does not open another", () => {
  const { record } = issueAdminTrustedDevice(admin, now, env);
  assert.equal(
    isAdminTrustedDeviceRecord({ ...record, revokedAt: null }, { ...admin, id: "admin-2" }, now, env),
    false,
  );
});

test("a revoked, missing, malformed or foreign-key device is refused", () => {
  const { token, record } = issueAdminTrustedDevice(admin, now, env);
  assert.equal(isAdminTrustedDeviceRecord({ ...record, revokedAt: now }, admin, now, env), false);
  assert.equal(isAdminTrustedDeviceRecord(null, admin, now, env), false);
  assert.equal(adminTrustedDeviceTokenHash(""), null);
  assert.equal(adminTrustedDeviceTokenHash(null), null);
  assert.equal(adminTrustedDeviceTokenHash(`${token}.extra`), null);
  assert.equal(adminTrustedDeviceTokenHash(token.toUpperCase()), null);
  const otherServer = { ...env, JWT_SECRET: "Zq7-Wm2Lp9X_cV4nB8yR1tH6kJ3dF5gS" };
  assert.equal(
    isAdminTrustedDeviceRecord({ ...record, revokedAt: null }, admin, now, otherServer),
    false,
  );
});

/** An admin, its stored devices and sessions, behind the fake client AuthService reads. */
async function harness() {
  // The service signs and checks devices with the server's own key.
  process.env.JWT_SECRET = env.JWT_SECRET;
  const password = "Aarast-admin-2026";
  const passwordHash = await bcryptjs.hash(password, 12);
  const at = new Date();
  const user = {
    id: "admin-1",
    name: "Aarast Admin",
    phone: "+967777123456",
    email: null,
    role: "ADMIN",
    adminRole: "SUPER_ADMIN",
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: at,
    lastLoginAt: at,
    passwordHash,
    appPasswordHash: null,
    appAccountActivatedAt: null,
    avatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    createdAt: at,
    updatedAt: at,
  };
  const devices: Array<Record<string, any>> = [];
  const sessions: Array<Record<string, any>> = [];
  const client: any = {
    $queryRaw: async () => [{ id: user.id, status: "ACTIVE" }],
    user: {
      findFirst: async ({ where }: any) => (where.phone === user.phone ? user : null),
      findUnique: async () => user,
      findUniqueOrThrow: async () => user,
      updateMany: async () => ({ count: 1 }),
    },
    adminTrustedDevice: {
      findUnique: async ({ where }: any) =>
        devices.find((device) => device.tokenHash === where.tokenHash) ?? null,
      updateMany: async ({ where, data }: any) => {
        const matched = devices.filter(
          (device) =>
            device.id === where.id &&
            device.revokedAt === null &&
            device.expiresAt > where.expiresAt.gt,
        );
        for (const device of matched) Object.assign(device, data);
        return { count: matched.length };
      },
    },
    refreshToken: {
      create: async ({ data }: any) => {
        const row = { id: `session-${sessions.length + 1}`, ...data };
        sessions.push(row);
        return row;
      },
    },
  };
  client.$transaction = async (fn: any) => fn(client);
  const service = authService(
    client,
    { sign: () => "admin-access-token" } as any,
    { reserveAttempt: async () => undefined, clear: async () => undefined } as any,
    { consume: async () => undefined } as any,
    { disconnectUser: () => undefined, disconnectSession: () => undefined } as any,
  );
  // The code path is not under test: reaching it means the device was not trusted.
  (service as any).issueOtp = async () => {
    throw new Error("WHATSAPP_CODE_REQUIRED");
  };
  return { service, user, password, devices, sessions };
}

test("a device the server stored signs in with the password alone", async () => {
  const { service, user, password, devices, sessions } = await harness();
  const issued = issueAdminTrustedDevice(user, new Date());
  devices.push({ id: "device-1", ...issued.record, revokedAt: null, lastUsedAt: null });

  const result = await service.startAdminLogin(
    { phone: user.phone, password },
    {},
    issued.token,
  );

  assert.equal(result.mfaRequired, false);
  assert.equal(sessions.length, 1);
  // RA-AD-26: the session it opens ends twelve hours later.
  const lasts = sessions[0]!.expiresAt.getTime() - Date.now();
  assert.ok(lasts > 11.9 * 60 * 60 * 1000 && lasts <= 12 * 60 * 60 * 1000, String(lasts));
  assert.ok(devices[0]!.lastUsedAt instanceof Date);
});

test("a device token the server does not hold, or holds revoked, asks for the code", async () => {
  const { service, user, password, devices } = await harness();
  const unknown = issueAdminTrustedDevice(user, new Date());
  await assert.rejects(
    service.startAdminLogin({ phone: user.phone, password }, {}, unknown.token),
    /WHATSAPP_CODE_REQUIRED/,
  );

  const revoked = issueAdminTrustedDevice(user, new Date());
  devices.push({ id: "device-2", ...revoked.record, revokedAt: new Date(), lastUsedAt: null });
  await assert.rejects(
    service.startAdminLogin({ phone: user.phone, password }, {}, revoked.token),
    /WHATSAPP_CODE_REQUIRED/,
  );
});
