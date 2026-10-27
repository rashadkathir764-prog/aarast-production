import { BookingParty, BookingStatus } from "@prisma/client";

// Bookings without payment (V1 checklist 4.6): after a customer accepts a
// provider's offer they ask the provider to reserve the wedding date; the
// provider confirms or declines; either side may cancel. Nothing here moves
// or holds money. Pure rules only, so the service stays orchestration.

/** What the customer and the provider see; COMPLETED is a confirmed booking whose day has passed. */
export type BookingLifecycle =
  | "REQUESTED"
  | "CONFIRMED"
  | "COMPLETED"
  | "NOT_HAPPENED"
  | "DECLINED"
  | "CANCELLED"
  | "EXPIRED";

export type BookingAction = "CONFIRM" | "DECLINE" | "CANCEL";

export type BookingViolation =
  | "INVALID_DATE"
  | "DATE_IN_PAST"
  | "NOT_ALLOWED_IN_STATUS";

/** A calendar day as stored (`@db.Date`): midnight UTC of that day. */
export function bookingDay(value: Date): Date {
  return new Date(
    Date.UTC(value.getUTCFullYear(), value.getUTCMonth(), value.getUTCDate()),
  );
}

/** Today's calendar day in Yemen (UTC+3), the day every booking date is compared with. */
export function bookingToday(now: Date = new Date()): Date {
  return bookingDay(new Date(now.getTime() + 3 * 60 * 60 * 1000));
}

/**
 * Parses a `YYYY-MM-DD` (or ISO) date the customer asked for, falling back to
 * the date on the quote request. A booking needs a day that has not passed.
 */
export function parseBookingDate(
  requested: string | null | undefined,
  quoteEventDate: Date | null,
  now: Date = new Date(),
): Date | BookingViolation {
  let day: Date | null = null;
  if (requested != null && requested.trim() !== "") {
    const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(requested.trim());
    if (!match) return "INVALID_DATE";
    const [year, month, date] = [Number(match[1]), Number(match[2]), Number(match[3])];
    day = new Date(Date.UTC(year, month - 1, date));
    if (
      day.getUTCFullYear() !== year ||
      day.getUTCMonth() !== month - 1 ||
      day.getUTCDate() !== date
    ) {
      return "INVALID_DATE";
    }
  } else if (quoteEventDate) {
    day = bookingDay(quoteEventDate);
  }
  if (!day) return "INVALID_DATE";
  if (day.getTime() < bookingToday(now).getTime()) return "DATE_IN_PAST";
  return day;
}

/**
 * Who may do what: the provider confirms or declines a request; either side
 * cancels a request or a confirmed booking before its day. A declined or
 * cancelled booking is final (the customer may ask again, which reopens it).
 */
export function bookingActionViolation(
  status: BookingStatus,
  action: BookingAction,
  actor: BookingParty,
  eventDate: Date,
  now: Date = new Date(),
): BookingViolation | null {
  const dayPassed = eventDate.getTime() < bookingToday(now).getTime();
  switch (action) {
    case "CONFIRM":
    case "DECLINE":
      return actor === BookingParty.PROVIDER &&
        status === BookingStatus.REQUESTED &&
        !dayPassed
        ? null
        : "NOT_ALLOWED_IN_STATUS";
    case "CANCEL":
      return (status === BookingStatus.REQUESTED ||
        status === BookingStatus.CONFIRMED) &&
        !dayPassed
        ? null
        : "NOT_ALLOWED_IN_STATUS";
  }
}

/**
 * A customer may ask (again) unless the booking is already open; a request
 * that expired with its provider's suspension (B-42) may be asked again once
 * he is back.
 */
export function canRequestBooking(existing: BookingStatus | null): boolean {
  return (
    existing === null ||
    existing === BookingStatus.DECLINED ||
    existing === BookingStatus.CANCELLED ||
    existing === BookingStatus.EXPIRED
  );
}

/**
 * B-20: a day takes `capacity` confirmed bookings. `taken` counts the
 * others confirmed that day; a capacity lowered below them keeps them and
 * refuses the next.
 */
export function bookingDayFull(taken: number, capacity: number): boolean {
  return taken >= capacity;
}

/** B-20: the provider's capacity, 1 to 20 confirmed bookings a day. */
export const DAILY_BOOKING_CAPACITY_MIN = 1;
export const DAILY_BOOKING_CAPACITY_MAX = 20;

export function bookingLifecycle(
  status: BookingStatus,
  eventDate: Date,
  now: Date = new Date(),
  /** B-22: the provider reported «ما صار». */
  notHappenedAt: Date | null = null,
): BookingLifecycle {
  if (status === BookingStatus.CONFIRMED && notHappenedAt) return "NOT_HAPPENED";
  if (
    status === BookingStatus.CONFIRMED &&
    eventDate.getTime() < bookingToday(now).getTime()
  ) {
    return "COMPLETED";
  }
  return status;
}

export interface BookingRow {
  id: string;
  quoteRequestId: string;
  quoteOfferId: string | null;
  providerId: string;
  eventDate: Date;
  status: BookingStatus;
  cancelledBy: BookingParty | null;
  note: string | null;
  confirmedAt: Date | null;
  declinedAt: Date | null;
  cancelledAt: Date | null;
  expiredAt?: Date | null;
  completedAt?: Date | null;
  notHappenedAt?: Date | null;
  notHappenedReason?: string | null;
  deliveryDueAt?: Date | null;
  deliveredAt?: Date | null;
  deliveryLink?: string | null;
  deliveryNote?: string | null;
  deliveryConfirmedAt?: Date | null;
  changes?: Array<{
    id: string;
    fromDate: Date;
    toDate: Date;
    status: string;
    note: string | null;
    declineReason: string | null;
    createdAt: Date;
    decidedAt: Date | null;
  }>;
  createdAt: Date;
  updatedAt: Date;
}

export function toBookingResponse(booking: BookingRow, now: Date = new Date()) {
  return {
    id: booking.id,
    quoteRequestId: booking.quoteRequestId,
    quoteOfferId: booking.quoteOfferId,
    providerId: booking.providerId,
    eventDate: booking.eventDate.toISOString().slice(0, 10),
    status: booking.status,
    lifecycleStatus: bookingLifecycle(
      booking.status,
      booking.eventDate,
      now,
      booking.notHappenedAt ?? null,
    ),
    cancelledBy: booking.cancelledBy,
    note: booking.note,
    confirmedAt: booking.confirmedAt,
    declinedAt: booking.declinedAt,
    cancelledAt: booking.cancelledAt,
    expiredAt: booking.expiredAt ?? null,
    // G25: B-22 the outcome, B-23 the delivery, B-24 the last change asked.
    completedAt: booking.completedAt ?? null,
    notHappenedAt: booking.notHappenedAt ?? null,
    notHappenedReason: booking.notHappenedReason ?? null,
    deliveryDueAt: booking.deliveryDueAt ?? null,
    deliveredAt: booking.deliveredAt ?? null,
    deliveryLink: booking.deliveryLink ?? null,
    deliveryNote: booking.deliveryNote ?? null,
    deliveryConfirmedAt: booking.deliveryConfirmedAt ?? null,
    change: lastChange(booking.changes),
    createdAt: booking.createdAt,
    updatedAt: booking.updatedAt,
  };
}

export type BookingResponse = ReturnType<typeof toBookingResponse>;

function lastChange(changes: BookingRow["changes"]) {
  if (!changes || changes.length === 0) return null;
  const last = [...changes].sort(
    (a, b) => b.createdAt.getTime() - a.createdAt.getTime(),
  )[0];
  return {
    id: last.id,
    fromDate: last.fromDate.toISOString().slice(0, 10),
    toDate: last.toDate.toISOString().slice(0, 10),
    status: last.status,
    note: last.note,
    declineReason: last.declineReason,
    createdAt: last.createdAt,
    decidedAt: last.decidedAt,
  };
}
