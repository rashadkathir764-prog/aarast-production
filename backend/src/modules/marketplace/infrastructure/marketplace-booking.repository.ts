import { BookingParty, BookingStatus, Prisma } from '@prisma/client';
import { bookingDayFull } from '../../../marketplace/booking-policy';

// Marketplace-owned booking and calendar rows (V1 checklist 4.6). Every read
// and write takes the caller's transaction so availability checks and the
// write they guard share one serializable snapshot.

type Tx = Prisma.TransactionClient;

const bookingQuoteSelect = {
  id: true,
  conversationId: true,
  userId: true,
  weddingPlanId: true,
  providerId: true,
  serviceId: true,
  status: true,
  eventDate: true,
  contactName: true,
  guestCount: true,
  location: true,
} satisfies Prisma.QuoteRequestSelect;

/** The quote a booking hangs on, with its accepted offer and current booking. */
export function findQuoteForBooking(tx: Tx, quoteRequestId: string) {
  return tx.quoteRequest.findUnique({
    where: { id: quoteRequestId },
    select: {
      ...bookingQuoteSelect,
      offers: {
        where: { status: 'ACCEPTED' },
        select: { id: true },
        orderBy: { updatedAt: 'desc' },
        take: 1,
      },
      booking: true,
    },
  });
}

export function findBooking(tx: Tx, id: string) {
  return tx.booking.findUnique({
    where: { id },
    include: { quoteRequest: { select: bookingQuoteSelect }, changes: true },
  });
}

export type BookingWithQuote = NonNullable<Awaited<ReturnType<typeof findBooking>>>;

/**
 * Q-42 (أ): whether anything in the conversation is still alive: a request
 * waiting on an answer or an offer, or an accepted one whose booking was not
 * asked yet or is asked, confirmed and not yet over (no outcome said).
 */
export async function conversationHasLiveWork(tx: Tx, conversationId: string): Promise<boolean> {
  const live = await tx.quoteRequest.count({
    where: {
      conversationId,
      OR: [
        { status: { in: ['SENT', 'VIEWED', 'RESPONDED'] } },
        {
          status: 'ACCEPTED',
          OR: [
            { booking: null },
            {
              booking: {
                status: { in: [BookingStatus.REQUESTED, BookingStatus.CONFIRMED] },
                completedAt: null,
                notHappenedAt: null,
              },
            },
          ],
        },
      ],
    },
  });
  return live > 0;
}

/** How many other bookings the provider has confirmed on that day (B-20: the seats taken). */
export function countConfirmedBookingsOn(
  tx: Tx,
  providerId: string,
  day: Date,
  exceptBookingId?: string,
): Promise<number> {
  return tx.booking.count({
    where: {
      providerId,
      eventDate: day,
      status: BookingStatus.CONFIRMED,
      ...(exceptBookingId ? { id: { not: exceptBookingId } } : {}),
    },
  });
}

/** The provider's seats per day (B-20), read under his row lock. */
export async function findProviderDailyCapacity(tx: Tx, providerId: string): Promise<number> {
  const row = await tx.provider.findUnique({
    where: { id: providerId },
    select: { dailyBookingCapacity: true },
  });
  return row?.dailyBookingCapacity ?? 1;
}

/**
 * RA-BE-150 (Q-36): of these providers, the ones who take no booking on
 * `day`: he closed it, or he has confirmed as many weddings as he takes in a
 * day (B-20; every confirmed booking counts, whoever asked). Read in one go
 * for a list; the one-provider decisions use the same two rules under his lock.
 */
export async function listProvidersUnavailableOn(
  client: Tx,
  providerIds: readonly string[],
  day: Date,
): Promise<Set<string>> {
  return new Set((await listProvidersDayStatus(client, providerIds, day)).keys());
}

/**
 * D131: why each of [providerIds] takes nothing on [day], for those with a
 * reason: he closed it, or Aarast's confirmed bookings filled his daily
 * number. A provider missing from the map is not known to be free (his
 * bookings outside Aarast are not here), only not known to be busy.
 */
export async function listProvidersDayStatus(
  client: Tx,
  providerIds: readonly string[],
  day: Date,
): Promise<Map<string, "CLOSED" | "FULL">> {
  if (providerIds.length === 0) return new Map();
  const ids = [...providerIds];
  const [closed, confirmed, capacities] = await Promise.all([
    client.providerBlockedDate.findMany({
      where: { providerId: { in: ids }, date: day },
      select: { providerId: true },
    }),
    client.booking.groupBy({
      by: ['providerId'],
      where: { providerId: { in: ids }, eventDate: day, status: BookingStatus.CONFIRMED },
      _count: { _all: true },
    }),
    client.provider.findMany({
      where: { id: { in: ids } },
      select: { id: true, dailyBookingCapacity: true },
    }),
  ]);
  const status = new Map<string, "CLOSED" | "FULL">(
    closed.map((row) => [row.providerId, "CLOSED" as const]),
  );
  const taken = new Map(confirmed.map((row) => [row.providerId, row._count._all]));
  for (const row of capacities) {
    if (
      !status.has(row.id) &&
      bookingDayFull(taken.get(row.id) ?? 0, row.dailyBookingCapacity)
    ) {
      status.set(row.id, "FULL");
    }
  }
  return status;
}

/** Confirmed bookings per day from `today` on (p28 «باقي N»). */
export async function countConfirmedBookingsByDay(
  tx: Tx,
  providerId: string,
  today: Date,
): Promise<Map<string, number>> {
  const groups = await tx.booking.groupBy({
    by: ['eventDate'],
    where: { providerId, status: BookingStatus.CONFIRMED, eventDate: { gte: today } },
    _count: { _all: true },
  });
  return new Map(
    groups.map((group) => [group.eventDate.toISOString().slice(0, 10), group._count._all]),
  );
}

/** B-42: the open requests of a provider being suspended, with whom to tell. */
export function listOpenBookingRequests(tx: Tx, providerId: string) {
  return tx.booking.findMany({
    where: { providerId, status: BookingStatus.REQUESTED },
    include: { quoteRequest: { select: bookingQuoteSelect } },
    orderBy: [{ eventDate: 'asc' }, { id: 'asc' }],
  });
}

/** B-42: ends the provider's open requests; the confirmed bookings stay. */
export function expireOpenBookingRequests(
  tx: Tx,
  providerId: string,
  bookingIds: readonly string[],
  now: Date,
) {
  return tx.booking.updateMany({
    where: { providerId, status: BookingStatus.REQUESTED, id: { in: [...bookingIds] } },
    data: { status: BookingStatus.EXPIRED, expiredAt: now },
  });
}

/** The provider's confirmed bookings from `today` on, with whom to tell (B-42, B-33). */
export function listUpcomingConfirmedBookings(tx: Tx, providerId: string, today: Date) {
  return tx.booking.findMany({
    where: { providerId, status: BookingStatus.CONFIRMED, eventDate: { gte: today } },
    include: { quoteRequest: { select: bookingQuoteSelect } },
    orderBy: [{ eventDate: 'asc' }, { id: 'asc' }],
  });
}

/** Is any booking confirmed on that day (a day with a booking cannot be blocked)? */
export async function hasConfirmedBookingOn(
  tx: Tx,
  providerId: string,
  day: Date,
): Promise<boolean> {
  return (await countConfirmedBookingsOn(tx, providerId, day)) > 0;
}

export async function isProviderDateBlocked(
  tx: Tx,
  providerId: string,
  day: Date,
): Promise<boolean> {
  const row = await tx.providerBlockedDate.findUnique({
    where: { providerId_date: { providerId, date: day } },
    select: { id: true },
  });
  return row !== null;
}

/** Opens a booking request, or reopens a declined or cancelled one for a new day. */
export function upsertBookingRequest(
  tx: Tx,
  input: {
    quoteRequestId: string;
    quoteOfferId: string | null;
    providerId: string;
    eventDate: Date;
    requestedByUserId: string;
    note: string | null;
  },
) {
  // RA-BE-48: a booking asked again is the same row; it starts clean, with
  // nothing of the booking before it (its outcome, its delivery).
  const reopened = {
    quoteOfferId: input.quoteOfferId,
    eventDate: input.eventDate,
    status: BookingStatus.REQUESTED,
    requestedByUserId: input.requestedByUserId,
    note: input.note,
    cancelledBy: null,
    confirmedAt: null,
    declinedAt: null,
    cancelledAt: null,
    expiredAt: null,
    completedAt: null,
    notHappenedAt: null,
    notHappenedReason: null,
    deliveryDueAt: null,
    deliveredAt: null,
    deliveryLink: null,
    deliveryNote: null,
    deliveryConfirmedAt: null,
  };
  return tx.booking.upsert({
    where: { quoteRequestId: input.quoteRequestId },
    create: {
      quoteRequestId: input.quoteRequestId,
      providerId: input.providerId,
      ...reopened,
    },
    update: reopened,
  });
}

/** The columns a booking step may write, named exactly for the ownership scan. */
export interface BookingTransition {
  status: BookingStatus;
  confirmedAt?: Date;
  declinedAt?: Date;
  cancelledAt?: Date;
  cancelledBy?: BookingParty;
  note?: string | null;
}

/** Moves a booking only from the status the caller checked (compare-and-set). */
export function transitionBooking(
  tx: Tx,
  id: string,
  from: BookingStatus,
  data: BookingTransition,
) {
  return tx.booking.updateMany({ where: { id, status: from }, data });
}

export function requireBooking(tx: Tx, id: string) {
  return tx.booking.findUniqueOrThrow({ where: { id }, include: { changes: true } });
}

/** G25: B-22's outcome, B-23's delivery, set on a booking. */
export interface BookingAftercare {
  completedAt?: Date;
  notHappenedAt?: Date;
  notHappenedReason?: string;
  deliveryDueAt?: Date | null;
  deliveredAt?: Date;
  deliveryLink?: string | null;
  deliveryNote?: string | null;
  deliveryConfirmedAt?: Date;
  eventDate?: Date;
}

/** Writes the aftercare fields while the booking is still in `status`. */
export function updateBookingAftercare(
  tx: Tx,
  id: string,
  status: BookingStatus,
  data: BookingAftercare,
) {
  return tx.booking.updateMany({ where: { id, status }, data });
}

/** B-22: confirmed bookings two days past their day with no word. */
export function listBookingsToAutoComplete(tx: Tx, before: Date) {
  return tx.booking.findMany({
    where: {
      status: BookingStatus.CONFIRMED,
      eventDate: { lt: before },
      completedAt: null,
      notHappenedAt: null,
    },
    include: {
      quoteOffer: { select: { deliveryDays: true } },
      quoteRequest: { select: { conversationId: true } },
    },
    take: 500,
  });
}

/** B-22: completes a booking only while no word was said (compare-and-set). */
export function completeBookingIfUndecided(
  tx: Tx,
  id: string,
  data: { completedAt: Date; deliveryDueAt: Date | null },
) {
  return tx.booking.updateMany({
    where: { id, status: BookingStatus.CONFIRMED, completedAt: null, notHappenedAt: null },
    data,
  });
}

/** B-23: the accepted offer's delivery days. */
export async function findOfferDeliveryDays(tx: Tx, quoteOfferId: string | null) {
  if (!quoteOfferId) return null;
  const offer = await tx.quoteOffer.findUnique({
    where: { id: quoteOfferId },
    select: { deliveryDays: true },
  });
  return offer?.deliveryDays ?? null;
}

/** B-24: a booking's pending change, if any. */
export function findPendingBookingChange(tx: Tx, bookingId: string) {
  return tx.bookingChange.findFirst({ where: { bookingId, status: 'PENDING' } });
}

export function findBookingChange(tx: Tx, id: string) {
  return tx.bookingChange.findUnique({ where: { id } });
}

export function createBookingChange(
  tx: Tx,
  data: { bookingId: string; fromDate: Date; toDate: Date; requestedByUserId: string; note: string | null },
) {
  return tx.bookingChange.create({ data });
}

/**
 * RA-BE-48: a booking asked again starts with no change waiting. One left
 * from the booking before was accepted onto the new one and moved its day.
 */
export function cancelPendingBookingChanges(tx: Tx, bookingId: string, at: Date) {
  return tx.bookingChange.updateMany({
    where: { bookingId, status: 'PENDING' },
    data: { status: 'CANCELLED', decidedAt: at },
  });
}

/** Decides a change only while it is still pending (compare-and-set). */
export function decideBookingChange(
  tx: Tx,
  id: string,
  data: { status: 'ACCEPTED' | 'DECLINED' | 'CANCELLED'; declineReason?: string | null },
) {
  return tx.bookingChange.updateMany({
    where: { id, status: 'PENDING' },
    data: { ...data, decidedAt: new Date() },
  });
}

/** The provider's bookings that are still relevant: open requests and dates from today on. */
export function listProviderBookings(tx: Tx, providerId: string, today: Date) {
  return tx.booking.findMany({
    where: {
      providerId,
      OR: [
        { status: BookingStatus.REQUESTED },
        { status: BookingStatus.CONFIRMED, eventDate: { gte: today } },
        // G25: a past booking still waiting for «تم» or for its delivery.
        {
          status: BookingStatus.CONFIRMED,
          eventDate: { gte: new Date(today.getTime() - 90 * 24 * 60 * 60 * 1000) },
          OR: [
            { completedAt: null, notHappenedAt: null },
            { notHappenedAt: null, deliveryDueAt: { not: null }, deliveredAt: null },
          ],
        },
      ],
    },
    include: {
      quoteRequest: { select: bookingQuoteSelect },
      quoteOffer: { select: { id: true, currency: true } },
      changes: true,
    },
    orderBy: [{ eventDate: 'asc' }, { createdAt: 'asc' }],
  });
}

/** p47: the provider's confirmed bookings whose day falls in [from, until). */
export function listConfirmedBookingsInRange(
  tx: Tx,
  providerId: string,
  from: Date,
  until: Date,
) {
  return tx.booking.findMany({
    where: {
      providerId,
      status: BookingStatus.CONFIRMED,
      eventDate: { gte: from, lt: until },
    },
    include: {
      quoteRequest: { select: bookingQuoteSelect },
      quoteOffer: { select: { id: true, currency: true } },
    },
    orderBy: [{ eventDate: 'asc' }, { id: 'asc' }],
  });
}

/** A plan's open requests and upcoming confirmed bookings, with the provider's name (V1 checklist 4.13). */
export function listPlanBookings(tx: Tx, weddingPlanId: string, today: Date) {
  return tx.booking.findMany({
    where: {
      quoteRequest: { weddingPlanId },
      OR: [
        { status: BookingStatus.REQUESTED },
        { status: BookingStatus.CONFIRMED, eventDate: { gte: today } },
      ],
    },
    include: {
      quoteRequest: { select: bookingQuoteSelect },
      provider: { select: { businessName: true } },
    },
    orderBy: [{ eventDate: 'asc' }, { createdAt: 'asc' }],
  });
}

export function listBlockedDates(tx: Tx, providerId: string, today: Date) {
  return tx.providerBlockedDate.findMany({
    where: { providerId, date: { gte: today } },
    orderBy: { date: 'asc' },
  });
}

export function insertBlockedDate(tx: Tx, providerId: string, day: Date) {
  return tx.providerBlockedDate.upsert({
    where: { providerId_date: { providerId, date: day } },
    create: { providerId, date: day },
    update: {},
  });
}

export function deleteBlockedDate(tx: Tx, providerId: string, day: Date) {
  return tx.providerBlockedDate.deleteMany({ where: { providerId, date: day } });
}

/** A customer may review a provider only after a confirmed booking's day has passed (F10). */
export async function hasCompletedBookingWith(
  tx: Tx,
  userId: string,
  providerId: string,
  today: Date,
): Promise<boolean> {
  const quotes = await tx.quoteRequest.findMany({
    where: { userId, providerId },
    select: { id: true },
  });
  if (quotes.length === 0) return false;
  const count = await tx.booking.count({
    where: {
      providerId,
      status: BookingStatus.CONFIRMED,
      eventDate: { lt: today },
      // B-22: a wedding the provider reported «ما صار» is not reviewed,
      // unless the provider's reason is its own absence (RA-BE-46): «ما
      // حضرنا» closed the review of exactly that.
      OR: [
        { notHappenedAt: null },
        { notHappenedReason: 'WE_DID_NOT_ATTEND' },
      ],
      quoteRequestId: { in: quotes.map((quote) => quote.id) },
    },
  });
  return count > 0;
}

/** Confirmed bookings from `today` through `until`, with what their reminders name (V1 checklist 4.17). */
export function listConfirmedBookingsDue(tx: Tx, today: Date, until: Date) {
  return tx.booking.findMany({
    where: {
      status: BookingStatus.CONFIRMED,
      eventDate: { gte: today, lte: until },
    },
    include: {
      quoteRequest: { select: bookingQuoteSelect },
      provider: { select: { userId: true, businessName: true } },
    },
    orderBy: [{ eventDate: 'asc' }, { id: 'asc' }],
  });
}
