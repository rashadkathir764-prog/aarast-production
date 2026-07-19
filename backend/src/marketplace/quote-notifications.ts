import { NotificationPriority, NotificationType } from "@prisma/client";
import type { CreateNotificationInput } from "../notifications/notifications.service";

// بناة مدخلات إشعارات دورة عروض الأسعار — نقية بلا Prisma ولا خدمات،
// حتى يبقى marketplace.service على التنسيق فقط (انظر عقد marketplace-presenter).
// المبدأ: الطرفان يعلمان دائمًا — لا طلب صامت ولا قبول لا يعرفه المورد.

export const PROVIDER_PORTAL_ROUTE = "/provider/dashboard";

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
    },
    dedupeKey: `${args.requesterId}:quote-submitted:${args.quoteId}`,
  };
}

// إشعار المورد بطلب جديد — بلا weddingPlanId: المورد ليس عضوًا في الخطة.
export function quoteSubmittedProviderNotification(args: {
  providerUserId: string;
  quoteId: string;
  providerId: string;
  contactName: string;
}): CreateNotificationInput {
  return {
    userId: args.providerUserId,
    type: NotificationType.QUOTE_REQUEST_SUBMITTED,
    priority: NotificationPriority.HIGH,
    title: "طلب عرض سعر جديد",
    body: `وصلك طلب عرض سعر جديد من ${args.contactName}. افتح بوابة المورد لمراجعته والرد بعرضك.`,
    entityType: "quote_request",
    entityId: args.quoteId,
    routeTarget: PROVIDER_PORTAL_ROUTE,
    data: {
      quoteRequestId: args.quoteId,
      providerId: args.providerId,
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
    body: "أصبح المزود ضمن مزودي الخطة المقبولين. لم يتم إنشاء تكلفة أو دفعة تلقائيًا.",
    entityType: "quote_request",
    entityId: args.quoteRequestId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
    data: {
      quoteRequestId: args.quoteRequestId,
      quoteOfferId: args.quoteOfferId,
      providerId: args.providerId,
    },
    dedupeKey: `${args.requesterId}:quote-accepted:${args.quoteRequestId}`,
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
    },
    dedupeKey: `${args.providerUserId}:quote-offer-accepted:${args.quoteOfferId}`,
  };
}
