import { QuoteRequestStatus } from '@prisma/client';
import { IsBoolean, IsEnum, IsIn, IsOptional, IsString } from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

/** B-05: why a provider declines a request. */
export const QUOTE_DECLINE_REASONS = [
  'BUSY_THAT_DAY',
  'OUT_OF_AREA',
  'NOT_MY_SERVICE',
  'OTHER',
] as const;
export type QuoteDeclineReason = (typeof QUOTE_DECLINE_REASONS)[number];

export class UpdateProviderQuoteStatusDto {
  @IsEnum(QuoteRequestStatus)
  status!: QuoteRequestStatus;

  /** B-05: with REJECTED, why; the customer reads it. */
  @IsOptional()
  @IsIn(QUOTE_DECLINE_REASONS)
  declineReason?: QuoteDeclineReason;

  @IsOptional()
  @IsString()
  @MaxCharacters(500)
  declineMessage?: string;

  /** B-05: with BUSY_THAT_DAY on a dated request, close that day too. */
  @IsOptional()
  @IsBoolean()
  blockDay?: boolean;
}
