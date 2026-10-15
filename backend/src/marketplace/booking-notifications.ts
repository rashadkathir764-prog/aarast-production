import { NotificationPriority, NotificationType } from "@prisma/client";
import type { CreateNotificationInput } from "../modules/notifications/public/notifications.port";
import { PROVIDER_PORTAL_ROUTE } from "../modules/marketplace/public/provider-access-policy";
import { requesterQuoteRoute } from "./quote-notifications";

// Each booking step tells the other side (V1 checklist 4.6): the provider
// learns of a request or a cancellation, the customer of a confirmation, a
// decline or a cancellation. Pure builders, no Prisma.

export type BookingEvent = "REQUESTED" | "CONFIRMED" | "DECLINED" | "CANCELLED";

interface BookingNotificationArgs {
  bookingId: string;
  quoteRequestId: string;
  providerId: string;
  eventDate: Date;
  /** Bumps on every reopen so a second request is not deduplicated away. */
  revision: number;
}

function formatDay(day: Date): string {
  return day.toISOString().slice(0, 10);
}

export function bookingProviderNotification(
  event: Extract<BookingEvent, "REQUESTED" | "CANCELLED">,
  args: BookingNotificationArgs & {
    providerUserId: string;
    customerName: string | null;
  },
): CreateNotificationInput {
  const who = args.customerName?.trim() || "العميل";
  const day = formatDay(args.eventDate);
  return {
    userId: args.providerUserId,
    type: NotificationType.BOOKING_UPDATED,
    priority: NotificationPriority.HIGH,
    title: event === "REQUESTED" ? "طلب حجز جديد" : "أُلغي حجز",
    body:
      event === "REQUESTED"
        ? `${who} يطلب حجز يوم ${day}. أكّد الحجز أو اعتذر من بوابة المزوّد.`
        : `${who} ألغى الحجز ليوم ${day}. أصبح اليوم متاحًا في تقويمك.`,
    entityType: "booking",
    entityId: args.bookingId,
    routeTarget: PROVIDER_PORTAL_ROUTE,
    data: {
      bookingId: args.bookingId,
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      recipientAudience: "PROVIDER",
    },
    dedupeKey: `${args.providerUserId}:booking:${args.bookingId}:${event}:${args.revision}`,
  };
}

export function bookingCustomerNotification(
  event: Extract<BookingEvent, "CONFIRMED" | "DECLINED" | "CANCELLED">,
  args: BookingNotificationArgs & {
    customerUserId: string;
    weddingPlanId: string | null;
    providerName: string;
  },
): CreateNotificationInput {
  const day = formatDay(args.eventDate);
  const copy = {
    CONFIRMED: {
      title: "تم تأكيد الحجز",
      body: `${args.providerName} أكّد حجز يوم ${day}.`,
    },
    DECLINED: {
      title: "اعتذر المزوّد عن الحجز",
      body: `${args.providerName} اعتذر عن يوم ${day}. يمكنك طلب يوم آخر أو اختيار مزوّد آخر.`,
    },
    CANCELLED: {
      title: "ألغى المزوّد الحجز",
      body: `${args.providerName} ألغى حجز يوم ${day}. تواصل معه أو اختر مزوّدًا آخر.`,
    },
  }[event];
  return {
    userId: args.customerUserId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.BOOKING_UPDATED,
    priority: NotificationPriority.HIGH,
    title: copy.title,
    body: copy.body,
    entityType: "booking",
    entityId: args.bookingId,
    routeTarget: requesterQuoteRoute(args.quoteRequestId),
    data: {
      bookingId: args.bookingId,
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      weddingPlanId: args.weddingPlanId,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.customerUserId}:booking:${args.bookingId}:${event}:${args.revision}`,
  };
}
