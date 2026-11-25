import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { HttpException } from "@nestjs/common";
import { AdminRole, AppRole, OtpPurpose, UserRole, UserStatus } from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import type { AuthenticatedUser } from "../src/modules/identity/public/identity-session.types";
import { authService } from "./support/owner-ports";

// RA-BE-141: the account's phone moved with a session and a code to the new
// number alone, so whoever held a signed-in phone or a stolen token took the
// account to their number for good. The change now also needs a code to the
// current number, or the password.

process.env.AUTH_OTP_MODE = "whatsapp";

const CURRENT_PHONE = "+967777100001";
const NEW_PHONE = "+967777200002";
const PASSWORD = "Secret123";

interface OtpRow {
  id: string;
  phone: string;
  purpose: OtpPurpose;
  planInviteId: string | null;
  codeHash: string;
  consumedAt: Date | null;
  expiresAt: Date;
  attempts: number;
  maxAttempts: number;
  createdAt: Date;
  updatedAt: Date;
}

function matches(row: OtpRow, where: any): boolean {
  if (where.id !== undefined && row.id !== where.id) return false;
  if (where.phone !== undefined && row.phone !== where.phone) return false;
  if (where.purpose !== undefined && row.purpose !== where.purpose) return false;
  if ("planInviteId" in where && row.planInviteId !== where.planInviteId) return false;
  if ("consumedAt" in where) {
    if (where.consumedAt === null && row.consumedAt !== null) return false;
    if (where.consumedAt instanceof Date && row.consumedAt?.getTime() !== where.consumedAt.getTime()) {
      return false;
    }
  }
  if (where.expiresAt?.gt && row.expiresAt <= where.expiresAt.gt) return false;
  if (where.attempts?.lt !== undefined && row.attempts >= where.attempts.lt) return false;
  return true;
}

function harness(
  options: { passwordHash?: string | null; deliveryFails?: boolean } = {},
) {
  const notices: Array<{ phone: string; text: string }> = [];
  const user = {
    id: "user-1",
    phone: CURRENT_PHONE,
    status: UserStatus.ACTIVE,
    role: UserRole.USER,
    passwordHash:
      options.passwordHash === undefined ? bcryptjs.hashSync(PASSWORD, 4) : options.passwordHash,
  };
  const otps: OtpRow[] = [];
  const throttle: string[] = [];
  let transactions = 0;
  const addCode = (phone: string, purpose: OtpPurpose, code: string) => {
    const now = new Date();
    otps.push({
      id: `otp-${otps.length + 1}`,
      phone,
      purpose,
      planInviteId: null,
      codeHash: bcryptjs.hashSync(code, 4),
      consumedAt: null,
      expiresAt: new Date(now.getTime() + 5 * 60_000),
      attempts: 0,
      maxAttempts: 5,
      createdAt: now,
      updatedAt: now,
    });
  };
  const users = {
    findUnique: async ({ where }: any) => (where.id === user.id ? { ...user } : null),
    findFirst: async ({ where }: any) => {
      const phones: string[] = typeof where.phone === "string" ? [where.phone] : where.phone?.in ?? [];
      return phones.includes(user.phone) ? { ...user } : null;
    },
    updateMany: async ({ where, data }: any) => {
      if (where.id !== user.id) return { count: 0 };
      Object.assign(user, data);
      return { count: 1 };
    },
  };
  const tx: any = {
    $queryRaw: async (query: any) => {
      const sql = query?.strings?.join(" ") ?? "";
      if (sql.includes('FROM "User"')) {
        return [{ id: user.id, status: user.status, deletionPending: false }];
      }
      return [];
    },
    user: users,
    otpCode: {
      findFirst: async ({ where }: any) =>
        [...otps].reverse().find((row) => matches(row, where)) ?? null,
      findUnique: async ({ where }: any) => {
        const row = otps.find((candidate) => candidate.id === where.id);
        return row ? { ...row } : null;
      },
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const row of otps) {
          if (!matches(row, where)) continue;
          if (data.attempts?.increment) row.attempts += data.attempts.increment;
          if ("consumedAt" in data) row.consumedAt = data.consumedAt;
          if (data.updatedAt) row.updatedAt = data.updatedAt;
          count += 1;
        }
        return { count };
      },
    },
    refreshToken: { updateMany: async () => ({ count: 1 }) },
    outboxEvent: { create: async () => ({}) },
  };
  const prisma = {
    user: users,
    $transaction: async (operation: (client: any) => Promise<unknown>) => {
      transactions += 1;
      return operation(tx);
    },
  };
  const service = authService(
    prisma,
    {},
    {
      reserveAttempt: async (subject: string) => {
        throttle.push(`reserve:${subject}`);
      },
      clear: async (subject: string) => {
        throttle.push(`clear:${subject}`);
      },
    },
    { consume: async () => undefined },
    { disconnectUser: () => undefined },
    {
      send: async (input: { phone: string; text: string }) => {
        notices.push(input);
        if (options.deliveryFails) throw new Error("OpenWA is down");
      },
    },
  );
  const session = {
    id: user.id,
    name: "User",
    phone: CURRENT_PHONE,
    email: null,
    role: UserRole.USER,
    adminRole: AdminRole.SUPPORT,
    appRole: AppRole.WEDDING_USER,
    status: UserStatus.ACTIVE,
    phoneVerifiedAt: new Date(),
  } as unknown as AuthenticatedUser;
  return {
    service,
    session,
    user,
    otps,
    throttle,
    addCode,
    notices,
    get transactions() {
      return transactions;
    },
  };
}

const refusedWith = (status: number, code: string) => (error: unknown) => {
  assert.ok(error instanceof HttpException, String(error));
  assert.equal(error.getStatus(), status);
  assert.equal((error.getResponse() as { code?: string }).code, code);
  return true;
};

test("RA-BE-141: the new number's code alone moves nothing", async () => {
  const h = harness();
  h.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");

  await assert.rejects(
    h.service.confirmPhoneChange(h.session, NEW_PHONE, "222222"),
    refusedWith(400, "PHONE_CHANGE_PROOF_REQUIRED"),
  );
  assert.equal(h.user.phone, CURRENT_PHONE);
  assert.equal(h.transactions, 0);
  assert.equal(h.otps[0].consumedAt, null);
});

test("RA-BE-141: a code to the current number and the new number's code move the account", async () => {
  const h = harness();
  h.addCode(CURRENT_PHONE, OtpPurpose.CURRENT_PHONE_PROOF, "111111");
  h.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");

  const moved = await h.service.confirmPhoneChange(
    h.session,
    NEW_PHONE,
    "222222",
    { currentCode: "111111" },
  );

  assert.deepEqual(moved, { changed: true, phone: NEW_PHONE });
  assert.equal(h.user.phone, NEW_PHONE);
  assert.ok(h.otps.every((row) => row.consumedAt !== null));
});

test("RA-BE-141: a wrong current code is refused before the new number's code is tried", async () => {
  const h = harness();
  h.addCode(CURRENT_PHONE, OtpPurpose.CURRENT_PHONE_PROOF, "111111");
  h.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");

  await assert.rejects(
    h.service.confirmPhoneChange(h.session, NEW_PHONE, "222222", { currentCode: "999999" }),
    refusedWith(400, "CURRENT_PHONE_CODE_INVALID"),
  );
  assert.equal(h.user.phone, CURRENT_PHONE);
  assert.equal(h.otps[0].attempts, 1, "the guess at the current code counts");
  assert.equal(h.otps[1].consumedAt, null, "the new number's code is untouched");
  assert.equal(h.otps[1].attempts, 0);
});

test("RA-BE-141: a wrong new code keeps the current code for the retry", async () => {
  const h = harness();
  h.addCode(CURRENT_PHONE, OtpPurpose.CURRENT_PHONE_PROOF, "111111");
  h.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");

  await assert.rejects(
    h.service.confirmPhoneChange(h.session, NEW_PHONE, "000000", { currentCode: "111111" }),
    refusedWith(400, "OTP_INVALID_OR_EXPIRED"),
  );
  assert.equal(h.otps[0].consumedAt, null);
  assert.equal(h.otps[1].attempts, 1);

  await h.service.confirmPhoneChange(h.session, NEW_PHONE, "222222", { currentCode: "111111" });
  assert.equal(h.user.phone, NEW_PHONE);
});

test("RA-BE-141: the password stands for the current number, counted by the password lock", async () => {
  const h = harness();
  h.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");

  await assert.rejects(
    h.service.confirmPhoneChange(h.session, NEW_PHONE, "222222", { currentPassword: "wrong-password" }),
    refusedWith(401, "INVALID_CREDENTIALS"),
  );
  assert.equal(h.transactions, 0);
  assert.equal(h.otps[0].consumedAt, null);
  assert.deepEqual(h.throttle, [`reserve:${CURRENT_PHONE}`]);

  await h.service.confirmPhoneChange(h.session, NEW_PHONE, "222222", { currentPassword: PASSWORD });
  assert.equal(h.user.phone, NEW_PHONE);
  assert.deepEqual(h.throttle.slice(1), [`reserve:${CURRENT_PHONE}`, `clear:${CURRENT_PHONE}`]);
});

test("RA-BE-141: an account without a password proves it with the current number's code", async () => {
  const h = harness({ passwordHash: null });
  h.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");

  await assert.rejects(
    h.service.confirmPhoneChange(h.session, NEW_PHONE, "222222", { currentPassword: PASSWORD }),
    refusedWith(401, "INVALID_CREDENTIALS"),
  );
  assert.equal(h.user.phone, CURRENT_PHONE);
});

test("RA-BE-141: the current number's code goes to the account's own number", async () => {
  const h = harness();
  const sent: Array<{ phone: string; purpose: OtpPurpose }> = [];
  (h.service as any).issueOtp = async (phone: string, purpose: OtpPurpose) => {
    sent.push({ phone, purpose });
    return { otpId: "otp-x", phone, purpose };
  };

  await h.service.requestCurrentPhoneCode(h.session);

  assert.deepEqual(sent, [{ phone: CURRENT_PHONE, purpose: OtpPurpose.CURRENT_PHONE_PROOF }]);
});

// RA-BE-141: the old number is told on WhatsApp that the account moved, so
// its owner learns of a change they did not make. The message names no new
// number. It goes through OpenWA (the free-text channel) on the messages'
// own daily budget, and a failed message never undoes the change.

async function withOtpMode<T>(mode: string, run: () => Promise<T>): Promise<T> {
  const previous = process.env.AUTH_OTP_MODE;
  process.env.AUTH_OTP_MODE = mode;
  try {
    return await run();
  } finally {
    process.env.AUTH_OTP_MODE = previous;
  }
}

function moveWithCodes(h: ReturnType<typeof harness>) {
  h.addCode(CURRENT_PHONE, OtpPurpose.CURRENT_PHONE_PROOF, "111111");
  h.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");
  return h.service.confirmPhoneChange(h.session, NEW_PHONE, "222222", { currentCode: "111111" });
}

test("RA-BE-141: after the move the old number is told, without the new one", async () => {
  const h = harness();
  await withOtpMode("openwa", () => moveWithCodes(h));
  assert.equal(h.notices.length, 1);
  assert.equal(h.notices[0].phone, CURRENT_PHONE);
  assert.match(h.notices[0].text, /^رقم حسابك في اعّرست تغيّر/);
  const digits = NEW_PHONE.replace(/\D/g, "");
  for (const part of [NEW_PHONE, digits, digits.slice(-9), digits.slice(-4)]) {
    assert.equal(h.notices[0].text.includes(part), false, `the notice must not carry ${part}`);
  }
});

test("RA-BE-141: a notice that fails leaves the move made", async () => {
  const h = harness({ deliveryFails: true });
  const moved = await withOtpMode("openwa", () => moveWithCodes(h));
  assert.deepEqual(moved, { changed: true, phone: NEW_PHONE });
  assert.equal(h.user.phone, NEW_PHONE);
  assert.equal(h.notices.length, 1);
});

test("RA-BE-141: no notice for a move refused, nor where WhatsApp takes templates only", async () => {
  const refused = harness();
  refused.addCode(CURRENT_PHONE, OtpPurpose.CURRENT_PHONE_PROOF, "111111");
  refused.addCode(NEW_PHONE, OtpPurpose.VERIFY_PHONE, "222222");
  await withOtpMode("openwa", () =>
    assert.rejects(
      refused.service.confirmPhoneChange(refused.session, NEW_PHONE, "999999", { currentCode: "111111" }),
    ),
  );
  assert.equal(refused.notices.length, 0);

  const templatesOnly = harness();
  await withOtpMode("whatsapp", () => moveWithCodes(templatesOnly));
  assert.equal(templatesOnly.user.phone, NEW_PHONE);
  assert.equal(templatesOnly.notices.length, 0);
});
