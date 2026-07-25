import "reflect-metadata";

import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { afterEach, test } from "node:test";
import { HttpException } from "@nestjs/common";
import { AuthErrorCode } from "../src/auth/auth-error";
import { invitationDeliveryOutcomesTotal } from "../src/common/observability/metrics";
import { InviteAccessService } from "../src/sharing/invite-access.service";
import {
  buildInvitationMessage,
  InvitationDeliveryService,
} from "../src/sharing/invitation-delivery.service";

const originalEnvironment = { ...process.env };
const originalFetch = globalThis.fetch;

async function invitationDeliveryMetricValue(outcome: string): Promise<number> {
  const metric = await invitationDeliveryOutcomesTotal.get();
  return (
    metric.values.find((value) => value.labels.outcome === outcome)?.value ?? 0
  );
}

afterEach(() => {
  process.env = { ...originalEnvironment };
  globalThis.fetch = originalFetch;
});

test("Aarast sends an invite through only the hardened transient OpenWA route", async () => {
  process.env.AUTH_OTP_MODE = "openwa";
  process.env.OPENWA_BASE_URL = "http://openwa:2785";
  process.env.OPENWA_SESSION_ID = "aarast-otp";
  process.env.OPENWA_API_KEY = "a-secure-openwa-api-key-for-tests-only";
  const requests: Array<{ url: string; body: Record<string, unknown> }> = [];
  globalThis.fetch = (async (input, init) => {
    requests.push({
      url: input.toString(),
      body: JSON.parse(init?.body?.toString() ?? "{}") as Record<
        string,
        unknown
      >,
    });
    return new Response(
      JSON.stringify({
        messageId: "wa-message-1",
        timestamp: 1706868000,
        deliveryStatus: "DELIVERED",
      }),
      {
        status: 201,
        headers: { "content-type": "application/json" },
      },
    );
  }) as typeof fetch;

  const deliveredBefore = await invitationDeliveryMetricValue("delivered");
  const token = "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789";
  const result = await new InvitationDeliveryService().deliver(
    "+967777123456",
    token,
  );

  assert.deepEqual(result, { channel: "WHATSAPP", status: "DELIVERED" });
  assert.equal(
    await invitationDeliveryMetricValue("delivered"),
    deliveredBefore + 1,
  );
  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].url,
    "http://openwa:2785/api/sessions/aarast-otp/messages/send-transient-text",
  );
  assert.equal(requests[0].body.chatId, "967777123456@c.us");
  assert.match(
    requests[0].body.text as string,
    new RegExp(`https://aarast\\.shadowgardn\\.com/invites/${token}`),
  );
  assert.doesNotMatch(requests[0].body.text as string, /رشاد|سارة|اسم الخطة/);
});

test("invite delivery maps explicit OpenWA outcomes without false success", async () => {
  process.env.AUTH_OTP_MODE = "openwa";
  process.env.OPENWA_BASE_URL = "http://openwa:2785";
  process.env.OPENWA_SESSION_ID = "aarast-otp";
  process.env.OPENWA_API_KEY = "a-secure-openwa-api-key-for-tests-only";
  const token = "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789";
  const rejectedBefore = await invitationDeliveryMetricValue("rejected");
  const uncertainBefore = await invitationDeliveryMetricValue("uncertain");

  for (const [payload, expectedStatus] of [
    [{ code: "NOT_ATTEMPTED" }, "UNAVAILABLE"],
    [{ code: "REJECTED" }, "UNAVAILABLE"],
    [{ code: "DELIVERY_UNCERTAIN" }, "UNCERTAIN"],
    [{ code: "UNKNOWN" }, "UNCERTAIN"],
  ] as const) {
    globalThis.fetch = (async () =>
      new Response(JSON.stringify(payload), {
        status: 503,
        headers: { "content-type": "application/json" },
      })) as typeof fetch;

    const result = await new InvitationDeliveryService().deliver(
      "+967777123456",
      token,
    );
    assert.deepEqual(result, {
      channel: "WHATSAPP",
      status: expectedStatus,
    });
  }

  globalThis.fetch = (async () =>
    new Response(
      JSON.stringify({
        messageId: "wa-message-2",
        timestamp: 1706868000,
        deliveryStatus: "QUEUED",
      }),
      {
        status: 200,
        headers: { "content-type": "application/json" },
      },
    )) as typeof fetch;
  const ambiguousSuccess = await new InvitationDeliveryService().deliver(
    "+967777123456",
    token,
  );
  assert.deepEqual(ambiguousSuccess, {
    channel: "WHATSAPP",
    status: "UNCERTAIN",
  });
  assert.equal(
    await invitationDeliveryMetricValue("rejected"),
    rejectedBefore + 2,
  );
  assert.equal(
    await invitationDeliveryMetricValue("uncertain"),
    uncertainBefore + 3,
  );
});

test("invite delivery records an unexpected failure without logging private fields", async () => {
  process.env.AUTH_OTP_MODE = "openwa";
  process.env.OPENWA_BASE_URL = "http://openwa:2785";
  process.env.OPENWA_SESSION_ID = "aarast-otp";
  process.env.OPENWA_API_KEY = "a-secure-openwa-api-key-for-tests-only";
  const failedBefore = await invitationDeliveryMetricValue("failed");
  const warningEntries: unknown[] = [];
  const service = new InvitationDeliveryService();
  (service as any).logger = {
    warn: (entry: unknown) => warningEntries.push(entry),
  };
  const result = await service.deliver(
    "+967777123456",
    "private-invalid-invite-token",
  );

  assert.deepEqual(result, { channel: "WHATSAPP", status: "UNAVAILABLE" });
  assert.deepEqual(warningEntries, [
    { event: "invitation_delivery_failed", outcome: "failed" },
  ]);
  const serializedWarnings = JSON.stringify(warningEntries);
  assert.doesNotMatch(serializedWarnings, /967777123456/);
  assert.doesNotMatch(serializedWarnings, /private-invalid-invite-token/);
  assert.doesNotMatch(serializedWarnings, /Invalid invitation token/);
  assert.equal(await invitationDeliveryMetricValue("failed"), failedBefore + 1);
});

test("invite delivery records a bounded not-attempted outcome without private labels", async () => {
  process.env.AUTH_OTP_MODE = "openwa";
  const before = await invitationDeliveryMetricValue("not_attempted");

  const result = await new InvitationDeliveryService().deliver(
    null,
    "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789",
  );

  assert.deepEqual(result, { channel: "WHATSAPP", status: "UNAVAILABLE" });
  assert.equal(
    await invitationDeliveryMetricValue("not_attempted"),
    before + 1,
  );
  const metric = await invitationDeliveryOutcomesTotal.get();
  for (const value of metric.values) {
    assert.deepEqual(Object.keys(value.labels), ["outcome"]);
  }
});

test("invite message is generic, private, and rejects an unsafe public origin", () => {
  const token = "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789";
  const message = buildInvitationMessage(token);
  assert.match(message, /تحقق من رقم هاتفك/);
  assert.doesNotMatch(message, /\+967|777123456/);
  assert.throws(
    () =>
      buildInvitationMessage(token, {
        INVITE_PUBLIC_ORIGIN: "http://example.com",
      }),
    /public HTTPS origin/,
  );
});

test("invite OTP is sent only when the bearer token and canonical phone match", async () => {
  const token = "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789";
  const expectedHash = createHash("sha256").update(token).digest("hex");
  const authCalls: Array<Record<string, unknown>> = [];
  const service = new InviteAccessService(
    {
      planInvite: {
        findFirst: async ({ where }: any) =>
          where.tokenHash === expectedHash &&
          where.normalizedPhone === "+967777123456"
            ? { id: "invite-1" }
            : null,
      },
      user: {
        findFirst: async () => null,
      },
    } as any,
    {
      requestOtp: async (dto: Record<string, unknown>) => {
        authCalls.push(dto);
        return { delivery: "WHATSAPP" };
      },
    } as any,
  );

  const result = await service.requestOtp(
    token,
    { phone: "777 123 456" },
    { ip: "127.0.0.1" },
  );
  assert.deepEqual(result, {
    delivery: "WHATSAPP",
    accountSetupRequired: true,
  });
  assert.equal(authCalls.length, 1);
  assert.equal(authCalls[0].phone, "+967777123456");
  assert.equal(authCalls[0].purpose, "LOGIN");

  await assert.rejects(
    () =>
      service.requestOtp(token, { phone: "777 999 999" }, { ip: "127.0.0.1" }),
    (error: unknown) => {
      assert.ok(error instanceof HttpException);
      const response = error.getResponse() as { code?: string };
      assert.equal(response.code, AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE);
      return true;
    },
  );
  assert.equal(authCalls.length, 1);
});

test("invite OTP verification stays bound to the exact private token", async () => {
  const token = "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789";
  const verifyCalls: Array<Record<string, unknown>> = [];
  const service = new InviteAccessService(
    {} as any,
    {
      verifyInviteOtp: async (input: Record<string, unknown>) => {
        verifyCalls.push(input);
        return { verified: true };
      },
    } as any,
  );

  const result = await service.verifyOtp(token, {
    phone: "777 123 456",
    code: "123456",
    name: "أحمد",
    password: "secret123",
  });

  assert.deepEqual(result, { verified: true });
  assert.deepEqual(verifyCalls, [
    {
      token,
      phone: "777 123 456",
      code: "123456",
      name: "أحمد",
      password: "secret123",
    },
  ]);
});

test("invite OTP never dispatches for accepted, declined, cancelled, or expired links", async () => {
  const token = "abcdefghijklmnopqrstuvwxyzABCDEFGH123456789";
  const expectedHash = createHash("sha256").update(token).digest("hex");
  const activeExpiry = new Date(Date.now() + 60_000);
  const terminalRows = [
    {
      label: "accepted",
      acceptedAt: new Date(),
      declinedAt: null,
      revokedAt: null,
      expiresAt: activeExpiry,
    },
    {
      label: "declined",
      acceptedAt: null,
      declinedAt: new Date(),
      revokedAt: null,
      expiresAt: activeExpiry,
    },
    {
      label: "cancelled",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: new Date(),
      expiresAt: activeExpiry,
    },
    {
      label: "expired",
      acceptedAt: null,
      declinedAt: null,
      revokedAt: null,
      expiresAt: new Date(Date.now() - 60_000),
    },
  ] as const;

  for (const row of terminalRows) {
    let authCalls = 0;
    const service = new InviteAccessService(
      {
        planInvite: {
          findFirst: async ({ where }: any) => {
            const matches =
              where.tokenHash === expectedHash &&
              where.normalizedPhone === "+967777123456" &&
              (where.acceptedAt === undefined ||
                row.acceptedAt === where.acceptedAt) &&
              (where.declinedAt === undefined ||
                row.declinedAt === where.declinedAt) &&
              (where.revokedAt === undefined ||
                row.revokedAt === where.revokedAt) &&
              (where.expiresAt?.gt === undefined ||
                row.expiresAt.getTime() > where.expiresAt.gt.getTime());
            return matches ? { id: "invite-1" } : null;
          },
        },
      } as any,
      {
        requestOtp: async () => {
          authCalls += 1;
          return { delivery: "WHATSAPP" };
        },
      } as any,
    );

    await assert.rejects(
      () =>
        service.requestOtp(
          token,
          { phone: "777 123 456" },
          { ip: "127.0.0.1" },
        ),
      (error: unknown) => {
        assert.ok(error instanceof HttpException, row.label);
        const response = error.getResponse() as { code?: string };
        assert.equal(
          response.code,
          AuthErrorCode.INVITE_NOT_FOUND_FOR_PHONE,
          row.label,
        );
        return true;
      },
    );
    assert.equal(authCalls, 0, row.label);
  }
});
