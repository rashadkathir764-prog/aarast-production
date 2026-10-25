import { NotificationPriority, NotificationType } from "@prisma/client";
import type { CreateNotificationInput } from "../modules/notifications/public/notifications.port";
import {
  customerFirstName,
  providerRequestRoute,
  requesterQuoteRoute,
} from "./quote-notifications";
import { type AddressedText, gendered } from "../shared-kernel/voice/address-form";
import {
  daysBetween,
  weekdayDayMonthWords,
  whenWords,
} from "../shared-kernel/voice/day-words";

// Each booking step tells the other side (V1 checklist 4.6): the provider
// learns of a request or a cancellation, the customer of a confirmation, a
// decline or a cancellation. Pure builders, no Prisma. A day reads
// «الخميس 21 يناير» (B-38); a request is its own type (B-19).

export type BookingEvent = "REQUESTED" | "CONFIRMED" | "DECLINED" | "CANCELLED";

interface BookingNotificationArgs {
  bookingId: string;
  quoteRequestId: string;
  providerId: string;
  eventDate: Date;
  /** Bumps on every reopen so a second request is not deduplicated away. */
  revision: number;
}

export function bookingProviderNotification(
  event: Extract<BookingEvent, "REQUESTED" | "CANCELLED">,
  args: BookingNotificationArgs & {
    providerUserId: string;
    customerName: string | null;
  },
): CreateNotificationInput {
  const who = customerFirstName(args.customerName);
  const day = weekdayDayMonthWords(args.eventDate);
  // The customer may be the groom or the bride: the lines name them
  // without a verb in their gender (D55).
  const copy =
    event === "REQUESTED"
      ? {
          title: who ? `طلب حجز من ${who}` : "وصلك طلب حجز",
          body: `يوم ${day}. أكّد الحجز أو اعتذر.`,
        }
      : {
          title: who ? `انلغى حجز ${who}` : "انلغى حجز",
          body: `يوم ${day} رجع فاضي في تقويمك.`,
        };
  return {
    userId: args.providerUserId,
    type:
      event === "REQUESTED"
        ? NotificationType.BOOKING_REQUESTED
        : NotificationType.BOOKING_UPDATED,
    priority: NotificationPriority.HIGH,
    title: copy.title,
    body: copy.body,
    entityType: "booking",
    entityId: args.bookingId,
    routeTarget: providerRequestRoute(args.quoteRequestId),
    data: {
      bookingId: args.bookingId,
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      bookingEvent: event,
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
  const day = weekdayDayMonthWords(args.eventDate);
  const copies: Record<typeof event, { title: string; body: AddressedText }> = {
    CONFIRMED: {
      title: `تأكد حجزك مع ${args.providerName}`,
      body: `يوم ${day} · بدون أي دفع داخل التطبيق.`,
    },
    DECLINED: {
      title: `اعتذر ${args.providerName} عن يوم ${day}`,
      body: gendered(
        "تقدر تطلب يوم ثاني أو تختار مزود غيره.",
        "تقدرين تطلبين يوم ثاني أو تختارين مزود غيره.",
      ),
    },
    CANCELLED: {
      title: `انلغى حجزك مع ${args.providerName}`,
      body: gendered(
        `كان يوم ${day}. تقدر تكلمه أو تختار مزود غيره.`,
        `كان يوم ${day}. تقدرين تكلمينه أو تختارين مزود غيره.`,
      ),
    },
  };
  const copy = copies[event];
  return {
    userId: args.customerUserId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.BOOKING_UPDATED,
    priority: NotificationPriority.HIGH,
    title: copy.title,
    body: copy.body,
    entityType: "booking",
    entityId: args.bookingId,
    routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
    data: {
      bookingId: args.bookingId,
      quoteRequestId: args.quoteRequestId,
      providerId: args.providerId,
      weddingPlanId: args.weddingPlanId,
      bookingEvent: event,
      recipientAudience: "CUSTOMER",
    },
    dedupeKey: `${args.customerUserId}:booking:${args.bookingId}:${event}:${args.revision}`,
  };
}

// ── Reminders before a confirmed booking (V1 checklist 4.17) ───────────

/** A confirmed booking reminds both sides once a week before and once the day before. */
export const BOOKING_REMINDER_MILESTONES = [7, 1] as const;

/** The reminder window a booking `daysUntil` away is in, or null outside every window. */
export function bookingReminderMilestone(daysUntil: number): number | null {
  if (daysUntil < 1) return null;
  for (const milestone of [...BOOKING_REMINDER_MILESTONES].reverse()) {
    if (daysUntil <= milestone) return milestone;
  }
  return null;
}

/** Whole calendar days from `today` to the booking day (both `@db.Date` midnights). */
export function bookingDaysUntil(eventDate: Date, today: Date): number {
  return daysBetween(today, eventDate);
}

export interface BookingReminderArgs {
  bookingId: string;
  quoteRequestId: string;
  providerId: string;
  eventDate: Date;
  customerUserId: string;
  weddingPlanId: string | null;
  customerName: string | null;
  providerUserId: string | null;
  providerName: string;
}

/**
 * The reminders due for one confirmed booking today: the customer and the
 * provider each once per window. The key carries the day, so a booking moved
 * to another day (cancelled and requested again) reminds again.
 */
export function bookingReminderNotifications(
  args: BookingReminderArgs,
  today: Date,
): CreateNotificationInput[] {
  const daysUntil = bookingDaysUntil(args.eventDate, today);
  const milestone = bookingReminderMilestone(daysUntil);
  if (milestone === null) return [];
  const isoDay = args.eventDate.toISOString().slice(0, 10);
  const day = weekdayDayMonthWords(args.eventDate);
  const when = whenWords(daysUntil);
  const priority =
    daysUntil <= 1 ? NotificationPriority.HIGH : NotificationPriority.NORMAL;
  const data = {
    bookingId: args.bookingId,
    quoteRequestId: args.quoteRequestId,
    providerId: args.providerId,
    daysUntil,
  };
  const key = (userId: string) =>
    `${userId}:booking:${args.bookingId}:REMINDER:${milestone}:${isoDay}`;
  const reminders: CreateNotificationInput[] = [
    {
      userId: args.customerUserId,
      weddingPlanId: args.weddingPlanId,
      type: NotificationType.BOOKING_UPDATED,
      priority,
      title: `حجزك مع ${args.providerName} ${when}`,
      body: gendered(
        `يوم ${day}. تواصل معه وتأكد من التفاصيل.`,
        `يوم ${day}. تواصلي معه وتأكدي من التفاصيل.`,
      ),
      entityType: "booking",
      entityId: args.bookingId,
      routeTarget: requesterQuoteRoute(args.weddingPlanId, args.quoteRequestId),
      data: {
        ...data,
        weddingPlanId: args.weddingPlanId,
        recipientAudience: "CUSTOMER",
      },
      dedupeKey: key(args.customerUserId),
    },
  ];
  if (args.providerUserId) {
    const who = customerFirstName(args.customerName);
    reminders.push({
      userId: args.providerUserId,
      type: NotificationType.BOOKING_UPDATED,
      priority,
      title: who ? `عندك حجز مع ${who} ${when}` : `عندك حجز ${when}`,
      body: `يوم ${day}.`,
      entityType: "booking",
      entityId: args.bookingId,
      routeTarget: providerRequestRoute(args.quoteRequestId),
      data: { ...data, recipientAudience: "PROVIDER" },
      dedupeKey: key(args.providerUserId),
    });
  }
  return reminders;
}
