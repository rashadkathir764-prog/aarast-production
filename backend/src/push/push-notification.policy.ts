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
  // B-19: a booking request has its own type; it waits on the provider.
  NotificationType.BOOKING_REQUESTED,
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

/** A WEDDING_COUNTDOWN notice for the wedding day itself (`daysUntil` 0). */
function isWeddingDayNotice(data: unknown): boolean {
  if (!data || typeof data !== "object" || Array.isArray(data)) return false;
  return (data as Record<string, unknown>).daysUntil === 0;
}

/**
 * The words on the lock screen: generic, never a name or an amount. `data`
 * is the notification's own data, read only to tell a revised offer from a
 * new one. A customer's lock screen may be the groom's or the bride's, so
 * these lines tell without an imperative in either gender (B5); the
 * provider's line keeps the provider's voice.
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
        body: "عندك مهمة جديدة، وتفاصيلها في اعّرست.",
      };
    case NotificationType.TASK_DUE_SOON:
      return {
        title: "تذكير بمهمة",
        body: "عندك مهمة موعدها قريب، وتفاصيلها في اعّرست.",
      };
    // RA-BE-99: a task whose day passed is late, not coming; the notice in
    // the app says «مهمة متأخرة», and the lock screen says the same.
    case NotificationType.TASK_OVERDUE:
      return {
        title: "مهمة متأخرة",
        body: "عندك مهمة فات موعدها، وتفاصيلها في اعّرست.",
      };
    case NotificationType.CHAT_MESSAGE_RECEIVED:
      return {
        title: "رسالة جديدة",
        body: "وصلتك رسالة في اعّرست.",
      };
    // RA-BE-99: on the day itself the lock screen does not say it is near.
    case NotificationType.WEDDING_COUNTDOWN:
      return isWeddingDayNotice(data)
        ? { title: "اليوم يوم العرس", body: "ألف مبروك، واللي باقي لليوم في اعّرست." }
        : { title: "العرس يقرب", body: "اللي باقي قبله في اعّرست." };
    case NotificationType.QUOTE_OFFER_RECEIVED:
      return isRevisedOfferNotice(data)
        ? {
            title: "عدّلوا عرضهم",
            body: "وصلتك نسخة جديدة من العرض، وفي اعّرست ايش تغيّر.",
          }
        : {
            title: "وصلك عرض",
            body: "وصلك عرض جديد، وتفاصيله في اعّرست.",
          };
    case NotificationType.QUOTE_REQUEST_EXPIRING:
      return {
        title: "طلب ينتهي بكرة",
        body: "عندك طلب ما رديت عليه وينتهي بكرة. افتح اعّرست وردّ عليه.",
      };
    case NotificationType.BOOKING_REQUESTED:
      return {
        title: "طلب حجز جديد",
        body: "وصلك طلب حجز، وتفاصيله في اعّرست.",
      };
    case NotificationType.BOOKING_UPDATED:
      return {
        title: "تحديث على حجز",
        body: "فيه جديد على حجز، وتفاصيله في اعّرست.",
      };
    default:
      throw new Error("UnsupportedPushNotificationType");
  }
}
