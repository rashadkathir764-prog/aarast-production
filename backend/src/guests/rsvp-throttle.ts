import type {
  ThrottlerGetTrackerFunction,
  ThrottlerOptions,
} from "@nestjs/throttler";

/**
 * RA-BE-172: a guest's reply limits are counted for one link on one
 * address, not for one address on one route. Guests behind a shared network
 * (a family on one Wi-Fi, a mobile carrier's gateway) each have their own
 * link and no longer spend one count between them, and a sender who opens
 * many links in a minute is not cut off from the previews of the others.
 */
export const rsvpLinkTracker: ThrottlerGetTrackerFunction = (req) =>
  `${req.ip ?? "unknown"}|${String(req.params?.token ?? "")}`;

/**
 * I-1: the per-link window above is keyed by the token, so one address that
 * tries many well-formed tokens never meets it. This second, named throttler
 * counts the address alone, across the guest routes together.
 */
export const RSVP_ADDRESS_THROTTLER = "rsvpAddress";
export const RSVP_ADDRESS_LIMIT = 300;
const RSVP_ADDRESS_TTL_MS = 60_000;

const rsvpAddressTracker: ThrottlerGetTrackerFunction = (req) =>
  req.ip ?? "unknown";

/**
 * Registered once in the app's throttler list. It only acts on a route that
 * carries `rsvpLinkLimit`, so every other route is untouched by it.
 */
export const rsvpAddressThrottler: ThrottlerOptions = {
  name: RSVP_ADDRESS_THROTTLER,
  ttl: RSVP_ADDRESS_TTL_MS,
  limit: RSVP_ADDRESS_LIMIT,
  getTracker: rsvpAddressTracker,
  // One count for the address over all the guest routes, not one per route.
  generateKey: (_context, tracker, name) => `${name}|${tracker}`,
  skipIf: (context) =>
    !Reflect.getMetadata(
      `THROTTLER:LIMIT${RSVP_ADDRESS_THROTTLER}`,
      context.getHandler(),
    ),
};

/** One route's limits: per link and address, and the address-wide ceiling. */
export function rsvpLinkLimit(limit: number) {
  return {
    default: { limit, ttl: 60_000, getTracker: rsvpLinkTracker },
    [RSVP_ADDRESS_THROTTLER]: {
      limit: RSVP_ADDRESS_LIMIT,
      ttl: RSVP_ADDRESS_TTL_MS,
    },
  };
}
