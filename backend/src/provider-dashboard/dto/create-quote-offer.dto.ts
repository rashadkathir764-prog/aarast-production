import {
  IsArray,
  IsInt,
  Max,
  MaxLength,
  Min,
  IsNotEmpty,
  IsOptional,
  IsString,
} from 'class-validator';
import { MaxCharacters } from '../../shared-kernel/text/text-length';

// RA-BE-15: the offer is read by the couple and kept in every version, so its
// text has a bound: the title is a package's (create-provider-package.dto.ts),
// the message the phone's field.
export class CreateQuoteOfferDto {
  @IsString()
  @IsOptional()
  @MaxCharacters(160)
  title?: string | null;

  @IsString()
  @IsNotEmpty()
  @MaxCharacters(2000)
  message!: string;

  @IsString()
  @IsNotEmpty()
  amount!: string;

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
}
