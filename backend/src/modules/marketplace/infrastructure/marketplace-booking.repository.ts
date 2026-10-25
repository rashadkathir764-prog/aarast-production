import { BookingParty, BookingStatus, Prisma } from '@prisma/client';

// Marketplace-owned booking and calendar rows (V1 checklist 4.6). Every read
// and write takes the caller's transaction so availability checks and the
// write they guard share one serializable snapshot.

type Tx = Prisma.TransactionClient;

const bookingQuoteSelect = {
  id: true,
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
    include: { quoteRequest: { select: bookingQuoteSelect } },
  });
}

export type BookingWithQuote = NonNullable<Awaited<ReturnType<typeof findBooking>>>;

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
  return tx.booking.findUniqueOrThrow({ where: { id } });
}

/** The provider's bookings that are still relevant: open requests and dates from today on. */
export function listProviderBookings(tx: Tx, providerId: string, today: Date) {
  return tx.booking.findMany({
    where: {
      providerId,
      OR: [
        { status: BookingStatus.REQUESTED },
        { status: BookingStatus.CONFIRMED, eventDate: { gte: today } },
      ],
    },
    include: {
      quoteRequest: { select: bookingQuoteSelect },
      quoteOffer: { select: { id: true, currency: true } },
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
