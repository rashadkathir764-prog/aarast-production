// What a provider sees of their own reach (V1 checklist 4.19): page views,
// quote requests and how many of their decided offers customers accepted,
// over the last 30 days, plus their bookings. Pure rules only.

export const PROVIDER_STATS_WINDOW_DAYS = 30;

const DAY_MS = 24 * 60 * 60 * 1000;

/** The first calendar day of the window that ends on `today` (inclusive). */
export function providerStatsWindowStart(today: Date): Date {
  return new Date(today.getTime() - (PROVIDER_STATS_WINDOW_DAYS - 1) * DAY_MS);
}

/** Accepted share of the offers customers decided on, as a whole percent; null before any decision. */
export function offerAcceptanceRate(accepted: number, decided: number): number | null {
  if (decided <= 0) return null;
  return Math.round((accepted / decided) * 100);
}

export interface ProviderStats {
  windowDays: number;
  profileViews: number;
  quoteRequests: number;
  offersAccepted: number;
  offersDecided: number;
  acceptanceRate: number | null;
  upcomingBookings: number;
  completedBookings: number;
}

export function toProviderStats(
  views: number | null,
  quoteRequests: number,
  offersAccepted: number,
  offersDecided: number,
  upcomingBookings: number,
  completedBookings: number,
): ProviderStats {
  return {
    windowDays: PROVIDER_STATS_WINDOW_DAYS,
    profileViews: views ?? 0,
    quoteRequests,
    offersAccepted,
    offersDecided,
    acceptanceRate: offerAcceptanceRate(offersAccepted, offersDecided),
    upcomingBookings,
    completedBookings,
  };
}
