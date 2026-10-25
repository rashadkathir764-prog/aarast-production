import { NotificationPriority, NotificationType } from "@prisma/client";
import type { CreateNotificationInput } from "../modules/notifications/public/notifications.port";
import { PROVIDER_PORTAL_ROUTE } from "../modules/marketplace/public/provider-access-policy";

// بناة مدخلات إشعارات دورة عروض الأسعار — نقية بلا Prisma ولا خدمات،
// حتى يبقى marketplace.service على التنسيق فقط (انظر عقد marketplace-presenter).
// المبدأ: الطرفان يعلمان دائمًا — لا طلب صامت ولا قبول لا يعرفه المورد.

export function requesterQuoteRoute(quoteId: string): string {
  return `/providers?quoteId=${encodeURIComponent(quoteId)}`;
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
    title: "تم إرسال طلب عرض السعر",
    body: `تم إرسال طلبك إلى ${args.providerName}. سنعرض الرد عند وصول عرض حقيقي من المورد.`,
    entityType: "quote_request",
    entityId: args.quoteId,
    routeTarget: requesterQuoteRoute(args.quoteId),
    data: {
      quoteRequestId: args.quoteId,
      providerId: args.providerId,
      weddingPlanId: args.weddingPlanId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-submitted:${args.quoteId}`,
  };
}

// إشعار المورد بطلب جديد — بلا weddingPlanId: المورد ليس عضوًا في الخطة.
export function quoteSubmittedProviderNotification(args: {
  providerUserId: string;
  quoteId: string;
  providerId: string;
}): CreateNotificationInput {
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_REQUEST_SUBMITTED,
    priority: NotificationPriority.HIGH,
    title: "طلب عرض سعر جديد",
    body: "وصلك طلب عرض سعر جديد. افتح بوابة المورد لمراجعته والرد بعرضك.",
    entityType: "quote_request",
    entityId: args.quoteId,
    routeTarget: PROVIDER_PORTAL_ROUTE,
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
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_ACCEPTED,
    priority: NotificationPriority.HIGH,
    title: "تم قبول عرض السعر",
    body: "أصبح المزود ضمن مزودي الخطة المقبولين، وأنشئت التكلفة تلقائيًا دون إنشاء دفعة أو موعد دفع أو مهمة.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      providerId: args.providerId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-accepted:${args.quoteRequestId}`,
  };
}

export function providerRejectedRequestNotification(args: {
  requesterId: string;
  weddingPlanId: string | null;
  quoteRequestId: string;
  providerId: string;
  providerName: string;
}): CreateNotificationInput {
  return {
    userId: args.requesterId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.QUOTE_REJECTED,
    priority: NotificationPriority.NORMAL,
    title: "اعتذر المورد عن الطلب",
    body: `اعتذر ${args.providerName} عن طلب عرض السعر. يمكنك فتح الطلب ومراجعة حالته.`,
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      status: "REJECTED",
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
}): CreateNotificationInput {
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_REJECTED,
    priority: NotificationPriority.NORMAL,
    title: "لم يُقبل عرض السعر",
    body: "اختار صاحب الطلب عدم قبول العرض. افتح بوابة المورد لمراجعة الطلب.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: PROVIDER_PORTAL_ROUTE,
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
    title: "وصل عرض سعر",
    body: `أرسل ${args.providerName} عرضًا لطلبك. افتح الطلب لمراجعة التفاصيل.`,
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
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
}): CreateNotificationInput {
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_ACCEPTED,
    priority: NotificationPriority.HIGH,
    title: "تم قبول عرضك",
    body: "قبل صاحب الطلب عرض السعر الذي أرسلته. افتح بوابة المورد للمتابعة والتواصل.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: PROVIDER_PORTAL_ROUTE,
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
    body: "عرضه ما عاد متاح. تقدر تسأله ليش في المحادثة، أو تنتظر عرضه الجديد.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
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
    body: "وصلتك نسخة جديدة من العرض. افتح الطلب وشوف ايش تغيّر.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
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
  const who = args.customerName?.trim().split(/\s+/u)[0];
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
    body: "انتهى طلبك بدون رد. اطلب من غيره من المزودين.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      status: "EXPIRED",
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.requesterId}:quote-request-expired:${args.quoteRequestId}`,
  };
}

/** The provider's own request page (D39), which the phone opens. */
export function providerRequestRoute(quoteRequestId: string): string {
  return `/provider/requests/${encodeURIComponent(quoteRequestId)}`;
}
