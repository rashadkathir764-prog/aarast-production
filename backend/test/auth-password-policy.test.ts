import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { CompleteRegistrationDto } from "../src/modules/identity/api/auth-dto/complete-registration.dto";
import { LoginDto } from "../src/modules/identity/api/auth-dto/login.dto";
import { PasswordResetConfirmDto } from "../src/modules/identity/api/auth-dto/password-reset-confirm.dto";
import { AdminPasswordResetConfirmDto } from "../src/modules/identity/api/auth-dto/admin-password-reset-confirm.dto";

async function errorsFor<T extends object>(type: new () => T, value: object) {
  return validate(plainToInstance(type, value));
}

test("application password inputs reject bcrypt truncation beyond 72 UTF-8 bytes", async () => {
  const accepted = "a".repeat(72);
  const rejectedAscii = "a".repeat(73);
  const rejectedArabic = "ع".repeat(37);

  assert.equal(
    (await errorsFor(LoginDto, { phone: "777123456", password: accepted }))
      .length,
    0,
  );
  assert.ok(
    (await errorsFor(LoginDto, {
      phone: "777123456",
      password: rejectedAscii,
    })).some((error) => error.property === "password"),
  );
  assert.ok(
    (await errorsFor(CompleteRegistrationDto, {
      name: "User",
      phone: "777123456",
      password: rejectedArabic,
      otpCode: "123456",
    })).some((error) => error.property === "password"),
  );
  assert.ok(
    (await errorsFor(PasswordResetConfirmDto, {
      phone: "777123456",
      code: "123456",
      newPassword: rejectedArabic,
    })).some((error) => error.property === "newPassword"),
  );
});

test("password reset confirm rejects a non six-digit code before it burns an attempt", async () => {
  for (const code of ["12345", "1234567", "12 456", "abcdef", " 123456"]) {
    assert.ok(
      (await errorsFor(PasswordResetConfirmDto, {
        phone: "777123456",
        code,
        newPassword: "abcdef",
      })).some((error) => error.property === "code"),
      `expected code "${code}" to be rejected`,
    );
  }
  assert.equal(
    (await errorsFor(PasswordResetConfirmDto, {
      phone: "777123456",
      code: "123456",
      newPassword: "abcdef",
    })).some((error) => error.property === "code"),
    false,
  );
});

test("administrator recovery uses the same byte-safe bcrypt boundary", async () => {
  const errors = await errorsFor(AdminPasswordResetConfirmDto, {
    challengeToken: "a".repeat(64),
    code: "123456",
    newPassword: `${"ع".repeat(37)}1A`,
  });
  assert.ok(errors.some((error) => error.property === "newPassword"));
});
