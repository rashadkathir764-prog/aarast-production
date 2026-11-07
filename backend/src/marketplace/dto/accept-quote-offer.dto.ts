import { IsInt, IsOptional, Max, Min } from 'class-validator';

/**
 * B-06: the version the customer read. When it is no longer the offer's
 * current version, acceptance is refused with QUOTE_OFFER_CHANGED, so the
 * customer never accepts something he has not seen. The phone always sends it.
 */
export class AcceptQuoteOfferDto {
  @IsInt()
  @Min(1)
  @Max(1_000_000)
  @IsOptional()
  versionNo?: number;
}
