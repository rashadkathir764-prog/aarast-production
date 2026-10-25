import { IsOptional, IsString, MaxLength } from 'class-validator';

/** B-03: why the provider takes the offer back; optional, shown in the conversation. */
export class WithdrawQuoteOfferDto {
  @IsString()
  @MaxLength(500)
  @IsOptional()
  reason?: string | null;
}
