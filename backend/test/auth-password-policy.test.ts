import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { plainToInstance } from "class-transformer";
import { validate } from "class-validator";
import { CompleteRegistrationDto } from "../src/modules/identity/api/auth-dto/complete-registration.dto";
import { LoginDto } from "../src/modules/identity/api/auth-dto/login.dto";
import { PasswordResetConfirmDto } from "../src/modules/identity/api/auth-dto/password-reset-confirm.dto";
import { AdminPasswordResetConfirmDto } from "../src/modules/identity/api/auth-dto/admin-password-reset-confirm.dto";
import { SetPasswordDto } from "../src/modules/identity/api/auth-dto/set-password.dto";
import { VerifyInviteOtpDto } from "../src/modules/collaboration/api/dto/verify-invite-otp.dto";

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
    newPassword: `${"ع".repeat(37)}1A`,
  });
  assert.ok(errors.some((error) => error.property === "newPassword"));
});

test("administrator recovery accepts the application password rule", async () => {
  const valid = (newPassword: string) =>
    errorsFor(AdminPasswordResetConfirmDto, {
      challengeToken: "a".repeat(64),
      newPassword,
    });
  // RA-BE-149: 8 or more, as an application password.
  assert.equal((await valid("12345678")).length, 0);
  assert.equal((await valid("abcdefgh")).length, 0);
  assert.ok((await valid("1234567")).some((error) => error.property === "newPassword"));
});

test("registration accepts no password, but a given one still follows the rule", async () => {
  const base = { name: "User", phone: "777123456", otpCode: "123456" };
  assert.equal((await errorsFor(CompleteRegistrationDto, base)).length, 0);
  assert.ok(
    (await errorsFor(CompleteRegistrationDto, { ...base, password: "1234567" }))
      .some((error) => error.property === "password"),
  );
  assert.ok(
    (await errorsFor(CompleteRegistrationDto, { ...base, password: "" }))
      .some((error) => error.property === "password"),
  );
  assert.equal(
    (await errorsFor(CompleteRegistrationDto, { ...base, password: "secret123" }))
      .length,
    0,
  );
});

// RA-BE-149 (NIST SP 800-63B): a password chosen from now on is 8 characters
// or more, and the refusal says so in the app's words. A password set before
// keeps signing in until its owner changes it: sign-in checks no length.
const SHORT_PASSWORD_MESSAGE = "كلمة المرور لازم تكون 8 أحرف أو أكثر";

test("RA-BE-149: every new password is 8 characters or more, refused in the dialect", async () => {
  const cases: Array<[string, new () => object, object, string]> = [
    ["set", SetPasswordDto, {}, "newPassword"],
    ["register", CompleteRegistrationDto, { name: "User", phone: "777123456", otpCode: "123456" }, "password"],
    ["reset", PasswordResetConfirmDto, { phone: "777123456", code: "123456" }, "newPassword"],
    ["admin reset", AdminPasswordResetConfirmDto, { challengeToken: "a".repeat(64) }, "newPassword"],
    ["invite", VerifyInviteOtpDto, { token: "t".repeat(43), phone: "777123456", code: "123456" }, "password"],
  ];
  for (const [name, type, base, field] of cases) {
    const short = (await errorsFor(type, { ...base, [field]: "abc1234" })).find(
      (error) => error.property === field,
    );
    assert.ok(short, `${name}: 7 characters are refused`);
    assert.equal(short.constraints?.minLength, SHORT_PASSWORD_MESSAGE, name);
    assert.equal(
      (await errorsFor(type, { ...base, [field]: "abcd1234" })).some(
        (error) => error.property === field,
      ),
      false,
      `${name}: 8 characters are accepted`,
    );
  }
});

test("RA-BE-149: a password set before keeps signing in whatever its length", async () => {
  assert.equal(
    (await errorsFor(LoginDto, { phone: "777123456", password: "abc123" })).length,
    0,
  );
});
