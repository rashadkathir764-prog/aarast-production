import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { QUOTE_REJECT_REASONS } from '../../modules/marketplace/public/quote-offer-versions';

/** B-11: why the customer turns an offer down; all optional. */
export class RejectQuoteOfferDto {
  @IsOptional()
  @IsIn(QUOTE_REJECT_REASONS)
  reason?: (typeof QUOTE_REJECT_REASONS)[number];

  @IsOptional()
  @IsString()
  @MaxLength(500)
  message?: string;
}
