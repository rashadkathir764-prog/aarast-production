import type { ThrottlerGetTrackerFunction } from "@nestjs/throttler";

/**
 * RA-BE-172: a guest's reply limits are counted for one link on one
 * address, not for one address on one route. Guests behind a shared network
 * (a family on one Wi-Fi, a mobile carrier's gateway) each have their own
 * link and no longer spend one count between them, and a sender who opens
 * many links in a minute is not cut off from the previews of the others.
 */
export const rsvpLinkTracker: ThrottlerGetTrackerFunction = (req) =>
  `${req.ip ?? "unknown"}|${String(req.params?.token ?? "")}`;

/** One route's limit, counted per link and address. */
export function rsvpLinkLimit(limit: number) {
  return { default: { limit, ttl: 60_000, getTracker: rsvpLinkTracker } };
}
