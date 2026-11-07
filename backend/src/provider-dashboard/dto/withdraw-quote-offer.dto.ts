import { IsOptional, IsString } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

/** B-03: why the provider takes the offer back; optional, shown in the conversation. */
export class WithdrawQuoteOfferDto {
  @IsString()
  @MaxCharacters(500)
  @IsOptional()
  reason?: string | null;
}
