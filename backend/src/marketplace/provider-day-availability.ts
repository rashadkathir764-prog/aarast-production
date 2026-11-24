import { ConflictException } from "@nestjs/common";
import type { Prisma } from "@prisma/client";
import * as bookings from "../modules/marketplace/infrastructure/marketplace-booking.repository";
import { bookingDay, bookingDayFull, bookingToday } from "./booking-policy";

type Tx = Prisma.TransactionClient;

/** Why a provider takes nothing on a day: he closed it, or it is full (B-20). */
export type ProviderDayUnavailable = "CLOSED" | "FULL";

/**
 * RA-BE-150 (Q-36): the one reading of «is this provider free that day».
 * The caller holds the provider's row lock, so the count and the write it
 * guards cannot interleave with another decision for him. Every confirmed
 * booking counts toward the day's seats whoever asked (RA-BE-154); the
 * seats are per day.
 */
export async function providerDayUnavailable(
  tx: Tx,
  providerId: string,
  day: Date,
  exceptBookingId?: string,
): Promise<ProviderDayUnavailable | null> {
  if (await bookings.isProviderDateBlocked(tx, providerId, day)) return "CLOSED";
  const [taken, capacity] = await Promise.all([
    bookings.countConfirmedBookingsOn(tx, providerId, day, exceptBookingId),
    bookings.findProviderDailyCapacity(tx, providerId),
  ]);
  return bookingDayFull(taken, capacity) ? "FULL" : null;
}

/**
 * The day a request names, when it can still be booked (a day that has
 * passed is no booking's day, and a request without a day asks nothing of
 * the calendar).
 */
export function requestedBookableDay(
  eventDate: Date | null | undefined,
  now: Date = new Date(),
): Date | null {
  if (!eventDate) return null;
  const day = bookingDay(eventDate);
  return day.getTime() < bookingToday(now).getTime() ? null : day;
}

/** RA-BE-150: the refusal before anyone commits to a day the provider cannot take. */
export function providerDayUnavailableError(message: string) {
  return new ConflictException({
    statusCode: 409,
    code: "PROVIDER_DAY_UNAVAILABLE",
    message,
  });
}
