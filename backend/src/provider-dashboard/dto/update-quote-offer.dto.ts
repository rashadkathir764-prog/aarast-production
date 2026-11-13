import {
  IsArray,
  IsInt,
  Max,
  MaxLength,
  Min,
  IsOptional,
  IsString,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: bounded as the offer is sent (create-quote-offer.dto.ts).
export class UpdateQuoteOfferDto {
  @IsString()
  @IsOptional()
  @MaxCharacters(160)
  title?: string | null;

  @IsString()
  @IsOptional()
  @MaxCharacters(2000)
  message?: string | null;

  @IsString()
  @IsOptional()
  amount?: string | null;

  @IsString()
  @IsOptional()
  @MaxLength(8)
  currency?: string;

  @IsString()
  @IsOptional()
  validUntil?: string | null;

  /** B-07: `[{ label, kind: INCLUDED|EXCLUDED|EXTRA, amount? }]`; checked by the service. */
  @IsOptional()
  @IsArray()
  lines?: unknown[] | null;

  /** B-07/B-23: days after the wedding to deliver (photos, video…). */
  @IsOptional()
  @IsInt()
  @Min(0)
  @Max(365)
  deliveryDays?: number | null;

  /**
   * RA-MO-289: the offer version this edit was made from. Another edit
   * since (his other phone) refuses it with `409 QUOTE_OFFER_CHANGED`, so an
   * old copy never undoes a newer offer. Optional: older phones send none.
   */
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100_000)
  baseVersionNo?: number;
}
