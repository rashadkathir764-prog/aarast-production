import { NotificationPriority, NotificationType } from "@prisma/client";
import type { CreateNotificationInput } from "../modules/notifications/public/notifications.port";
import { gendered } from "../shared-kernel/voice/address-form";
import { noticeRoutes } from "../shared-kernel/routes/notification-routes";

// Pure builders of the request-and-offer notices (no Prisma, no services),
// so marketplace.service stays on coordination (the marketplace-presenter
// contract). Both sides always know: no silent request, no acceptance the
// provider does not hear of. Each notice opens its own screen (B-19) and
// speaks as the app does (B-38): «مزود», never «مورد» or «بوابة»; no
// amount (a reader of notices may not see money, D53). A provider-facing
// notice names the customer without a verb in their gender (D55).

/** f04: the customer's request (the plan's request page, else the providers' list). */
export function requesterQuoteRoute(
  weddingPlanId: string | null,
  quoteId: string,
): string {
  return noticeRoutes.customerRequest(weddingPlanId, quoteId);
}

/** The provider's own request page (D39), which the phone opens. */
export function providerRequestRoute(quoteRequestId: string): string {
  return noticeRoutes.providerRequest(quoteRequestId);
}

/** The customer's first name as the provider reads it (B-14), or null. */
export function customerFirstName(name: string | null | undefined): string | null {
  return name?.trim().split(/\s+/u)[0] || null;
}

export function quoteSubmittedRequesterNotification(args: {
  requesterId: string;
  weddingPlanId: string | null;
  quoteId: string;
  providerId: string;
  providerName: string;
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_REQUEST_SUBMITTED,
    priority: NotificationPriority.NORMAL,
    title: `وصل طلبك لـ${args.providerName}`,
    body: "نبلغك هنا أول ما يرد بعرضه.",
    entityType: "quote_request",
    entityId: args.quoteId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteId),
    data: {
      quoteRequestId: args.quoteId,
      providerId: args.providerId,
      weddingPlanId: args.weddingPlanId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-submitted:${args.quoteId}`,
  };
}

// The provider's notice of a new request: no weddingPlanId, he is not a
// member of the plan.
export function quoteSubmittedProviderNotification(args: {
  providerUserId: string;
  quoteId: string;
  providerId: string;
  customerName: string | null;
}): CreateNotificationInput {
  const who = customerFirstName(args.customerName);
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_REQUEST_SUBMITTED,
    priority: NotificationPriority.HIGH,
    title: who ? `طلب جديد من ${who}` : "وصلك طلب جديد",
    body: "ردّ بعرضك أو اعتذر خلال 7 أيام.",
    entityType: "quote_request",
    entityId: args.quoteId,
    routeTarget: providerRequestRoute(args.quoteId),
    data: {
      quoteRequestId: args.quoteId,
      providerId: args.providerId,
      recipientAudience: "PROVIDER",
    },
    dedupeKey: `${args.providerUserId}:quote-request-received:${args.quoteId}`,
  };
}

export function offerAcceptedRequesterNotification(args: {
  requesterId: string;
  weddingPlanId: string;
  quoteRequestId: string;
  quoteOfferId: string;
  providerId: string;
  providerName: string;
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_ACCEPTED,
    priority: NotificationPriority.HIGH,
    title: `انقبل عرض ${args.providerName}`,
    body: "انضاف اتفاقه في المال بدون أي دفعة، والحجز يُطلب من صفحة الطلب.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      providerId: args.providerId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-accepted:${args.quoteRequestId}`,
  };
}

/** B-11: the customer's reasons as the provider reads them. */
export const QUOTE_REJECT_REASON_WORDS: Readonly<Record<string, string>> = {
  PRICE: "السعر فوق اللي حاسب له",
  CHOSE_OTHER: "اختار مزود ثاني",
  DATE: "الموعد ما يناسب",
  NONE: "ما ذكر سبب",
};

/** B-05: the decline reasons as the customer reads them. */
export const QUOTE_DECLINE_REASON_WORDS: Readonly<Record<string, string>> = {
  BUSY_THAT_DAY: "مشغول ذاك اليوم",
  OUT_OF_AREA: "خارج منطقته",
  NOT_MY_SERVICE: "ما يقدّم هذي الخدمة",
  OTHER: "سبب آخر",
};

export function providerRejectedRequestNotification(args: {
  requesterId: string;
  weddingPlanId: string | null;
  quoteRequestId: string;
  providerId: string;
  providerName: string;
  /** B-05: why, when the provider said. */
  declineReason?: string | null;
}): CreateNotificationInput {
  const why = args.declineReason ? QUOTE_DECLINE_REASON_WORDS[args.declineReason] : undefined;
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_REJECTED,
    priority: NotificationPriority.NORMAL,
    title: why
      ? `اعتذر ${args.providerName}: ${why}`
      : `اعتذر ${args.providerName} عن طلبك`,
    body: gendered(
      "تقدر تطلب من مزود غيره.",
      "تقدرين تطلبين من مزود غيره.",
    ),
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      status: "REJECTED",
      ...(args.declineReason ? { declineReason: args.declineReason } : {}),
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:provider-rejected-quote:${args.quoteRequestId}`,
  };
}

export function requesterRejectedOfferNotification(args: {
  providerUserId: string;
  quoteRequestId: string;
  quoteOfferId: string;
  providerId: string;
  /** B-11: the customer's reason, when given. */
  reason?: string | null;
}): CreateNotificationInput {
  const why = args.reason ? QUOTE_REJECT_REASON_WORDS[args.reason] : undefined;
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_REJECTED,
    priority: NotificationPriority.NORMAL,
    title: "عرضك ما انقبل",
    body: why ? `السبب: ${why}` : "الطلب انقفل بدون عرضك.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: providerRequestRoute(args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      providerId: args.providerId,
      status: "REJECTED",
      recipientAudience: "PROVIDER",
    },
    dedupeKey: `${args.providerUserId}:requester-rejected-offer:${args.quoteOfferId}`,
  };
}

export function quoteOfferReceivedNotification(args: {
  requesterId: string;
  weddingPlanId: string | null;
  quoteRequestId: string;
  quoteOfferId: string;
  providerId: string;
  providerName: string;
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_OFFER_RECEIVED,
    priority: NotificationPriority.HIGH,
    title: `وصلك عرض من ${args.providerName}`,
    body: gendered(
      "افتح الطلب وشوف التفاصيل.",
      "افتحي الطلب وشوفي التفاصيل.",
    ),
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      providerId: args.providerId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-offer:${args.quoteOfferId}`,
  };
}

export function offerAcceptedProviderNotification(args: {
  providerUserId: string;
  quoteRequestId: string;
  quoteOfferId: string;
  providerId: string;
  customerName: string | null;
}): CreateNotificationInput {
  const who = customerFirstName(args.customerName);
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_ACCEPTED,
    priority: NotificationPriority.HIGH,
    title: "انقبل عرضك",
    body: who
      ? `عرضك لطلب ${who} انقبل. الحجز يوصلك طلبه هنا.`
      : "الحجز يوصلك طلبه هنا.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: providerRequestRoute(args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      providerId: args.providerId,
      recipientAudience: "PROVIDER",
    },
    dedupeKey: `${args.providerUserId}:quote-offer-accepted:${args.quoteOfferId}`,
  };
}

/** B-03: the provider took his offer back; the request waits for him again. */
export function quoteOfferWithdrawnNotification(args: {
  requesterId: string;
  weddingPlanId: string | null;
  quoteRequestId: string;
  quoteOfferId: string;
  providerId: string;
  providerName: string;
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_REJECTED,
    priority: NotificationPriority.NORMAL,
    title: `سحب ${args.providerName} عرضه`,
    body: gendered(
      "عرضه ما عاد متاح. تقدر تسأله ليش في المحادثة، أو تنتظر عرضه الجديد.",
      "عرضه ما عاد متاح. تقدرين تسأليه ليش في المحادثة، أو تنتظرين عرضه الجديد.",
    ),
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      providerId: args.providerId,
      status: "WITHDRAWN",
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-offer-withdrawn:${args.quoteOfferId}`,
  };
}

/** How long after a told revision the next revision of the same offer stays untold. */
export const QUOTE_OFFER_NOTICE_WINDOW_MS = 10 * 60 * 1000;

/**
 * Whether a revision at `at` tells the customer: revisions of one offer are
 * told once per ten minutes (counted from the last told revision), so a
 * provider fixing his offer several times in a row sends one notice. The
 * conversation's timeline records every version either way.
 */
export function isQuoteOfferRevisionNoticeDue(
  lastNoticeAt: Date | null,
  at: Date,
): boolean {
  return (
    lastNoticeAt === null ||
    at.getTime() - lastNoticeAt.getTime() >= QUOTE_OFFER_NOTICE_WINDOW_MS
  );
}

/**
 * B-06: a new version of an offer. The amount stays out of the notice (a
 * member who reads notices may not see money); the request shows the change.
 */
export function quoteOfferRevisedNotification(args: {
  requesterId: string;
  weddingPlanId: string | null;
  quoteRequestId: string;
  quoteOfferId: string;
  versionNo: number;
  providerId: string;
  providerName: string;
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_OFFER_RECEIVED,
    priority: NotificationPriority.HIGH,
    title: `عدّل ${args.providerName} عرضه`,
    body: gendered(
      "وصلتك نسخة جديدة من العرض. افتح الطلب وشوف ايش تغيّر.",
      "وصلتك نسخة جديدة من العرض. افتحي الطلب وشوفي ايش تغيّر.",
    ),
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      versionNo: args.versionNo,
      providerId: args.providerId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-offer:${args.quoteOfferId}:v${args.versionNo}`,
  };
}

/** B-04: told the day before; one notice per answer window. */
export function quoteRequestExpiringProviderNotification(args: {
  providerUserId: string;
  quoteRequestId: string;
  providerId: string;
  customerName: string | null;
  expiresAt: Date;
}): CreateNotificationInput {
  const who = customerFirstName(args.customerName);
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_REQUEST_EXPIRING,
    priority: NotificationPriority.HIGH,
    title: who ? `طلب ${who} ينتهي بكرة` : "عندك طلب ينتهي بكرة",
    body: "ما رديت عليه للحين. أرسل عرضك أو اعتذر قبل ما ينتهي.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: providerRequestRoute(args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      expiresAt: args.expiresAt.toISOString(),
      recipientAudience: "PROVIDER",
    },
    dedupeKey: `${args.providerUserId}:quote-request-expiring:${args.quoteRequestId}:${args.expiresAt.toISOString()}`,
  };
}

/** B-04: the request ended without an answer; the customer asks someone else. */
export function quoteRequestExpiredRequesterNotification(args: {
  requesterId: string;
  weddingPlanId: string | null;
  quoteRequestId: string;
  providerId: string;
  providerName: string;
  answerDays: number;
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_REJECTED,
    priority: NotificationPriority.NORMAL,
    title: `ما رد ${args.providerName} خلال ${args.answerDays} أيام`,
    body: gendered(
      "انتهى طلبك بدون رد. اطلب من غيره من المزودين.",
      "انتهى طلبك بدون رد. اطلبي من غيره من المزودين.",
    ),
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      status: "EXPIRED",
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-request-expired:${args.quoteRequestId}`,
  };
}
