/**
 * B-43 (D41): featured placement. The provider pays outside the app;
 * an administrator records a period; while a period covers now the provider
 * is ranked first in the customers' list and carries «مميز». Everything is
 * read at request time from the periods, so a placement lapses at its end
 * with no job; the hourly job only tells the provider.
 */

/** The provider is told this many days before the placement ends. */
export const FEATURED_ENDING_NOTICE_DAYS = 7;

/** The longest period one activation may cover. */
export const FEATURED_PERIOD_MAX_DAYS = 366;

const DAY_MS = 24 * 60 * 60 * 1000;
// Placements are bought by the day in Yemen (UTC+3, no daylight saving).
const YEMEN_OFFSET_MS = 3 * 60 * 60 * 1000;

/** The instant a Yemen calendar day (`YYYY-MM-DD`) starts; null when it is not a real day. */
export function yemenDayStart(day: string): Date | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) return null;
  const start = new Date(`${day}T00:00:00.000Z`);
  if (Number.isNaN(start.getTime()) || start.toISOString().slice(0, 10) !== day) return null;
  return new Date(start.getTime() - YEMEN_OFFSET_MS);
}

/** The Yemen calendar day (`YYYY-MM-DD`) an instant falls on. */
export function yemenDayOf(instant: Date): string {
  return new Date(instant.getTime() + YEMEN_OFFSET_MS).toISOString().slice(0, 10);
}

/** The last day a period covers: `endsAt` is the start of the day after it. */
export function featuredLastDay(endsAt: Date): string {
  return yemenDayOf(new Date(endsAt.getTime() - 1));
}

const ARABIC_MONTHS = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/** «31 ديسمبر» for a `YYYY-MM-DD` day, as the provider's notices write it. */
export function arabicDayLabel(day: string): string {
  const [, month, date] = day.split('-').map(Number);
  return `${date} ${ARABIC_MONTHS[month! - 1]}`;
}

/** The instant after the last covered day (`YYYY-MM-DD`) ends. */
export function featuredEndAfter(lastDay: string): Date | null {
  const start = yemenDayStart(lastDay);
  return start ? new Date(start.getTime() + DAY_MS) : null;
}

/** A period that covers `now` and was not ended by an administrator. */
export function activeFeaturedPeriodWhere(now: Date) {
  return {
    startsAt: { lte: now },
    endsAt: { gt: now },
    endedAt: null,
  };
}

export type ActiveFeaturedPeriodWhere = ReturnType<typeof activeFeaturedPeriodWhere>;

/** The provider's active period (at most one: periods never overlap). */
export function activeFeaturedPeriodInclude(now: Date) {
  return {
    where: activeFeaturedPeriodWhere(now),
    select: { startsAt: true, endsAt: true },
    take: 1,
  };
}

/** What `activeFeaturedPeriodInclude` reads. */
export interface FeaturedWindow {
  startsAt: Date;
  endsAt: Date;
}

/** Until when the provider is featured, or null when it is not featured now. */
export function featuredUntil(periods: readonly FeaturedWindow[] | undefined): Date | null {
  return periods?.[0]?.endsAt ?? null;
}

export type FeaturedPeriodState = 'ACTIVE' | 'SCHEDULED' | 'EXPIRED' | 'ENDED';

/**
 * ACTIVE covers now; SCHEDULED starts later; EXPIRED reached its end; ENDED
 * was ended (or cancelled before it started) by an administrator.
 */
export function featuredPeriodState(
  period: { startsAt: Date; endsAt: Date; endedAt: Date | null },
  now: Date,
): FeaturedPeriodState {
  if (period.endedAt !== null) return 'ENDED';
  if (period.endsAt.getTime() <= now.getTime()) return 'EXPIRED';
  if (period.startsAt.getTime() > now.getTime()) return 'SCHEDULED';
  return 'ACTIVE';
}
