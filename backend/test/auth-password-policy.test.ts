import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { CompleteRegistrationDto } from "../src/auth/dto/complete-registration.dto";
import { LoginDto } from "../src/auth/dto/login.dto";
import { PasswordResetConfirmDto } from "../src/auth/dto/password-reset-confirm.dto";
import { AdminPasswordResetConfirmDto } from "../src/auth/dto/admin-password-reset-confirm.dto";

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

test("administrator recovery uses the same byte-safe bcrypt boundary", async () => {
  const errors = await errorsFor(AdminPasswordResetConfirmDto, {
    challengeToken: "a".repeat(64),
    code: "123456",
    newPassword: `${"ع".repeat(37)}1A`,
  });
  assert.ok(errors.some((error) => error.property === "newPassword"));
});
