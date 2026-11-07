import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ForbiddenException, UnauthorizedException } from "@nestjs/common";
import { UsersController } from "../src/modules/identity/api/users.controller";
import { AccountDeletionStatusController } from "../src/modules/identity/api/account-deletion-status.controller";
import { MeController } from "../src/modules/identity/api/me.controller";
import { AuthController } from "../src/modules/identity/api/auth.controller";
import { PushController } from "../src/push/push.controller";
import { JwtAuthGuard } from "../src/modules/identity/public/jwt-auth.guard";
import { accountDeletionReceiptHash } from "../src/modules/identity/internal/profile/users.service";
import {
  ACCOUNT_DELETION_CONFIRM_WORD,
  ACCOUNT_DELETION_GRACE_DAYS,
} from "../src/modules/identity/internal/profile/account-deletion.service";
import { toSafeUser } from "../src/modules/identity/internal/safe-user.presenter";

// D63: an account is deleted after 30 days. The app asks for it and may take
// it back; while it waits it reaches only w06's routes; the hourly purge
// erases it through the one saga (test/account-deletion.test.ts).

function guardFor(handler: Function) {
  const guard = new JwtAuthGuard();
  const context = { getHandler: () => handler } as never;
  return (user: Record<string, unknown>) =>
    guard.handleRequest(null, { sessionScope: "application", ...user } as never, null, context);
}

test("D63: the deletion routes forward to the grace service", async () => {
  const seen: unknown[] = [];
  const controller = new AccountDeletionStatusController({
    impact: async (user: unknown) => (seen.push(["impact", user]), { graceDays: 30 }),
    request: async (user: unknown, word: string) => (seen.push(["request", user, word]), { status: "PENDING" }),
    status: (user: unknown) => (seen.push(["status", user]), { status: "NONE" }),
    cancel: async (user: unknown) => (seen.push(["cancel", user]), { status: "NONE" }),
  } as never);
  const users = new UsersController(
    {} as never,
    { create: async (user: unknown) => (seen.push(["export", user]), { id: "export-1" }) } as never,
  );
  const user = { id: "user-a" } as never;
  await controller.deletionImpact(user);
  await controller.requestDeletion(user, { confirmWord: "حذف" });
  controller.deletionStatus(user);
  await controller.cancelDeletion(user);
  await users.createExport(user);
  assert.deepEqual(seen, [
    ["impact", user],
    ["request", user, "حذف"],
    ["status", user],
    ["cancel", user],
    ["export", user],
  ]);
  assert.equal(ACCOUNT_DELETION_CONFIRM_WORD, "حذف");
  assert.equal(ACCOUNT_DELETION_GRACE_DAYS, 30);
  // The immediate erasure is no route of the app any more.
  assert.equal("deleteMe" in UsersController.prototype, false);
  assert.equal(
    Reflect.getMetadata("path", AccountDeletionStatusController),
    "api/v1/users/me/deletion",
  );
});

test("D63: an account waiting out its deletion reaches only w06's routes", () => {
  const pending = { id: "user-a", deletionScheduledFor: new Date("2026-11-27T09:00:00Z") };
  const allowed = [
    AccountDeletionStatusController.prototype.deletionStatus,
    AccountDeletionStatusController.prototype.cancelDeletion,
    MeController.prototype.me,
    AuthController.prototype.me,
    AuthController.prototype.logout,
    PushController.prototype.unregister,
    // RA-BE-56: these two were refused, which is the defect: in the 30 days
    // someone leaving wants their data most (the privacy page promises the
    // download), and signing out everywhere is a sign-out as `logout` is.
    UsersController.prototype.createExport,
    AuthController.prototype.logoutAll,
  ];
  for (const handler of allowed) {
    assert.equal(guardFor(handler)(pending).id, "user-a", handler.name);
  }
  const refused = [
    AccountDeletionStatusController.prototype.requestDeletion,
    AccountDeletionStatusController.prototype.deletionImpact,
    UsersController.prototype.updateMe,
    UsersController.prototype.getSettings,
    PushController.prototype.register,
  ];
  for (const handler of refused) {
    assert.throws(
      () => guardFor(handler)(pending),
      (error: unknown) =>
        error instanceof ForbiddenException &&
        (error.getResponse() as { code?: string }).code === "ACCOUNT_DELETION_PENDING",
      handler.name,
    );
  }
  // An account that waits for nothing passes every route, and the guard
  // still demands an application session.
  assert.equal(guardFor(UsersController.prototype.updateMe)({ id: "user-b", deletionScheduledFor: null }).id, "user-b");
  assert.throws(
    () =>
      new JwtAuthGuard().handleRequest(
        null,
        { id: "admin", sessionScope: "admin" } as never,
        null,
        { getHandler: () => MeController.prototype.me } as never,
      ),
    UnauthorizedException,
  );
});

test("D63: the session's user carries its pending deletion, never to an admin session", () => {
  const base = {
    id: "user-a",
    name: "سلمان",
    phone: null,
    email: null,
    role: "USER",
    adminRole: null,
    appRole: "WEDDING_USER",
    status: "ACTIVE",
    phoneVerifiedAt: null,
    lastLoginAt: null,
    avatarUrl: null,
    locale: "ar",
    activeWeddingPlanId: null,
    onboardingPath: null,
    persona: null,
    onboardingCompletedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    deletionRequestedAt: new Date("2026-10-28T09:00:00Z"),
    deletionScheduledFor: new Date("2026-11-27T09:00:00Z"),
  } as never;
  const safe = toSafeUser(base) as unknown as Record<string, unknown>;
  assert.deepEqual(safe.deletion, {
    requestedAt: new Date("2026-10-28T09:00:00Z"),
    scheduledFor: new Date("2026-11-27T09:00:00Z"),
  });
  assert.equal("deletionScheduledFor" in safe, false);
  assert.equal((toSafeUser(base, true) as unknown as Record<string, unknown>).deletion, null);
});

test("HTTP smokes leave through the grace: they ask, then run the purge; none erases at once", () => {
  const smokeDir = join(process.cwd(), "scripts", "smoke");
  for (const fileName of readdirSync(smokeDir).filter((name) => name.endsWith("-smoke.js"))) {
    const source = readFileSync(join(smokeDir, fileName), "utf8");
    assert.doesNotMatch(
      source,
      /request\(\s*["']DELETE["'],\s*["']\/api\/v1\/users\/me["']/,
      `${fileName} still calls the removed immediate erasure`,
    );
  }
  for (const fileName of [
    "assistant-smoke.js",
    "cost-receipts-smoke.js",
    "financial-ledger-concurrency-smoke.js",
    "mahr-smoke.js",
    "money-apis-smoke.js",
    "money-budget-smoke.js",
    "phone-change-smoke.js",
    "plan-partner-smoke.js",
    "quote-stability-smoke.js",
    "task-shift-smoke.js",
  ]) {
    const source = readFileSync(join(smokeDir, fileName), "utf8");
    assert.match(source, /require\('\.\/account-grace'\)/, fileName);
  }
});

test("receipt digest is stable and stores neither source identifier", () => {
  const digest = accountDeletionReceiptHash("user-a", "request-a");
  assert.match(digest, /^[0-9a-f]{64}$/);
  assert.equal(digest.includes("user-a"), false);
  assert.equal(digest.includes("request-a"), false);
  assert.notEqual(digest, accountDeletionReceiptHash("user-a", "request-b"));
});

test("receipt migration enforces append-only anonymous rows", () => {
  const migration = readFileSync(
    join(
      process.cwd(),
      "prisma",
      "migrations",
      "20260803110000_add_account_deletion_receipts",
      "migration.sql",
    ),
    "utf8",
  );
  assert.match(migration, /^BEGIN;\s*$/m);
  assert.match(migration, /SET LOCAL lock_timeout = '15s';/);
  assert.match(migration, /COMMIT;\s*$/);
  assert.match(migration, /CREATE TABLE "AccountDeletionReceipt"/);
  assert.match(migration, /CHECK \("receiptHash" ~ '\^\[0-9a-f\]\{64\}\$'\)/);
  assert.match(migration, /BEFORE UPDATE ON "AccountDeletionReceipt"/);
  assert.match(migration, /BEFORE DELETE ON "AccountDeletionReceipt"/);
  assert.doesNotMatch(migration, /CREATE OR REPLACE FUNCTION/);
  assert.doesNotMatch(migration, /"userId"|"clientRequestId"/);
});

test("D63 migration: a deletion request is whole, and a download link keeps only its digest", () => {
  const migration = readFileSync(
    join(
      process.cwd(),
      "prisma",
      "migrations",
      "20261028200000_account_deletion_grace_and_data_exports",
      "migration.sql",
    ),
    "utf8",
  );
  assert.match(migration, /"User_deletion_request_whole_check"/);
  assert.match(migration, /"deletionScheduledFor" > "deletionRequestedAt"/);
  assert.match(migration, /"tokenHash" CHAR\(64\) NOT NULL/);
  assert.match(migration, /CREATE UNIQUE INDEX "DataExport_tokenHash_key"/);
  assert.match(migration, /ON DELETE CASCADE/);
  assert.doesNotMatch(migration, /"token" /);
});
