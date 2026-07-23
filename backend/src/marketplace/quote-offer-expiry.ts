import type { QuoteOffer } from "@prisma/client";

type OfferExpiry = Pick<QuoteOffer, "status" | "validUntil">;

export function isQuoteOfferExpired(
  offer: OfferExpiry,
  now = new Date(),
): boolean {
  return (
    offer.status === "PENDING" &&
    offer.validUntil !== null &&
    offer.validUntil.getTime() < now.getTime()
  );
}
