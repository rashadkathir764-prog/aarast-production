import { NotificationPriority, NotificationType } from "@prisma/client";
import type { CreateNotificationInput } from "../modules/notifications/public/notifications.port";
import { PROVIDER_PORTAL_ROUTE } from "../modules/marketplace/public/provider-access-policy";
import { requesterQuoteRoute } from "./quote-notifications";
import { type AddressedText, gendered } from "../shared-kernel/voice/address-form";

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
        ? // The customer may be the groom or the bride: the line names
          // them without a verb in their gender (B5).
          `طلب حجز يوم ${day} من ${who}. أكّد الحجز أو اعتذر من بوابة المزوّد.`
        : `انلغى حجز ${who} ليوم ${day}. أصبح اليوم متاحًا في تقويمك.`,
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
  const copies: Record<typeof event, { title: string; body: AddressedText }> = {
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
      body: gendered(
        `${args.providerName} ألغى حجز يوم ${day}. تواصل معه أو اختر مزوّدًا آخر.`,
        `${args.providerName} ألغى حجز يوم ${day}. تواصلي معه أو اختاري مزوّدًا آخر.`,
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

// ── Reminders before a confirmed booking (V1 checklist 4.17) ───────────

const DAY_MS = 24 * 60 * 60 * 1000;

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
  return Math.round((eventDate.getTime() - today.getTime()) / DAY_MS);
}

function whenLabel(daysUntil: number): string {
  if (daysUntil === 1) return "غدًا";
  if (daysUntil === 2) return "بعد يومين";
  return `بعد ${daysUntil} أيام`;
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
  const day = formatDay(args.eventDate);
  const when = whenLabel(daysUntil);
  const priority =
    daysUntil <= 1 ? NotificationPriority.HIGH : NotificationPriority.NORMAL;
  const data = {
    bookingId: args.bookingId,
    quoteRequestId: args.quoteRequestId,
    providerId: args.providerId,
    daysUntil,
  };
  const key = (userId: string) =>
    `${userId}:booking:${args.bookingId}:REMINDER:${milestone}:${day}`;
  const reminders: CreateNotificationInput[] = [
    {
      userId: args.customerUserId,
      weddingPlanId: args.weddingPlanId,
      type: NotificationType.BOOKING_UPDATED,
      priority,
      title: "تذكير بحجز",
      body: gendered(
        `حجزك مع ${args.providerName} ${when} (${day}). تواصل معه لتأكيد التفاصيل.`,
        `حجزك مع ${args.providerName} ${when} (${day}). تواصلي معه لتأكيد التفاصيل.`,
      ),
      entityType: "booking",
      entityId: args.bookingId,
      routeTarget: requesterQuoteRoute(args.quoteRequestId),
      data: {
        ...data,
        weddingPlanId: args.weddingPlanId,
        recipientAudience: "CUSTOMER",
      },
      dedupeKey: key(args.customerUserId),
    },
  ];
  if (args.providerUserId) {
    const who = args.customerName?.trim() || "العميل";
    reminders.push({
      userId: args.providerUserId,
      type: NotificationType.BOOKING_UPDATED,
      priority,
      title: "تذكير بحجز",
      body: `عندك حجز مع ${who} ${when} (${day}).`,
      entityType: "booking",
      entityId: args.bookingId,
      routeTarget: PROVIDER_PORTAL_ROUTE,
      data: { ...data, recipientAudience: "PROVIDER" },
      dedupeKey: key(args.providerUserId),
    });
  }
  return reminders;
}
