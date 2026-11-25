import "reflect-metadata";

import assert from "node:assert/strict";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { Logger } from "@nestjs/common";
import * as bcryptjs from "bcryptjs";
import { AuthService } from "../src/modules/identity/internal/auth/auth.service";
import {
  OTP_CODE_HASH_COST,
  PASSWORD_HASH_COST,
  hashPassword,
} from "../src/modules/identity/internal/auth/password-hash";
import { authService } from "./support/owner-ports";

// RA-BE-149 (D124): a new password hash costs bcrypt 12 (about 300 ms with
// bcryptjs; sign-in is throttled), from one constant. A sign-in with an older,
// cheaper hash re-hashes it at 12, best-effort: the sign-in never fails for
// it. A WhatsApp code's hash stays at 10: it lives five minutes and its
// attempts are counted.

const PHONE = "+967777123456";
const PASSWORD = "secret-pass-123";

function loginHarness(
  stored: { passwordHash?: string | null; appPasswordHash?: string | null; role?: string },
  options: { failUpgrade?: boolean; beforeUpgrade?: (user: any) => void } = {},
) {
  const user: any = {
    id: "user-1",
    phone: PHONE,
    name: "علي",
    email: null,
    role: stored.role ?? "USER",
    adminRole: null,
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    passwordHash: stored.passwordHash ?? null,
    appPasswordHash: stored.appPasswordHash ?? null,
    appAccountActivatedAt: new Date("2026-01-01T00:00:00Z"),
    phoneVerifiedAt: new Date("2026-01-01T00:00:00Z"),
    appName: null,
    appEmail: null,
    appAvatarUrl: null,
    avatarUrl: null,
    locale: "ar",
    lastLoginAt: null,
    deletionRequestedAt: null,
    createdAt: new Date("2026-01-01T00:00:00Z"),
    updatedAt: new Date("2026-01-01T00:00:00Z"),
  };
  const upgrades: any[] = [];
  const matches = (where: any) =>
    Object.entries(where).every(([key, value]) => {
      if (value && typeof value === "object" && "not" in (value as any)) {
        return user[key] !== null;
      }
      return user[key] === value;
    });
  const prisma: any = {
    user: {
      findFirst: async ({ where }: any) => (where.phone === PHONE ? { ...user } : null),
      findUniqueOrThrow: async () => ({ ...user }),
      findUnique: async () => ({ ...user }),
      updateMany: async ({ where, data }: any) => {
        const upgrade = "passwordHash" in data || "appPasswordHash" in data;
        if (upgrade) {
          options.beforeUpgrade?.(user);
          upgrades.push({ where, data });
          if (options.failUpgrade) throw new Error("database unavailable");
        }
        if (!matches(where)) return { count: 0 };
        Object.assign(user, data);
        return { count: 1 };
      },
    },
    refreshToken: {
      create: async ({ data }: any) => ({ id: "session-1", ...data }),
    },
    $transaction: async (work: any) => work(prisma),
  };
  const service = authService(
    prisma,
    { sign: () => "signed-access-token" },
    { reserveAttempt: async () => undefined, clear: async () => undefined },
    { consume: async () => undefined },
    { disconnectUser: () => undefined, disconnectSession: () => undefined },
  );
  return { service, user, upgrades };
}

test("RA-BE-149: one password cost of 12; the WhatsApp code's hash stays at 10", async () => {
  assert.equal(PASSWORD_HASH_COST, 12);
  assert.equal(OTP_CODE_HASH_COST, 10);
  const hash = await hashPassword(PASSWORD);
  assert.equal(bcryptjs.getRounds(hash), PASSWORD_HASH_COST);
  assert.ok(await bcryptjs.compare(PASSWORD, hash));
  // A missing account costs what a real one does.
  assert.equal(bcryptjs.getRounds((AuthService as any).dummyPasswordHash), PASSWORD_HASH_COST);
});

test("RA-BE-149: no identity code hashes with a cost of its own", () => {
  const root = join(__dirname, "..", "src", "modules", "identity");
  const files: string[] = [];
  const walk = (dir: string) => {
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      if (statSync(full).isDirectory()) walk(full);
      else if (full.endsWith(".ts")) files.push(full);
    }
  };
  walk(root);
  const literal: string[] = [];
  for (const file of files) {
    const source = readFileSync(file, "utf8");
    for (const match of source.matchAll(/bcryptjs\.hash\(([^;]*?)\)/gsu)) {
      if (!/(PASSWORD_HASH_COST|OTP_CODE_HASH_COST)\s*$/u.test(match[1])) {
        literal.push(`${file.slice(root.length)}: ${match[0]}`);
      }
    }
  }
  assert.deepEqual(literal, []);
});

test("RA-BE-149: a sign-in with a cost-10 hash stores it again at 12", async () => {
  const { service, user, upgrades } = loginHarness({
    passwordHash: await bcryptjs.hash(PASSWORD, 10),
  });
  const before = user.passwordHash;

  const response = await service.login({ phone: "777123456", password: PASSWORD });

  assert.equal(response.accessToken, "signed-access-token");
  assert.equal(upgrades.length, 1);
  // Only the hash the sign-in proved is replaced (a change since then wins).
  assert.deepEqual(upgrades[0].where, { id: user.id, passwordHash: before });
  assert.notEqual(user.passwordHash, before);
  assert.equal(bcryptjs.getRounds(user.passwordHash), PASSWORD_HASH_COST);
  assert.ok(await bcryptjs.compare(PASSWORD, user.passwordHash));
});

test("RA-BE-149: an administrator's application password is upgraded in its own field", async () => {
  const { service, user, upgrades } = loginHarness({
    role: "ADMIN",
    passwordHash: await bcryptjs.hash("admin-console-password", 12),
    appPasswordHash: await bcryptjs.hash(PASSWORD, 10),
  });
  const adminHash = user.passwordHash;

  await service.login({ phone: "777123456", password: PASSWORD });

  assert.equal(upgrades.length, 1);
  assert.equal(user.passwordHash, adminHash, "the console password is not touched");
  assert.equal(bcryptjs.getRounds(user.appPasswordHash), PASSWORD_HASH_COST);
  assert.ok(await bcryptjs.compare(PASSWORD, user.appPasswordHash));
});

test("RA-BE-149: a hash already at 12 is left as it is", async () => {
  const { service, upgrades } = loginHarness({
    passwordHash: await bcryptjs.hash(PASSWORD, 12),
  });
  await service.login({ phone: "777123456", password: PASSWORD });
  assert.equal(upgrades.length, 0);
});

test("RA-BE-149: the sign-in stands when the upgrade fails, and the failure is logged", async (t) => {
  const warnings: unknown[] = [];
  t.mock.method(Logger.prototype, "warn", (message: unknown) => {
    warnings.push(message);
  });
  const { service, user, upgrades } = loginHarness(
    { passwordHash: await bcryptjs.hash(PASSWORD, 10) },
    { failUpgrade: true },
  );
  const before = user.passwordHash;

  const response = await service.login({ phone: "777123456", password: PASSWORD });

  assert.equal(response.accessToken, "signed-access-token");
  assert.equal(upgrades.length, 1);
  assert.equal(user.passwordHash, before);
  assert.deepEqual(warnings, [{ event: "password_hash_upgrade_failed" }]);
});

test("RA-BE-149: a password changed between the sign-in and its upgrade is kept", async () => {
  const changed = await bcryptjs.hash("changed-meanwhile", 12);
  const { service, user } = loginHarness(
    { passwordHash: await bcryptjs.hash(PASSWORD, 10) },
    { beforeUpgrade: (row) => { row.passwordHash = changed; } },
  );
  await service.login({ phone: "777123456", password: PASSWORD });
  assert.equal(user.passwordHash, changed);
});
