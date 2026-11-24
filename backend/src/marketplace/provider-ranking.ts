import type { ProviderResponsiveness } from "./provider-responsiveness";

// RA-BE-151 (Q-36): the customers' list order. The raw average buried new
// providers: one 5-star review beat 63 reviews averaging 4.8, and a listing
// nobody had claimed stood beside the real ones. Featured placement (B-43)
// stays first; below it the order is a score of four things, each kept in
// its own named weight so a change is one line.

/** A provider with no history reads as this many reviews of this average. */
export const RATING_PRIOR_REVIEWS = 5;
export const RATING_PRIOR_AVERAGE = 4;

export const RANK_WEIGHTS = {
  rating: 0.45,
  profile: 0.25,
  response: 0.2,
} as const;

/** A new provider is lifted by up to this much, falling to nothing at `NEWCOMER_DAYS`. */
export const NEWCOMER_LIFT = 0.1;
export const NEWCOMER_DAYS = 30;

const DAY_MS = 86_400_000;

export interface RankSignals {
  id: string;
  /** The owner claimed the listing; an unclaimed one takes no request (D41). */
  claimed: boolean;
  /** Featured now and shown by the placement rule (B-43). */
  featuredNow: boolean;
  createdAt: Date;
  ratingAverage: number;
  ratingCount: number;
  /** 0 to 1, from `profileCompleteness`. */
  profile: number;
  response: ProviderResponsiveness | null;
}

/** The average with a prior of a few middling reviews, so a thin record cannot top a long one. */
export function smoothedRating(average: number, count: number): number {
  const reviews = Math.max(0, count);
  return (
    (average * reviews + RATING_PRIOR_AVERAGE * RATING_PRIOR_REVIEWS) /
    (reviews + RATING_PRIOR_REVIEWS)
  );
}

/** What he shows a customer: a logo, a cover, a description, an address, a way to reach him. */
export function profileCompleteness(provider: {
  logoUrl: string | null;
  coverUrl: string | null;
  description: string | null;
  address: string | null;
  whatsapp: string | null;
  socialLinks: unknown;
}): number {
  const filled = (value: string | null) => (value?.trim().length ?? 0) > 0;
  const hasSocial =
    provider.socialLinks !== null &&
    typeof provider.socialLinks === "object" &&
    Object.keys(provider.socialLinks as object).length > 0;
  const shown = [
    filled(provider.logoUrl),
    filled(provider.coverUrl),
    filled(provider.description),
    filled(provider.address),
    filled(provider.whatsapp) || hasSocial,
  ];
  return shown.filter(Boolean).length / shown.length;
}

/** 0 to 1: how many requests he answers and how fast; middling when there is too little history. */
export function responseScore(response: ProviderResponsiveness | null): number {
  if (!response) return 0.5;
  const hours = response.typicalResponseHours;
  const speed =
    hours === null ? 0 : hours <= 1 ? 1 : hours <= 6 ? 0.8 : hours <= 24 ? 0.5 : 0.2;
  return 0.5 * (response.answeredPercent / 100) + 0.5 * speed;
}

export function newcomerLift(createdAt: Date, now: Date): number {
  const ageDays = (now.getTime() - createdAt.getTime()) / DAY_MS;
  if (ageDays < 0 || ageDays >= NEWCOMER_DAYS) return 0;
  return NEWCOMER_LIFT * (1 - ageDays / NEWCOMER_DAYS);
}

export function providerRankScore(signals: RankSignals, now: Date): number {
  return (
    RANK_WEIGHTS.rating * (smoothedRating(signals.ratingAverage, signals.ratingCount) / 5) +
    RANK_WEIGHTS.profile * signals.profile +
    RANK_WEIGHTS.response * responseScore(signals.response) +
    newcomerLift(signals.createdAt, now)
  );
}

/**
 * Featured first, then claimed listings, then unclaimed ones; inside each
 * group by score, then the newer, then the id (a total order).
 */
export function rankProviders<T extends RankSignals>(rows: readonly T[], now: Date): T[] {
  const group = (row: T) => (row.featuredNow ? 0 : row.claimed ? 1 : 2);
  const scored = rows.map((row) => ({ row, score: providerRankScore(row, now) }));
  scored.sort(
    (a, b) =>
      group(a.row) - group(b.row) ||
      b.score - a.score ||
      b.row.createdAt.getTime() - a.row.createdAt.getTime() ||
      (a.row.id < b.row.id ? -1 : a.row.id > b.row.id ? 1 : 0),
  );
  return scored.map(({ row }) => row);
}
