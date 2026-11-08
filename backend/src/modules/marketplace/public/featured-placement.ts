/**
 * B-43 (D41): featured placement. The provider pays outside the app;
 * an administrator records a period; while a period covers now the provider
 * is ranked first in the customers' list and carries «مميز». Everything is
 * read at request time from the periods, so a placement lapses at its end
 * with no job; the hourly job only tells the provider.
 */

import { ProviderStatus } from '@prisma/client';
import { dayMonthWords } from '../../../shared-kernel/voice/day-words';

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

/** «31 ديسمبر» for a `YYYY-MM-DD` day, as every notice writes a day (B-38). */
export function arabicDayLabel(day: string): string {
  return dayMonthWords(day);
}

/** The instant after the last covered day (`YYYY-MM-DD`) ends. */
export function featuredEndAfter(lastDay: string): Date | null {
  const start = yemenDayStart(lastDay);
  return start ? new Date(start.getTime() + DAY_MS) : null;
}

/**
 * The providers customers find in the list: approved, and offering at least
 * one active service (a profile with no service showed an empty card, field
 * test Q14), and not leaving: an owner waiting out the account's deletion
 * answers no new request (RA-BE-26, D63).
 */
export function listedProviderConditions() {
  return [
    { status: ProviderStatus.ACTIVE },
    { services: { some: { isActive: true } } },
    { ownerLeavingAt: null },
  ] as const;
}

/**
 * The one rule of where a placement shows (B-43): on a listed provider whose
 * owner claimed the listing (an unclaimed listing takes no requests, D41).
 * Recording a placement, a17's state and counts, the provider's notices, the
 * customers' ranking and every featured counter read it; a period on any
 * other provider ranks and counts nothing.
 */
export function featuredShowsWhere() {
  return { AND: [...listedProviderConditions(), { userId: { not: null } }] };
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

/**
 * Added to a search that is already limited to listed providers: claimed,
 * with a period covering `now` (featured), or not.
 */
export function featuredNowConditions(now: Date) {
  return [
    { userId: { not: null } },
    { featuredPeriods: { some: activeFeaturedPeriodWhere(now) } },
  ] as const;
}

export function notFeaturedNowCondition(now: Date) {
  return {
    OR: [{ userId: null }, { featuredPeriods: { none: activeFeaturedPeriodWhere(now) } }],
  };
}

/** The providers featured at `now`: the rule above, and a period covering now. */
export function featuredNowProviderWhere(now: Date) {
  return { AND: [...listedProviderConditions(), ...featuredNowConditions(now)] };
}

/** The database refused a period overlapping another (`ProviderFeaturedPeriod_no_overlap`). */
export function isFeaturedOverlapViolation(error: unknown): boolean {
  const message = error instanceof Error ? error.message : String(error);
  return message.includes('ProviderFeaturedPeriod_no_overlap') || message.includes('23P01');
}

/** A period nobody ended, as the run below reads it. */
export interface OpenFeaturedPeriod {
  id: string;
  startsAt: Date;
  endsAt: Date;
}

/**
 * The run of one provider's back-to-back periods (a renewal starts when the
 * one before it ends) that `id` belongs to: when it began and when it really
 * ends. Null when `id` is not among `periods`. Periods never overlap.
 */
export function featuredRunAround(
  periods: readonly OpenFeaturedPeriod[],
  id: string,
): { startsAt: Date; endsAt: Date } | null {
  const sorted = [...periods].sort(
    (left, right) => left.startsAt.getTime() - right.startsAt.getTime() || left.id.localeCompare(right.id),
  );
  let run: { startsAt: Date; endsAt: Date; ids: string[] } | null = null;
  const runs: Array<{ startsAt: Date; endsAt: Date; ids: string[] }> = [];
  for (const period of sorted) {
    if (run && period.startsAt.getTime() <= run.endsAt.getTime()) {
      if (period.endsAt.getTime() > run.endsAt.getTime()) run.endsAt = period.endsAt;
      run.ids.push(period.id);
    } else {
      run = { startsAt: period.startsAt, endsAt: period.endsAt, ids: [period.id] };
      runs.push(run);
    }
  }
  const found = runs.find((candidate) => candidate.ids.includes(id));
  return found ? { startsAt: found.startsAt, endsAt: found.endsAt } : null;
}

/**
 * «ينتهي قريب» is said only of a run longer than the week it warns about: a
 * short placement is not warned about minutes after it starts.
 */
export function featuredRunWarnsBeforeEnd(run: { startsAt: Date; endsAt: Date }): boolean {
  return run.endsAt.getTime() - run.startsAt.getTime() > FEATURED_ENDING_NOTICE_DAYS * DAY_MS;
}

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
