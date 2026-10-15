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

/** Is the provider already confirmed on that day by another booking? */
export async function hasConfirmedBookingOn(
  tx: Tx,
  providerId: string,
  day: Date,
  exceptBookingId?: string,
): Promise<boolean> {
  const count = await tx.booking.count({
    where: {
      providerId,
      eventDate: day,
      status: BookingStatus.CONFIRMED,
      ...(exceptBookingId ? { id: { not: exceptBookingId } } : {}),
    },
  });
  return count > 0;
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
    include: { quoteRequest: { select: bookingQuoteSelect } },
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
