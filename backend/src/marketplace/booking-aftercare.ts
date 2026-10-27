import { BookingStatus } from "@prisma/client";
import { bookingDay, bookingToday } from "./booking-policy";

// G25 (owner-vision audit 2026-10-27): what follows a confirmed booking.
// B-22: from the day to seven days after, the provider says «تم» or «ما
// صار» (why); two days after the day without a word, it completes by
// itself. B-23: an offer's delivery days set the delivery due day; the
// provider delivers (a link, a note), the customer confirms. B-24: before
// the day, the customer moves it; the provider accepts or declines.

const DAY_MS = 24 * 60 * 60 * 1000;

/** B-22: how long after the day the provider may still say what happened. */
export const BOOKING_OUTCOME_WINDOW_DAYS = 7;
/** B-22: days after the day a booking with no word completes by itself. */
export const BOOKING_AUTO_COMPLETE_DAYS = 2;

export const BOOKING_NOT_HAPPENED_REASONS = [
  "CUSTOMER_NO_SHOW",
  "WE_DID_NOT_ATTEND",
  "FORCE_MAJEURE",
  "OFFICIAL_DECISION",
] as const;
export type BookingNotHappenedReason = (typeof BOOKING_NOT_HAPPENED_REASONS)[number];

export type AftercareViolation =
  | "NOT_CONFIRMED"
  | "TOO_EARLY"
  | "TOO_LATE"
  | "ALREADY_DECIDED"
  | "NOT_COMPLETED"
  | "ALREADY_DELIVERED"
  | "NOT_DELIVERED"
  | "ALREADY_CONFIRMED"
  | "DAY_PASSED"
  | "SAME_DAY"
  | "CHANGE_PENDING";

interface OutcomeState {
  status: BookingStatus;
  eventDate: Date;
  completedAt: Date | null;
  notHappenedAt: Date | null;
}

function addDays(day: Date, days: number): Date {
  return new Date(bookingDay(day).getTime() + days * DAY_MS);
}

/** B-22: «تم» or «ما صار», by the provider, from the day to a week after. */
export function outcomeViolation(
  booking: OutcomeState,
  now: Date = new Date(),
): AftercareViolation | null {
  if (booking.status !== BookingStatus.CONFIRMED) return "NOT_CONFIRMED";
  if (booking.completedAt || booking.notHappenedAt) return "ALREADY_DECIDED";
  const today = bookingToday(now).getTime();
  if (today < bookingDay(booking.eventDate).getTime()) return "TOO_EARLY";
  if (today > addDays(booking.eventDate, BOOKING_OUTCOME_WINDOW_DAYS).getTime()) {
    return "TOO_LATE";
  }
  return null;
}

/** B-22: the last day a confirmed booking with no word stays undecided. */
export function autoCompleteBefore(now: Date = new Date()): Date {
  return new Date(bookingToday(now).getTime() - BOOKING_AUTO_COMPLETE_DAYS * DAY_MS);
}

/** B-23: the delivery due day from the accepted offer's days; null without. */
export function deliveryDueAt(eventDate: Date, deliveryDays: number | null | undefined): Date | null {
  return deliveryDays == null ? null : addDays(eventDate, deliveryDays);
}

/** B-23: the provider delivers a completed booking once. */
export function deliveryViolation(booking: OutcomeState & { deliveredAt: Date | null }) {
  if (booking.status !== BookingStatus.CONFIRMED || !booking.completedAt) {
    return "NOT_COMPLETED" as const;
  }
  return booking.deliveredAt ? ("ALREADY_DELIVERED" as const) : null;
}

/** B-23: the customer confirms a delivery once. */
export function deliveryConfirmViolation(booking: {
  deliveredAt: Date | null;
  deliveryConfirmedAt: Date | null;
}) {
  if (!booking.deliveredAt) return "NOT_DELIVERED" as const;
  return booking.deliveryConfirmedAt ? ("ALREADY_CONFIRMED" as const) : null;
}

/** B-24: the customer moves a confirmed booking before its day, one change at a time. */
export function changeViolation(
  booking: { status: BookingStatus; eventDate: Date },
  toDay: Date,
  hasPendingChange: boolean,
  now: Date = new Date(),
): AftercareViolation | null {
  if (booking.status !== BookingStatus.CONFIRMED) return "NOT_CONFIRMED";
  const today = bookingToday(now).getTime();
  if (bookingDay(booking.eventDate).getTime() < today) return "DAY_PASSED";
  if (bookingDay(toDay).getTime() === bookingDay(booking.eventDate).getTime()) {
    return "SAME_DAY";
  }
  return hasPendingChange ? "CHANGE_PENDING" : null;
}

/** What the customer and the provider read of a booking's outcome. */
export type BookingOutcome = "PENDING" | "COMPLETED" | "NOT_HAPPENED";

export function bookingOutcome(booking: {
  completedAt: Date | null;
  notHappenedAt: Date | null;
}): BookingOutcome {
  if (booking.notHappenedAt) return "NOT_HAPPENED";
  return booking.completedAt ? "COMPLETED" : "PENDING";
}
