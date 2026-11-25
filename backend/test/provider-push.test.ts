import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { NotificationType, UserStatus } from "@prisma/client";
import {
  offerAcceptedProviderNotification,
  offerAcceptedRequesterNotification,
  providerRejectedRequestNotification,
  quoteOfferWithdrawnNotification,
  quoteSubmittedProviderNotification,
  quoteSubmittedRequesterNotification,
  requesterRejectedOfferNotification,
} from "../src/marketplace/quote-notifications";
import { reviewReceivedProviderNotification } from "../src/marketplace/review-notifications";
import { switchProviderStatusNotification } from "../src/admin/provider-status-notification";
import { OutboxEventTypes } from "../src/platform/outbox/outbox.constants";
import { OutboxService } from "../src/platform/outbox/outbox.service";
import {
  isPushNotificationType,
  isQuietHoursExempt,
  pushAndroidChannelId,
  pushNotificationCopy,
} from "../src/push/push-notification.policy";
import { ProviderStatus } from "@prisma/client";
import { notificationsService } from "./support/owner-ports";

// RA-BE-186 (Q-48 أ): the provider's phone hears of a new request, an
// accepted offer, a rejected offer and his account approved or refused;
// Q-60 (أ, D127) adds «يحتاج تعديل», the suspension, the claim's answer and
// the photos' review. Reviews stay in the inbox. The customer's own side of the same types
// (his request received, his offer accepted, the provider's apology) does
// not push: it is the customer's own act or an answer in the inbox.

const customerNotices = [
  quoteSubmittedRequesterNotification({
    requesterId: "customer-1",
    weddingPlanId: "plan-1",
    quoteId: "quote-1",
    providerId: "provider-1",
    providerName: "قاعة سبأ",
  }),
  offerAcceptedRequesterNotification({
    requesterId: "customer-1",
    weddingPlanId: "plan-1",
    quoteRequestId: "quote-1",
    quoteOfferId: "offer-1",
    providerId: "provider-1",
    providerName: "قاعة سبأ",
  }),
  providerRejectedRequestNotification({
    requesterId: "customer-1",
    weddingPlanId: "plan-1",
    quoteRequestId: "quote-1",
    providerId: "provider-1",
    providerName: "قاعة سبأ",
  }),
  quoteOfferWithdrawnNotification({
    requesterId: "customer-1",
    weddingPlanId: "plan-1",
    quoteRequestId: "quote-1",
    quoteOfferId: "offer-1",
    providerId: "provider-1",
    providerName: "قاعة سبأ",
  }),
];

const providerNotices = [
  quoteSubmittedProviderNotification({
    providerUserId: "provider-user",
    quoteId: "quote-1",
    providerId: "provider-1",
    customerName: "خالد القاضي",
  }),
  offerAcceptedProviderNotification({
    providerUserId: "provider-user",
    quoteRequestId: "quote-1",
    quoteOfferId: "offer-1",
    providerId: "provider-1",
    customerName: "خالد القاضي",
  }),
  requesterRejectedOfferNotification({
    providerUserId: "provider-user",
    quoteRequestId: "quote-1",
    quoteOfferId: "offer-1",
    providerId: "provider-1",
    reason: "PRICE",
  }),
];

test("a new request splits: the customer's acknowledgement stays in the inbox, the provider's notice pushes", () => {
  assert.equal(customerNotices[0]!.type, NotificationType.QUOTE_REQUEST_SUBMITTED);
  assert.equal(providerNotices[0]!.type, NotificationType.QUOTE_REQUEST_SUBMITTED);
  assert.equal(isPushNotificationType(customerNotices[0]!.type, customerNotices[0]!.data), false);
  assert.equal(isPushNotificationType(providerNotices[0]!.type, providerNotices[0]!.data), true);
});

test("an offer accepted or rejected pushes to the provider, never the customer's side of the same type", () => {
  for (const notice of providerNotices) {
    assert.equal(isPushNotificationType(notice.type, notice.data), true, `${notice.type}/provider`);
  }
  for (const notice of customerNotices) {
    assert.equal(isPushNotificationType(notice.type, notice.data), false, `${notice.type}/customer`);
  }
  // A type that is split by audience does not push without saying who it is for.
  for (const type of [
    NotificationType.QUOTE_REQUEST_SUBMITTED,
    NotificationType.QUOTE_ACCEPTED,
    NotificationType.QUOTE_REJECTED,
  ]) {
    assert.equal(isPushNotificationType(type), false, type);
    assert.equal(isPushNotificationType(type, { recipientAudience: "CUSTOMER" }), false, type);
    assert.equal(isPushNotificationType(type, { recipientAudience: "PROVIDER" }), true, type);
  }
});

// Q-60 (أ), D127 (amends Q-48): every decision the team takes on his
// account reaches the phone: approved, to fix, refused and stopped. Back in
// review is his own act, and reviews stay in the inbox.
test("every team decision on the provider's account pushes; his own resubmission and reviews stay in the inbox", () => {
  for (const status of [
    ProviderStatus.ACTIVE,
    ProviderStatus.NEEDS_CHANGES,
    ProviderStatus.REJECTED,
    ProviderStatus.SUSPENDED,
  ]) {
    assert.equal(
      isPushNotificationType(switchProviderStatusNotification("قاعة سبأ", status, null).type),
      true,
      status,
    );
  }
  assert.equal(
    isPushNotificationType(
      switchProviderStatusNotification("قاعة سبأ", ProviderStatus.PENDING, null).type,
    ),
    false,
  );
  const review = reviewReceivedProviderNotification({
    providerUserId: "provider-user",
    providerId: "provider-1",
    reviewId: "review-1",
    rating: 4,
    reviewerName: "خالد القاضي",
  });
  assert.equal(isPushNotificationType(review.type, review.data), false);
  assert.equal(isPushNotificationType(NotificationType.REVIEW_REPLIED), false);
});

test("Q-60: the team's answer to a claim and to his photos reaches the phone", () => {
  for (const claimStatus of ["APPROVED", "REJECTED"]) {
    assert.equal(
      isPushNotificationType(NotificationType.PROVIDER_CLAIM_DECIDED, { claimStatus }),
      true,
      claimStatus,
    );
  }
  for (const decision of ["APPROVED", "REJECTED"]) {
    assert.equal(
      isPushNotificationType(NotificationType.PORTFOLIO_REVIEWED, {
        decision,
        recipientAudience: "PROVIDER",
      }),
      true,
      decision,
    );
  }
});

test("Q-60: the lock screen says which decision came, never the name, the reason or a figure", () => {
  const cases: Array<[NotificationType, unknown, string, string]> = [
    [
      NotificationType.PROVIDER_NEEDS_CHANGES,
      { providerStatus: "NEEDS_CHANGES", reviewNote: "غيّر الاسم يا خالد" },
      "ملاحظة على ملفك",
      "ملفك يحتاج تعديل بسيط، والملاحظة تنتظرك في اعّرست.",
    ],
    [
      NotificationType.PROVIDER_SUSPENDED,
      { providerStatus: "SUSPENDED", reviewNote: "بلاغات من 3 عرسان" },
      "وقّفنا ملفك",
      "ملفك ما يظهر للعرسان الحين، والتفاصيل في اعّرست.",
    ],
    [
      NotificationType.PROVIDER_CLAIM_DECIDED,
      { claimStatus: "APPROVED" },
      "انقبل استلامك للملف",
      "الملف صار لك، وتكمّله من اعّرست.",
    ],
    [
      NotificationType.PROVIDER_CLAIM_DECIDED,
      { claimStatus: "REJECTED" },
      "ما قبلنا الاستلام",
      "السبب في اعّرست.",
    ],
    [
      NotificationType.PORTFOLIO_REVIEWED,
      { decision: "APPROVED" },
      "انقبلت صورة من معرضك",
      "تفاصيلها في اعّرست.",
    ],
    [
      NotificationType.PORTFOLIO_REVIEWED,
      { decision: "REJECTED" },
      "ما قبلنا صورة من معرضك",
      "السبب في اعّرست.",
    ],
  ];
  for (const [type, data, title, body] of cases) {
    const copy = pushNotificationCopy(type, data);
    assert.equal(copy.title, title, type);
    assert.equal(copy.body, body, type);
    for (const words of [copy.title, copy.body]) {
      assert.doesNotMatch(words, /\d|خالد|سبأ|بلاغات|الاسم/u, type);
    }
  }
});

test("Q-60: the new pushes go on the messages channel and wait out the quiet hours", () => {
  for (const type of [
    NotificationType.PROVIDER_NEEDS_CHANGES,
    NotificationType.PROVIDER_SUSPENDED,
    NotificationType.PROVIDER_CLAIM_DECIDED,
    NotificationType.PORTFOLIO_REVIEWED,
  ]) {
    assert.equal(pushAndroidChannelId(type), "aarast_messages", type);
    assert.equal(isQuietHoursExempt(type), false, type);
  }
});

test("the provider's lock screen says what happened with no name, amount or customer", () => {
  const cases: Array<[NotificationType, unknown, string]> = [
    [NotificationType.QUOTE_REQUEST_SUBMITTED, { recipientAudience: "PROVIDER" }, "وصلك طلب جديد"],
    [NotificationType.QUOTE_ACCEPTED, { recipientAudience: "PROVIDER" }, "انقبل عرضك"],
    [NotificationType.QUOTE_REJECTED, { recipientAudience: "PROVIDER" }, "عرضك ما انقبل"],
    [NotificationType.PROVIDER_APPROVED, undefined, "اعتمدنا ملفك"],
    [NotificationType.PROVIDER_REJECTED, undefined, "ما اعتمدنا ملفك"],
  ];
  for (const [type, data, title] of cases) {
    const copy = pushNotificationCopy(type, data);
    assert.equal(copy.title, title, type);
    assert.match(copy.body, /في اعّرست/u, type);
    for (const words of [copy.title, copy.body]) {
      assert.doesNotMatch(words, /\d|خالد|سبأ/u, type);
    }
  }
});

/** One notice written through the one service path, and the outbox rows it queued. */
async function write(notice: { type: NotificationType; data?: unknown }, userId: string) {
  const outbox: Array<Record<string, any>> = [];
  const tx = {
    $queryRaw: async (query: any) => {
      const sql = Array.isArray(query?.strings) ? query.strings.join(" ") : String(query);
      if (sql.includes('FROM "User"')) return [{ id: userId, status: UserStatus.ACTIVE }];
      return [];
    },
    user: { findMany: async () => [] },
    notificationPreference: { findUnique: async () => null },
    notification: {
      create: async ({ data }: { data: Record<string, any> }) => ({
        ...data,
        id: "notification-1",
        createdAt: new Date(),
        readAt: null,
        archivedAt: null,
      }),
    },
    outboxEvent: {
      create: async ({ data }: { data: Record<string, any> }) => {
        outbox.push(data);
        return { id: `outbox-${outbox.length}` };
      },
    },
  };
  const service = notificationsService({} as any, {} as any, new OutboxService());
  await service.createNotificationInTransaction(tx as any, notice as any);
  return outbox.map((event) => event.type);
}

test("the service queues a phone push for the provider's notice and none for the customer's", async () => {
  assert.deepEqual(await write(providerNotices[0]!, "provider-user"), [
    OutboxEventTypes.notificationCreated,
    OutboxEventTypes.pushNotificationRequested,
  ]);
  assert.deepEqual(await write(customerNotices[0]!, "customer-1"), [
    OutboxEventTypes.notificationCreated,
  ]);
  // Q-60: the team's «يحتاج تعديل» is written and queued for his phone.
  const needsChanges = switchProviderStatusNotification(
    "قاعة سبأ",
    ProviderStatus.NEEDS_CHANGES,
    "غيّر الاسم",
  );
  assert.deepEqual(
    await write(
      {
        ...needsChanges,
        data: { providerId: "provider-1", providerStatus: ProviderStatus.NEEDS_CHANGES },
      } as any,
      "provider-user",
    ),
    [OutboxEventTypes.notificationCreated, OutboxEventTypes.pushNotificationRequested],
  );
});
