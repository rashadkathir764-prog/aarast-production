import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";
import { ConflictException } from "@nestjs/common";
import { Prisma, QuoteOfferStatus, QuoteRequestStatus } from "@prisma/client";
import {
  assertQuoteRequestAnswerable,
  assertQuoteRequestTransition,
  isQuoteRequestOverdue,
  QUOTE_REQUEST_ANSWER_DAYS,
  quoteLifecycleStatus,
  quoteRequestAnswerDeadline,
} from "../src/marketplace/quote-lifecycle";
import {
  quoteOfferChanges,
  quoteOfferLocked,
  readQuoteOfferChanges,
  toQuoteOfferChangesJson,
  visibleQuoteOfferChanges,
} from "../src/modules/marketplace/public/quote-offer-versions";
import {
  quoteOfferRevisedNotification,
  quoteOfferWithdrawnNotification,
  quoteRequestExpiredRequesterNotification,
  quoteRequestExpiringProviderNotification,
} from "../src/marketplace/quote-notifications";

const now = new Date("2026-10-25T12:00:00.000Z");

function codeOf(run: () => void): string | undefined {
  try {
    run();
  } catch (error) {
    assert.ok(error instanceof ConflictException);
    return (error.getResponse() as { code?: string }).code;
  }
  return undefined;
}

// B-04: seven days to answer.
test("a request waits seven days, then only the hourly job may end it", () => {
  assert.equal(QUOTE_REQUEST_ANSWER_DAYS, 7);
  assert.equal(
    quoteRequestAnswerDeadline(now).toISOString(),
    "2026-11-01T12:00:00.000Z",
  );
  const schema = readFileSync(
    join(__dirname, "..", "prisma", "schema", "marketplace.prisma"),
    "utf8",
  );
  assert.match(
    schema,
    /expiresAt\s+DateTime\s+@default\(dbgenerated\("\(CURRENT_TIMESTAMP \+ '7 days'::interval\)"\)\)/u,
    "the database default and QUOTE_REQUEST_ANSWER_DAYS say the same",
  );

  const due = new Date(now.getTime() - 1);
  for (const status of [QuoteRequestStatus.SENT, QuoteRequestStatus.VIEWED]) {
    assert.equal(isQuoteRequestOverdue({ status, expiresAt: due }, now), true);
    assert.equal(isQuoteRequestOverdue({ status, expiresAt: now }, now), true);
    assert.equal(
      isQuoteRequestOverdue({ status, expiresAt: new Date(now.getTime() + 1) }, now),
      false,
    );
    assert.doesNotThrow(() =>
      assertQuoteRequestTransition(status, QuoteRequestStatus.EXPIRED, "expiry"),
    );
  }
  // An answered, accepted or closed request never expires.
  for (const status of [
    QuoteRequestStatus.RESPONDED,
    QuoteRequestStatus.ACCEPTED,
    QuoteRequestStatus.REJECTED,
    QuoteRequestStatus.CANCELLED,
  ]) {
    assert.equal(isQuoteRequestOverdue({ status, expiresAt: due }, now), false);
    assert.throws(() =>
      assertQuoteRequestTransition(status, QuoteRequestStatus.EXPIRED, "expiry"),
    );
  }
  assert.equal(quoteLifecycleStatus(QuoteRequestStatus.EXPIRED), "EXPIRED");
});

test("an expired or overdue request takes no answer, with one Arabic code", () => {
  assert.equal(
    codeOf(() =>
      assertQuoteRequestTransition(
        QuoteRequestStatus.EXPIRED,
        QuoteRequestStatus.RESPONDED,
        "provider_offer",
      ),
    ),
    "QUOTE_REQUEST_EXPIRED",
  );
  assert.equal(
    codeOf(() =>
      assertQuoteRequestTransition(
        QuoteRequestStatus.EXPIRED,
        QuoteRequestStatus.CANCELLED,
        "requester",
      ),
    ),
    "QUOTE_REQUEST_EXPIRED",
  );
  assert.equal(
    codeOf(() =>
      assertQuoteRequestAnswerable(
        { status: QuoteRequestStatus.VIEWED, expiresAt: new Date(now.getTime() - 1) },
        now,
      ),
    ),
    "QUOTE_REQUEST_EXPIRED",
  );
  assert.doesNotThrow(() =>
    assertQuoteRequestAnswerable(
      { status: QuoteRequestStatus.SENT, expiresAt: new Date(now.getTime() + 1) },
      now,
    ),
  );
});

// B-03: a withdrawn offer gives the request back to the provider.
test("withdrawing moves only an answered request back to the provider", () => {
  assert.doesNotThrow(() =>
    assertQuoteRequestTransition(
      QuoteRequestStatus.RESPONDED,
      QuoteRequestStatus.VIEWED,
      "provider_withdraw",
    ),
  );
  for (const status of [
    QuoteRequestStatus.SENT,
    QuoteRequestStatus.VIEWED,
    QuoteRequestStatus.ACCEPTED,
    QuoteRequestStatus.REJECTED,
  ]) {
    assert.throws(() =>
      assertQuoteRequestTransition(status, QuoteRequestStatus.VIEWED, "provider_withdraw"),
    );
  }
});

// B-06: versions and «ايش تغيّر».
test("a new version lists exactly what changed, amounts first", () => {
  const before = {
    title: "صور وفيديو",
    message: "مصورين · فيلم 10 دقائق",
    amount: new Prisma.Decimal("550000"),
    currency: "YER",
    validUntil: new Date("2026-10-28T00:00:00.000Z"),
  };
  assert.deepEqual(quoteOfferChanges(before, { ...before, amount: "550000.00" }), []);
  assert.deepEqual(
    quoteOfferChanges(before, {
      ...before,
      amount: "520000",
      message: "مصورين · فيلم 10 دقائق · ألبوم مطبوع",
    }),
    [
      { field: "amount", from: "550000", to: "520000" },
      {
        field: "message",
        from: "مصورين · فيلم 10 دقائق",
        to: "مصورين · فيلم 10 دقائق · ألبوم مطبوع",
      },
    ],
  );
  const renewed = quoteOfferChanges(before, {
    ...before,
    validUntil: new Date("2026-11-07T00:00:00.000Z"),
  });
  assert.deepEqual(renewed, [
    {
      field: "validUntil",
      from: "2026-10-28T00:00:00.000Z",
      to: "2026-11-07T00:00:00.000Z",
    },
  ]);

  const stored = toQuoteOfferChangesJson([
    { field: "amount", from: "550000", to: "520000" },
    { field: "title", from: null, to: "باقة" },
  ]) as Prisma.JsonValue;
  assert.deepEqual(readQuoteOfferChanges(stored), [
    { field: "amount", from: "550000", to: "520000" },
    { field: "title", from: null, to: "باقة" },
  ]);
  assert.deepEqual(readQuoteOfferChanges(null), []);
  assert.deepEqual(readQuoteOfferChanges([{ field: "phone", from: "1", to: "2" }]), []);
  // A member who sees no money reads the change of words, never the price.
  assert.deepEqual(
    visibleQuoteOfferChanges(readQuoteOfferChanges(stored), false),
    [{ field: "title", from: null, to: "باقة" }],
  );
});

test("an accepted or withdrawn offer is locked with one code", () => {
  for (const status of [
    QuoteOfferStatus.ACCEPTED,
    QuoteOfferStatus.WITHDRAWN,
    QuoteOfferStatus.REJECTED,
  ]) {
    const response = quoteOfferLocked(status).getResponse() as {
      code: string;
      message: string;
    };
    assert.equal(response.code, "QUOTE_OFFER_LOCKED");
    assert.match(response.message, /[؀-ۿ]/u);
  }
});

test("the B2 notices say what happened and keep money out", () => {
  const withdrawn = quoteOfferWithdrawnNotification({
    requesterId: "u1",
    weddingPlanId: "p1",
    quoteRequestId: "q1",
    quoteOfferId: "o1",
    providerId: "pr1",
    providerName: "عدسة سبأ",
  });
  assert.equal(withdrawn.title, "سحب عدسة سبأ عرضه");
  assert.equal(withdrawn.dedupeKey, "u1:quote-offer-withdrawn:o1");

  const revised = quoteOfferRevisedNotification({
    requesterId: "u1",
    weddingPlanId: "p1",
    quoteRequestId: "q1",
    quoteOfferId: "o1",
    versionNo: 2,
    providerId: "pr1",
    providerName: "ضوء صنعاء",
  });
  assert.equal(revised.title, "عدّل ضوء صنعاء عرضه");
  assert.doesNotMatch(revised.body, /\d/u);
  // One notice per version: a retried edit does not notify twice.
  assert.equal(revised.dedupeKey, "u1:quote-offer:o1:v2");

  const expiresAt = new Date("2026-11-01T12:00:00.000Z");
  const expiring = quoteRequestExpiringProviderNotification({
    providerUserId: "pu",
    quoteRequestId: "q1",
    providerId: "pr1",
    customerName: "محمد الحمدي",
    expiresAt,
  });
  assert.equal(expiring.title, "طلب محمد ينتهي بكرة");
  assert.equal(expiring.routeTarget, "/provider/requests/q1");
  assert.equal(
    expiring.dedupeKey,
    "pu:quote-request-expiring:q1:2026-11-01T12:00:00.000Z",
  );

  const expired = quoteRequestExpiredRequesterNotification({
    requesterId: "u1",
    weddingPlanId: "p1",
    quoteRequestId: "q1",
    providerId: "pr1",
    providerName: "مقوّت الروضة",
    answerDays: 7,
  });
  assert.equal(expired.title, "ما رد مقوّت الروضة خلال 7 أيام");
  assert.match(expired.body, /اطلب من غيره/u);
  assert.equal(expired.dedupeKey, "u1:quote-request-expired:q1");
});
