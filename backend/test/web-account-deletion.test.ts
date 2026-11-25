import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ConflictException, HttpException, ValidationPipe } from "@nestjs/common";
import { GUARDS_METADATA, METHOD_METADATA, PATH_METADATA } from "@nestjs/common/constants";
import { OtpPurpose, UserRole, UserStatus } from "@prisma/client";
import * as bcryptjs from "bcryptjs";
import { PublicAccountDeletionController } from "../src/modules/identity/api/public-account-deletion.controller";
import {
  AccountDeletionCodeDto,
  AccountDeletionConfirmDto,
} from "../src/modules/identity/api/auth-dto/public-account-deletion.dto";
import { AccountDeletionService } from "../src/modules/identity/internal/profile/account-deletion.service";
import { DEVICE_SHARE_THROTTLER } from "../src/platform/http/route-throttle";
import { authService } from "./support/owner-ports";

// Q-52 (أ, D124), RA-OP-21: a person without the app asks the account's
// deletion from the public site. The registered number is proven with a
// WhatsApp code of its own purpose; the account then waits the same 30 days
// (D63) and signing in takes it back. The page asks the code for any number
// and says the same whatever it is, so it tells nobody which numbers have an
// account; the code's limits are the sign-in codes' own (number, phone,
// address, the app's day).

process.env.AUTH_OTP_MODE = "whatsapp";

const PHONE = "+967777300003";
const request = { ip: "198.51.100.40", headers: { "x-aarast-device": "3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c" } } as any;

test("the page's two routes are public, under /api/v1/public, each with its limit", () => {
  assert.equal(Reflect.getMetadata(PATH_METADATA, PublicAccountDeletionController), "api/v1/public/account-deletion");
  assert.equal(Reflect.getMetadata(GUARDS_METADATA, PublicAccountDeletionController), undefined);
  for (const [route, path] of [["requestCode", "code"], ["confirm", "confirm"]] as const) {
    const handler = PublicAccountDeletionController.prototype[route] as unknown as object;
    assert.equal(Reflect.getMetadata(PATH_METADATA, handler), path);
    assert.equal(Reflect.getMetadata(METHOD_METADATA, handler), 1, `${route} is a POST`);
    assert.equal(Reflect.getMetadata(GUARDS_METADATA, handler), undefined);
    assert.ok(Reflect.getMetadata("THROTTLER:LIMITdefault", handler) > 0);
    assert.ok(Reflect.getMetadata(`THROTTLER:LIMIT${DEVICE_SHARE_THROTTLER}`, handler) > 0);
  }
});

test("the bodies take a number, and a number with its six digits", async () => {
  const pipe = new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true });
  await assert.rejects(pipe.transform({}, { type: "body", metatype: AccountDeletionCodeDto }));
  await assert.rejects(pipe.transform({ phone: PHONE, purpose: "LOGIN" }, { type: "body", metatype: AccountDeletionCodeDto }));
  assert.equal((await pipe.transform({ phone: PHONE }, { type: "body", metatype: AccountDeletionCodeDto })).phone, PHONE);
  for (const code of ["12345", "abcdef", "1234567"]) {
    await assert.rejects(pipe.transform({ phone: PHONE, code }, { type: "body", metatype: AccountDeletionConfirmDto }), code);
  }
  assert.equal(
    (await pipe.transform({ phone: PHONE, code: "123456" }, { type: "body", metatype: AccountDeletionConfirmDto })).code,
    "123456",
  );
});

test("the code is the deletion's own purpose, asked with the caller's address and phone", async () => {
  const issued: unknown[][] = [];
  const service = authService({}, {}, {}, { consume: async () => undefined }, {});
  (service as any).issueOtp = async (...args: unknown[]) => {
    issued.push(args);
    return { otpId: "otp-1", phone: PHONE, purpose: OtpPurpose.ACCOUNT_DELETION_WEB, expiresAt: new Date(), delivery: "WHATSAPP", deliveryStatus: "DELIVERED" };
  };
  const controller = new PublicAccountDeletionController(service, {} as AccountDeletionService);
  const answer = await controller.requestCode({ phone: "777300003" }, request);
  assert.equal(issued.length, 1);
  assert.equal(issued[0][0], PHONE, "the number as the account holds it");
  assert.equal(issued[0][1], OtpPurpose.ACCOUNT_DELETION_WEB);
  assert.deepEqual(issued[0][2], { ip: "198.51.100.40", device: "3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c" });
  assert.equal("otpId" in (answer as object), false, "the code's id stays on the server");
});

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
  if ("consumedAt" in where && where.consumedAt === null && row.consumedAt !== null) return false;
  if (where.expiresAt?.gt && row.expiresAt <= where.expiresAt.gt) return false;
  if (where.attempts?.lt !== undefined && row.attempts >= where.attempts.lt) return false;
  return true;
}

function harness(account: Record<string, unknown> | null) {
  const otps: OtpRow[] = [];
  const addCode = (purpose: OtpPurpose, code: string) => {
    const now = new Date();
    otps.push({
      id: `otp-${otps.length + 1}`, phone: PHONE, purpose, planInviteId: null,
      codeHash: bcryptjs.hashSync(code, 4), consumedAt: null,
      expiresAt: new Date(now.getTime() + 5 * 60_000), attempts: 0, maxAttempts: 5, createdAt: now, updatedAt: now,
    });
  };
  const users = {
    findUnique: async ({ where }: any) => (account && where.id === account.id ? { ...account } : null),
    findFirst: async ({ where }: any) => {
      const phones: string[] = typeof where.phone === "string" ? [where.phone] : where.phone?.in ?? [];
      return account && phones.includes(account.phone as string) ? { ...account } : null;
    },
  };
  const tx: any = {
    $queryRaw: async () => (account ? [{ id: account.id, status: account.status, deletionPending: false }] : []),
    user: users,
    otpCode: {
      findFirst: async ({ where }: any) => [...otps].reverse().find((row) => matches(row, where)) ?? null,
      findUnique: async ({ where }: any) => otps.find((row) => row.id === where.id) ?? null,
      updateMany: async ({ where, data }: any) => {
        let count = 0;
        for (const row of otps) {
          if (!matches(row, where)) continue;
          if (data.attempts?.increment) row.attempts += data.attempts.increment;
          if ("consumedAt" in data) row.consumedAt = data.consumedAt;
          count += 1;
        }
        return { count };
      },
    },
  };
  const prisma = { user: users, $transaction: async (operation: (client: any) => Promise<unknown>) => operation(tx) };
  const service = authService(prisma, {}, {}, { consume: async () => undefined }, { disconnectUser: () => undefined });
  return { service, otps, addCode };
}

const activeAccount = {
  id: "user-9", phone: PHONE, status: UserStatus.ACTIVE, role: UserRole.USER,
  appAccountActivatedAt: new Date("2026-01-01T00:00:00Z"), phoneVerifiedAt: new Date("2026-01-01T00:00:00Z"),
};

const refusedWith = (status: number, code: string) => (error: unknown) => {
  assert.ok(error instanceof HttpException, String(error));
  assert.equal(error.getStatus(), status);
  assert.equal((error.getResponse() as { code?: string }).code, code);
  return true;
};

test("only the deletion's own code proves the number; a wrong one counts", async () => {
  const h = harness(activeAccount);
  h.addCode(OtpPurpose.LOGIN, "111111");
  h.addCode(OtpPurpose.ACCOUNT_DELETION_WEB, "222222");
  await assert.rejects(h.service.claimWebAccountDeletionCode(PHONE, "111111"), refusedWith(400, "OTP_INVALID_OR_EXPIRED"));
  assert.equal(h.otps[1].attempts, 1);
  assert.equal(await h.service.claimWebAccountDeletionCode(PHONE, "222222"), "user-9");
  assert.notEqual(h.otps[1].consumedAt, null);
  assert.equal(h.otps[0].consumedAt, null, "the sign-in code is left alone");
});

test("a proven number with no application account, or a disabled one, is told so", async () => {
  const none = harness(null);
  none.addCode(OtpPurpose.ACCOUNT_DELETION_WEB, "222222");
  await assert.rejects(none.service.claimWebAccountDeletionCode(PHONE, "222222"), refusedWith(404, "ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF"));
  const adminOnly = harness({ ...activeAccount, role: UserRole.ADMIN, appAccountActivatedAt: null });
  adminOnly.addCode(OtpPurpose.ACCOUNT_DELETION_WEB, "222222");
  await assert.rejects(adminOnly.service.claimWebAccountDeletionCode(PHONE, "222222"), refusedWith(404, "ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF"));
  const disabled = harness({ ...activeAccount, status: UserStatus.DISABLED });
  disabled.addCode(OtpPurpose.ACCOUNT_DELETION_WEB, "222222");
  await assert.rejects(disabled.service.claimWebAccountDeletionCode(PHONE, "222222"), refusedWith(403, "ACCOUNT_DISABLED_AFTER_PHONE_PROOF"));
});

test("the proven account enters the 30 days; a provider with weddings to do is refused without their ids", async () => {
  const scheduledFor = new Date("2026-12-25T00:00:00Z");
  const asked: string[] = [];
  const auth = { claimWebAccountDeletionCode: async () => "user-9" } as any;
  const deletion = {
    requestForAccount: async (userId: string) => {
      asked.push(userId);
      return { status: "PENDING", requestedAt: new Date(), scheduledFor };
    },
  } as unknown as AccountDeletionService;
  const controller = new PublicAccountDeletionController(auth, deletion);
  assert.deepEqual(await controller.confirm({ phone: PHONE, code: "222222" }), { status: "PENDING", scheduledFor });
  assert.deepEqual(asked, ["user-9"]);

  const busy = new PublicAccountDeletionController(auth, {
    requestForAccount: async () => {
      throw new ConflictException({ statusCode: 409, code: "PROVIDER_HAS_UPCOMING_BOOKINGS", message: "x", count: 2, bookingIds: ["b1", "b2"] });
    },
  } as unknown as AccountDeletionService);
  await assert.rejects(busy.confirm({ phone: PHONE, code: "222222" }), (error: unknown) => {
    assert.ok(error instanceof ConflictException);
    const body = error.getResponse() as Record<string, unknown>;
    assert.equal(body.code, "PROVIDER_HAS_UPCOMING_BOOKINGS");
    assert.equal("bookingIds" in body, false);
    assert.equal("count" in body, false);
    return true;
  });
});

test("the in-app request and the page's share one scheduling of the deletion", () => {
  const source = readFileSync(join(__dirname, "..", "src/modules/identity/internal/profile/account-deletion.service.ts"), "utf8");
  assert.match(source, /async requestForAccount\(userId: string\)/);
  assert.match(source, /return this\.requestForAccount\(currentUser\.id\);/);
});

test("the code's WhatsApp text names what it is for, and an erased account's codes go", () => {
  const channel = readFileSync(join(__dirname, "..", "src/platform/otp-transport/openwa-otp.channel.ts"), "utf8");
  assert.match(channel, /ACCOUNT_DELETION_WEB: 'لطلب حذف حسابك'/);
  const erasure = readFileSync(join(__dirname, "..", "src/modules/identity/infrastructure/account-erasure.repository.ts"), "utf8");
  assert.match(erasure, /OtpPurpose\.ACCOUNT_DELETION_WEB,/);
});
