import assert from "node:assert/strict";
import { test } from "node:test";
import { BookingParty, BookingStatus } from "@prisma/client";
import {
  bookingActionViolation,
  bookingLifecycle,
  bookingToday,
  canRequestBooking,
  parseBookingDate,
} from "../src/marketplace/booking-policy";

// Bookings without payment (V1 checklist 4.6): the date rules and who may
// move a booking where.

const now = new Date("2026-10-15T09:00:00Z");
const day = (value: string) => new Date(`${value}T00:00:00Z`);

test("today is the Yemen calendar day", () => {
  assert.deepEqual(bookingToday(new Date("2026-10-15T22:30:00Z")), day("2026-10-16"));
  assert.deepEqual(bookingToday(new Date("2026-10-15T20:30:00Z")), day("2026-10-15"));
});

test("a booking day comes from the request or else the quote, never the past", () => {
  assert.deepEqual(parseBookingDate("2027-02-18", null, now), day("2027-02-18"));
  assert.deepEqual(
    parseBookingDate(undefined, new Date("2027-02-18T00:00:00Z"), now),
    day("2027-02-18"),
  );
  assert.deepEqual(parseBookingDate("2026-10-15", null, now), day("2026-10-15"));
  assert.equal(parseBookingDate("2026-10-14", null, now), "DATE_IN_PAST");
  assert.equal(parseBookingDate("2027-02-30", null, now), "INVALID_DATE");
  assert.equal(parseBookingDate("tomorrow", null, now), "INVALID_DATE");
  assert.equal(parseBookingDate(undefined, null, now), "INVALID_DATE");
});

test("only the provider confirms or declines, and only an open request", () => {
  const future = day("2027-02-18");
  assert.equal(
    bookingActionViolation(BookingStatus.REQUESTED, "CONFIRM", BookingParty.PROVIDER, future, now),
    null,
  );
  assert.equal(
    bookingActionViolation(BookingStatus.REQUESTED, "CONFIRM", BookingParty.CUSTOMER, future, now),
    "NOT_ALLOWED_IN_STATUS",
  );
  assert.equal(
    bookingActionViolation(BookingStatus.CONFIRMED, "DECLINE", BookingParty.PROVIDER, future, now),
    "NOT_ALLOWED_IN_STATUS",
  );
  assert.equal(
    bookingActionViolation(BookingStatus.REQUESTED, "CONFIRM", BookingParty.PROVIDER, day("2026-10-01"), now),
    "NOT_ALLOWED_IN_STATUS",
  );
});

test("either side cancels an open or confirmed booking before its day", () => {
  const future = day("2027-02-18");
  for (const actor of [BookingParty.CUSTOMER, BookingParty.PROVIDER]) {
    assert.equal(bookingActionViolation(BookingStatus.REQUESTED, "CANCEL", actor, future, now), null);
    assert.equal(bookingActionViolation(BookingStatus.CONFIRMED, "CANCEL", actor, future, now), null);
    assert.equal(
      bookingActionViolation(BookingStatus.DECLINED, "CANCEL", actor, future, now),
      "NOT_ALLOWED_IN_STATUS",
    );
    assert.equal(
      bookingActionViolation(BookingStatus.CONFIRMED, "CANCEL", actor, day("2026-10-01"), now),
      "NOT_ALLOWED_IN_STATUS",
    );
  }
});

test("a declined or cancelled booking can be asked again; an open one cannot", () => {
  assert.equal(canRequestBooking(null), true);
  assert.equal(canRequestBooking(BookingStatus.DECLINED), true);
  assert.equal(canRequestBooking(BookingStatus.CANCELLED), true);
  assert.equal(canRequestBooking(BookingStatus.REQUESTED), false);
  assert.equal(canRequestBooking(BookingStatus.CONFIRMED), false);
});

test("a confirmed booking whose day passed reads as completed", () => {
  assert.equal(bookingLifecycle(BookingStatus.CONFIRMED, day("2026-10-01"), now), "COMPLETED");
  assert.equal(bookingLifecycle(BookingStatus.CONFIRMED, day("2027-02-18"), now), "CONFIRMED");
  assert.equal(bookingLifecycle(BookingStatus.CANCELLED, day("2026-10-01"), now), "CANCELLED");
});
