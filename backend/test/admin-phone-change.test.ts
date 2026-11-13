import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { ForbiddenException } from "@nestjs/common";
import { AdminRole, AppRole, UserRole, UserStatus } from "@prisma/client";
import { AuthUserRepository } from "../src/modules/identity/infrastructure/auth-user.repository";
import type { AuthenticatedUser } from "../src/modules/identity/public/identity-session.types";
import { authService } from "./support/owner-ports";

// RA-BE-19: one `User.phone` carries an administrator's second factor and
// recovery, and the application could move it. The app password alone (six
// characters, one factor) signed the admin into the app; the app's phone
// change then sent the admin login code and the admin recovery to another
// number. An administrator's phone does not change from the application.

const untouchable = new Proxy(
  {},
  {
    get(_target, property) {
      throw new Error(`the refusal must come before the database (${String(property)})`);
    },
  },
);

function service() {
  return authService(
    untouchable,
    {},
    {},
    { consume: async () => { throw new Error("no code may be sent"); } },
    { disconnectUser: () => undefined },
  );
}

const admin: AuthenticatedUser = {
  id: "admin-1",
  name: "Admin",
  phone: "+967777000001",
  email: null,
  role: UserRole.ADMIN,
  adminRole: AdminRole.SUPER_ADMIN,
  appRole: AppRole.WEDDING_USER,
  status: UserStatus.ACTIVE,
  phoneVerifiedAt: new Date(),
} as AuthenticatedUser;

async function refused(action: Promise<unknown>) {
  try {
    await action;
  } catch (error) {
    assert.ok(error instanceof ForbiddenException, `expected 403, got ${String(error)}`);
    const body = error.getResponse() as { code?: string; message?: string };
    assert.equal(body.code, "ADMIN_PHONE_CHANGE_REFUSED");
    assert.match(String(body.message), /الإدارة/);
    return;
  }
  assert.fail("an administrator's phone change was not refused");
}

test("an administrator's app session cannot ask a code for a new phone", async () => {
  await refused(service().requestPhoneChange(admin, "+967777999999"));
});

test("nor confirm one", async () => {
  await refused(service().confirmPhoneChange(admin, "+967777999999", "123456"));
});

// RA-BE-127: an app session carries the administrator as USER; the session's
// role never refused, a code went to the new number, and the write's own
// refusal came back as a general 401. The stored role refuses first.
test("an administrator signed into the app as USER is refused before any code", async () => {
  const appSession = { ...admin, role: UserRole.USER } as AuthenticatedUser;
  const stored = authService(
    { user: { findUnique: async () => ({ id: "admin-1", role: UserRole.ADMIN }) } },
    {},
    {},
    { consume: async () => { throw new Error("no code may be sent"); } },
    { disconnectUser: () => undefined },
  );
  await refused(stored.requestPhoneChange(appSession, "+967777999999"));
  await refused(stored.confirmPhoneChange(appSession, "+967777999999", "123456"));
});

test("the write itself never moves an administrator's phone", async () => {
  let where: unknown;
  const repository = new AuthUserRepository();
  await repository.changePhone(
    { user: { updateMany: async (args: { where: unknown }) => { where = args.where; return { count: 0 }; } } } as never,
    "user-1",
    "+967777999999",
    new Date(),
  );
  assert.deepEqual(where, { id: "user-1", status: "ACTIVE", role: { not: UserRole.ADMIN } });
});
