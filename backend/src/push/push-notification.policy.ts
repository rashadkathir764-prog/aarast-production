import { NotificationType } from "@prisma/client";

const PUSH_NOTIFICATION_TYPES = new Set<NotificationType>([
  NotificationType.TASK_ASSIGNED,
  NotificationType.TASK_DUE_SOON,
  NotificationType.TASK_OVERDUE,
  NotificationType.CHAT_MESSAGE_RECEIVED,
  NotificationType.WEDDING_COUNTDOWN,
  // A price offer for the customer and every booking step for the other
  // side: each waits on a decision (V1 checklist 4.6).
  NotificationType.QUOTE_OFFER_RECEIVED,
  NotificationType.BOOKING_UPDATED,
  // B-04: a request the provider has not answered ends tomorrow.
  NotificationType.QUOTE_REQUEST_EXPIRING,
]);

export function isPushNotificationType(type: NotificationType): boolean {
  return PUSH_NOTIFICATION_TYPES.has(type);
}

/**
 * A QUOTE_OFFER_RECEIVED notice about a new version (B-06) carries the
 * version number from 2 up; the first offer carries none.
 */
function isRevisedOfferNotice(data: unknown): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  const versionNo = (data as Record<string, unknown>).versionNo;
  return typeof versionNo === "number" && versionNo > 1;
}

/**
 * The words on the lock screen: generic, never a name or an amount. `data`
 * is the notification's own data, read only to tell a revised offer from a
 * new one.
 */
export function pushNotificationCopy(
  type: NotificationType,
  data?: unknown,
): {
  title: string;
  body: string;
} {
  switch (type) {
    case NotificationType.TASK_ASSIGNED:
      return {
        title: "مهمة جديدة",
        body: "تم إسناد مهمة جديدة إليك. افتح اعّرست لعرض التفاصيل.",
      };
    case NotificationType.TASK_DUE_SOON:
    case NotificationType.TASK_OVERDUE:
      return {
        title: "تذكير بمهمة",
        body: "لديك تحديث جديد على مهام الخطة. افتح اعّرست للمتابعة.",
      };
    case NotificationType.CHAT_MESSAGE_RECEIVED:
      return {
        title: "رسالة جديدة",
        body: "لديك رسالة جديدة. افتح اعّرست لقراءتها.",
      };
    case NotificationType.WEDDING_COUNTDOWN:
      return {
        title: "العد التنازلي للعرس",
        body: "موعد العرس يقترب. افتح اعّرست لمراجعة ما تبقى.",
      };
    case NotificationType.QUOTE_OFFER_RECEIVED:
      return isRevisedOfferNotice(data)
        ? {
            title: "عدّلوا عرضهم",
            body: "وصلتك نسخة جديدة من العرض. افتح اعّرست وشوف ايش تغيّر.",
          }
        : {
            title: "وصل عرض سعر",
            body: "وصلك عرض سعر جديد. افتح اعّرست لمراجعته.",
          };
    case NotificationType.QUOTE_REQUEST_EXPIRING:
      return {
        title: "طلب ينتهي بكرة",
        body: "عندك طلب ما رديت عليه وينتهي بكرة. افتح اعّرست وردّ عليه.",
      };
    case NotificationType.BOOKING_UPDATED:
      return {
        title: "تحديث على حجز",
        body: "لديك تحديث على حجز. افتح اعّرست لعرض التفاصيل.",
      };
    default:
      throw new Error("UnsupportedPushNotificationType");
  }
}
