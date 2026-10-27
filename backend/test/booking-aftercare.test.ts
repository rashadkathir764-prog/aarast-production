import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  autoCompleteBefore,
  bookingOutcome,
  changeViolation,
  deliveryConfirmViolation,
  deliveryDueAt,
  deliveryViolation,
  outcomeViolation,
} from '../src/marketplace/booking-aftercare';
import { bookingLifecycle, toBookingResponse } from '../src/marketplace/booking-policy';
import {
  bookingAftercareCustomerNotification,
  bookingAftercareProviderNotification,
} from '../src/marketplace/booking-notifications';

// G25 (owner-vision audit 2026-10-27): B-22, B-23, B-24.

const day = (iso: string) => new Date(`${iso}T00:00:00.000Z`);
// Noon in Sana'a on 2026-11-10.
const now = new Date('2026-11-10T09:00:00.000Z');
const confirmed = (eventDate: string) => ({
  status: 'CONFIRMED' as const,
  eventDate: day(eventDate),
  completedAt: null,
  notHappenedAt: null,
});

test('B-22: «تم» or «ما صار» from the day to a week after, once', () => {
  assert.equal(outcomeViolation(confirmed('2026-11-11'), now), 'TOO_EARLY');
  assert.equal(outcomeViolation(confirmed('2026-11-10'), now), null);
  assert.equal(outcomeViolation(confirmed('2026-11-03'), now), null);
  assert.equal(outcomeViolation(confirmed('2026-11-02'), now), 'TOO_LATE');
  assert.equal(
    outcomeViolation({ ...confirmed('2026-11-08'), completedAt: now }, now),
    'ALREADY_DECIDED',
  );
  assert.equal(
    outcomeViolation({ ...confirmed('2026-11-08'), status: 'CANCELLED' as const }, now),
    'NOT_CONFIRMED',
  );
  // Two days after the day with no word, it completes by itself.
  assert.deepEqual(autoCompleteBefore(now), day('2026-11-08'));
  assert.equal(bookingOutcome({ completedAt: null, notHappenedAt: now }), 'NOT_HAPPENED');
  assert.equal(
    bookingLifecycle('CONFIRMED', day('2026-11-08'), now, now),
    'NOT_HAPPENED',
  );
  assert.equal(bookingLifecycle('CONFIRMED', day('2026-11-08'), now, null), 'COMPLETED');
});

test('B-23: the offer\'s days set the due day; delivery and its confirmation once each', () => {
  assert.deepEqual(deliveryDueAt(day('2026-11-10'), 30), day('2026-12-10'));
  assert.equal(deliveryDueAt(day('2026-11-10'), null), null);
  const done = { ...confirmed('2026-11-08'), completedAt: now, deliveredAt: null };
  assert.equal(deliveryViolation({ ...done, completedAt: null }), 'NOT_COMPLETED');
  assert.equal(deliveryViolation(done), null);
  assert.equal(deliveryViolation({ ...done, deliveredAt: now }), 'ALREADY_DELIVERED');
  assert.equal(
    deliveryConfirmViolation({ deliveredAt: null, deliveryConfirmedAt: null }),
    'NOT_DELIVERED',
  );
  assert.equal(deliveryConfirmViolation({ deliveredAt: now, deliveryConfirmedAt: null }), null);
  assert.equal(
    deliveryConfirmViolation({ deliveredAt: now, deliveryConfirmedAt: now }),
    'ALREADY_CONFIRMED',
  );
});

test('B-24: a confirmed booking moves before its day, one change at a time', () => {
  const booking = { status: 'CONFIRMED' as const, eventDate: day('2026-12-01') };
  assert.equal(changeViolation(booking, day('2026-12-15'), false, now), null);
  assert.equal(changeViolation(booking, day('2026-12-01'), false, now), 'SAME_DAY');
  assert.equal(changeViolation(booking, day('2026-12-15'), true, now), 'CHANGE_PENDING');
  assert.equal(
    changeViolation({ ...booking, eventDate: day('2026-11-01') }, day('2026-12-15'), false, now),
    'DAY_PASSED',
  );
  assert.equal(
    changeViolation({ ...booking, status: 'REQUESTED' as const }, day('2026-12-15'), false, now),
    'NOT_CONFIRMED',
  );
});

test('the booking response carries the outcome, the delivery and the last change', () => {
  const response = toBookingResponse(
    {
      id: 'b1',
      quoteRequestId: 'q1',
      quoteOfferId: 'o1',
      providerId: 'p1',
      eventDate: day('2026-12-01'),
      status: 'CONFIRMED',
      cancelledBy: null,
      note: null,
      confirmedAt: now,
      declinedAt: null,
      cancelledAt: null,
      deliveryDueAt: day('2026-12-31'),
      changes: [
        {
          id: 'c1',
          fromDate: day('2026-11-20'),
          toDate: day('2026-12-01'),
          status: 'ACCEPTED',
          note: null,
          declineReason: null,
          createdAt: new Date('2026-11-01T00:00:00Z'),
          decidedAt: now,
        },
        {
          id: 'c2',
          fromDate: day('2026-12-01'),
          toDate: day('2026-12-20'),
          status: 'PENDING',
          note: 'أجّلنا',
          declineReason: null,
          createdAt: new Date('2026-11-09T00:00:00Z'),
          decidedAt: null,
        },
      ],
      createdAt: now,
      updatedAt: now,
    },
    now,
  );
  assert.equal(response.change?.id, 'c2');
  assert.equal(response.change?.toDate, '2026-12-20');
  assert.deepEqual(response.deliveryDueAt, day('2026-12-31'));
  assert.equal(response.notHappenedAt, null);
});

test('each side reads the aftercare in its words, no raw number', () => {
  const base = {
    bookingId: 'b1',
    quoteRequestId: 'q1',
    providerId: 'p1',
    eventDate: day('2026-12-01'),
    revision: 1,
  };
  const completed = bookingAftercareCustomerNotification('COMPLETED', {
    ...base,
    customerUserId: 'u1',
    weddingPlanId: 'w1',
    providerName: 'استوديو الفن',
  });
  assert.match(String(completed.title), /استوديو الفن/);
  const moved = bookingAftercareProviderNotification('CHANGE_REQUESTED', {
    ...base,
    providerUserId: 'pu',
    customerName: 'محمد الحمدي',
    toDate: day('2026-12-20'),
  });
  assert.equal(String(moved.title), 'محمد غيّر موعد العرس');
  assert.doesNotMatch(String(moved.body), /\d{4}-\d{2}/);
});
